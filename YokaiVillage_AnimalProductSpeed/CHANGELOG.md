# 妖怪村产物速度补丁

## 当前修改

- 九尾狐 `Yokai_NineTail`
  - 原参数：`shearIntervalDays=30`
  - 新参数：`shearIntervalDays=3`
  - 效果：九尾毛剪取周期缩短为原来的 1/10，约 10 倍速度

- 月牙精灵（本机 Def：`Yokai_YukiShizuku`）
  - 原参数：`pointPerSecond=1`、`needPoint=5000`
  - 新参数：`pointPerSecond=1`、`needPoint=100`
  - 效果：`Yokai_SnowMilk` 进度达到产出所需点数的速度提高 50 倍

- 尖牙精灵（本机 Def：`Yokai_TuskSprit`）
  - 原参数：`needPoint=135000`
  - 新参数：`needPoint=2700`
  - 产物：`Yokai_DragonTusk`
  - 效果：生产速度提高 50 倍

- 日绯色壁（Def：`Yokai_HihiiroKabe`）
  - 原参数：`shearIntervalDays=15`
  - 新参数：`shearIntervalDays=1.5`
  - 产物：日绯色金（每次仍为20个）
  - 效果：剪取产出速率提高10倍

## 2026-10-08 修复

- 修正月牙精灵补丁 XPath：`needPoint` 位于 `dropThingAndNeedPoint` 节点内。
- 新增尖牙精灵 50 倍生产补丁；原 Mod 的 DefName 拼写为 `Yokai_TuskSprit`。
- 修复后不会再出现 `Failed to find a node with the given xpath`。
- 修复前备份：
  `D:/learn/openCode/content/game-data/rimworld/backups/20261008-080621-YokaiSpeed-and-CustomInfestations-before-fix/`

## 使用方式

1. 将本目录作为本地 Mod 放入 RimWorld 的 `Mods` 目录。
2. 在 Mod 列表中将 `Yokai Village - Animal Product Speed` 放在 `Yokai Village` 后面。
3. 重启游戏使 Def 补丁重新加载。

## 回退方式

- 在 Mod 列表中禁用并删除本地补丁目录即可恢复妖怪村原始定义。
- 原始文件备份位于：
  `D:/learn/openCode/content/game-data/rimworld/backups/20261008-060505-YokaiVillage-animal-products-before-speed-patch/`
- 备份对象：
  - `Races_NineTail.xml`
  - `Races_Yokai_YukiShizuku.xml`

## 备注

本补丁不直接修改 Steam 创意工坊 Mod 文件，因此妖怪村更新时不会覆盖原文件。若妖怪村作者改动 Def 名称或组件结构，补丁可能失效，需要重新检查日志。
