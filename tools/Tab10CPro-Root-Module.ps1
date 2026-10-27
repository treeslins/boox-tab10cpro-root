#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'BOOX Tab10CPro Root / Magisk Module Tool'

function Pause-Exit([int]$Code = 0) {
    Write-Host ''
    Read-Host '按 Enter 退出' | Out-Null
    exit $Code
}
function Invoke-Adb([string[]]$Args) {
    & $script:Adb @Args
    if ($LASTEXITCODE -ne 0) { throw "ADB 命令失败：adb $($Args -join ' ')" }
}
function Get-DeviceList {
    $raw = & $script:Adb devices
    if ($LASTEXITCODE -ne 0) { throw 'ADB 无法启动。' }
    @($raw | Select-Object -Skip 1 | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
}
function Select-Zip {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = '选择要安装的 Magisk 模块 ZIP'
    $dialog.Filter = 'ZIP 文件 (*.zip)|*.zip|所有文件 (*.*)|*.*'
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.FileName }
    return $null
}

try {
    $script:ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $candidates = @((Join-Path $script:ToolDir 'adb.exe'), (Join-Path $script:ToolDir '..\platform-tools\adb.exe'))
    $script:Adb = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $script:Adb) { $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue; if ($adbCommand) { $script:Adb = $adbCommand.Source } }
    if (-not $script:Adb) { throw '找不到 adb.exe。请将 Android platform-tools 中的 adb.exe 放在本工具目录，或配置到 PATH。' }

    Write-Host 'BOOX Tab10CPro 一键 ROOT / Magisk 模块工具' -ForegroundColor Cyan
    Write-Host '此工具不会自动选择或刷写 IMG/boot 镜像。'
    Write-Host ''

    $devices = Get-DeviceList
    if ($devices.Count -eq 0) {
        Write-Host '没有检测到已授权的 ADB 设备。请连接设备，在屏幕上允许 USB 调试，然后重试。' -ForegroundColor Yellow
        Pause-Exit 1
    }
    if ($devices.Count -gt 1) {
        Write-Host '检测到多台设备，请只保留一台设备连接后重试：' -ForegroundColor Yellow
        $devices | ForEach-Object { Write-Host "  $_" }
        Pause-Exit 1
    }
    $serial = $devices[0]
    Write-Host "设备：$serial"
    $model = (& $script:Adb -s $serial shell getprop ro.product.model 2>$null).Trim()
    $android = (& $script:Adb -s $serial shell getprop ro.build.version.release 2>$null).Trim()
    $build = (& $script:Adb -s $serial shell getprop ro.build.display.id 2>$null).Trim()
    Write-Host "型号：$model  Android：$android  Build：$build"
    if ($model -notmatch 'Tab10CPro') {
        Write-Host '提示：检测到的型号不是 Tab10CPro。本工具只对该机型的流程做了说明。' -ForegroundColor Yellow
    }

    $idResult = (& $script:Adb -s $serial shell su -c id 2>&1 | Out-String).Trim()
    $isRoot = $LASTEXITCODE -eq 0 -and $idResult -match 'uid=0\(root\)'
    if ($isRoot) {
        Write-Host "ROOT 已可用：$idResult" -ForegroundColor Green
    } else {
        Write-Host '当前 ADB shell 尚未获得 root。首次 ROOT 请按以下步骤完成：' -ForegroundColor Yellow
        Write-Host '  1. 在 Magisk App 中检查版本，并启用 Magisk 自带 Zygisk（若计划使用 Zygisk 模块）。'
        Write-Host '  2. 准备与设备当前固件完全匹配的原始 boot.img；不要使用其他固件或其他设备镜像。'
        Write-Host '  3. 在 Magisk App 选择“安装 > 选择并修补一个文件”，生成 patched boot 镜像。'
        Write-Host '  4. 先保留原始 boot.img 和恢复方案；只有确认本机 boot 分区布局、解锁状态和镜像匹配后才刷写。'
        Write-Host '  5. 重启后重新运行本工具；确认出现 uid=0(root) 后即可安装模块。'
        Write-Host ''
        Write-Host '为避免误刷导致无法启动，本工具不会自动刷 boot，也不会触碰目录里已有 IMG。' -ForegroundColor Red
        Pause-Exit 2
    }

    Write-Host ''
    $moduleDirs = (& $script:Adb -s $serial shell su -c 'ls -1 /data/adb/modules' 2>$null) | Where-Object { $_ }
    if ($moduleDirs) {
        Write-Host '当前模块目录：'
        $moduleDirs | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host ''
    $answer = Read-Host '现在选择一个 Magisk 模块 ZIP 安装吗？(Y/N)'
    if ($answer -notmatch '^(y|yes|是)$') { Pause-Exit 0 }

    $zip = Select-Zip
    if (-not $zip) { Write-Host '已取消选择，没有安装模块。'; Pause-Exit 0 }
    if ([IO.Path]::GetExtension($zip) -ne '.zip') { throw '所选文件不是 ZIP。' }
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    Write-Host "模块文件：$zip"
    Write-Host "SHA256：$hash"
    $confirm = Read-Host '确认将此 ZIP 交给 Magisk 安装？(Y/N)'
    if ($confirm -notmatch '^(y|yes|是)$') { Write-Host '已取消，没有安装。'; Pause-Exit 0 }

    $remote = '/sdcard/Download/' + [IO.Path]::GetFileName($zip)
    Invoke-Adb @('-s', $serial, 'push', $zip, $remote)
    Write-Host '正在请求 Magisk 安装模块……设备上若出现超级用户授权，请由你本人确认。' -ForegroundColor Cyan
    & $script:Adb -s $serial shell su -c "magisk --install-module '$remote'"
    if ($LASTEXITCODE -ne 0) { throw 'Magisk 模块安装命令失败。请查看设备端 Magisk 通知/日志。' }
    Write-Host ''
    Write-Host '安装命令已完成。请查看 Magisk 的模块页/通知；若提示重启，再手动重启设备。' -ForegroundColor Green
    Write-Host '工具不会自动重启设备。'
    Pause-Exit 0
} catch {
    Write-Host "`n发生错误：$($_.Exception.Message)" -ForegroundColor Red
    Pause-Exit 1
}




