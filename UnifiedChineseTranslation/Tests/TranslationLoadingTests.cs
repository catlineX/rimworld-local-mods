// Isolated stand-ins: do not load or execute game/Unity assemblies.
using System;
using System.Collections.Generic;
using System.Reflection;
using Local.XueWen.UnifiedTranslation;

namespace HarmonyLib
{
    public class Harmony { public string Id; public Harmony(string id) { Id=id; } public void Patch(MethodInfo method, HarmonyMethod prefix) {} public void UnpatchAll(string id) {} }
    public class HarmonyMethod { public HarmonyMethod(Type type, string name) {} }
    public static class AccessTools
    {
        public static FieldInfo Field(Type type, string name) { return type.GetField(name, (BindingFlags)61); }
        public static MethodInfo Method(Type type, string name) { return type.GetMethod(name, (BindingFlags)61); }
    }
}
namespace RimWorld.IO
{
    public class VirtualFile { public string FullPath; public string Text; public string ReadAllText() { return Text; } }
}
namespace Verse
{
    public class Mod { public Mod(ModContentPack pack) {} }
    public class ModContentPack { public string RootDir; }
    public class DefInjectionPackage { public Type defType=typeof(string); public Dictionary<string,object> injections=new Dictionary<string,object>(); public List<string> loadErrors=new List<string>(); }
    public class LoadedLanguage { public string folderName; public Dictionary<string,object> keyedReplacements=new Dictionary<string,object>(); public List<string> loadErrors=new List<string>(); public List<DefInjectionPackage> defInjections=new List<DefInjectionPackage>(); }
    public static class LanguageDatabase { public static LoadedLanguage activeLanguage; }
    public static class Log { public static void Warning(string value) {} public static void Message(string value) {} }
    public class StaticConstructorOnStartupAttribute : Attribute {}
    public static class LongEventHandler { public static void ExecuteWhenFinished(Action value) {} }
}
namespace Local.XueWen.UnifiedTranslation
{
    public static class UpstreamTranslationRepair
    {
        public static readonly List<string> Decisions=new List<string>();
        public static void Start(string root,HarmonyLib.Harmony harmony) {}
    }
}
public static class TranslationLoadingTests
{
    private static int checks;
    private static void Check(bool passed, string name) { checks++; if (!passed) throw new Exception(name); }
    public static void Main()
    {
        const string root="D:/pack";
        const string own=root+"/Modules/Test/Languages/ChineseSimplified/Keyed/test.xml";
        TranslationLoading.Root=root;
        Check(TranslationLoading.IsOwnedPath(root, own), "own module accepted");
        Check(!TranslationLoading.IsOwnedPath(root, "D:/pack-other/Modules/Test/Languages/ChineseSimplified/Keyed/test.xml"), "sibling excluded");
        Check(!TranslationLoading.IsOwnedPath(root, root+"/Modules/../Languages/ChineseSimplified/Keyed/test.xml"), "traversal excluded");
        Check(!TranslationLoading.IsOwnedPath(root, root+"/Modules/Test/Languages/English/Keyed/test.xml"), "English excluded");
        Check(!TranslationLoading.IsOwnedPath(root, null), "null excluded");
        var file=new RimWorld.IO.VirtualFile { FullPath=own, Text="<LanguageData><A>new</A><B>new</B></LanguageData>" };
        var language=new Verse.LoadedLanguage();
        language.keyedReplacements["A"]="old"; language.keyedReplacements["Keep"]="keep";
        TranslationLoading.BeforeKeyed(language,file);
        Check(!language.keyedReplacements.ContainsKey("A"), "own exact override prepared");
        Check(language.keyedReplacements.ContainsKey("Keep"), "unrelated keyed preserved");
        language.keyedReplacements["A"]="old";
        file.Text="<LanguageData><A>broken";
        TranslationLoading.BeforeKeyed(language,file);
        Check(language.keyedReplacements.ContainsKey("A"), "malformed XML preserves previous text");
        file.Text="<LanguageData><A>x</A><A>y</A></LanguageData>";
        TranslationLoading.BeforeKeyed(language,file);
        Check(language.keyedReplacements.ContainsKey("A"), "same-file duplicate not hidden");
        file.Text="<Wrong><A>x</A></Wrong>";
        TranslationLoading.BeforeKeyed(language,file);
        Check(language.keyedReplacements.ContainsKey("A"), "wrong root preserves previous text");
        file.FullPath="D:/other/Languages/ChineseSimplified/test.xml";
        file.Text="<LanguageData><A>x</A></LanguageData>";
        TranslationLoading.BeforeKeyed(language,file);
        Check(language.keyedReplacements.ContainsKey("A"), "other mod untouched");
        var package=new Verse.DefInjectionPackage();
        package.injections["A.label"]="old"; package.injections["B.label"]="keep";
        TranslationLoading.BeforeDef(package,file,"A.label");
        Check(package.injections.ContainsKey("A.label"), "other Def mod untouched");
        file.FullPath=own;
        TranslationLoading.BeforeDef(package,file,"A.label");
        Check(!package.injections.ContainsKey("A.label"), "own exact Def override prepared");
        Check(package.injections.ContainsKey("B.label"), "other Def key preserved");
        package.injections["NoDot"]="keep";
        TranslationLoading.BeforeDef(package,file,"NoDot");
        Check(package.injections.ContainsKey("NoDot"), "invalid Def syntax left for native checks");
        package.injections["A.list.0.label"]="old";
        TranslationLoading.BeforeDef(package,file,"A.list[0].label");
        Check(!package.injections.ContainsKey("A.list.0.label"), "native bracket normalization matched");
        package.injections["A.label"]="own-first";
        TranslationLoading.BeforeDef(package,file,"A.label");
        Check(package.injections.ContainsKey("A.label"), "same-pack Def duplicate left for native checks");
        language.keyedReplacements["A"]="own-first";
        file.Text="<LanguageData><A>second</A></LanguageData>";
        TranslationLoading.BeforeKeyed(language,file);
        Check(language.keyedReplacements.ContainsKey("A"), "same-pack cross-file Keyed duplicate left for native checks");
        Console.WriteLine("PASS: "+checks+" scoped translation-loading checks (stand-ins, not game runtime)");
    }
}
