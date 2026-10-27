# BOOX Tab10CPro：Magisk ROOT 与模块安装

本文记录本仓库对应的实机流程：BOOX Tab10CPro、Android 13（SDK 33）、BOOX 固件 4.2.1、Magisk 30.7。固件构建号变更、OTA 更新、同名设备的区域版本差异，都可能令镜像或分区信息不再适用。每次操作前请按设备“关于本机”核对完整型号和构建号。

> **风险提示**：解锁 bootloader 可能清空数据；写错槽位或写入不匹配镜像可能导致无法启动。开始前备份数据、原始分区和官方恢复包。本文不提供固件、boot 镜像或 firehose programmer；原始 boot 应从本机全分区回读中取得，或来自与本机当前构建严格匹配的官方固件。请勿使用注明用于其他用途的 IMG。

## 总体流程

```text
确认型号/构建、恢复路径和当前槽位
  → 用 Qualcomm 工具箱进入 EDL 并读取全分区
  → 生成并保存 GPT/XML 与完整分区备份
  → 从当前活动槽位的 boot 备份取镜像
  → 在 Magisk App 中修补该镜像
  → 用工具只写回对应的 boot_<槽位>
  → 启动并验证 uid=0(root)
```

Magisk 官方要求 bootloader 解锁后才继续首次安装；首次安装要修补含 ramdisk 的正确镜像，可能是 `boot.img`、`init_boot.img` 或 `vendor_boot.img`，具体由设备结构决定。不要仅凭“Android 13”就猜分区。官方说明：[Magisk Installation](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md)。

## 0. 准备与恢复

1. 备份设备上的书籍、下载内容和其他重要数据。解锁流程可能会 factory reset。
2. 确认官方恢复流程可用；按第 2 节用 Qualcomm 工具箱回读全分区，生成并异地保存 GPT、XML 与分区备份。
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

## 2. 用高通工具箱回读全分区并生成 GPT/XML（主流程）

本设备记录的关键准备步骤是：使用 Qualcomm 工具箱通过 EDL **回读全分区**，并让工具生成 GPT 和 XML。此过程先做完整备份、确认分区映射，再从回读结果中取得当前活动槽位的 boot 镜像给 Magisk 修补。不要跳过 GPT/XML，也不要把“读取”误做成“写入”。

### 2.1 先确认槽位并进入 EDL

1. 在 Android 仍可启动时连接 ADB，重启到 fastboot 并记录解锁状态和当前槽位：

```powershell
adb reboot bootloader
fastboot devices
fastboot getvar unlocked
fastboot getvar current-slot
```

2. 只有 `unlocked: yes` 且槽位明确为 `a` 或 `b` 才继续。记录结果。若命令不支持、没有设备或结果不确定，先查明正确方法，不要猜槽位。
3. 回到 Android 后，按已验证的 Tab10CPro 流程进入 EDL。参考资料中使用 `adb reboot edl`；如果当前固件不支持或设备状态与参考不符，不要尝试短接/强制进入等未经验证的方式。

### 2.2 在 Qualcomm 工具箱回读全分区

1. 使用与设备硬件匹配、来源可信的 Qualcomm SDM855 firehose programmer/loader。工具中的 loader 必须确认是适用于该设备的版本；不要拿别的型号 loader 试错。
2. 在 Qualcomm 工具箱选择正确的 loader 并执行“发送引导/Send programmer”，确认日志显示连接成功。
3. 选择 **回读全部分区/Readback all partitions**，并启用生成 GPT 与 XML 的选项。输出到单独目录。工具版本的按钮名称可能不同，操作前确认所选功能是只读回读。
4. 等待所有分区回读完成。检查 GPT/XML 已生成，分区列表与读回文件齐全，日志没有失败；不要只凭进度条结束就认为备份完整。
5. 将完整输出目录复制到另一块存储，并为关键文件计算 SHA-256。保留原始 GPT、XML、全分区镜像和日志；这些是恢复与确认分区映射的重要依据。
6. 根据生成的 GPT/XML 和分区清单定位 `boot_a`、`boot_b`。对照刚才记录的 `current-slot`，只取当前活动槽位对应的原始 boot 镜像。不要因为有两个 boot 文件就任选其一。

