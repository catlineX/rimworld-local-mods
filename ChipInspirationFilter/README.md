# 战术芯片灵感过滤（Chip Inspiration Filter）

版本：1.1.0；适用本机 RimWorld 1.6 与 Polarisbloc - Core LAB tmp port。

## 范围

`PolarisCombatChip_Inspiration`（灵感型战术芯片）只允许抽取 `Frenzy_Work`（工作狂热）和 `Inspired_Creativity`（创造灵感）。芯片候选中的射击、移动、交易、招募、驯服、手术及其他模组灵感均被排除。自然心情、灵能、其他模组的灵感来源不受影响。已有灵感不会被移除或替换。

采用 Harmony 转译补丁，仅作用于 `Polarisbloc.HediffComp_Inspire.Inspire(Pawn)`：读取候选列表后生成过滤副本，不修改共享 DefDatabase 列表、不补丁全局 InspirationWorker、不改任何灵感 Def。再次核对来源 Hediff，其他建筑/植入物复用该组件时也不被过滤。

原版资格判断、两种允许灵感的随机权重、芯片 2,500 ticks 检查周期及“已有灵感时不抽取”行为保持不变。不会保证两种灵感各占一半；角色不满足创造灵感条件时不强行赋予，无合格候选时本轮不生成灵感。上游方法或预期 IL 不匹配时报告错误，不安装过滤。

## 安装与使用

在游戏关闭后部署到 `F:/SteamLibrary/steamapps/common/RimWorld/Mods/ChipInspirationFilter`。

启用“战术芯片灵感过滤 / Chip Inspiration Filter”，放在 Harmony 和 Polarisbloc - Core LAB tmp port 之后，重启游戏。无需设置。

日志成功标识：`[ChipInspirationFilter] v1.1.0 已启用`。失败标识：`[ChipInspirationFilter] 补丁未启用`。

## 构建与检查

从仓库根目录运行：

```powershell
./tools/mod-workflow.ps1 -Action Build -Mod ChipInspirationFilter
./tools/mod-workflow.ps1 -Action Validate -Mod ChipInspirationFilter
./ChipInspirationFilter/Tests/run-tests.ps1
./tools/mod-workflow.ps1 -Action Deploy -Mod ChipInspirationFilter
```

编译只引用当前游戏 Managed 与已安装 Harmony，不打包或修改上游 DLL。自动测试使用替身验证过滤范围、共享列表不变和转译形状，不等同于真实游戏验证。

## 回退

退出游戏后禁用此补丁并重启即可恢复芯片原来的抽取规则。没有新增存档对象或设置，不需要编辑存档。注册表和构建工具的旧版本已在修改前独立备份；部署工具另行备份源文件和部署目标。

## 发布

自写补丁，不含上游源码、游戏 DLL 或 Harmony DLL。发布许可尚未指定；不自动推送 GitHub 或公开发布。
