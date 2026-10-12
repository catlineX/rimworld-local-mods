using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Local.XueWen.UnifiedTranslation;
namespace HarmonyLib {
 public class Harmony{public void Patch(MethodInfo m,HarmonyMethod prefix=null,HarmonyMethod postfix=null){}}
 public class HarmonyMethod{public HarmonyMethod(Type t,string n){}}
 public static class AccessTools{
 public static FieldInfo Field(Type t,string n){return t.GetField(n,(BindingFlags)61);}
 public static MethodInfo Method(Type t,string n){return t.GetMethod(n,(BindingFlags)61);}
 public static MethodInfo PropertyGetter(Type t,string n){return t.GetProperty(n).GetGetMethod();}}
}
namespace RimWorld.IO{
 public abstract class VirtualDirectory{
 public abstract string Name{get;} public abstract string FullPath{get;} public abstract bool Exists{get;}
 public abstract VirtualDirectory GetDirectory(string n);public abstract VirtualFile GetFile(string n);
 public abstract IEnumerable<VirtualDirectory> GetDirectories(string p,SearchOption o);public abstract IEnumerable<VirtualFile> GetFiles(string p,SearchOption o);}
 public abstract class VirtualFile{
 public abstract string Name{get;} public abstract string FullPath{get;} public abstract bool Exists{get;}public abstract long Length{get;}
 public abstract Stream CreateReadStream();public abstract string ReadAllText();public abstract string[] ReadAllLines();public abstract byte[] ReadAllBytes();}
}
namespace Verse{
 public class ModContentPack{}
 public static class Log{public static void Warning(string s){throw new Exception(s);}}
 public static class GenDefDatabase{public static readonly HashSet<string> Defs=new HashSet<string>();public static object GetDefSilentFail(Type t,string n,bool b){return Defs.Contains(n)?new object():null;}}
 public class LoadedLanguage{public string folderName="ChineseSimplified";public ArrayList defInjections=new ArrayList();}
 public class DefInjectionPackage{
 public Type defType;public Hashtable injections=new Hashtable();public DefInjectionPackage(Type t){defType=t;}
 public static readonly HashSet<string> Valid=new HashSet<string>();public static int Validations;
 public bool SetDefFieldAtPath(Type t,string p,object v,Type ft,bool error,string file,bool placeholder,out string n,out string s,out string r,out IEnumerable<string> list){
 if(!placeholder)throw new Exception("Validation attempted to write a Def");Validations++;n=s=r=null;list=null;return Valid.Contains(p);}}
}
public class TestDef{}
public class TestInjection{public string path,nonBackCompatiblePath,fileSource="Test.xml",injection="译文";public List<string> fullListInjection;public bool injected;}
public static class UpstreamRepairTests{
 static int checks;static void Check(bool b,string n){checks++;if(!b)throw new Exception(n);}
 static void Known(string key){((HashSet<string>)typeof(UpstreamTranslationRepair).GetField("Known",(BindingFlags)40).GetValue(null)).Add(typeof(TestDef).FullName+"|Test.xml|"+key);}
 static TestInjection Entry(string p){return new TestInjection{path=p,nonBackCompatiblePath=p};}
 public static void Main(){
 var lang=new Verse.LoadedLanguage();var pack=new Verse.DefInjectionPackage(typeof(TestDef));lang.defInjections.Add(pack);
 string old="Building_Blueprint.label",next="Blueprint_Building.label";Known(old);pack.injections[old]=Entry(old);
 Verse.GenDefDatabase.Defs.Add("Blueprint_Building");Verse.DefInjectionPackage.Valid.Add(next);
 UpstreamTranslationRepair.BeforeEarly(lang);Check(pack.injections.Contains(old),"defer implied targets");
 UpstreamTranslationRepair.BeforeLate(lang);Check(!pack.injections.Contains(old)&&pack.injections.Contains(next),"verified blueprint rename");
 Check(((TestInjection)pack.injections[next]).injection=="译文","preserve text");
 Known("Removed.label");pack.injections["Removed.label"]=Entry("Removed.label");
 UpstreamTranslationRepair.BeforeLate(lang);Check(!pack.injections.Contains("Removed.label"),"known absent translation made conditional");
 pack.injections["Unknown.label"]=Entry("Unknown.label");UpstreamTranslationRepair.BeforeLate(lang);Check(pack.injections.Contains("Unknown.label"),"unknown errors remain visible");
 Known("Exists.bad.path");pack.injections["Exists.bad.path"]=Entry("Exists.bad.path");Verse.GenDefDatabase.Defs.Add("Exists");
 UpstreamTranslationRepair.BeforeEarly(lang);Check(!pack.injections.Contains("Exists.bad.path"),"known invalid path made conditional");
 lang.folderName="English";pack.injections["Removed.label"]=Entry("Removed.label");UpstreamTranslationRepair.BeforeLate(lang);Check(pack.injections.Contains("Removed.label"),"English untouched");
 Check(Verse.DefInjectionPackage.Validations>0,"native validation invoked in placeholder mode");
 Check(UpstreamTranslationRepair.Decisions.Count==3,"each action recorded");
 Console.WriteLine("PASS: "+checks+" upstream repair stand-in checks; no game objects written");}
}
