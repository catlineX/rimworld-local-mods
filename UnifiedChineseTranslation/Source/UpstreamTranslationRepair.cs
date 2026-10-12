using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using System.Xml;
using HarmonyLib;
using RimWorld.IO;
using Verse;

namespace Local.XueWen.UnifiedTranslation
{
    // Translation-only compatibility. Never modify Defs, source files or saves.
    public static class UpstreamTranslationRepair
    {
        private static readonly HashSet<string> Known = new HashSet<string>();
        public static readonly List<string> Decisions = new List<string>();
        private static readonly Dictionary<string,string> Routes = new Dictionary<string,string> {
            {"3056996662|MarkerDef", "MarkThatPawn.MarkerDef"}
        };
        private static readonly FieldInfo Packages=AccessTools.Field(typeof(LoadedLanguage),"defInjections");
        private static readonly FieldInfo TypeField=AccessTools.Field(typeof(DefInjectionPackage),"defType");
        private static readonly FieldInfo Entries=AccessTools.Field(typeof(DefInjectionPackage),"injections");
        private static readonly FieldInfo Errors=AccessTools.Field(typeof(DefInjectionPackage),"loadErrors");
        private static readonly MethodInfo Check=AccessTools.Method(typeof(DefInjectionPackage),"SetDefFieldAtPath");

        public static void Start(string root, Harmony harmony)
        {
            var xml=new XmlDocument(); xml.Load(Path.Combine(root,"Repairs/KnownErrors.xml"));
            foreach(XmlNode n in xml.SelectNodes("/repairs/entry"))
                Known.Add(n.Attributes["type"].Value+"|"+n.Attributes["file"].Value+"|"+n.Attributes["key"].Value);
            harmony.Patch(AccessTools.PropertyGetter(typeof(LoadedLanguage),"AllDirectories"),
                postfix:new HarmonyMethod(typeof(UpstreamTranslationRepair),"WrapDirectories"));
            harmony.Patch(AccessTools.Method(typeof(LoadedLanguage),"InjectIntoData_BeforeImpliedDefs"),
                prefix:new HarmonyMethod(typeof(UpstreamTranslationRepair),"BeforeEarly"));
            harmony.Patch(AccessTools.Method(typeof(LoadedLanguage),"InjectIntoData_AfterImpliedDefs"),
                prefix:new HarmonyMethod(typeof(UpstreamTranslationRepair),"BeforeLate"));
        }
        public static void WrapDirectories(LoadedLanguage __instance, ref IEnumerable<Tuple<VirtualDirectory,ModContentPack,string>> __result)
        {
            if(!__instance.folderName.StartsWith("ChineseSimplified",StringComparison.OrdinalIgnoreCase)) return;
            var list=new List<Tuple<VirtualDirectory,ModContentPack,string>>();
            foreach(var tuple in __result)
                list.Add(tuple.Item1.FullPath.Replace('\\','/').Contains("/294100/3056996662/")
                    ? Tuple.Create<VirtualDirectory,ModContentPack,string>(new RoutedDirectory(tuple.Item1,null),tuple.Item2,tuple.Item3) : tuple);
            __result=list;
        }
        public static void BeforeEarly(LoadedLanguage __instance) { SafeRepair(__instance,false); }
        public static void BeforeLate(LoadedLanguage __instance) { SafeRepair(__instance,true); }
        private static void SafeRepair(LoadedLanguage language,bool late)
        {
            try{Repair(language,late);}
            catch(Exception error){Log.Warning("[UnifiedChineseTranslation] 旧汉化适配未完成，保留原生检查："+error);}
        }

