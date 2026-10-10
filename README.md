# RimWorld 本地模组仓库

公开远端：[catlineX/rimworld-local-mods](https://github.com/catlineX/rimworld-local-mods)，默认分支 `main`。

本目录是自建模组、独立补丁、汉化和可复现工程配置的唯一源码入口。游戏 `Mods` 中的同名目录为部署副本。

| 模组 | 用途 |
|---|---|
| AnimalFilthControl | 中文可配置动物污物倍率，默认10%，范围0～200% |
| YokaiVillage_AnimalProductSpeed | 九尾狐10倍、月牙/尖牙精灵50倍、日绯色壁10倍产物速度 |
| CustomInfestationsContinued_ChineseSimplified | Custom Infestations (Continued) 中文设置补丁 |

`config/mod-registry.json` 管理包ID、依赖、构建入口和部署名称；`config/workspace.json` 管理本机路径。`config/game-mods.snapshot.json` 为加载列表快照，`config/mod-settings` 保存上述自建模组的设置快照。移至其他电脑时先改工作环境路径。不得向这里写入认证凭据。

`tools/mod-workflow.ps1` 提供清单、XML验证、构建、独立备份、部署、ZIP打包、配置快照、Git状态和连接。操作示例：

```powershell
.\tools\mod-workflow.ps1 -Action Validate
.\tools\mod-workflow.ps1 -Action Build -Mod AnimalFilthControl
.\tools\mod-workflow.ps1 -Action Deploy -Mod AnimalFilthControl -DryRun
.\tools\mod-workflow.ps1 -Action ConfigSnapshot
.\tools\mod-workflow.ps1 -Action Package -Mod AnimalFilthControl
```

构建和覆盖部署前自动备份；不在游戏运行时覆盖部署，不操作存档或原版/Workshop文件。Git不替代备份。发布包不包含源码测试输出、个人设置和游戏程序集。

技能入口：`D:/learn/openCode/content/skills/rimworld-mod-workflow/SKILL.md`，可用 `$rimworld-mod-workflow` 调用。OpenCode读取全局技能目录；Codex通过 `.agents/skills/rimworld-mod-workflow` 的目录联接发现。

发布许可尚未指定。提交源码和私有备份同步不等于对外公开发行；公开发行前须确定许可，汉化包只包含自写补丁，不能把上游模组一起发布。

GitHub CLI 已通过官方校验安装到 D 盘，调用入口为 `D:/learn/openCode/content/commands/github.ps1`。OAuth认证配置保存在仓库之外，包装器自动沿用本机已有Git代理。用户已要求公开源码仓库，公开源码仓库不自动授予开源许可，也不等同于创建Release或上传Workshop。
