# BOOX Tab10CPro：Magisk ROOT 与模块安装

本文记录本仓库对应的实机流程：BOOX Tab10CPro、Android 13（SDK 33）、BOOX 固件 4.2.1、Magisk 30.7。固件构建号变更、OTA 更新、同名设备的区域版本差异，都可能令镜像或分区信息不再适用。每次操作前请按设备“关于本机”核对完整型号和构建号。

> **风险提示**：解锁 bootloader 可能清空数据；写错槽位或写入不匹配镜像可能导致无法启动。开始前备份数据、原始分区和官方恢复包。本文不提供固件、boot 镜像或 firehose programmer；请勿使用本地目录里来源不明或注明用于其他用途的 IMG。

## 总体流程

```text
确认型号/构建和恢复路径
  → 确认 bootloader 已解锁
  → 获取本机当前构建的原始 boot 镜像
  → 在设备 Magisk App 中修补
  → 读取当前槽位并只写对应 boot 分区
  → 重启并验证 uid=0(root)
```

Magisk 官方要求 bootloader 解锁后才继续首次安装；首次安装要修补含 ramdisk 的正确镜像，可能是 `boot.img`、`init_boot.img` 或 `vendor_boot.img`，具体由设备结构决定。不要仅凭“Android 13”就猜分区。官方说明：[Magisk Installation](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md)。

## 0. 准备与恢复

