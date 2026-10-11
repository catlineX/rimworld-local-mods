using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using Verse;

namespace Local.XueWen.GlitterNetChineseFix
{
    [StaticConstructorOnStartup]
    public static class DebugLabels
    {
        private static readonly Dictionary<string, string> Keys = new Dictionary<string, string>
        {
            { "DEBUG Reset System Wake", "Local.GlitterNetChineseFix.Debug.ResetLabel" },
            { "Reset the state of System Wake", "Local.GlitterNetChineseFix.Debug.ResetDesc" },
            { "DEBUG Give random quest", "Local.GlitterNetChineseFix.Debug.QuestLabel" },
            { "Give a random awoken hub quest", "Local.GlitterNetChineseFix.Debug.QuestDesc" },
            { "DEBUG Force default mood", "Local.GlitterNetChineseFix.Debug.MoodLabel" },
            { "Forces this hub to its default mood", "Local.GlitterNetChineseFix.Debug.MoodDesc" },
            { "DEBUG Add 5 trust", "Local.GlitterNetChineseFix.Debug.AddTrustLabel" },
            { "Adds 5 trust to this hub", "Local.GlitterNetChineseFix.Debug.AddTrustDesc" },
            { "DEBUG Remove 5 trust", "Local.GlitterNetChineseFix.Debug.RemoveTrustLabel" },
            { "Removes 5 trust to this hub", "Local.GlitterNetChineseFix.Debug.RemoveTrustDesc" },
            { "DEBUG Dump quest log", "Local.GlitterNetChineseFix.Debug.LogLabel" },
            { "Dumps the quest log", "Local.GlitterNetChineseFix.Debug.LogDesc" }
        };
        static DebugLabels()
        {
            const string id = "local.xuewen.glitternet.zhcnfix.debug";
            Harmony harmony = new Harmony(id);
            try
            {
                Type hub = AccessTools.TypeByName("GlitterNet.BuildingGlitterNetHub");
                if (hub == null) throw new InvalidOperationException("GlitterNet hub type missing.");
                MethodInfo target = null;
                foreach (Type nested in hub.GetNestedTypes(BindingFlags.NonPublic | BindingFlags.Public))
                {
                    if (!nested.Name.StartsWith("<GetGizmos>")) continue;
                    if (target != null) throw new InvalidOperationException("Ambiguous GetGizmos iterator.");
                    target = AccessTools.DeclaredMethod(nested, "MoveNext");
                }
                if (target == null) throw new InvalidOperationException("GetGizmos iterator missing.");
                harmony.Patch(target, transpiler: new HarmonyMethod(typeof(DebugLabels), "Transpiler"));
                Log.Message("[GlitterNetChineseFix] 开发按钮文字汉化已启用；按钮行为不变。");
            }
            catch (Exception exception)
            {
                harmony.UnpatchAll(id);
                Log.Warning("[GlitterNetChineseFix] 开发按钮汉化未应用，普通语言文件仍可使用：" + exception);
            }
        }
        public static string TranslateLiteral(string original)
        {
            string key;
            return Keys.TryGetValue(original, out key) ? Translator.Translate(key).ToString() : original;
        }
        public static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
        {
            List<CodeInstruction> code = new List<CodeInstruction>(instructions);
            int count = 0;
            foreach (CodeInstruction instruction in code)
                if (instruction.opcode == OpCodes.Ldstr && Keys.ContainsKey((string)instruction.operand)) count++;
            if (count != Keys.Count) throw new InvalidOperationException("Debug label shape changed: " + count);
            MethodInfo translate = AccessTools.DeclaredMethod(typeof(DebugLabels), "TranslateLiteral");
            List<CodeInstruction> result = new List<CodeInstruction>();
            foreach (CodeInstruction instruction in code)
            {
                result.Add(instruction);
                if (instruction.opcode == OpCodes.Ldstr && Keys.ContainsKey((string)instruction.operand))
                    result.Add(new CodeInstruction(OpCodes.Call, translate));
            }
            return result;
        }
    }
}

