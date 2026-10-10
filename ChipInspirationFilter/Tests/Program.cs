using System;
using System.Collections.Generic;
using System.Reflection.Emit;
using HarmonyLib;
using RimWorld;
using Verse;
using Local.XueWen.ChipInspirationFilter;

public static class Program
{
    private static int passed;
    private static void Check(bool value, string name)
    {
        if (!value) throw new Exception("FAIL: " + name);
        passed++; Console.WriteLine("PASS: " + name);
    }
    public static void Main()
    {
        InspirationDef shoot = new InspirationDef { defName = "Frenzy_Shoot" };
        InspirationDef work = new InspirationDef { defName = "Frenzy_Work" };
        InspirationDef creative = new InspirationDef { defName = "Inspired_Creativity" };
        List<InspirationDef> original = new List<InspirationDef> { shoot, work, creative };
        HediffComp chip = new HediffComp { parent = new Hediff { def = new HediffDef { defName = ChipFilter.ChipDefName } } };
        List<InspirationDef> filtered = ChipFilter.FilterCandidates(original, chip);
        Check(filtered.Count == 2 && !filtered.Contains(shoot), "chip shooting candidate removed");
        Check(filtered[0] == work && filtered[1] == creative, "other candidates retain order and objects");
        Check(original.Count == 3 && original[0] == shoot, "global list unchanged for natural/other inspiration");
        Check(!object.ReferenceEquals(original, filtered), "chip receives independent candidate list");
        Check(object.ReferenceEquals(original, ChipFilter.FilterCandidates(original, null)), "natural/no chip source untouched");
        HediffComp other = new HediffComp { parent = new Hediff { def = new HediffDef { defName = "SomeOtherImplant" } } };
        Check(object.ReferenceEquals(original, ChipFilter.FilterCandidates(original, other)), "other implant reusing component untouched");
        Check(object.ReferenceEquals(original, ChipFilter.FilterCandidates(original, new HediffComp())), "missing parent untouched");
        Check(ChipFilter.FilterCandidates(null, chip) == null, "null input preserved");
        Check(ChipFilter.FilterCandidates(new List<InspirationDef> { shoot }, chip).Count == 0, "shoot-only pool becomes empty, no forced replacement");
        Check(!ChipFilter.ShouldExclude(ChipFilter.ChipDefName, "Inspired_Trade"), "trade inspiration allowed");
        Check(!ChipFilter.ShouldExclude("OtherSource", "Frenzy_Shoot"), "shoot inspiration allowed outside designated chip");
        var getter = AccessTools.PropertyGetter(typeof(DefDatabase<InspirationDef>), "AllDefsListForReading");
        CodeInstruction begin = new CodeInstruction(OpCodes.Nop);
        CodeInstruction read = new CodeInstruction(OpCodes.Call, getter);
        CodeInstruction end = new CodeInstruction(OpCodes.Ret);
        List<CodeInstruction> output = new List<CodeInstruction>(ChipFilter.Transpiler(new[] { begin, read, end }));
        Check(output.Count == 5 && output[0] == begin && output[1] == read && output[4] == end, "original instructions retained");
        Check(output[2].opcode == OpCodes.Ldarg_0 && output[3].Calls(AccessTools.DeclaredMethod(typeof(ChipFilter), "FilterCandidates")), "source and filter inserted after list getter");
        bool rejected = false;
        try { ChipFilter.Transpiler(new[] { begin, end }); } catch (InvalidOperationException) { rejected = true; }
        Check(rejected, "changed upstream with no getter rejected");
        rejected = false;
        try { ChipFilter.Transpiler(new[] { read, read, end }); } catch (InvalidOperationException) { rejected = true; }
        Check(rejected, "ambiguous upstream with two getters rejected");
        Console.WriteLine("Tests passed: " + passed);
    }
}
