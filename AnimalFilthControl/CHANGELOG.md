# 修改与安装记录

## 2026-10-10 版本1.0.0

- 新增独立模组 `local.xuewen.animalfilthcontrol`，无Harmony依赖。
- 新增 `FilthRate` StatPart：只对动物乘以可配置系数，默认0.10，范围0～2。
- 新增中文设置界面、百分比滑块、0/10/25/50/100%快捷按钮及属性说明。
- 用当前 RimWorld 1.6.4871 rev591 的游戏自带 Mono/netstandard 程序集编译成功。
- 通过24项API替身逻辑检查：动物倍率、定义预览、人类不变、空请求、NaN及上下限。
- XML解析通过；当前FilthRate目标唯一、没有现有parts，安装时走nomatch分支添加新parts。
- 验证范围：编译、逻辑和静态XML；尚未启动游戏验证实际读档和属性缓存。
- 源码位置：`D:/learn/openCode/content/game-data/rimworld/mod-patches/AnimalFilthControl`。
- 游戏安装位置：`F:/SteamLibrary/steamapps/common/RimWorld/Mods/AnimalFilthControl`。
- 操作前备份：`D:/learn/openCode/content/game-data/rimworld/backups/20261010-AnimalFilthControl-before-install`。
- 部署检查时游戏正在运行，因此只安装模组目录，**未写回ModsConfig，也未自动启用**。
- 启用：退出并重启游戏，在模组列表勾选「动物污物系数调整」，放在动物属性修改模组之后，应用并按游戏提示重启。
- 回退：退出游戏，禁用该模组并重启。既有存档没有增加任何引用，无需编辑存档。
