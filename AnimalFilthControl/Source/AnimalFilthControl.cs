using System;
using RimWorld;
using UnityEngine;
using Verse;

namespace XueWen.AnimalFilthControl
{
    public sealed class FilthSettings : ModSettings
    {
        public float multiplier = 0.10f;

        public override void ExposeData()
        {
            Scribe_Values.Look(ref multiplier, "animalFilthMultiplier", 0.10f);
            if (float.IsNaN(multiplier) || float.IsInfinity(multiplier)) multiplier = 0.10f;
            multiplier = Mathf.Clamp(multiplier, 0f, 2f);
        }
    }

    public sealed class AnimalFilthControlMod : Mod
    {
        public static FilthSettings Settings;
        public AnimalFilthControlMod(ModContentPack content) : base(content)
        {
            Settings = GetSettings<FilthSettings>();
        }

        public override string SettingsCategory() { return "动物污物系数调整"; }

        public override void DoSettingsWindowContents(Rect inRect)
        {
            Listing_Standard ui = new Listing_Standard();
            ui.Begin(inRect);
            ui.Label("动物污物产生系数：" + Settings.multiplier.ToString("P0"));
            Settings.multiplier = Mathf.Round(ui.Slider(Settings.multiplier, 0f, 2f) * 100f) / 100f;
            ui.Gap();
            ui.Label("原有污物速率 × 此系数。10% 表示产生速率降为原来的十分之一。");
            ui.Label("0% 停止通过 FilthRate 属性生成的新污物；100% 保持原速率。");
            ui.Label("适用于所有动物及采用原版属性的模组动物。人类、血迹和动物产物不受影响。");
            ui.Label("已有污物仍需清扫。参数改变后等待属性缓存刷新；如显示未更新，可重新加载游戏。");
            ui.Gap();
            if (ui.ButtonText("停止产生：0%")) Settings.multiplier = 0f;
            if (ui.ButtonText("大幅减少：10%（默认）")) Settings.multiplier = 0.10f;
            if (ui.ButtonText("减少：25%")) Settings.multiplier = 0.25f;
            if (ui.ButtonText("减半：50%")) Settings.multiplier = 0.50f;
            if (ui.ButtonText("恢复原速率：100%")) Settings.multiplier = 1f;
            ui.End();
        }
    }

    public sealed class StatPart_AnimalFilthScale : StatPart
    {
        private static bool IsAnimal(StatRequest req)
        {
            Pawn pawn = req.Thing as Pawn;
            if (pawn != null) return pawn.RaceProps != null && pawn.RaceProps.Animal;
            ThingDef def = req.Def as ThingDef;
            return def != null && def.race != null && def.race.Animal;
        }

        private static float Multiplier
        {
            get { return AnimalFilthControlMod.Settings == null ? 0.10f : AnimalFilthControlMod.Settings.multiplier; }
        }

        public override void TransformValue(StatRequest req, ref float val)
        {
            if (IsAnimal(req)) val *= Multiplier;
        }

        public override string ExplanationPart(StatRequest req)
        {
            return IsAnimal(req) ? "动物污物系数调整：×" + Multiplier.ToString("P0") : null;
        }
    }
}
