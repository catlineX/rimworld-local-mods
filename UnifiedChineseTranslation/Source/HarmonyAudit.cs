using System;
using System.Reflection;
using System.Text;
using HarmonyLib;
using Verse;
namespace Local.XueWen.UnifiedTranslation
{
    // Read-only inventory. No new patches and no assembly loading/replacement.
    public static class HarmonyAudit
    {
        public static void Append(StringBuilder text)
        {
            try
            {
                text.AppendLine("=== Harmony runtime audit ===");
                text.AppendLine("Translation uses: "+typeof(Harmony).Assembly.FullName+" @ "+typeof(Harmony).Assembly.Location);
                foreach(Assembly assembly in AppDomain.CurrentDomain.GetAssemblies())
                    if(assembly.GetName().Name=="0Harmony")text.AppendLine("Loaded Harmony: "+assembly.FullName+" @ "+assembly.Location);
                Dump(text,AccessTools.Method(typeof(DefInjectionPackage),"TryAddInjection"));
                Dump(text,AccessTools.Method(typeof(LoadedLanguage),"LoadFromFile_Keyed"));
                Dump(text,AccessTools.PropertyGetter(typeof(LoadedLanguage),"AllDirectories"));
                Dump(text,AccessTools.Method(typeof(LoadedLanguage),"InjectIntoData_BeforeImpliedDefs"));
                Dump(text,AccessTools.Method(typeof(LoadedLanguage),"InjectIntoData_AfterImpliedDefs"));
                Type hub=AccessTools.TypeByName("GlitterNet.BuildingGlitterNetHub");
                if(hub!=null)foreach(Type nested in hub.GetNestedTypes(BindingFlags.Public|BindingFlags.NonPublic))
                    if(nested.Name.StartsWith("<GetGizmos>"))Dump(text,AccessTools.DeclaredMethod(nested,"MoveNext"));
            }
            catch(Exception error){text.AppendLine("Harmony audit incomplete: "+error.Message);}
        }
        private static void Dump(StringBuilder text,MethodBase method)
        {
            if(method==null)return;
            text.AppendLine("Patch target: "+method.DeclaringType.FullName+"."+method.Name);
            var info=Harmony.GetPatchInfo(method);if(info==null)return;
            foreach(var patch in info.Prefixes)text.AppendLine(" prefix "+patch.owner+" "+patch.PatchMethod);
            foreach(var patch in info.Postfixes)text.AppendLine(" postfix "+patch.owner+" "+patch.PatchMethod);
            foreach(var patch in info.Transpilers)text.AppendLine(" transpiler "+patch.owner+" "+patch.PatchMethod);
            foreach(var patch in info.Finalizers)text.AppendLine(" finalizer "+patch.owner+" "+patch.PatchMethod);
            // Query each already loaded Harmony version, without loading another DLL.
            foreach(Assembly assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                if(assembly.GetName().Name!="0Harmony" || assembly==typeof(Harmony).Assembly)continue;
                try
                {
                    Type harmony=assembly.GetType("HarmonyLib.Harmony");if(harmony==null)continue;
                    MethodInfo query=harmony.GetMethod("GetPatchInfo",BindingFlags.Public|BindingFlags.Static,null,new Type[]{typeof(MethodBase)},null);
                    if(query==null)continue;object other=query.Invoke(null,new object[]{method});if(other==null)continue;
                    PropertyInfo owners=other.GetType().GetProperty("Owners");if(owners==null)continue;
                    foreach(object owner in (System.Collections.IEnumerable)owners.GetValue(other,null))
                        text.AppendLine(" other-version owner "+assembly.GetName().Version+" "+owner);
                }
                catch(Exception error){text.AppendLine("Other Harmony inventory unavailable: "+error.Message);}
            }
        }
    }
}
