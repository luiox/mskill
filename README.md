# mskill

AI skill 单仓库：meta 方法论 + 领域 skill 自己写，vendor 原样引用。

## 布局

```
meta/            跨领域个人纪律（自己写，≤5 条，每条要密）
stm32/           领域 skill（自己写，绑定本机环境）
  └── stm32cubemx/   CubeMX .ioc + headless 生成工作流
vendor/          别人的仓库（submodule，只读参考，绝不 junction 启用）
```

## 原则

1. **单仓库分层**：宿主发现机制只看"skills 根下每个子目录一个 SKILL.md + description 门控"，仓库只是存储——组织靠目录，不拆库。
2. **submodule 硬边界**：原样引用的（不会改一个字）→ vendor/；要绑定本地环境的 → 自己写薄 skill（头部注明方法来源），原仓库挂 vendor/ 旁边当参考。**submodule 放"读的"，自己的目录放"改的"。**
3. **只写"只有自己会这么干"的**：模型权重里已有的通用方法论不写；沉淀的是个人纪律 + 实测踩坑（每条都必须真实踩过）。

## 启用（junction 平铺）

```
sync.cmd            # 把含 SKILL.md 的目录 junction 进 C:\Users\Canrad\.agents\skills\
sync.cmd --remove   # 摘除本仓库创建的 junction
```

平铺而非整库链接：多数宿主只扫一层目录；且可精确控制启用面。vendor/ 永不启用。

## 领域 skill 一览

| skill | 用途 |
|---|---|
| `stm32/stm32cubemx` | .ioc 手写规范 + CubeMX headless（-q）生成管线 + 生成物进 git 边界（F103ZET6/精英板/xmake 绑定版） |

## meta skill 一览

| skill | 用途 |
|---|---|
| `meta/local-software-use` | Windows 本机软件定位与安装纪律：Everything CLI (es) 全盘秒搜代替递归遍历（独立传参 / `!path:` / `-w` 全词等实测坑）+ PATH 安全写法（禁 setx 防静默截断）+ 小工具装用户目录、大型软件先问装哪 + 常用软件→exe 映射表 |
