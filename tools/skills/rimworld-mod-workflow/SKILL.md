---
name: rimworld-mod-workflow
description: 制作、修改、汉化、构建、部署和发布 RimWorld 本地模组，并用用户指定的 Git 仓库管理源码与可复现配置。用于实际模组工程任务，不用于普通玩法问答或仅分析崩溃日志。
---

# RimWorld 模组工程

先读取 `D:/learn/openCode/content/AGENTS.md`、`agents/rimworld.md` 和 `memory/rimworld-work-context.md`。以当前安装的游戏程序集、实际加载目录和模组版本为依据。

## 源码与版本管理

- 单一源码目录及 Git 仓库：`D:/learn/openCode/content/game-data/rimworld/mod-patches`。
- 模组注册表：仓库 `config/mod-registry.json`。工作环境配置：`config/workspace.json`。
- 本技能的Git源码位于仓库 `tools/skills/rimworld-mod-workflow`，`D:/learn/openCode/content/skills/rimworld-mod-workflow` 是运行副本。修改技能源码后使用 `SkillDeploy` 备份并同步，不让两份内容独立演化。
- 游戏 Mods 目录是部署副本，Workshop 目录是上游参考，不把它们作为自建模组的编辑入口。
- 新模组使用独立目录和唯一 `packageId`。本机约定为 `local.xuewen.<name>`，共享发布前根据用户要求确定身份，已使用的 ID 不随意改动。
- 新模组加入注册表，包括源码目录、部署目录、前置、构建入口、设置文件名称和发布许可状态。
- 用户要求“分析”时只诊断；要求修改时完成修改、检查和部署。用户当前目标优先于历史默认值。

## 制作、修改和汉化

1. 先检查 Git 状态、已部署版本和现有实现；用户已有修改不得覆盖或混入本任务提交。
2. 任何已有文件编辑、构建覆盖、部署或配置覆盖前，运行工具的 `Backup`，并核实独立目录与清单。Git 提交不能代替用户要求的备份。新文件没有旧版本时记录这一事实。
3. 读懂 `LoadFolders.xml`、继承和目标 XPath。优先独立 XML 补丁与游戏提供的扩展点；只有需求确实需要时才引入 Harmony。
4. C# 引用当前游戏 `Managed` 程序集，不复制游戏、Unity 或上游 DLL 进仓库/发布包。构建时使用 `/noconfig /nostdlib` 防止混用系统程序集。
5. 有可配置需求时实现设置持久化、默认值、范围与恢复操作。中文模组同时提供中文设置、提示和属性解释。
6. 汉化保留原设置键、DefName、数字和格式占位符。优先 `Languages/ChineseSimplified/DefInjected` 或 `Keyed`；XML Extensions 设置菜单等特殊情况以实际定义结构为准。
7. 区分编译、XML检查、替身逻辑测试和真实游戏验证。报告准确写明完成到哪一层，不把编译通过当成读档已验证。

## 工具入口

在仓库根目录调用 `tools/mod-workflow.ps1`。用 `-Action Inventory` 或 `Validate` 检查，用 `-Mod <注册名>` 选一个模组。

```powershell
& 'D:/learn/openCode/content/game-data/rimworld/mod-patches/tools/mod-workflow.ps1' -Action Validate
& 'D:/learn/openCode/content/game-data/rimworld/mod-patches/tools/mod-workflow.ps1' -Action Backup -Mod AnimalFilthControl
& 'D:/learn/openCode/content/game-data/rimworld/mod-patches/tools/mod-workflow.ps1' -Action Build -Mod AnimalFilthControl
& 'D:/learn/openCode/content/game-data/rimworld/mod-patches/tools/mod-workflow.ps1' -Action Deploy -Mod AnimalFilthControl -DryRun
& 'D:/learn/openCode/content/game-data/rimworld/mod-patches/tools/mod-workflow.ps1' -Action Package -Mod AnimalFilthControl
```

`Build`、`Deploy`、`Package` 和 `ConfigSnapshot` 对已有目标自动备份。`Deploy` 检测游戏进程，在运行时停止覆盖。配置快照只管理本地模组设置和启用模组 ID，不纳入存档、备份、日志或凭据。游戏运行时不写回配置、不自动关闭游戏。

沙箱生成文件可能属于另一Windows用户。遇到Git dubious ownership时，只为本仓库配置精确的 `safe.directory`，修改全局Git配置前先备份，不设通配符信任。

## Git 与发布

- 用户仓库地址是权威值；仓库无远端时先完成本地工程，再索取准确地址，不能猜测用户账号或把其他项目远端挪过来。
- 使用现有 Git/SSH/凭据管理器或已授权连接器认证；不从浏览器提取 token、不将认证信息写进 URL 或文件。
- 提交前检查实际差异，按模组目录和本任务配置明确暂存，避免 `git add .` 把其他工作混入提交。提交身份使用现有配置；若缺失，本工具初始归档可显式标注作者为 Codex，不冒充用户身份。
- 在当前创建任务中，用户已要求连接并管理其仓库；取得准确远端后可执行该次连接和同步。后续仅本地修改不自动授权公开发布，按当次“同步/推送/发布”请求执行外部写入。
- 推送不强制覆盖、不删除远端分支；非空远端先读取其分支和历史，使用独立分支，避免覆盖原主分支。
- 发布 ZIP 只包含可运行的模组文件、必要许可和说明，排除游戏 DLL、源码测试输出、个人设置、日志和备份。维护模组版本、修改记录、验证范围和回退说明。
- 第三方汉化/补丁需注明上游依赖；未核实许可时只发布自写补丁，不打包上游模组。注册表 `publishLicense` 为 `unassigned` 时，完成打包但不创建公开发行版，先向用户说明具体缺口。
- 发布版本、标签、GitHub Release 或 Steam Workshop 上传时阅读 [发布流程](references/publishing.md)。

完成时给出修改范围、备份、提交/远端状态、部署是否启用、验证结果及剩余阻塞。无需重复讲通用 Git 教程。