1. 备份设备上的书籍、下载内容和其他重要数据。解锁流程可能会 factory reset。
2. 提前取得该设备、该区域、当前完整构建号的官方固件包，并确认官方恢复流程可用。把原始 boot 分区备份到电脑和另一份安全存储中。
3. Windows 安装 Android SDK Platform-Tools，确认 `adb.exe`、`fastboot.exe` 正常。设备启用开发者选项/USB 调试；连接后在设备上接受 RSA 授权。
4. 下载 Magisk App 只从 [Magisk 官方仓库](https://github.com/topjohnwu/Magisk)进入 Releases。不要从网盘重打包下载 patched boot。
5. 若没有经过验证的当前固件镜像、分区表或恢复方案，先停在这里，不要刷写。

## 1. 确认 bootloader 状态

重启到 fastboot 后查询（不同固件可能对变量支持不同）：

```powershell
adb reboot bootloader
fastboot devices
fastboot getvar unlocked
fastboot getvar current-slot
```

- `unlocked: yes` 表示查询确认已解锁；若为 `no`、不支持、无设备或输出含糊，停止，不要试刷。
- `current-slot` 可能返回 `a` 或 `b`。把结果记录下来；如果查询不支持，需用设备上可验证的分区信息确认，不能猜 `boot_a`/`boot_b`。
- 解锁仅使用此型号/地区的可靠官方说明。不要用其他 BOOX 型号的 unlock 命令；解锁会清除数据。若无法确认官方支持解锁，不要继续。

## 2. 获取与固件严格匹配的原始镜像

有两种取镜像的方式，选能证明版本匹配且更可靠的一种。两种方式取到的镜像都要先备份，不能把其他目的的 IMG 当成输入。

### A. 从官方 OTA 包提取（优先）

1. 通过设备的官方更新渠道取得 Tab10CPro 当前构建的更新包。确认下载包的型号、区域、版本号与设备构建完全对应。
2. 若文件是 BOOX `.upx` 包，按 [decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx) 的项目说明准备依赖；在 PowerShell 中用设备型号 `Tab10CPro` 解密。命令格式如下，路径替换成你自己的真实文件路径：

```powershell
python DeBooxUpx.py Tab10CPro "C:\firmware\Tab10CPro.update.upx" "C:\firmware\Tab10CPro-update.zip"
```

不要把其他设备或不同构建的包传入。若项目版本的参数格式有变化，以项目 README 为准。
3. 从解密出的包中找到 `payload.bin`，用 [payload-dumper-go](https://github.com/ssut/payload-dumper-go) 解出分区镜像。命令格式如下：

```powershell
.\payload-dumper-go.exe "C:\firmware\payload.bin"
```

确认输出中存在 boot 分区，并保留完整输出与来源信息。
4. 对设备当前安装的完整构建号进行交叉核对。OTA 是增量包、版本不匹配、包结构无法确认时，不要把其中镜像当作当前原始 boot。

### B. 从本机做 EDL 分区只读备份

仅在确认 OTA 提取路径不可用、并能识别准确分区布局时使用。参考资料使用 Qualcomm SDM855 EDL programmer 和 QCTool 读取分区；loader 必须与设备硬件匹配且来自可信来源。

1. 先用 fastboot 记录当前槽位；然后只使用 QCTool 的 **Readback/读取** 功能备份 GPT 与全部分区（或至少 GPT、当前活动槽位 boot 及必要的 vbmeta 信息）。
2. 将回读结果另存两份，计算 SHA-256；记录文件名、分区名、分区起始/大小和对应构建号。
3. 对照 GPT 确认当前槽位的 boot 分区。不要对 GPT、modem、abl、xbl、vbmeta 或整盘执行写入/擦除。
4. EDL 读写、错误 loader 和全分区操作都可能使设备无法恢复。若 QCTool 显示的分区/文件大小不一致或界面按钮不明确，停止，不要试点写入。

> 这一步只用于获得本机原始分区备份；它不代表可以使用其他设备的 loader 或镜像。

## 3. 在 Magisk 中修补

1. 正常启动 Android，把确认过的原始 `boot.img`（或者由 Magisk 官方说明判定的其他正确镜像）复制到设备存储。
2. 安装并打开 Magisk App → 点 Magisk 卡片中的“安装”→“选择并修补一个文件”，选取原始镜像。
3. 等待 App 完成，在日志中确认输出文件名类似 `magisk_patched-*.img`。将**刚生成的文件**复制回电脑；不要改用旧文件或别人分享的 patched 镜像。
4. 对原始镜像和 patched 镜像分别计算 SHA-256，并保留哈希和 Magisk 日志。核实 patched 文件确实是本次修补生成、大小合理。
5. Magisk 安装方式或 UI 若与以上不一致，以当前版本的[官方安装文档](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md)为准。

## 4. 写入当前活动槽位的 boot

本仓库的 PowerShell 工具**不写分区**。写入前，必须同时确认：

- fastboot 明确报告 bootloader 已解锁；
- 当前槽位已明确为 `a` 或 `b`；
- patched 镜像来自本机当前固件原始镜像；
- 原始 boot 备份和官方恢复方法可用；
- GPT/设备资料确认目标分区确为 `boot_a` 或 `boot_b`，且镜像格式与分区匹配。

参考的 Tab10CPro 流程通过 QCTool 在 EDL 下选中单一 `boot_<当前槽位>` 分区并写入 patched boot。设备文档中的案例选择单个分区写入；工具界面/版本不同时不要照搬按钮位置。确认窗口中显示的**唯一目标分区名**与当前槽位一致后，再由设备所有者操作写入。绝不要选择“全部写入”“擦除”“格式化”或相邻分区。

此型号/当前构建不保证通用 `fastboot flash boot` 命令适用于所有槽位与固件。若你没有可靠证据确认 fastboot 目标映射、槽位行为和设备解锁状态，请不要自行把分区名替换后尝试刷写；应使用已验证的设备专用流程或停止操作。

## 5. 启动和确认 ROOT

1. 结束写入后，不要再写其他分区。按已验证的工具/设备流程退出 EDL 并启动系统。
2. 首次启动比平时久时先等待。若卡启动，停止重复写入，使用原始 boot 和备份恢复；不要随机尝试其他版本镜像。
3. 打开 Magisk App 查看安装状态。必要时在 Magisk 内完成它提示的环境修复并按提示重启。
4. 在设备端自己确认任何 Magisk 超级用户授权提示。Windows 上运行：

```powershell
adb shell su -c id
```

成功输出应含 `uid=0(root)`。本仓库辅助脚本也会进行此检查。

## 6. 安装 Magisk 模块

ROOT 验证成功后，才安装模块：从作者官方渠道取 ZIP，核对 Android/架构/Magisk/Zygisk 兼容性，并将下载 SHA-256 与作者公布值比较。通过 Magisk → 模块安装，或用本仓库脚本选 ZIP、核对显示的哈希并二次确认。安装日志成功后再按模块说明重启；一次只安装一个，便于回退。

LSPosed 需要 Zygisk。此设备记录中使用 Magisk 内置 Zygisk。ZygiskNext 是替代实现，遵循其文档关闭 Magisk 内置 Zygisk，勿同时启用两套实现。模块可能导致启动失败；使用 Magisk 官方救援方式禁用最近的模块或恢复官方固件。

## 出错时

- `unauthorized`：解锁屏幕，在设备上批准 USB 调试 RSA；不要重复 root/刷写。
- 无 fastboot/槽位变量：先确认数据线/驱动/模式与查询方法，不能推测活动槽位。
- Magisk 没有 root 或 `su` 被拒绝：在设备端查看 Magisk 的超级用户条目及用户授权提示；不要自动批准，也不要循环请求。
- 启动卡住：使用预先保存的原始 boot/官方恢复包回退；不要继续写其他分区。
- 模块造成异常：按 Magisk 官方救援说明禁用最近安装模块，再逐个排查。

## 来源

- [Magisk 官方安装说明](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md)
- [BOOX Tab10CPro 刷机/root 实机参考](https://doc.yoouu.cn/interest/flash/tab10cpro.html#root)（其中工具与分区操作仅适用于作者自己的设备环境）
- [decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx)
- [payload-dumper-go](https://github.com/ssut/payload-dumper-go)
- [Qualcomm SDM855 factory loaders](https://github.com/bkerler/Loaders/tree/main/qualcomm/factory/sdm855)

本指南是针对已记录设备的经验记录，不是厂商支持或通用刷机保证。请只在自有且获准操作的设备上使用；刷写风险由操作者承担。



