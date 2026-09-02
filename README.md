# mskill

AI skill 单仓库：meta 方法论 + 领域 skill 自己写，别人的仓库只留链接。

## 布局

```
meta/            跨领域个人纪律（自己写，≤5 条，每条要密）
stm32/           领域 skill（自己写）
  └── stm32cubemx/   CubeMX .ioc + headless 生成工作流
<领域>/<名字>/    新领域照这个模式加目录即可，sync 会自动发现
```

## 原则

1. **单仓库分层**：宿主发现机制只看"skills 根下每个子目录一个 SKILL.md + description 门控"，仓库只是存储——组织靠目录，不拆库。
2. **参考不进仓库**：别人的方法论仓库不 vendor、不 submodule，只在文末维护链接清单；AI 需要原版时 `git clone --depth 1` 到临时目录读，用完即删。要绑定本地环境的 → 自己写薄 skill，头部注明方法来源 URL。
3. **机器事实不写死**：绝对路径、用户名、盘符不进 git。SKILL.md 只写探测步骤（es / `Get-Command`），实测结果写进 skill 目录下 `local.md`（`.gitignore` 已忽略），换机器重新探测。
4. **只写"只有自己会这么干"的**：模型权重里已有的通用方法论不写；沉淀的是个人纪律 + 实测踩坑（每条都必须真实踩过）。
5. **脚本只用 PowerShell**：不写 cmd/bat（编码、引号行为在 GBK 代码页下是坑，且与 meta/local-software-use 的纪律一致）。

## 启用（junction 平铺）

```
powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1            # 链接全部（已存在跳过）
powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1 -List      # 只看会链接哪些
powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1 -Remove    # 摘除本仓库创建的 junction
```

默认链接到 `%USERPROFILE%\.agents\skills`（ZCode / Claude / Codex 等宿主的用户级发现目录，跨宿主通用），`-Dest <路径>` 可覆盖。扫描规则：除 `vendor` 和点目录外，凡二级目录含 SKILL.md 即视为 skill，加新领域不用改脚本。**opt-in 域**：领域目录里放一个 `.nosync` 空标记文件即默认不 sync（如 `win-clean/`，不是人人需要），要用时 `sync.ps1 -Include win-clean` 手动装。平铺而非整库链接：多数宿主只扫一层目录；且可精确控制启用面。

## 领域 skill 一览

| skill | 用途 |
|---|---|
| `stm32/stm32cubemx` | .ioc 手写规范 + CubeMX headless（-q）生成管线 + 生成物进 git 边界（F103ZET6/精英板/xmake 绑定版） |
| `win-clean/homepage-hijack-cleanup` | 浏览器主页劫持（360导航家族）取证+清理：双通道认知（设置篡改+持久化重改）、七通道判定、二进制指纹（ANSI/UTF-16LE）、安全清理顺序 + detect-hijack.ps1 只读体检；指纹库含疾风软件市场/NStore 全套特征 |

## meta skill 一览

| skill | 用途 |
|---|---|
| `meta/local-software-use` | Windows 本机软件定位与安装纪律：Everything CLI (es) 全盘秒搜代替递归遍历（独立传参 / `!path:` / `-w` 全词等实测坑）+ PATH 安全写法（禁 setx 防静默截断）+ 小工具装用户目录、大型软件先问装哪 + 常用软件→exe 映射表 |

## 参考仓库（不进仓库，按需克隆）

| 仓库 | 内容 | 服务的 skill |
|---|---|---|
| [Aidankong/embedded-development-skill](https://github.com/Aidankong/embedded-development-skill) | 嵌入式开发方法论 | `stm32/stm32cubemx` |
| [limpidautumn/skill-stm32cubemx](https://github.com/limpidautumn/skill-stm32cubemx) | CubeMX headless + UM1718 知识库 | `stm32/stm32cubemx` |

需要原版参考时：`git clone --depth 1 <url> "$env:TEMP\<名字>"`，读完即删——绝不 junction 启用、不提交进本仓库。