        private static bool Validate(Type type,string path,object value,string source)
        {
            // isPlaceholder=true is the game's validation path: no setter is executed.
            var probe=new DefInjectionPackage(type);
            var args=new object[]{type,path,value,value is string ? typeof(string) : typeof(List<string>),true,source,true,null,null,null,null};
            // The return value means "a value was injected", NOT "the path is valid".
            // In placeholder mode a valid string path can return false without errors.
            Check.Invoke(probe,args);
            return ((ICollection)Errors.GetValue(probe)).Count==0;
        }
        private static object Field(object entry,string name) {return AccessTools.Field(entry.GetType(),name).GetValue(entry);}
        private static void Set(object entry,string name,object value) {AccessTools.Field(entry.GetType(),name).SetValue(entry,value);}
        private static object Translation(object entry)
        { return Field(entry,"fullListInjection") ?? Field(entry,"injection"); }
        private static string Candidate(string key)
        {
            int dot=key.IndexOf('.');if(dot<0)return key;
            string def=key.Substring(0,dot),rest=key.Substring(dot);
            if(def.EndsWith("_Blueprint_Install"))return "Blueprint_Install_"+def.Substring(0,def.Length-18)+rest;
            if(def.EndsWith("_Blueprint"))return "Blueprint_"+def.Substring(0,def.Length-10)+rest;
            if(def.EndsWith("_Frame"))return "Frame_"+def.Substring(0,def.Length-6)+rest;
            return key;
        }
        private static void Repair(LoadedLanguage language,bool late)
        {
            if(!language.folderName.StartsWith("ChineseSimplified",StringComparison.OrdinalIgnoreCase))return;
            var packages=(IList)Packages.GetValue(language);
            // Snapshot: a corrected category can require a package not present previously.
            var snapshot=new List<object>();foreach(object p in packages)snapshot.Add(p);
            foreach(object package in snapshot)
            {
                Type type=(Type)TypeField.GetValue(package);var entries=(IDictionary)Entries.GetValue(package);
                var keys=new List<object>();foreach(object key in entries.Keys)keys.Add(key);
                foreach(object raw in keys)
                {
                    string key=(string)raw;object entry=entries[key];string source=(string)Field(entry,"fileSource");
                    bool routed=source.StartsWith("UCT_ROUTED:",StringComparison.Ordinal);
                    if(!routed && !Known.Contains(type.FullName+"|"+source+"|"+key))continue;
                    // Missing implied definitions are deferred until AFTER implied generation.
                    string defName=key.Split('.')[0];
                    if(!late && GenDefDatabase.GetDefSilentFail(type,defName,false)==null)continue;
                    if(Validate(type,key,Translation(entry),source))continue;
                    string candidate=Candidate(key);Type targetType=type;
                    bool fixedPath=(candidate!=key || targetType!=type) && Validate(targetType,candidate,Translation(entry),source);
                    if(fixedPath)
                    {
                        object target=null;foreach(object p in packages)if((Type)TypeField.GetValue(p)==targetType){target=p;break;}
                        if(target==null){target=new DefInjectionPackage(targetType);packages.Add(target);}
                        var dest=(IDictionary)Entries.GetValue(target);
                        // Existing valid translation wins; never replace it with legacy data.
                        if(!dest.Contains(candidate))
                        {
                            Set(entry,"path",candidate);Set(entry,"nonBackCompatiblePath",candidate);Set(entry,"injected",false);
                            dest[candidate]=entry;
                        }
                        entries.Remove(key);Decisions.Add("RELOCATED "+type.FullName+" "+key+" -> "+targetType.FullName+" "+candidate+" ("+source+")");
                    }
                    else
                    {
                        entries.Remove(key);
                        Decisions.Add("INACTIVE_LEGACY_TRANSLATION "+type.FullName+" "+key+" ("+source+") - target absent or invalid; original text retained on disk");
                    }
                }
            }
        }

        private sealed class RoutedDirectory : VirtualDirectory
        {
            private readonly VirtualDirectory original;private readonly string alias;
            public RoutedDirectory(VirtualDirectory original,string alias){this.original=original;this.alias=alias;}
            public override string Name {get{return alias ?? original.Name;}}
            public override string FullPath {get{return original.FullPath;}}
            public override bool Exists {get{return original.Exists;}}
            public override VirtualDirectory GetDirectory(string name){return Wrap(original.GetDirectory(name));}
            public override VirtualFile GetFile(string name){return WrapFile(original.GetFile(name));}
            public override IEnumerable<VirtualDirectory> GetDirectories(string pattern,SearchOption option)
            {foreach(var d in original.GetDirectories(pattern,option))yield return Wrap(d);}
            public override IEnumerable<VirtualFile> GetFiles(string pattern,SearchOption option)
            {foreach(var f in original.GetFiles(pattern,option))yield return WrapFile(f);}
            private static string Route(string path,string name)
            {
                foreach(var item in Routes)
                {
                    string[] parts=item.Key.Split('|');
                    if(name==parts[1] && path.Replace('\\','/').Contains("/294100/"+parts[0]+"/"))return item.Value;
                }
                return null;
            }
            private static VirtualDirectory Wrap(VirtualDirectory d){return new RoutedDirectory(d,Route(d.FullPath,d.Name));}
            private static VirtualFile WrapFile(VirtualFile f)
            {
                string dir=Path.GetDirectoryName(f.FullPath);string name=Path.GetFileName(dir);
                return Route(dir,name)==null ? f : new RoutedFile(f);
            }
        }
        private sealed class RoutedFile : VirtualFile
        {
            private readonly VirtualFile original;
            public RoutedFile(VirtualFile original){this.original=original;}
            public override string Name {get{return "UCT_ROUTED:"+original.Name;}}
            public override string FullPath {get{return original.FullPath;}}
            public override bool Exists {get{return original.Exists;}}
            public override long Length {get{return original.Length;}}
            public override Stream CreateReadStream(){return original.CreateReadStream();}
            public override string ReadAllText(){return original.ReadAllText();}
            public override string[] ReadAllLines(){return original.ReadAllLines();}
            public override byte[] ReadAllBytes(){return original.ReadAllBytes();}
        }
    }
}
