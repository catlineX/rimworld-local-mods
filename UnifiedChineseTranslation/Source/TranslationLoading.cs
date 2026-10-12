using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using System.Xml;
using HarmonyLib;
using RimWorld.IO;
using Verse;

namespace Local.XueWen.UnifiedTranslation
{
    // Installed before language loading, not in a late static constructor.
    public sealed class UnifiedTranslationMod : Mod
    {
        public UnifiedTranslationMod(ModContentPack content) : base(content)
        {
            TranslationLoading.Root = content.RootDir;
            var harmony = new Harmony("local.xuewen.unifiedchinesetranslation.loading");
            try
            {
                harmony.Patch(AccessTools.Method(typeof(DefInjectionPackage), "TryAddInjection"),
                    prefix: new HarmonyMethod(typeof(TranslationLoading), "BeforeDef"));
                harmony.Patch(AccessTools.Method(typeof(LoadedLanguage), "LoadFromFile_Keyed"),
                    prefix: new HarmonyMethod(typeof(TranslationLoading), "BeforeKeyed"));
                UpstreamTranslationRepair.Start(content.RootDir,harmony);
            }
            catch (Exception error)
            {
                harmony.UnpatchAll(harmony.Id);
                Log.Warning("[UnifiedChineseTranslation] 覆盖处理未启用，保留原生翻译加载：" + error);
            }
        }
    }

    public static class TranslationLoading
    {
        public static string Root;
        private static readonly List<string> Overrides = new List<string>();
        private static readonly HashSet<string> OwnDefKeys = new HashSet<string>();
        private static readonly ConditionalWeakTable<object, HashSet<string>> SeenOwnKeys = new ConditionalWeakTable<object, HashSet<string>>();
        private static readonly FieldInfo Injections = AccessTools.Field(typeof(DefInjectionPackage), "injections");
        private static readonly FieldInfo DefType = AccessTools.Field(typeof(DefInjectionPackage), "defType");
        private static readonly FieldInfo Keyed = AccessTools.Field(typeof(LoadedLanguage), "keyedReplacements");

        public static bool IsOwnedPath(string root, string path)
        {
            if (String.IsNullOrEmpty(root) || String.IsNullOrEmpty(path)) return false;
            string prefix = Path.GetFullPath(Path.Combine(root, "Modules")).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            string full = Path.GetFullPath(path);
            return full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
                && (full.IndexOf("/Languages/ChineseSimplified/", StringComparison.OrdinalIgnoreCase) >= 0
                    || full.IndexOf("\\Languages\\ChineseSimplified\\", StringComparison.OrdinalIgnoreCase) >= 0);
        }

        // Only remove an exact previous key for this pack's explicit replacement.
        // The original game method still performs syntax/list checks and insertion;
        // later field injection still performs all type, attribute and bounds checks.
        public static void BeforeDef(DefInjectionPackage __instance, VirtualFile __0, string __1)
        {
            try
            {
                if (!IsOwnedPath(Root, __0.FullPath) || Injections == null || DefType == null) return;
                string key = (__1 ?? "").Replace("]", "").Replace('[', '.');
                if (!key.Contains(".")) return;
                string type = ((Type)DefType.GetValue(__instance)).FullName;
                OwnDefKeys.Add(type + "|" + key);
                var entries = (IDictionary)Injections.GetValue(__instance);
                if (!SeenOwnKeys.GetOrCreateValue(entries).Add(key)) return; // Keep real duplicates inside this pack visible.
                if (entries.Contains(key))
                {
                    Overrides.Add("DefInjected " + type + " " + key + " <- " + __0.FullPath);
                    entries.Remove(key);
                }
            }
            catch (Exception error) { Log.Warning("[UnifiedChineseTranslation] 单条覆盖检查失败，继续原生加载：" + error.Message); }
        }

        public static void BeforeKeyed(LoadedLanguage __instance, VirtualFile __0)
        {
            try
            {
                if (!IsOwnedPath(Root, __0.FullPath) || Keyed == null) return;
                // Parse completely before touching the existing dictionary.
                var xml = new XmlDocument();
                xml.LoadXml(__0.ReadAllText());
                if (xml.DocumentElement == null || xml.DocumentElement.Name != "LanguageData") return;
                var keys = new HashSet<string>();
                foreach (XmlNode node in xml.DocumentElement.ChildNodes)
                    if (node.NodeType == XmlNodeType.Element && !keys.Add(node.Name)) return;
                var entries = (IDictionary)Keyed.GetValue(__instance);
                foreach (string key in keys)
                    if (SeenOwnKeys.GetOrCreateValue(entries).Add(key) && entries.Contains(key))
                    {
                        Overrides.Add("Keyed " + key + " <- " + __0.FullPath);
                        entries.Remove(key);
                    }
            }
            catch (Exception error) { Log.Warning("[UnifiedChineseTranslation] 文件覆盖检查失败，继续原生加载：" + error.Message); }
        }

        public static void WriteReport()
        {
            try
            {
                LoadedLanguage language = LanguageDatabase.activeLanguage;
                if (language == null) return;
                var report = new StringBuilder();
                report.AppendLine("UnifiedChineseTranslation 0.1.3 translation diagnostics");
                report.AppendLine("Language: " + language.folderName);
                report.AppendLine("Explicit replacements (not suppressed errors): " + Overrides.Count);
                foreach (string line in Overrides) report.AppendLine(line);
                report.AppendLine("\n=== Upstream translation compatibility decisions ===");
                foreach(string line in UpstreamTranslationRepair.Decisions) report.AppendLine(line);
                report.AppendLine("\n=== Language load errors (all active mods) ===");
                AppendErrors(report, language, "loadErrors");
                report.AppendLine("\n=== Def injection errors (all active mods) ===");
                var packages = (IEnumerable)AccessTools.Field(typeof(LoadedLanguage), "defInjections").GetValue(language);
                int failed = 0;
                foreach (object package in packages)
                {
                    AppendErrors(report, package, "loadErrors");
                    var entries = (IDictionary)Injections.GetValue(package);
                    string type = ((Type)DefType.GetValue(package)).FullName;
                    foreach (DictionaryEntry entry in entries)
                        if (OwnDefKeys.Contains(type + "|" + entry.Key)
                            && !(bool)AccessTools.Field(entry.Value.GetType(), "injected").GetValue(entry.Value))
                        {
                            failed++;
                            report.AppendLine("OWN_UNINJECTED " + type + " " + entry.Key);
                        }
                }
                report.AppendLine("Own uninjected fields: " + failed);
                string directory = "D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-runtime";
                Directory.CreateDirectory(directory);
                string path = Path.Combine(directory, DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + "-" + Guid.NewGuid().ToString("N") + ".txt");
                using (var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.Read))
                using (var writer = new StreamWriter(stream, new UTF8Encoding(false))) writer.Write(report.ToString());
                Log.Message("[UnifiedChineseTranslation] 翻译诊断已导出；本包未成功注入字段=" + failed + "；报告：" + path);
            }
            catch (Exception error) { Log.Warning("[UnifiedChineseTranslation] 诊断报告导出失败（不影响翻译加载）：" + error); }
        }

        private static void AppendErrors(StringBuilder report, object value, string field)
        {
            var errors = (IEnumerable)AccessTools.Field(value.GetType(), field).GetValue(value);
            foreach (object error in errors) report.AppendLine(Convert.ToString(error));
        }
    }

    [StaticConstructorOnStartup]
    public static class TranslationReportStartup
    {
        static TranslationReportStartup() { LongEventHandler.ExecuteWhenFinished(TranslationLoading.WriteReport); }
    }
}
