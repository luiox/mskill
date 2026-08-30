# es.exe 完整参考（Everything CLI）

> 来源：voidtools 官方文档 <https://www.voidtools.com/zh-cn/support/everything/command_line_interface/>，
> 下载：<https://www.voidtools.com/zh-cn/downloads/#cli>（仅 zip，x64 / x86 / ARM64 / ARM，版本以下载页为准，不要凭记忆拼带版本号的 URL）。
> 前置条件：Everything 客户端必须已安装且正在运行（es 通过 IPC 窗口与它通信）。

```
es.exe [选项] [搜索词1] [搜索词2] ...
```

## 传参规则（最容易踩的坑）

- **每个搜索词是独立参数**。`es 7z ext:exe` 是两个 AND 词；`es "7z ext:exe"` 是一个字面短语搜索（含空格原样匹配），通常是空结果。
- es 不能访问 Everything 的书签和过滤器。
- 含空格的单个搜索词才需要引号：`es "visual studio" ext:exe`。
- 选项的 `-` 可省略或写成 `/`（`-n 10` = `/n 10`）；多数选项可用 `no-` 前缀取反。

## 通用选项

| 选项 | 作用 |
|---|---|
| `-r` `-regex` | 正则搜索 |
| `-i` `-case` | 区分大小写 |
| `-w` `-ww` | 全词匹配 |
| `-p` `-match-path` | 同时匹配完整路径和文件名（默认只匹配文件名） |
| `-h` `-help` | 帮助 |
| `-o <offset>` | 结果偏移（翻页） |
| `-n <num>` `-max-results <num>` | 限制结果条数 |
| `-s` | 按完整路径排序输出 |

## Everything 1.4+ 选项

**输出列**：`-name`、`-path-column`、`-full-path-and-name`、`-ext`、`-size`、`-date-created`(`-dc`)、`-date-modified`(`-dm`)、`-date-accessed`(`-da`)、`-attributes`(`-attrib`)、`-run-count`、`-date-run`、`-rc`（最近变更日期）。name/path 默认就有。

**排序**：`-sort <属性>`，属性可取 name、path、size、extension、date-created、date-modified、date-accessed、attributes、run-count 等；配 `-sort-ascending` / `-sort-descending`，或直接 `-sort size-descending`。默认：体积最大、日期最新、运行次数最多的在前，其余字母序。

**导出**：`-export-csv <file>`、`-export-efu`、`-export-txt`、`-export-m3u`、`-export-m3u8`（不输出到控制台，直接写文件）；格式化输出用 `-csv`、`-efu`、`-txt`、`-m3u`、`-m3u8` 配合 `>` 重定向或 `|` 管道。

**大小显示**：`-size-format <0..4>`（0 自适应、1 字节、2 KB、3 MB）；`-no-digit-grouping` 去千分位。

**路径过滤**（也可以不用选项、直接用搜索语法 `path:` / `parent:`）：
- `-path <路径>`：在该路径的子文件夹和文件里搜
- `-parent-path <路径>`：在父目录下搜
- `-parent <路径>`：只在指定父目录这一层搜

**实例与杂项**：`-instance <名称>` 指定 Everything 实例；`-timeout <毫秒>` 等待数据库加载；`-highlight` 高亮命中；`-pause`/`-more` 分页暂停；`-save-settings`/`-clear-settings` 把当前选项存入/清除 es.ini（存在 es.exe 同目录，会跳过本次搜索）。

## DIR 风格语法

- `/o<序>` 排序：N 名称、S 大小、E 扩展名、D 修改日期；大写升序小写降序（如 `/os` = 按大小降序）
- `/ad` 只要文件夹，`/a-d` 只要文件
- `/a<属性>` 按属性过滤：R 只读、H 隐藏、S 系统、D 目录、A 归档、C 压缩、E 加密……属性前加 `-` 表示排除（`/a-r` = 非只读）

## 搜索语法（Everything 语法，写进搜索词里）

| 语法 | 含义 |
|---|---|
| `foo bar` | AND（foo 且 bar，均默认只匹配文件名） |
| `foo|bar` | OR |
| `!foo` | 排除（不含 foo 的） |
| `ext:exe` | 按扩展名过滤 |
| `path:xxx` | 匹配完整路径 |
| `parent:xxx` | 限定直接父目录 |
| `dupe:` | 查重复文件名 |
| `count:` | 只返回数量 |
| `dm:today` / `dm:2024` | 按修改日期过滤 |
| 含 `\` 的裸词（如 `C:\Windows`） | 自动按完整路径匹配 |

注意 `!foo` 不带 `path:` 时只排除**文件名**命中；要排除路径噪音必须写 `!path:foo`（实测 `uv.exe !Prefetch` 排不掉 Prefetch 目录下的 `UV.EXE-xxx.pf`，`!path:Prefetch` 才行）。

**找精确 exe 名时加 `-w`（全词匹配）**：Everything 默认对文件名做子串匹配，搜 `cmake.exe` 会误中 `bscmake.exe`、`ament_lint_cmake.exe`；`es -w cmake.exe` 只返回真正的 cmake.exe（notepad++.exe、mingw32-make.exe 这类含特殊字符的名字实测不受影响）。

## 退出码

| 码 | 含义 | 处置 |
|---|---|---|
| 0 | 成功 | — |
| 1 | 注册窗口类失败 | 环境异常，重开 shell |
| 3 | 内存不足 | — |
| 4 | 缺少参数 | 检查选项（如 `-n` 后没跟数字） |
| 5 | 创建导出文件失败 | 检查输出路径权限 |
| 6 | 未知参数 | 拼写检查选项名 |
| 7 | IPC 查询发送失败 | 重试 |
| 8 | **找不到 Everything IPC 窗口** | **Everything 没运行**，先启动 Everything 再搜 |

## 在 PowerShell 里的推荐写法

```powershell
# 1) 万一出乱码，先统一编码（默认 GBK 控制台下不设也正确；设了 UTF8 实测同样正确）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 2) 定位 es
$es = (Get-Command es -ErrorAction SilentlyContinue).Source
if (-not $es) { $es = "$env:LOCALAPPDATA\Programs\es\es.exe" }

# 3) 搜索（搜索词全部作为独立参数）
& $es -n 10 7z ext:exe !path:C:\Windows !path:C:\ProgramData

# 4) 检查退出码
if ($LASTEXITCODE -eq 8) { Write-Error "Everything 未运行" }
```
