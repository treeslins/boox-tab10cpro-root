# BOOX Tab10CPro Root 指南与 Magisk 模块工具

记录 BOOX Tab10CPro（本指南验证设备：Tab10CPro，Android 13，BOOX 固件 4.2.1）使用 Magisk 获取 root、检查 root 状态与安装 Magisk 模块的流程。固件/系统更新会改变适用性；请先核对自己的完整型号和构建号，不要把本指南当作通用 BOOX 刷机包。

> **重要风险**：解锁 bootloader、修补/刷写 boot 镜像可能清除数据、触发启动失败或影响保修。公开仓库不提供设备镜像，也不会自动刷写任何分区。优先使用 Qualcomm 工具箱从本机回读的原始 boot；也可使用与本机当前构建严格匹配的官方镜像。先备份并准备可用的官方恢复包/救援方式。操作风险由设备所有者自行承担。

## 内容

- `docs/ROOT-AND-MODULES.zh-CN.md`：详细 ROOT 流程，重点包括 Qualcomm 工具箱 EDL 回读全分区、生成 GPT/XML、Magisk 修补及活动槽位 boot 写入边界
- `tools/Tab10CPro-Root-Module.ps1`：Windows PowerShell 辅助脚本，检测 ADB/root 并安装用户选择的模块 ZIP
- `modules/boox-ams-fix-tab10cpro-4.2.1.zip`：Tab10CPro 固件 4.2.1 专用 Magisk systemless 模块，用于修复 ROOT 后 Magisk 卡在启动页
- `一键ROOT并安装模块.cmd`：启动入口

## 快速开始

1. Windows 安装 Android SDK Platform-Tools，并在设备上启用 USB 调试。
2. 解压本仓库；把 `adb.exe` 放在 `tools` 目录，或将 platform-tools 加入 `PATH`。
3. 双击 `一键ROOT并安装模块.cmd`，首次连接时在设备上确认 USB 调试授权。
4. 已有 Magisk root 时，脚本可选择模块 ZIP 并请求 Magisk 安装。检查 ZIP 来源与兼容性，并对 SHA-256 做独立核验。
5. 若尚未 root，先按[详细 ROOT 指南](docs/ROOT-AND-MODULES.zh-CN.md)操作：用 Qualcomm 工具箱回读全分区并生成 GPT/XML，取当前槽位 boot 给 Magisk 修补，再按设备专用流程处理目标分区。脚本本身不会刷写。

**本仓库没有一键解锁或自动刷 boot 功能。**脚本不会自动重启、不会挑选 `.img` 文件，也不会尝试绕过 bootloader 锁或 Magisk 的授权界面。首次 ROOT 的准确步骤见详细指南。Android 端如果出现超级用户授权，由设备所有者亲自确认。

## 已验证情况与边界

本次设备操作记录：BOOX Tab10CPro，Android 13 / SDK 33，固件 4.2.1；Magisk 30.7（内部版本 30700）；Magisk 内置 Zygisk 已启用。通过与该固件匹配的 boot 镜像修补并刷入后，重启验证 root 可用。曾安装 LSPosed v2.2.1（build 7912）作为 Magisk/Zygisk 模块。此记录不代表所有同型号设备或后续固件都适用。

本仓库不包含 boot/recovery/完整固件镜像、EDL programmer、设备分区备份、商业 APK、Magisk/LSPosed/ZygiskNext 安装包。仓库内的 AMS 修复模块仅匹配 Tab10CPro 固件 4.2.1；Qualcomm 工具箱从维护者的 [GeekFlashTool 高通资源包](https://gitee.com/geekflashtool/Package_Qualcomm_EDL)获取，本仓库不重新分发该第三方工具集。

## 参考资料

- [Magisk 官方安装说明](https://github.com/topjohnwu/Magisk#installation)
- [Magisk 官方 Releases](https://github.com/topjohnwu/Magisk/releases)
- [LSPosed 官方仓库](https://github.com/LSPosed/LSPosed)
- [ZygiskNext 官方仓库](https://github.com/LSPosed/ZygiskNext)（独立 Zygisk 实现；使用前关闭 Magisk 内置 Zygisk，避免重复实现）
- [BOOX Tab10CPro 刷机/root 参考](https://doc.yoouu.cn/interest/flash/tab10cpro.html#root)
- [boox-p6pro-root 参考项目](https://github.com/dynamicfire/boox-p6pro-root)（不同机型/固件内容仅作参考）

## 免责声明

本仓库仅供设备所有者研究和维护自有设备。刷机/ROOT 可能造成数据丢失、系统损坏或安全性下降；不提供任何保证。请勿在未经许可的设备上操作。第三方工具与模块由其各自作者负责。





