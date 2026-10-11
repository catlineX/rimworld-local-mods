# 机械师遗迹间隔调整

版本1.0.0，适用于 RimWorld 1.6，需要 Biotech。仅 XML 补丁，不需要 Harmony。

## 改动范围

只把故事叙述者组件 `StorytellerCompProperties_MechanitorComplexQuest` 的 `existingMechanitorOrMechlinkMTBFactor` 从4改为0.16666667。

原版基础 `mtbDays=60` 不变，已有机械师或控制中枢时平均间隔由240日降为约10日。无机械师时仍为60日。`minSpacingDays=60` 保持不变，已有相关任务的阻挡规则及其他触发条件不变。

因此不是每10日固定生成任务；上次任务后的60日最小间隔内，仍不会因本补丁得到下一次任务。不立即生成任务，不解除活动任务阻挡，不修改任务地点、尸体或战斗难度。

继承原版 BaseStoryteller 的叙述者可获得该参数。自定义叙述者若完全不使用此组件，本补丁不会为它添加组件。其他模组后续覆盖同一字段可能改变效果。

## 启用

退出游戏后部署，在模组列表启用“机械师遗迹间隔调整 / Mechanitor Complex Interval”，排列在 Biotech 后，重启游戏。无需改存档或开发者模式。

## 验证与回退

运行 `Tests/Validate.ps1` 检查当前游戏定义的 XPath、10日计算及非目标参数未变；不等于实际游戏触发验证。

禁用本模组并重启即可恢复原参数。源码与规则通过用户指定 Git 仓库管理，不另建文件备份；不包含上游游戏文件。
