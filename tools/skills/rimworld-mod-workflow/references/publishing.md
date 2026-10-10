# 远端与发布

## 连接

在模组仓库执行 `git remote -v`，禁止输出包含凭据的URL。用户给出正确URL后用工具 `Connect -RemoteUrl <URL>`。验证远端能读通，已有不同 origin 不自动改写。

用户要求同步时，先读取远端默认分支和是否为空。空仓库可推送当前初始分支；非空仓库使用独立分支，例如 `codex/rimworld-mods-20261010`，不要向不相关主分支直接写入或强制合并无关历史。

身份沿用仓库或全局 Git 配置，不能从目录名编造用户邮箱。Git凭据助手或SSH的认证沿用已有设置；本工具不生成或保存token。

本机已安装官方 GitHub CLI。使用 `config/workspace.json` 中的 `githubCliWrapper` 调用，包装器设置独立的 D 盘 `GH_CONFIG_DIR` 并沿用现有 Git 代理。不要直接假定系统 PATH 中有 gh。执行 `auth status` 和 `api user --jq .login` 核实账户；用户授权创建仓库时才执行 `repo create <账户>/<名称> --public --source <源码仓库> --remote origin --push`。

首次 OAuth 设备授权由用户在 GitHub 官方页面完成；不要提取浏览器会话或token。认证目录不在模组仓库中，不提交 hosts.yml。Git推送需要gh凭据助手时，仅为该仓库配置调用上述包装器的helper，沿用其认证目录；配置前备份 `.git/config`，不覆盖其他仓库的认证配置。

## 验证与提交

先 `Validate`；C# 模组执行 `Build`。检查本次 changed files 和 Git 回退依据；本地模组不建立独立备份。真实游戏验证包括启动日志、XPath匹配、菜单中文、参数持久化和实际功能，按风险检查已有存档读入；操作存档仍遵守独立备份规则。

只暂存本次明确路径。提交消息建议 `feat(AnimalFilthControl): ...`、`fix(YokaiVillage_AnimalProductSpeed): ...`、`i18n(CustomInfestations): ...`。提交说明不带token、存档内容或个人日志。

## 发布包

用 `Package -Mod <name>`，检查 ZIP 中有 `About/About.xml`，C#模组有自建DLL。包内不含上游模组、游戏程序集、临时配置、备份或测试。

发布前确定许可、作者、版本、目标平台和已经完成的验证。授权发布时使用 `<ModName>/v<Version>` 的标签，先查同名标签，已发布版本不移动，改动使用新版本。

GitHub Release 可使用已登录 `gh` 或已连接 GitHub工具；若没有现成认证/工具，说明缺少项，不能擅自安装插件或提取浏览器凭据。Steam Workshop 是单独的外部发布行为，GitHub同步不意味着授权Workshop上传。

发布完核实远端分支/标签或Release返回链接；报告清楚区分“本地commit”“已push”“已上传release”“已发布Workshop”。

## 回退

本地模组回退不另建备份。先确认当前需保留的改动已提交或以限定路径保存在 Git 中，再用 `git restore --source=<明确提交> -- <明确文件>` 恢复工作文件，重新验证和部署；禁止 `reset --hard`、整仓删除或无范围checkout。需要撤销已推送更改时用 `git revert` 形成新提交，不强推旧历史。涉及存档、游戏配置或凭据时，仍按对应备份规则处理。
