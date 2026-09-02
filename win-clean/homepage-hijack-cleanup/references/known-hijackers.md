# 已知劫持家族指纹库

> 只收录实测踩过的家族，机器相关观测值不进 git。新家族按文末方法论补充。

## 疾风软件市场（NStore 家族 / 奇鲁科技）

**身份**：数字签名 `成都奇鲁科技有限公司`；托盘进程 `Gt.exe` 的 FileDescription 为"疾风托盘程序"；卸载项显示名"疾风软件市场"。基于 360 OEM SDK 套壳的软件市场 + 推广组件，随其他软件捆绑进入。

**安装与组件**（默认 `%ProgramFiles(x86)%\NStore\`）：

| 文件 | 角色 |
|---|---|
| `Gt.exe` | 托盘常驻主进程，计划任务登录自启（`/autorun --from=task`） |
| `Ghall.exe` | 软件市场主程序 |
| `Utils\guardhp.exe` | **主页守护**（guard home page），高权限运行；内含 ANSI 串 `lockhomepage` |
| `GHallProtect*.sys`（Slim/Win10/Ex × x86/x64） | **内核保护驱动**，服务名 `GHallProtect` |
| `360OemSdk.dll` / `360Base.dll` / `360NetBase.dll` | 360 OEM SDK（推广/联网能力） |
| `Plugin\Basic.tpi` / `inst_pop.tpi` / `store_dist.tpi` | tpi 插件：`inst_pop` = 安装弹窗（"要不要改主页"弹窗的来源），与数据 INI 的 `tpi_run` 键对应 |
| `Plugin\Resource\guardhp\*.png` | 弹窗 UI 素材（radio/ok/close 按钮 + nstore 后缀） |
| `lpi\NStoreSvc.dll` | 服务化模块 |
| `Utils\EdgeInst.dll` / `EdgeWeb.exe` / `hp_edge_assist.exe` | **Edge 劫持组件**（常与 Chrome 劫持并存） |
| `Utils\ComputerZ12*.dll` | 鲁大师组件，内含 ANSI 串 `hao.360` |
| `imageCache\` | 全盘已装软件图标缓存（软件市场功能） |
| `uninst.exe` | 卸载器 |

**数据目录** `%APPDATA%\lockhomepage\`：

- `LockHomePage.ini`：`[Lockhp] value=<base64 加密的主页>`、`pop_guide`、`pop_hp_check_time`；`[general] poped_hp`（已弹窗）、`hp_modify_time`、`tpi_run`、`guide_bguard`。
- `home_page_helper.ini`：`[safelock_status] lock_status`、`timestamp`。
- 键名 `tpi_run`/`pop_guide` 是该家族最独特的静态指纹。

**劫持行为**（双通道并存）：

1. 写 Chrome `Secure Preferences`：`restore_on_startup=4` + `startup_urls = hao.360.com?src=lm&ls=<渠道码>`。
2. 弹窗问"要不要改主页"后，ShellExecute 打开跳转域 `go.huanyuroad.cn/go/<渠道码>` → 302 落地 360导航（父进程显示 explorer.exe）。

**二进制指纹**（grep -a 命中即定案）：UTF-16LE `lockhomepage`、`huanyuroad` 遍布全目录（Gt.exe、Ghall.exe、驱动 .sys、360*.dll、uninst.exe、config.ini、cacert.dat 等）；ANSI `lockhomepage` 在 `Utils\guardhp.exe`；ANSI `hao.360` 在 `Utils\ComputerZ12*.dll`。

**清理要点**：先 `Disable-ScheduledTask NStoreTray` → 停 `GHallProtect` 驱动服务 → 杀 `Gt/Ghall/guardhp` 进程 → 卸载器卸载 → 删 `%APPDATA%\lockhomepage` 与残留目录 → chrome://settings 修回。

## 360 系通用特征（跨家族速查）

- 落地页 `hao.360.com` 必带渠道参数（`src=` + `ls=<码>`），渠道码可溯源到捆绑方。
- DLL 三件套：`360OemSdk.dll`、`360Base.dll`、`360NetBase.dll`。
- 产物命名风格：`XX软件市场`、`XX托盘`、`XX管家`、`guardhp/lockhomepage/home_page_helper`。
- 持久化组合拳：计划任务（登录触发）+ 托盘常驻 + 内核保护驱动 + 高权限守护进程。
- 同机器常多浏览器通杀（Chrome/Edge 各一套组件）。

## 遇到新家族：指纹化方法论

1. **从数据目录入手**：`%APPDATA%` 下可疑目录（名字怪、INI 键名独特）→ INI 键名是最独特指纹。
2. Everything 全盘搜目录名（`es lockhomepage`）确认无散落副本。
3. 嫌疑安装目录内二进制 grep：INI 键名 + 跳转域名，**ANSI 和 UTF-16LE 两种编码都要试**（`grep -r -a -l` / `grep -a $'k\x00e\x00y\x00'`）。
4. 四查持久化：计划任务 / 服务（含驱动）/ Run 键 / 卸载表。
5. 签名者公司名作为锚点记录（举报、写报告、跨家族关联都靠它）。
6. 把新家族按本文件格式补进指纹库；本机观测值写 `local.md`。
