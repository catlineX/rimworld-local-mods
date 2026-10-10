# 验证记录 — 2026-10-10

本文为 1.0.0 历史验证记录；1.1.0 见 `VALIDATION-1.1.0.md`。

- 当前游戏 Managed + 已安装 Harmony 编译：通过。
- 模组 XML、packageId、1.6 声明、程序集元数据：通过。
- 替身自动测试：15/15 通过，涵盖来源限定、射击候选过滤、其他候选不变、共享列表不变、空列表与错误 IL 拒绝。
- 实际上游 `Polarisbloc.HediffComp_Inspire.Inspire(Pawn)` IL：仅一处 `DefDatabase<InspirationDef>.AllDefsListForReading` getter，返回 `List<InspirationDef>`，与注入要求匹配；保留后续资格筛选、权重和 TryStartInspiration。
- 补丁 DLL SHA256：`7100722EE6A71DA4ED00CF2F10FC7DF47D335C553B24EEF6BB89F6B11290B73F`。
- 核对时上游 1.6 Polarisbloc.dll SHA256：`CD0C6C4312BFAF17F61740161157C8B0C51C5F7C1A511242F6C047112032D802`。
- 真实游戏启动、Harmony 在 Unity/Mono 中应用补丁、读档与芯片触发：尚未验证。

## 独立备份

工程编辑前备份：`D:/learn/openCode/content/game-data/rimworld/backups/20261010-231418-ChipInspirationFilter-before-engineering-67dd2f`。

包含注册表和构建工具原文件及 SHA256 清单；同时记录新模组源码/部署目录当时不存在。

构建前备份：`D:/learn/openCode/content/game-data/rimworld/backups/20261010-231551-ChipInspirationFilter-before-build-58eaab`。

部署由工作流另行生成独立备份与校验清单。游戏运行时不会执行部署或覆盖启用列表。

## 游戏内检查

1. 启用本模组并排列在 Harmony 和天轴 Core LAB tmp port 后，重启。
2. 检查日志的 `[ChipInspirationFilter] 已启用` 标识。
3. 让灵感型战术芯片在无已有灵感时触发，验证能正常得到其他灵感。
4. 原有射击灵感不会被清除；自然和其他途径仍可产生射击灵感。

自动测试和静态 IL 核对不能替代以上运行验证。
