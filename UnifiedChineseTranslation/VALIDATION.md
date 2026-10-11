# 统一汉化首轮验证 — 2026-10-12

## 已完成

- 当前启用列表156项全部定位，含游戏/DLC、玩法模组和社区汉化；不是156个都需要新增翻译。
- 识别当前1.6有效目录和中文目录别名，将已启用社区汉化一起作为覆盖依据。
- 整合61个按上游模组划分的条件加载模块。旧GlitterNet与虫灾自写汉化资产完整迁入，旧源目录仍保留。
- 模块内2172条语言条目（含迁入与校正）通过XML、重复键及模块路由检查，另保留虫灾设置XML补丁。
- 扫描范围内未处理英文候选为0，未处理变量/规则标识差异为0。扩大到教程、提示和通知字段后补齐额外9条。
- 人工复核本次译文，保留格式变量、原规则左侧与必要技术名称；16个保留决策单独记录。
- 修正旧汉化中的变量丢失、射速公式缺失、Numbers默认视图语义，以及接待对话的中文组合词序。
- 当前英文近战副武器教程误写ranged，按近战语境校正；未修改代码。
- Use This Instead的英文提示重复使用{0}，但实际ReplaceMods调用传入两个名称，原中文{1}正确，未将正确中文改坏。
- 原版Anomaly术语从本机中文归档核对：血棘巨人、隐形魔、夜魇、恶咒吟诵者等。
- 构建通过；只引用游戏和Harmony，不分发上游DLL。
- 运行时只有GlitterNet开发按钮文字的局部Harmony补丁，未添加其他全局字符串补丁。

## 不能据此宣称全部运行时内容已完整验证

- 静态审计不能证明现有中文全文的语义全部正确；已修正确认的问题，没有盲目改写存疑译文。
- 抽象父Def的继承字段、动态生成文本、XML补丁新增的全部内容及所有C#硬编码尚未全量运行审查。
- DefInjected的XML路径和变量检查不等于真实游戏对象注入成功；列表继承、缓存和扩展设置需启动日志验证。
- Follow Me与Oracle重贴图没有明确的v1.6/default加载项，当前使用根目录语言回退，需运行核对。
- Glitter Tech已有中文 `Items_AdvancedBodyParts.xml` 存在未闭合的 `GTEar.description`，原文件不能解析。补全包未修改上游文件，也不能消除上游原文件的解析警告。
- 尚未实际启动游戏、检查每个菜单布局或核对所有硬编码文本。游戏更新后重新审计。

## 结构与维护

- 运行内容：`Modules/<模组>/Languages`及必要的`Patches`。
- 人工译文：`Reviewed/<模组>.json`；增改后执行Generate，再执行Audit和Validate。
- 保留英文理由：`Reviewed/RetainedEnglish.json`。
- 本地原文/审计输出：`D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-audit/`，不把整个上游快照上传。
- 公开仓库只管理本次补丁、工具及必要验证记录；没有存档、凭据、实时配置或原模组包。

## 部署与启用

部署到 `F:/SteamLibrary/steamapps/common/RimWorld/Mods/UnifiedChineseTranslation`，整合包排在最后。

只停用 `local.xuewen.glitternet.zhcnfix` 和 `local.xuewen.custominfestations.continued.zhcn`；保留上游模组与其他社区汉化。后者已提供的正确文本不应被一并禁用。

实际部署与配置切换已完成：整合包已启用并位于列表末尾，两份旧自建汉化已停用，其他启用ID和顺序经逐项比较未变。部署差异文件数为0。

配置切换备份：`D:/learn/openCode/content/game-data/rimworld/backups/20261012-045227-unified-translation-before-config-switch-75ad42`。此前一次原子替换因PowerShell空参数转换失败，原配置未变；临时配置已核对与最终配置相同并移入此备份保留。

本地ZIP已生成，核对包含61个模块且没有源码、测试、原版DLL或上游DLL。未创建公开发行版，许可状态仍未指定。

模组文件按用户要求不另建备份。启用列表属于游戏配置，切换前仍独立备份并校验；仅这三个ID改变，其他模组顺序不变。真实运行验证等待用户启动游戏。
