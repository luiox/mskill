# .ioc 手写/编辑规范

适用：AI 直接编辑 .ioc 后用 CubeMX headless 生成（GUI 打开验证也可，但脚本化是本命）。

## 同步规则（改一处必改其偶）

- 加外设：`Mcu.IPx` 新条目 + `Mcu.IPNb` 计数，二者必须一致。
- 加引脚：`Mcu.Pin<n>` 条目 + `Mcu.PinsNb` 计数，且引脚必须有自己的 `Signal=` 行。
- 每个用到的引脚：`<pin>.Signal=<信号名>`；有模式要求再加 `<pin>.Mode=<模式>`。
- `ProjectManager.functionlistsort` 决定 main.c 里 init 函数的调用顺序，加了 MX_*_Init 就补一条（编号递增）。

## 转义规则（.ioc 是 java properties 变体）

`:` → `\:`，`#` → `\#`，`=` → `\=`，属性名里的空格 → `\ `。
例：`NVIC.USART1_IRQn=true\:5\:0\:false\:false\:true\:true\:true\:true`

## 常用键速查（F1 实测有效）

```ini
# GPIO 输出（标签 → main.h 生成 <标签>_Pin / <标签>_GPIO_Port 宏）
PB5.GPIOParameters=PinState,GPIO_Label
PB5.GPIO_Label=LED0
PB5.PinState=GPIO_PIN_SET
PB5.Signal=GPIO_Output

# GPIO 输入带上/下拉
PE3.GPIOParameters=GPIO_PuPd,GPIO_Label
PE3.GPIO_Label=KEY1
PE3.GPIO_PuPd=GPIO_PULLUP
PE3.Signal=GPIO_Input

# USART1 异步（PA9/PA10，默认 115200 8N1 不用显式写）
PA9.Mode=Asynchronous
PA9.Signal=USART1_TX
PA10.Mode=Asynchronous
PA10.Signal=USART1_RX
USART1.IPParameters=VirtualMode
USART1.VirtualMode=VM_ASYNC

# 中断使能（第二个 5 = 抢占优先级）
NVIC.USART1_IRQn=true\:5\:0\:false\:false\:true\:true\:true\:true
```

## STM32F103ZET6（LQFP144）身份块

```ini
Mcu.CPN=STM32F103ZET6
Mcu.Family=STM32F1
Mcu.Name=STM32F103Z(C-D-E)Tx
Mcu.Package=LQFP144
Mcu.UserName=STM32F103ZETx
ProjectManager.DeviceId=STM32F103ZETx
```

时钟（HSE 8MHz ×9 = 72MHz，APB1=36MHz）RCC 块直接抄 mcu_frameproject `starters/stm32f1/starter.ioc` 的 RCC 段（同家族同 FW 1.8.7 的权威模板），含 `RCC.PLLSourceVirtual=RCC_PLLSOURCE_HSE`、`RCC.PLLMUL=RCC_PLL_MUL9`、`RCC.APB1CLKDivider=RCC_HCLK_DIV2` 及全部 `*_Freq_Value` 派生值。

## ProjectManager 关键键

```ini
ProjectManager.FirmwarePackage=STM32Cube FW_F1 V1.8.7
ProjectManager.TargetToolchain=Makefile     ; 本机构建用 xmake，此值仅影响生成物形态
ProjectManager.CoupleFile=true              ; 每外设独立 gpio.c/usart.c（mf 同款结构）
ProjectManager.LibraryCopy=0                ; 只拷必要库文件
ProjectManager.MainLocation=Core/Src
ProjectManager.KeepUserCode=true
ProjectManager.CompilerLinker=GCC
ProjectManager.ComputerToolchain=false      ; 不生成 Makefile（RC3 会把三件套丢进 Projects/）
```

## 引脚名权威查法

 CubeMX 安装目录设备库（名字带模式通配，如 ZET6 → `STM32F103Z(C-D-E)Tx.xml`）：

```bash
python -c "import re;xml=open(r'D:/Program Files/STMicroelectronics/STM32Cube/STM32CubeMX/db/mcu/STM32F103Z(C-D-E)Tx.xml',encoding='utf-8',errors='ignore').read();print(sorted(set(re.findall(r'Name=\"([^\"]*OSC[^\"]*)\"',xml))))"
```

LQFP144 vs LQFP64 差异实例：晶振脚 144 脚是专用 `OSC_IN/OSC_OUT`，64 脚是复用 `PD0-OSC_IN/PD1-OSC_OUT`。名字写错 → 加载报 `Cannot map signal` → SaveConfig 静默丢脚。

## 已验证的 F103ZET6 引脚语义（正点原子精英板）

| 资源 | 引脚 | 语义 |
|---|---|---|
| LED0 / LED1 | PB5 / PE5 | 推挽输出，**低电平点亮**，初始置 SET（灭） |
| BEEP | PB8 | 高电平响，初始 RESET |
| KEY0/KEY1/KEY2 | PE4/PE3/PE2 | 按下=低，上拉输入 |
| WK_UP | PA0 | 按下=高，下拉输入 |
| USART1 | PA9 TX / PA10 RX | APB2 72MHz，115200 8N1 |
| HSE | OSC_IN/OSC_OUT | 8MHz 晶振，PLL×9 |
