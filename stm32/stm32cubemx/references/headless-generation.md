# CubeMX headless 生成（-q 脚本模式）

## 脚本格式

纯文本，一行一条命令，最后 `exit`：

```
config load D:\abs\path\project.ioc
project generate
config load D:\abs\path\project.ioc
project generate
exit
```

- 路径必须绝对；`config load` 之后 CubeMX 会 SaveConfig **规范化重写** .ioc。
- **load → generate 连写两遍**：第一遍触发时钟树解算（会报 `IP not ready for code generation: Clock`，属预期），第二遍真生成。
- 本机 FW 包已在 Repository → 不需要 `login`；若要 `swmgr install` 才需要。

## 本机调用链（lab-stm32 已落地）

```
tools/cubemx_gen.bat <abs.ioc>      # 入口：生成临时脚本（load/generate ×2/exit）
  └─ tools/cubemx_run.bat <script>  # 通用："%CUBEMX%" -q "%~f1"
```

cubemx_run.bat 实体（**必须 ASCII + CRLF**，中文注释会把 GBK 代码页下的解析炸掉）：

```bat
@echo off
setlocal
set "CUBEMX=D:\Program Files\STMicroelectronics\STM32Cube\STM32CubeMX\STM32CubeMX.exe"
if "%~1"=="" exit /b 1
"%CUBEMX%" -q "%~f1"
exit /b %ERRORLEVEL%
```

从 Git Bash 调：

```bash
MSYS2_ARG_CONV_EXCL="*" cmd /c 'tools\cubemx_run.bat D:\path\script.txt' > /tmp/out.log 2>&1
```

要点：`MSYS2_ARG_CONV_EXCL="*"` 必须（否则 `/c` 被路径转换毁掉，cmd 进交互模式）；**输出必须重定向到文件**——javaw 吞控制台，但重定向后 exe4j 会把 JVM stdout 接过来，这是唯一的排障手段；退出码不可信（launcher 假退出），成败只看产物。

## 批量生成

一个脚本里对多个 .ioc 串行 `load/generate ×2`，单 JVM 跑完（省启动）。实测 3 个 demo（各两遍 generate）约 3-4 分钟。

## 故障排查树

| 症状 | 根因 | 处置 |
|---|---|---|
| 退出码 0 但没产物 | launcher 假退出 / 脚本命令没执行 | 落文件看日志；grep `Generated code` |
| 日志停在插件加载，javaw 常驻 | 僵尸实例持单实例锁 | PowerShell 确认无窗口后 taskkill javaw，重跑 |
| `IP not ready for code generation: Clock` | 时钟树未解算完（单遍 generate） | 脚本里 load+generate 连两遍 |
| `Cannot map signal (RCC_OSC_IN) on pin (PD0-OSC_IN)` | 引脚名与封装不符（144 脚应叫 OSC_IN） | 查 db/mcu XML 改名，生成后 grep 复查没被丢 |
| `Pin7 (VP_RIF_VS_RIF1) cannot be retrieved` | 6.18.0-RC3 RIF 插件 bug | 忽略，无害 |
| `命令语法不正确`（cmd） | bat 含 UTF-8 中文 / MSYS 路径转换 | bat 重写为 ASCII+CRLF；加 MSYS2_ARG_CONV_EXCL |

## 成功日志特征

```
CodeEngine:321 - Generated code: <demo>\Core\Src\main.c
ProjectBuilder:3738 - Time for Copy HAL[0] : ...
ProjectBuilder:5636 - Time for Generating toolchain IDE Files: ...
OK
exit
Bye bye
```

## 生成物处置（本仓库边界）

| 生成物 | 处置 |
|---|---|
| `Core/`（Src+Inc 含 hal_conf/syscalls/sysmem/system） | 提交（含 USER CODE，照 mf 惯例） |
| `.mxproject` | 提交 |
| `.ioc`（被 SaveConfig 规范化后） | 提交（此后以它为真源 diff） |
| `Drivers/`（68MB 库拷贝） | 忽略 + 删除，构建走共享 hal/ 静态库 |
| `Projects/`（Makefile/startup/ld，RC3 落这里） | 忽略，构建用自有 ld + 共享 startup |
| `MXTmpFiles/` | 忽略 |

生成后再生成（改了 .ioc）：直接重跑脚本，USER CODE 区间自动保留；若删了某外设，其 init 函数会被注释保留在原位，需手动清理 USER CODE 外的残句。
