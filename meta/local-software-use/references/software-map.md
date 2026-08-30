# 常用软件 → es 搜索词映射表

> 数据源同 `assets/software-map.json`（脚本读 JSON，本文供 AI/人阅读）。
> 原则：本表只含**通用知识**（软件名→exe 名），不含任何具体机器的路径。

## 定位流程（先判断再搜）

1. **先 `Get-Command <名>`**：一步命中说明工具已在 PATH，直接用，最省事。注意 Windows 商店的 app 执行别名（如 `python.exe` 位于 `WindowsApps`）也会被命中，属于真可用。
2. **`Get-Command` 没有再上 es**：搜 exe 名，拿真实安装路径。适合"没进 PATH 的工具、找全部已装版本、找安装根目录"。
3. **判断结果真伪**：路径在 `Program Files`、`<用户目录>\.local\bin`、`<用户目录>\AppData\Local\Programs`、工具自带目录（如 `...\Toolbox\apps`）→ 大概率真实安装；路径在别的软件内部（见下方 java 的捆绑 JRE 陷阱）、`Prefetch`、`WER`、`WinSxS`、`$Recycle.Bin` → 噪音或残留。
4. **由 exe 推断安装根**：多数工具根目录 = exe 所在目录；带 `bin\` 结构的（java、cargo、go、nginx）根目录 = exe 所在 `bin` 的上一级（这就是 `JAVA_HOME` 之类变量的值）。
5. **验证版本再下结论**："装没装"以 `& <路径> <版本参数>` 的输出为准，不要只凭搜到文件。

## 映射表

### 压缩

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| 7-Zip | `7z.exe`（CLI）、`7zFM.exe`（GUI） | `7z.exe` 裸跑打印横幅 | `7za.exe` 是独立精简版；给脚本/CI 用 `7z.exe` |
| WinRAR | `WinRAR.exe`（GUI）、`Rar.exe` / `UnRAR.exe`（CLI） | `Rar.exe` 裸跑打印横幅 | CLI 在安装目录内，常不在 PATH |
| Bandizip | `Bandizip.exe` | — | GUI 为主 |

### Java

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| JDK | `java.exe`、`javac.exe`、`javaw.exe`、`jshell.exe` | `java.exe -version`（**输出在 stderr**，需 `2>&1`） | 有 `javac.exe` 才是 JDK，只有 `java.exe`/`javaw.exe` 是 JRE |
| JRE | `java.exe`、`javaw.exe` | 同上 | **捆绑 JRE 陷阱**：MATLAB、Altair、ANSYS、Android Studio、Gradle 等都自带 java.exe，搜出来一堆不代表装了独立 JDK；独立安装一般在 `Java\jdk-*` / `Java\jre*` 目录，且同目录有 `release` 文件 |

### Python 生态

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| Python | `python.exe`、`pythonw.exe`、`py.exe` | `python.exe --version` | 多版本共存极常见；商店版在 `WindowsApps`（app 别名）；`py.exe` 是官方启动器，`py -0p` 可列出所有已装版本 |
| uv | `uv.exe`、`uvx.exe` | `uv.exe --version` | 默认装在 `<用户>\.local\bin` |
| pip | `pip.exe` | `pip.exe --version` | 跟随各 Python 环境，通常不用单独找 |
| conda | `conda.exe`、`mamba.exe` | `conda.exe --version` | 在 conda 安装的 `condabin`/`Scripts` 下 |

### Node / JS

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| Node.js | `node.exe` | `node.exe --version` | — |
| npm / npx / pnpm / yarn | `npm.cmd`、`npx.cmd`、`pnpm.exe`、`yarn.cmd` | `npm --version` | npm/npx 是 `.cmd` shim 不是 exe，`Get-Command npm` 更直接 |
| nvm-windows / volta / fnm | `nvm.exe`、`volta.exe`、`fnm.exe` | `--version` | 版本管理器会改变哪个 node 生效 |

### 编译 / 构建（C/C++）

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| MSVC (cl) | `cl.exe` | `cl.exe` 裸跑（stderr） | **不在 PATH**；位于 VS 的 `VC\Tools\MSVC\<版本>\bin\Hostx64\x64`。找 VS 用 vswhere：`& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`，再配 `vcvarsall.bat` |
| MinGW gcc | `gcc.exe`、`g++.exe`、`mingw32-make.exe` | `gcc.exe --version` | — |
| LLVM | `clang.exe`、`clang++.exe`、`clangd.exe` | `clang.exe --version` | — |
| CMake | `cmake.exe` | `--version` | — |
| Ninja | `ninja.exe` | `--version` | — |
| xmake | `xmake.exe` | `xmake.exe --version` | — |
| make | `make.exe` | `--version` | Windows 上多为 mingw32-make 或 MSYS2 提供 |

### 其他语言 / 运行时

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| Go | `go.exe` | `go.exe version` | — |
| Rust | `cargo.exe`、`rustc.exe`、`rustup.exe` | `cargo.exe --version` | 默认在 `<用户>\.cargo\bin` |
| Git | `git.exe`、`git-bash.exe` | `git.exe --version` | — |

### JVM 构建

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| Maven | `mvn.cmd` | `mvn --version` | .cmd shim |
| Gradle | `gradle.bat`、`gradle.exe` | `gradle --version` | IDEA 下载的发行版在 `<用户>\.gradle\wrapper` 下也能搜到 |

### IDE / 编辑器

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| VS Code | `Code.exe`；CLI 是 `code.cmd` | `code --version` | CLI 在 `<用户>\AppData\Local\Programs\Microsoft VS Code\bin` |
| JetBrains 全家 | `idea64.exe`、`pycharm64.exe`、`clion64.exe`、`webstorm64.exe`、`goland64.exe` 等 | — | Toolbox 安装在 `<用户>\AppData\Local\JetBrains\Toolbox\apps`，多版本并存搜出来一堆是正常的 |
| Notepad++ | `notepad++.exe` | — | — |
| Neovim / Vim | `nvim.exe`、`vim.exe` | `--version` | — |

### 容器 / 虚拟化 / 媒体 / 网络

| 软件 | es 搜 | 验证版本 | 备注 |
|---|---|---|---|
| Docker | `docker.exe`、`dockerd.exe` | `docker --version` | — |
| ffmpeg | `ffmpeg.exe`、`ffprobe.exe` | `ffmpeg.exe -version` | 常被剪映等软件捆绑 |
| wget | `wget.exe` | `--version` | — |

### Everything 自身

| 软件 | es 搜 | 备注 |
|---|---|---|
| Everything | `Everything.exe`（服务/GUI）、`es.exe`（CLI） | es 装哪了，直接搜 `es.exe` |

## Windows 自带工具（**不要用 es 搜，直接 `Get-Command`**）

Win10 1809+ 内置：`curl.exe`、`ssh.exe`、`scp.exe`、`tar.exe`；另有 `powershell.exe`、`wsl.exe`、`makecert` 类工具。装了 PowerShell 7 才有 `pwsh.exe`。
搜这些只会得到系统副本和噪音，没有信息量。

## 数据库（按需）

| 软件 | es 搜 | 验证 |
|---|---|---|
| PostgreSQL | `psql.exe`、`postgres.exe` | `psql.exe --version` |
| MySQL | `mysql.exe`、`mysqld.exe` | `mysql.exe --version` |
| Redis(Windows 移植) | `redis-server.exe`、`redis-cli.exe` | `redis-cli.exe --version` |
