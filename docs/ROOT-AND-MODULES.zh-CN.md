# BOOX Tab10CPro：Magisk ROOT 与模块安装步骤

本文针对 BOOX Tab10CPro 的已记录流程。设备型号、固件分支和更新版本可能改变 boot 镜像、分区布局、启动验证策略与 Magisk 行为。开始前在设备“设置 → 关于本机”记录完整型号、Android 版本和完整构建号。

## 0. 准备与恢复方案

- 备份重要个人数据。解锁 bootloader 通常会清除用户数据；如果当前设备已解锁，则不要重复解锁。
- 确认可以访问与当前固件完全匹配的官方完整固件包，并理解如何用 BOOX 官方方式恢复。
- 安装官方 Android SDK Platform-Tools；启用开发者选项和 USB 调试。连接电脑后在设备上接受 RSA 授权。
- 只使用当前设备/当前构建的原始 `boot.img`。不要从相近型号、旧固件、论坛附件或不明来源拿镜像。
- 本仓库没有镜像文件；此前工具目录里的 IMG 属于其他用途，不应据此刷写。

## 1. 解锁（仅在确实锁定且已研究官方解锁路径时）

通过设备对应的官方 bootloader/厂商流程确认是否可解锁。解锁可能清除数据、改变设备安全状态并影响保修。不要猜测 fastboot 命令，不要尝试 EDL 写入或跨型号解锁。如设备无法确认官方支持的解锁路径，先停止并查证对应固件的可靠恢复资料。

## 2. 用 Magisk 修补原始 boot 镜像

1. 安装从 [Magisk 官方仓库](https://github.com/topjohnwu/Magisk)获取的 Magisk App。
2. 把本机当前固件提取/官方包中的原始 `boot.img` 复制到设备存储。
3. 在 Magisk App 点“安装”→“选择并修补一个文件”，选中原始 `boot.img`。
4. 等待完成，从 Magisk 日志/输出路径取得 `magisk_patched-*.img`，复制回电脑。
5. 记录原始与修补镜像的 SHA-256，分别保留在安全位置。确认修补镜像来源、大小合理且与本机构建匹配。

Magisk 的具体 UI 与镜像要求以当前版本官方安装说明为准。不要将本步骤替换为目录里恰好存在的任意 IMG。

## 3. 刷入与首次启动

本仓库的辅助脚本**不执行** `fastboot flash`。分区名称、A/B 槽位、启动镜像类型及锁状态需要针对本机核实；盲刷可能导致无法启动。仅按已验证且适用于本机精确构建的流程操作，并确保能恢复原始 boot。刷入后重启，首次启动留出足够时间。

## 4. 验证 root

- 打开 Magisk App，确认安装状态与版本。
- 可在已授权 ADB shell 中运行 `su -c id`；成功结果应包含 `uid=0(root)`。Android 端出现 Magisk 授权窗口时，由设备所有者确认。
- 如果 Magisk App 被 BOOX 的应用冻结/自启动策略停用，先在系统设置中允许 Magisk 自启动/后台运行，再打开 App。不要因 App 图标卡住就重复刷写。
- 若设备启动异常，使用之前准备的官方恢复方案；不要反复尝试不同设备的 boot 镜像。

## 5. 安装 Magisk 模块

1. 从模块开发者的官方发布渠道获取 ZIP。先确认适用 Android 版本、CPU 架构、Magisk 版本、Zygisk 需求与已知问题。
2. 对照开发者公布的 SHA-256/签名验证下载文件。仅有本地哈希值不等于可信。
3. 打开 Magisk → 模块 → 从本地存储安装，选择 ZIP；或者用仓库中的 Windows 辅助脚本选择 ZIP，并在二次确认后请求 Magisk 安装。
4. 阅读安装日志。只有提示成功后才按模块说明重启；一次只添加一个模块，方便出问题时定位。
5. 出现 bootloop 时，按 Magisk 官方救援/安全模式说明禁用最近安装的模块，或使用官方固件恢复。

### Zygisk 与 LSPosed

LSPosed 需要 Zygisk。此次已记录的设备使用 Magisk 内置 Zygisk，并安装了 LSPosed v2.2.1（build 7912）。这只是该次设备的记录，不是对任意构建的兼容性承诺。ZygiskNext 是替代 Zygisk 实现；不要同时启用 Magisk 内置 Zygisk 与 ZygiskNext。遵循 LSPosed 与 ZygiskNext 当前官方文档及各自模块说明。

## 6. Windows 辅助脚本

双击仓库根目录 `一键ROOT并安装模块.cmd`：

- 检测唯一在线 ADB 设备与型号信息。
- 尝试检查 `su -c id` 是否返回 root。
- 已 root 时显示当前模块目录，可选 ZIP、显示 SHA-256 并二次确认安装。
- 未 root 时提示 Magisk 修补步骤，不会自动刷写 boot、重启设备或触碰 IMG。

依赖 Windows PowerShell 5.1 和 ADB。只连接一台已授权设备。请审阅脚本再运行；模块 ZIP 是可执行代码，只安装你信任的模块。

## 排错

- **ADB 显示 unauthorized**：解锁设备屏幕，重新插拔 USB，在设备上确认 RSA 提示。
- **ADB 找不到设备**：检查数据线、USB 模式、驱动与 platform-tools；不要因此切换成 EDL。
- **su 被拒绝/超时**：检查 Magisk 超级用户列表与弹窗；确认是由设备所有者批准。拒绝后不要循环触发无意义请求。
- **模块安装失败**：检查模块 ZIP 结构、设备空间、Magisk 安装日志与兼容性；不要对 APK 或不明 ZIP 使用 `magisk --install-module`。
- **Magisk/系统启动异常**：先禁用最近添加的模块；若仍失败，依照已准备的官方恢复资料恢复原始系统镜像。
