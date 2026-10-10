// Test-only substitutes. Never compiled into or deployed with the runtime DLL.
using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
namespace Verse
{
    public class Pawn { }
    public class HediffDef { public string defName; }
    public class Hediff { public HediffDef def; }
    public class HediffComp { public Hediff parent; }
    public class StaticConstructorOnStartupAttribute : Attribute { }
    public static class Log { public static void Message(string s) { } public static void Error(string s) { } }
    public static class DefDatabase<T>
    {
        private static readonly List<T> defs = new List<T>();
        public static List<T> AllDefsListForReading { get { return defs; } }
    }
}
namespace RimWorld { public class InspirationDef { public string defName; } }
namespace HarmonyLib
{
    public class Harmony
    {
        public Harmony(string id) { }
        public void Patch(MethodInfo original, HarmonyMethod transpiler) { }
        public void UnpatchAll(string id) { }
    }
    public class HarmonyMethod { public HarmonyMethod(Type t, string name) { } }
    public static class AccessTools
    {
        public static Type TypeByName(string name) { return null; }
        public static MethodInfo DeclaredMethod(Type t, string name, Type[] args = null)
        {
            const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance | BindingFlags.DeclaredOnly;
            return args == null ? t.GetMethod(name, flags) : t.GetMethod(name, flags, null, args, null);
        }
        public static MethodInfo PropertyGetter(Type t, string name) { return t.GetProperty(name).GetGetMethod(); }
    }
    public class CodeInstruction
    {
        public OpCode opcode; public object operand;
        public CodeInstruction(OpCode op, object value = null) { opcode = op; operand = value; }
        public bool Calls(MethodInfo method) { return method != null && (opcode == OpCodes.Call || opcode == OpCodes.Callvirt) && object.Equals(operand, method); }
    }
}