> **只读阶段的边界**：此处只做回读和备份。不要在 Qualcomm 工具箱中选择全分区写入、擦除、格式化，也不要改写 GPT、modem、abl、xbl、vbmeta 或其他分区。

### 2.3 OTA 提取作为备用取镜像路径

只有 Qualcomm 工具箱回读不可行、且能严格确认 OTA 与当前构建匹配时，才考虑从官方 OTA 提取原始 boot。此路径不能替代全分区备份和 GPT/XML。

1. 从设备官方更新渠道取得 Tab10CPro 当前构建的更新包，核对型号、地区和完整版本号。
2. 若为 BOOX `.upx` 包，按 [decryptBooxUpdateUpx](https://github.com/Hagb/decryptBooxUpdateUpx) 项目说明，使用 `Tab10CPro` 型号参数解密。命令示例中的路径需替换成实际文件：

```powershell
python DeBooxUpx.py Tab10CPro "C:\firmware\Tab10CPro.update.upx" "C:\firmware\Tab10CPro-update.zip"
```

3. 从解密包中提取 `payload.bin`，使用 [payload-dumper-go](https://github.com/ssut/payload-dumper-go) 解包：

```powershell
.\payload-dumper-go.exe "C:\firmware\payload.bin"
```

4. 确认输出中包含可用的 boot 镜像，并证明它对应设备当前完整构建。增量包不含 boot、版本不符或来源不能确认时，不要使用此镜像。即使采用此备用方式，也要通过设备专用方法确认当前槽位和目标分区。
## 3. 在 Magisk 中修补

1. 正常启动 Android，把从全分区回读中取出的**当前活动槽位原始 boot 镜像**复制到设备存储；确认文件对应 GPT/XML 里的 `boot_a` 或 `boot_b`。
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

## 7. ROOT 后 Magisk 卡在启动页的原因与修复

### 故障原因

在这台 Tab10CPro 上，现象是 Magisk App 卡在启动页，但系统仍能正常启动，且 root 后台可能仍可用。这不是 Magisk 管理器一定“没装好”：BOOX 在 framework 的 `services.jar` 中修改了 `ActivityManagerService.addPackageDependency()`，增加了更新 WebView 使用包记录的逻辑。Magisk 的 root 守护进程（`RootServerMain`，uid 0）不是普通应用进程，不一定有对应的 `ProcessRecord`；BOOX 代码未判空就读取其 `info.packageName`，因此可能触发空指针异常，导致管理器启动卡死/崩溃，而 `su` 本身仍能工作。

这个具体的空指针路径及一字节分支修复已由 [dynamicfire 的 P6 Pro 项目](https://github.com/dynamicfire/boox-p6pro-root)针对 BOOX 4.1 系列记录。我们在 Tab10CPro 4.2.1 上制作并验证了专用的 systemless 修复模块，说明这一类 AMS 空指针问题与本机现象吻合；不同设备/固件的 `services.jar` 不能互换，不能刷入 P6 Pro 的 4.1 模块代替本模块。

### Tab10CPro 4.2.1 修复模块

本机对应的模块 ZIP 名称为 `boox-ams-fix-tab10cpro-4.2.1.zip`，模块 ID 为 `boox-ams-fix-tab10cpro-421`。模块以 Magisk systemless overlay 替换 framework 的 `services.jar`，清理相关 Dalvik 缓存后重启生效。ZIP SHA-256：

```text
2EE43415F45772FE823CDB8E17694CE118A6304596FC0C2D622DEB0206012038
```

仅用于 BOOX Tab10CPro、Android 13、固件 4.2.1 且 `services.jar` 与本机匹配的环境。OTA 或系统更新后请先卸载此模块并重新验证；不要在其他机型/构建使用。若 Magisk App 打不开但 `su` 可用，应先按本机恢复流程安装/启用该匹配模块并重启；若无法确认 build 或 ZIP 哈希不一致，停止使用并恢复原系统文件。

上游修复仓库也明确警告其 services.jar 仅针对指定 P6 Pro 固件，版本不符可能导致无法启动：[boox-ams-fix 兼容说明](https://github.com/dynamicfire/boox-ams-fix)。

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





