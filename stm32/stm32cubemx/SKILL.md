---
name: stm32cubemx
description: "AI 操作 STM32CubeMX 的标准工作流：.ioc 手写/编辑规范、headless（-q 脚本）代码生成、生成物进 git 的边界、xmake/CMake 构建。当任务涉及 .ioc 文件、CubeMX 生成 Core/ 目录、MX_*_Init、USER CODE 区间、STM32 工程脚手架时使用。绑定本机环境（CubeMX 6.18.0-RC3 / STM32F103 精英板 / lab-stm32）。"
---

# STM32CubeMX 工作流（本机环境绑定版）

方法源自 Aidankong/embedded-development-skill 与 limpidautumn/skill-stm32cubemx（UM1718 知识库），原版在 `../vendor/`。本版差异：绑定本机路径、坑清单全部来自 lab-stm32 实测（2026-08），构建用 xmake 而非 CMake/Makefile。

## 环境绑定（本机事实）

| 项 | 值 |
|---|---|
| CubeMX | `D:\Program Files\STMicroelectronics\STM32Cube\STM32CubeMX\STM32CubeMX.exe`（6.18.0-RC3） |
| 固件包 | `C:\Users\Canrad\STM32Cube\Repository\STM32Cube_FW_F1_V1.8.7\`（本地已有 → generate 无需 login） |
| 主力芯片 | STM32F103ZET6，LQFP144（正点原子精英板；LED0=PB5、LED1=PE5 低电平亮，BEEP=PB8，KEY0/1/2=PE4/3/2 上拉输入，WK_UP=PA0 下拉输入，USART1=PA9/PA10） |
| ARM GCC | `D:/sdk/Arm GNU Toolchain arm-none-eabi/11.3 rel1`（xmake `--sdk=` 传入） |
| 构建规则 | lab-stm32 `xmake/f1.lua`（自动注入 demo 的 Core/Src + Core/Inc） |
| 生成脚本 | lab-stm32 `tools/cubemx_gen.bat <file.ioc>`（内部：写 -q 脚本 → 调 `tools/cubemx_run.bat`） |

## 核心工作流

```
编辑 .ioc（唯一配置源）
  → tools/cubemx_gen.bat <abs\path.ioc>     # headless 生成 Core/
  → xmake b <target>                        # Core/Src 由 f1.lua 自动注入
```

**绝对原则：初始化代码（main.c 的 SystemClock_Config/MX_*_Init、gpio.c、usart.c、it.c、msp.c、syscalls/sysmem/system）一律由 CubeMX 生成，绝不手写。** 手只碰两类地方：
1. `.ioc`——外设拓扑的唯一真源；
2. 生成文件里的 `/* USER CODE BEGIN n */ ... END n */` 区间——再生成时唯一保留的区域。

## 硬坑清单（每条都真实踩过）

1. **exe4j 假退出**：`STM32CubeMX.exe -q script` 的 launcher 会 fork 出 javaw 立刻返回（bash 里 `$?`==0 是假的），真身在后台 javaw 里跑。判断成败只能看**产物文件**，不能看退出码。
2. **单实例锁 + 僵尸**：一个卡死的 headless 实例会把后续所有实例堵死（新实例 10 秒内静默退出）。症状：javaw 常驻无窗口、内存 500MB+ 不动。处置：`taskkill /F /PID <javaw>`（先用 PowerShell `Get-Process javaw | select Id,MainWindowTitle` 确认无窗口，别误杀用户 GUI），再重跑。
3. **Clock 解算抢跑**：首次 `config load` 后时钟树是异步解算的，立刻 `project generate` 报 `IP not ready for code generation: Clock` 且不产出。**解法：一个脚本里连两遍 `load → generate`**（第一遍触发解算+SaveConfig，第二遍真生成）。
4. **SaveConfig 会重写 .ioc 并静默丢弃解算失败的引脚**：HSE 晶振脚名字写错（见第 5 条）→ 加载失败 → 保存时晶振脚直接消失 → 下次生成时钟不可解。生成后必须 `grep OSC xxx.ioc` 复查。
5. **引脚名随封装变**：LQFP144 的 F103ZET6 晶振脚叫 `OSC_IN`/`OSC_OUT`；`PD0-OSC_IN`/`PD1-OSC_OUT` 是 LQFP64 的叫法。查权威名字：`db/mcu/STM32F103Z(C-D-E)Tx.xml` 里 grep `Name="...OSC..."`（db 在 CubeMX 安装目录）。
6. **6.18.0-RC3 的幽灵 pin**：加载时报 `Pin7 (VP_RIF_VS_RIF1) cannot be retrieved` ——RC 版 RIF 插件 bug，**无害可忽略**，SaveConfig 不会真写进去。
7. **cmd 批处理必须 ASCII + CRLF**：UTF-8 中文注释在 GBK 代码页下直接把 bat 解析炸掉（报"命令语法不正确"）。bat 写完后 `python -c` 重写为纯 ASCII 字节 + `\r\n`。
8. **Git Bash 调 cmd**：必须 `MSYS2_ARG_CONV_EXCL="*"` 前缀，否则 `/c` 被路径转换毁掉；单引号内的 `\` 原样传递，内层不要再套双引号（会被转义成 `\"` 字面量）。路径无空格就别加引号。
9. **控制台输出**：javaw 默认吞 stdout；经 `cmd /c ... > file 2>&1` 重定向后 exe4j 会把 JVM 输出接过来——调试 headless 必须落文件看。

## .ioc 边界（进 git 的内容）

| 进 | 不进 |
|---|---|
| `.ioc`（配置真源）、`.mxproject` | `Drivers/`（CubeMX 拷的 68MB 库源码，用仓库共享 hal/ 静态库代替） |
| `Core/`（生成物但含 USER CODE，照 mf 惯例提交） | `Projects/`（RC3 的 Makefile/startup/ld 落这里；构建用自有 ld + 共享 startup） |
| `xmake.lua`、README | `MXTmpFiles/`、build 产物 |

## 详细参考

- [references/ioc-authoring.md](references/ioc-authoring.md) —— 键名/同步规则/转义/ZET6 身份块模板/引脚名查法
- [references/headless-generation.md](references/headless-generation.md) —— 脚本命令表/两遍生成/bat 模板/故障排查树
