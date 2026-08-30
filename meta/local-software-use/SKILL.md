---
name: local-software-use
description: 在 Windows 上定位和安装本机软件。定位：用 Everything CLI (es.exe) 秒级全盘搜索 exe/工具/安装目录，代替 Get-ChildItem -Recurse、dir /s、find、grep 式的暴力遍历。安装：PATH 的安全写法（禁 setx 防截断）、小工具装用户目录、大型软件先问用户装哪。凡是要回答"XX 装在哪 / 有没有装 XX / 找某个文件"，要给用户安装软件（uv、7z、jdk、node、gcc……），或要在 Windows 上定位任何工具链时必须先读本技能。包含 es 安装方法、PowerShell 编码(GBK)注意事项、常用软件到 exe 名的映射表和快速查找脚本。
---

# Local Software Use（Windows 本机软件定位）

目标：在 Windows 上回答"某个软件装没装、装在哪、哪个版本、可执行文件路径是什么"，用 Everything 的 CLI（es.exe）做全盘秒搜，而不是递归遍历目录。

## 核心原则（先读这四条）

1. **Shell 只用 PowerShell**：所有命令用 `powershell.exe` 或 `pwsh` 执行。不要用 cmd，不要用 Git Bash。原因：路径、引号、编码行为在三者间不一致，本技能的所有命令只在 PowerShell 下验证过。
2. **编码注意 GBK**：中文 Windows 控制台默认代码页是 GBK (cp936)。es.exe 的输出编码跟随当前控制台代码页，默认状态下直接用就是对的、不乱码。如果输出出现乱码，先执行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` 再跑 es，实测两种状态下输出都正确。写脚本时建议开头就设这一行，保证跨机器稳定。
3. **不在共享文件里留本机环境信息**：搜索结果里的绝对路径、用户名、盘符布局属于本机隐私。除非用户明确要求，不要把 `es` 的搜索结果原样写进将来要上传/共享/提交的文件（如 README、dotfiles、issue、配置模板）。引用路径时优先写占位符（`<install-dir>\7z.exe`），只在直接回复用户的对话里给出真实路径。
4. **用 es 搜，不要暴力遍历**：定位软件/文件一律优先 es。`Get-ChildItem -Recurse`、`dir /s`、`where.exe` 只能搜 PATH 上的东西且很慢，仅当工具明显已在 PATH（`Get-Command <name>` 一次就能确认）时才用它。

## 第一步：确认环境（每次使用前）

```powershell
# Everything 服务在跑吗？（es 通过 IPC 跟它通信，Everything 没运行则 es 退出码 8）
Get-Process -Name Everything -ErrorAction SilentlyContinue

# es 可用吗？
$es = (Get-Command es -ErrorAction SilentlyContinue).Source
if (-not $es) { $es = "$env:LOCALAPPDATA\Programs\es\es.exe" }
Test-Path $es
```

两者都 OK → 直接用。缺哪个 → 按下面装。

## 安装（一次性，不写死版本号）

下载直链总在变，**安装时先打开下载页取当前稳定版直链**（需要的话用 WebFetch 抓页面找 zip/exe 链接），不要凭记忆拼带版本号的 URL。

**Everything 本体**（es 的依赖，NTFS 全盘索引服务）：

- 下载页：<https://www.voidtools.com/zh-cn/downloads/>，取稳定版 x64 安装包直链，静默安装（NSIS 安装器，`/S` 静默参数与版本无关）：
  ```powershell
  Invoke-WebRequest -Uri "<下载页取到的最新稳定版 x64 Setup.exe 直链>" -OutFile "$env:TEMP\Everything-Setup.exe"
  Start-Process "$env:TEMP\Everything-Setup.exe" -ArgumentList "/S" -Wait
  ```
- 装完它会开机自启并常驻。装完立即 `Start-Process "$env:ProgramFiles\Everything\Everything.exe"`（首次运行建索引，NTFS 全盘一般几秒到几十秒）。

**es CLI**（独立 zip，无安装器；已实测 zip 解压后就是单个 es.exe，无子目录）：

```powershell
$dest = "$env:LOCALAPPDATA\Programs\es"
$zip  = "$env:TEMP\es.zip"
# 直链从 https://www.voidtools.com/zh-cn/downloads/#cli 取（x64 / x86 / ARM64 / ARM 四种，按 CPU 选）
Invoke-WebRequest -Uri "<下载页取到的 ES x64 zip 直链>" -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $dest -Force

