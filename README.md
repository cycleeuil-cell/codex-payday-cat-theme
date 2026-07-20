# Codex 月薪猫动态皮肤

公开仓库：<https://github.com/cycleeuil-cell/codex-payday-cat-theme>

一套适用于 **Windows Microsoft Store 版 Codex 桌面应用**的奶油金色主题。右下角的“月薪猫”不是静态图标，它会跟随 Codex 的状态切换动画：

- 空闲待命
- 正在思考
- 正在工作
- 等待审批
- 任务完成
- 任务异常

![月薪猫主页横幅](theme/payday-hero.png)

<p align="center"><img src="theme/payday-pet.png" alt="月薪猫动态工作状态宠物" width="220"></p>

## 直接把本仓库链接交给 Codex

在另一台 Windows 电脑上打开 Codex，新建任务，把 <https://github.com/cycleeuil-cell/codex-payday-cat-theme> 和下面这句话一起发给它：

> 请打开这个仓库，完整阅读 README、INSTALL_WITH_CODEX.md 和 scripts 下的 PowerShell 脚本；先做安全审计，再按照仓库说明为我安装 Codex 月薪猫动态皮肤。不要修改 Microsoft Store 原版，不要读取或上传我的账号、聊天或任务数据。安装完成后验证素材哈希、主题运行副本和回滚能力。

对方 Codex 会自动克隆仓库并运行安装器。安装完成后，只需完全退出当前 Codex，再打开桌面的 **Codex Payday Cat**。

给 Codex 的详细执行规范见 [INSTALL_WITH_CODEX.md](INSTALL_WITH_CODEX.md)。

## 它会做什么

- 从本机已安装的 Microsoft Store Codex 创建一个独立运行副本；
- 只对独立副本的界面资源注入主题 CSS、图片和状态宠物脚本；
- 默认安装到 `%LOCALAPPDATA%\CodexPaydayCat`；
- 创建一个桌面快捷方式和一个开始菜单快捷方式；
- Codex 更新后，下一次启动主题版时会自动重新适配；
- 按 Codex 版本保存原始 `app.asar`，可以回滚独立副本。

## 它不会做什么

- 不修改 Microsoft Store 安装的原版 Codex；
- 不打包或分发 Codex/ChatGPT 程序、`app.asar` 或任何 OpenAI 二进制文件；
- 不读取、复制或上传账号凭据、Cookie、聊天、任务、日志和本地数据库；
- 不替换你的官方 Codex 快捷方式。

## 手动安装（可选）

需要 Windows PowerShell、Microsoft Store 版 Codex，以及 Node.js 提供的 `npx.cmd`（也支持 `pnpm.cmd`）。在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Install-PaydayCat.ps1"
```

安装器运行时可以保持当前原版 Codex 打开。安装完成后，完全退出当前 Codex，再打开 **Codex Payday Cat**。

## 更新、启动与还原

安装目录默认是 `%LOCALAPPDATA%\CodexPaydayCat`：

```powershell
# 手动重新应用主题
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CodexPaydayCat\Update-PaydayCat.ps1"

# 启动主题版
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CodexPaydayCat\Launch-PaydayCat.ps1"

# 把独立运行副本恢复成原界面
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CodexPaydayCat\Restore-Original.ps1"
```

随时直接打开 Microsoft Store 原版 Codex，也可以立即回到官方界面。

## 支持范围与注意事项

- 当前仅支持 Windows x64 的 Microsoft Store `OpenAI.Codex` 桌面应用；
- Codex 大版本更新可能改变界面入口或选择器。安装器会在关键结构不匹配时停止，不会强行写入；
- 这是社区外观修改，不是 OpenAI 官方功能；
- 主题运行副本会占用约 2 GB 磁盘空间；
- 完整安全模型见 [SECURITY.md](SECURITY.md)。

## 素材来源

视觉形象摘取自抖音作者 **Ai柳丁汁** 的公开图文作品：<https://v.douyin.com/xPohiMdKWOE/>。

代码许可和图片权利边界见 [LICENSE](LICENSE) 与 [ATTRIBUTION.md](ATTRIBUTION.md)。原作品及角色形象的权利归原作者/权利人所有，请勿用于商业用途。
