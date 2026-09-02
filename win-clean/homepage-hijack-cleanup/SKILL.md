---
name: homepage-hijack-cleanup
description: "清理 Windows 上国产捆绑软件造成的浏览器主页劫持（360导航 hao.360.com、2345、hao123 等家族）。取证→通道判定→定位持久化宿主→二进制指纹→安全清理→复验全流程，含只读体检脚本。当浏览器主页被改且改回来又复发、反复弹出'要不要改主页'、发现 lockhomepage/NStore/疾风软件市场、chrome.exe 被带推广网址拉起时必须使用本技能。"
---

# 浏览器主页劫持取证与清理（360导航家族实测版）

先跑 `scripts/detect-hijack.ps1` 只读体检，再按流程深挖。通道细节见 `references/hijack-channels.md`，
已知家族指纹库见 `references/known-hijackers.md`，本机实测案例见 `local.md`（git 忽略，换机器重新探测）。

## 核心认知（全部实测踩过，2026-09）

1. **劫持 = 设置篡改 + 持久化重改，双通道**。只修浏览器设置必然复发：实测修回 Bing 后 2 小时内，Chrome 又被带推广 URL 拉起。修设置只是断表，铲持久化才是断根。
2. **Chrome 的 `Secure Preferences` 有 HMAC 完整性校验**：外部直接改该文件会被判损坏并整体重置。修主页/启动页/搜索引擎**必须走 chrome://settings 界面**，让 Chrome 自己写回合法校验值。
3. **chrome.exe 主进程命令行带推广 URL = "启动注入"通道**：此时快捷方式往往是干净的。父进程显示 explorer.exe 只是 ShellExecute 代理，不是真凶——真凶是用数据目录 INI 写入时间与开机自启项启动时间做相关性定位的常驻程序。
4. **数据目录的"修改时间"是活性证据**：目录创建于数月前 + INI 今天还在写 = 持久化还活着。创建时间告诉你它是哪天被捆绑装进来的。
5. **本家族带内核驱动与高权限守护**：`GHallProtect*.sys` 驱动服务 + `guardhp.exe` 高权限运行（WMI 读不到其路径）。浏览器设置被"幽灵改回"时，先查驱动服务再怀疑进程。
6. **卸载后仍复发 + 静态排查全部干净 = 内存注入**。家族软件活着时把推广代码注入常驻进程（实测注入 explorer.exe：点击干净快捷方式，explorer 拉起的 chrome.exe 命令行却带推广 URL）。注入代码经手工映射不出现在 `Process.Modules` 枚举里，任何文件级扫描都找不到。**验证/修复：重启被注入的进程**（`taskkill /f /im explorer.exe; start explorer`）后复测，复发消失即确认。

## 六步流程

### 1. 固定证据（趁热，先于一切清理）

- 运行中浏览器主进程命令行快照（启动注入的现场）：见 channels 第 2 节。
- 数据目录 INI 内容与时间戳（`stat -c '%n %w %y'`；Git Bash 的 `%w` 给创建时间）。
- 计划任务 XML：`schtasks /query /tn <名> /xml`；服务配置；exe 签名（`Get-AuthenticodeSignature`）。

### 2. 通道判定

| 通道 | 判据 | 命中处理 |
|---|---|---|
| Chrome 配置篡改 | Secure Preferences 里 startup_urls / homepage / 默认搜索指向劫持站 | chrome://settings UI 改回 |
| 启动注入 | chrome.exe 主进程 CommandLine 带 URL 参数（如 go.xxx.cn/go/码） | 铲持久化后自然消失 |
| 快捷方式改参 | .lnk 的 Arguments 带 URL | 重写快捷方式 |
| 策略锁 | Policies\Google\Chrome 下 RestoreOnStartupURLs 等 | 删策略键 |
| IFEO 劫持 | IFEO\chrome.exe 的 Debugger 值 | 删 Debugger 值 |
| 恶意扩展 | Preferences extensions.settings 非空且可疑 | chrome://extensions 移除 |
| hosts / 代理 | hosts 或 ProxyServer 指向劫持域 | 还原对应配置 |

检测命令逐一见 `references/hijack-channels.md`；配置解析用 python json（`ConvertFrom-Json` 亦可），**不要对 20MB 的 Preferences 裸 grep**——键名存在但值为 null 时会误导。

### 3. 定位持久化宿主

- 开机自启四查：计划任务（按 LastRunTime 排序，看 [Running] 状态的）、Run 键、服务、Startup 目录；命令见 channels 第 6 节。
- 与数据目录 INI 写入时间做相关性：开机 08:33 → INI 08:36 被写，嫌疑就是 08:33 启动的那个。
- 卸载表反查身份：`HKLM\...\Uninstall`（含 WOW6432Node）按 InstallLocation 匹配安装目录，拿到显示名 + 卸载器路径。

### 4. 二进制取证（定案手段）

在嫌疑安装目录内 grep 数据目录名/INI 键名/跳转域名：

```bash
grep -r -a -l "lockhomepage" "/c/Program Files (x86)/<目录>"          # ANSI 串
grep -r -a -l $'l\x00o\x00c\x00k\x00h\x00o\x00m\x00e\x00p\x00a\x00g\x00e' <目录>   # UTF-16LE 串
```

一次命中即可定案（详见 known-hijackers.md 的指纹表）。INI 里的加密 `value=` 不用解——通道判定和宿主定位已足够。

### 5. 清理顺序（不可倒序）

1. 导出证据（第 1 步没做完的补完）。
2. **先停持久化**：`Disable-ScheduledTask` → 停驱动/服务（`sc stop` + `sc config start= disabled`）→ 结束常驻进程（`taskkill /F /IM Gt.exe` 等）。
3. **卸载前征得用户同意**（用户可能认识这个软件）。优先厂商卸载器（uninst.exe / 控制面板），卸不干净再删目录 + 驱动 .sys。
4. 删数据目录（如 `%APPDATA%\lockhomepage`）。
5. 修浏览器设置：**走 chrome://settings UI**（onStartup、搜索引擎、主页按钮）。
6. 复验：重启 → `detect-hijack.ps1` 全绿 → 重开浏览器落地的是用户设置的主页。

### 6. 复发处理

设置又被改回 → 说明还有没铲掉的持久化，回到第 3 步换关键词（新 INI 时间戳 → 新的写入时刻 → 新的嫌疑进程），并用 Procmon 过滤数据目录路径抓现行（运行 `procmon /Quiet /Minimized /BackingFile log.pml`，复现后停止并过滤导出）。

**静态穷尽仍复发**（任务/服务/驱动/注册表/模块全干净）→ 按"内存注入"假设处理：布控（WMI `__InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'` 临时订阅，普通权限即可）→ 让用户复现一次 → 看可疑进程的创建与父进程；若拉起者已是 broker（explorer）且无任何文件级痕迹 → 重启 explorer 验证内存注入。实测此法一击定案。

## 脚本纪律

- Windows PowerShell 5.1 把**无 BOM 的 UTF-8 .ps1 当 GBK 解析**，含中文的脚本会直接语法错误（实测：字符串终止符丢失）。必须存成 UTF-8 with BOM；补救：python `open(p, encoding='utf-8-sig')` 重写一遍。
- 体检脚本保持只读；清理动作永远手动按 SKILL.md 第 5 步顺序来，不写进脚本。