# 加入用户 PATH（幂等写法；已存在则跳过）
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$dest*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$dest", "User")
}
```

装完重开一个 shell 再 `Get-Command es` 验证。

## 安装其他软件的纪律（PATH 安全 + 装哪里）

**改 PATH 永远用 PowerShell，禁止 cmd 的 `setx`**：`setx` 对超过 1024 字符的值会静默截断（只打一行容易错过的警告），PATH 一长就被砍坏，砍掉的还恰恰是排在后面的老条目。统一写法：

```powershell
# 幂等追加；作用域选 "User"（不要管理员）或 "Machine"（确需所有用户可用时才用）
$dir = "<要加入的目录>"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$dir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$dir", "User")
}
```

PATH 越长越脆：每次追加前先查重（上面的 `-notlike` 判断），同一目录绝不写两遍；能用用户 PATH 解决就不动系统 PATH。

**装哪里，先分两类再动手**：

- **小工具**（单 exe / 绿色软件 / CLI，如 uv、es、node 版本管理器这类）：默认装 `%LOCALAPPDATA%\Programs\<名字>`，写入**用户 PATH**。无需管理员、无需询问用户，直接装；装完重开 shell 用 `Get-Command` 验证。
- **大型软件**（IDE、数据库、GB 级工具链、带正式安装器的）：装哪里影响磁盘布局和全局环境，**先问用户**，给三选一：All Users（`C:\Program Files`，要管理员提权）/ 仅当前用户 / 用户指定目录（大盘常在 D:\，不要替用户默认 C 盘）。用户选定后再装；带安装器的用静默参数（NSIS `/S`、Inno Setup `/VERYSILENT`、MSI `msiexec /qn`）。
- 装完检查安装器有没有自作主张改**系统** PATH（有的安装器会往 Machine PATH 塞自己的 bin）。

## es 用法（实测过的关键点）

**最重要的坑：搜索词必须作为独立参数传入，不要拼成一个带空格的引号字符串。**

```powershell
# 对：三个独立参数 = 三个 AND 搜索词
es 7z ext:exe !path:C:\Windows
# 错：整串是一个参数，会被当成一个"字面短语"搜索，结果为空
es "7z ext:exe !path:C:\Windows"
```

常用查询模式（按需组合，全部实测）：

```powershell
es -n 10 -w 7z.exe               # 找 7-Zip：-w 全词匹配，限制 10 条
es -n 10 -w java.exe              # 精确 exe 名（不加 -w 时 cmake.exe 会子串误中 bscmake.exe）
es -n 10 java ext:exe             # 模糊搜：所有名字含 java 的 exe
es -n 5 uv.exe !path:Prefetch     # 排除路径噪音（!path: 只对路径生效）
es java.exe !path:WER             # 排除崩溃报告噪音
es -n 20 -s git.exe               # -s 按全路径排序，多版本安装时结果更可读
es -n 10 -size -sort size-descending ext:exe path:C:\Tools   # 某目录下最大的 exe
es -n 3 -dm 毕设                  # 中文关键词直接搜，输出编码见原则 2
```

噪音来源（裸搜 exe 时常见，用 `!path:` 排除）：`C:\Windows\Prefetch`（预读取缓存）、`C:\ProgramData\Microsoft\Windows\WER`（崩溃报告）、`$Recycle.Bin`（回收站）、`node_modules\.bin`（包管理器 shim）。

**判断"装没装"**：搜索结果里出现 exe ≠ 装了这个软件（可能是别家捆绑的 JRE，见 java.exe 常命中 Altair/ANSYS 自带 JRE 的例子）。确认后用 `& "<找到的路径>" --version` 验证版本，再下结论。很多软件崩溃报告（WER）里出现过 exe 名，那只说明它曾经运行过，不代表现在装着。

**退出码**：`0` 成功；`8` = Everything 没在运行（去把它启动）；`6` = 参数不认识。完整列表见 references/es-cli.md。

## 快捷方式（推荐）

本技能自带两样东西：

1. **常用软件映射表** `assets/software-map.json`（数据源，机器可读）和 `references/software-map.md`（含使用说明的表格）。想知道"某软件该搜什么 exe"先查它，例如 7-Zip→`7z.exe`、JDK→`java.exe`+`javac.exe`、uv→`uv.exe`。表里还标了哪些是 Windows 自带的（curl、ssh 等，直接 `Get-Command`，不用 es 搜）。
2. **快速查找脚本** `scripts/find-software.ps1`：一条命令完成"别名→exe 映射 → es 搜索 → 噪音过滤 → 输出真实安装路径"。

```powershell
pwsh -File "<本技能目录>\scripts\find-software.ps1" uv      # 查单个
pwsh -File "<本技能目录>\scripts\find-software.ps1" java 7z # 查多个
```

脚本失败时（Everything 没运行、es 没装）会给出明确提示和修复命令，此时回到上面的安装/检查步骤。

## 何时读参考文件

- 需要 es 完整参数、排序/导出/退出码细节 → 读 `references/es-cli.md`
- 需要常用软件→exe 对照、版本验证命令、安装目录推断规则 → 读 `references/software-map.md`
