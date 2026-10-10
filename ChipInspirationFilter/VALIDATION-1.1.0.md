# 1.1.0 验证与部署记录 — 2026-10-11

- 修改前独立备份：`D:/learn/openCode/content/game-data/rimworld/backups/20261011-003339-ChipInspirationFilter-manual-2722e2`；含源码、旧 DLL 和已部署副本，工作流校验哈希并生成 manifest.json。
- 构建前备份：`D:/learn/openCode/content/game-data/rimworld/backups/20261011-003445-ChipInspirationFilter-before-build-613dda`。
- 当前游戏程序集和 Harmony 编译：通过。
- XML、元数据及程序集检查：通过。
- 替身自动测试：23/23 通过。
- 白名单仅允许 `Frenzy_Work` 和 `Inspired_Creativity`；其他来源仍返回原候选列表，不修改共享数据库。
- 允许的两种候选仍由上游进行资格判断和加权随机抽取；不强行保证创造灵感发生。
- 1.1.0 DLL SHA256：`6A1F4398715A678A989B1F7C4361B61D98DC1089391AEA07B2E7C1749F35DC39`。
- 当前启用列表已包含 `local.xuewen.chipinspirationfilter`，无需新增启用项。
- 当前游戏进程 PID 32108 仍运行；按工程技能要求未覆盖部署目录，已部署版本仍是 1.0.0。
- 真实游戏运行验证尚未完成。

## 下一步

退出 RimWorld 后，在仓库根目录运行 `./tools/mod-workflow.ps1 -Action Deploy -Mod ChipInspirationFilter`；工具将先备份旧部署，再逐文件复制并校验。重启游戏后检查 `[ChipInspirationFilter] v1.1.0 已启用`。

## 回退

退出游戏后，可从上述修改前备份恢复旧版本源码和部署副本。恢复操作前仍须再备份当时文件。单纯禁用补丁会恢复上游完整灵感池，而不是恢复 1.0.0 的“只排除射击”规则。
