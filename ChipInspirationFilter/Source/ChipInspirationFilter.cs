using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using RimWorld;
using Verse;

namespace Local.XueWen.ChipInspirationFilter
{
    [StaticConstructorOnStartup]
    public static class Bootstrap
    {
        private const string HarmonyId = "local.xuewen.chipinspirationfilter";

        static Bootstrap()
        {
            Harmony harmony = new Harmony(HarmonyId);
            try
            {
                Type type = AccessTools.TypeByName("Polarisbloc.HediffComp_Inspire");
                MethodInfo target = type == null ? null : AccessTools.DeclaredMethod(type, "Inspire", new Type[] { typeof(Pawn) });
                if (target == null || target.IsStatic || target.ReturnType != typeof(void)
                    || !typeof(HediffComp).IsAssignableFrom(type))
                    throw new InvalidOperationException("Unsupported Polarisbloc chip implementation: Inspire(Pawn) not found.");

                harmony.Patch(target, transpiler: new HarmonyMethod(typeof(ChipFilter), "Transpiler"));
                Log.Message("[ChipInspirationFilter] v1.1.0 已启用：灵感型战术芯片只允许工作狂热和创造灵感；自然灵感不变。");
            }
            catch (Exception exception)
            {
                harmony.UnpatchAll(HarmonyId);
                Log.Error("[ChipInspirationFilter] 补丁未启用，上游逻辑保持原样：" + exception);
            }
        }
    }

    public static class ChipFilter
    {
        public const string ChipDefName = "PolarisCombatChip_Inspiration";
        public const string WorkInspiration = "Frenzy_Work";
        public const string CreativeInspiration = "Inspired_Creativity";

        // Inject only into the chip's private Inspire method, not a global worker.
        public static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
        {
            MethodInfo getter = AccessTools.PropertyGetter(typeof(DefDatabase<InspirationDef>), "AllDefsListForReading");
            MethodInfo filter = AccessTools.DeclaredMethod(typeof(ChipFilter), "FilterCandidates");
            List<CodeInstruction> code = new List<CodeInstruction>(instructions);
            int matches = 0;
            foreach (CodeInstruction instruction in code)
                if (instruction.Calls(getter)) matches++;
            if (getter == null || filter == null || matches != 1)
                throw new InvalidOperationException("Expected exactly one inspiration-list getter in chip Inspire; found " + matches);

            List<CodeInstruction> result = new List<CodeInstruction>();
            foreach (CodeInstruction instruction in code)
            {
                result.Add(instruction);
                if (instruction.Calls(getter))
                {
                    result.Add(new CodeInstruction(OpCodes.Ldarg_0));
                    result.Add(new CodeInstruction(OpCodes.Call, filter));
                }
            }
            return result;
        }

        public static bool ShouldExclude(string sourceHediffDefName, string inspirationDefName)
        {
            return sourceHediffDefName == ChipDefName
                && inspirationDefName != WorkInspiration
                && inspirationDefName != CreativeInspiration;
        }

        public static List<InspirationDef> FilterCandidates(List<InspirationDef> candidates, HediffComp source)
        {
            string sourceName = source == null || source.parent == null || source.parent.def == null
                ? null : source.parent.def.defName;
            if (candidates == null || sourceName != ChipDefName) return candidates;

            // Never mutate DefDatabase's shared list: natural and other sources keep it.
            List<InspirationDef> filtered = new List<InspirationDef>(candidates.Count);
            foreach (InspirationDef candidate in candidates)
                if (candidate != null && !ShouldExclude(sourceName, candidate.defName))
                    filtered.Add(candidate);
            return filtered;
        }
    }
}
