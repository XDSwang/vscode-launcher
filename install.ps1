# VSCode 启动器 - 一键安装脚本
# 在新电脑上右键 -> 使用 PowerShell 运行即可

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host "    VSCode 启动器 - 一键安装" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = $PSScriptRoot
$configDir = $(if (Test-Path "D:\") { "D:\vscode-launcher\VSCodeLauncher" } else { "$env:USERPROFILE\vscode-launcher\VSCodeLauncher" })
$installDir = $(if (Test-Path "D:\") { "D:\vscode-launcher\VSCode启动器" } else { "$env:USERPROFILE\vscode-launcher\VSCode启动器" })

# 1. 检测 VSCode
function Find-VSCodePath {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "C:\Program Files\Microsoft VS Code\Code.exe",
        "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    return $null
}
function Get-SavedVSCodePath {
    $cf = "$configDir\config.json"
    if (Test-Path $cf) {
        try { $s = Get-Content $cf -Raw -Encoding UTF8 | ConvertFrom-Json; if ($s.VSCodePath) { return $s.VSCodePath } } catch { }
    }
    return $null
}
$savedCode = Get-SavedVSCodePath
$codePath = Find-VSCodePath
if ($savedCode) {
    if (Test-Path $savedCode) {
        Write-Host ""
        Write-Host "  [提示] 已配置 VSCode: $savedCode" -ForegroundColor Yellow
        while ($true) {
            $yn = Read-Host "  使用已配置路径? (y=使用, n=重新输入)"
            if ($yn -match '^[Yy]$') { $codePath = $savedCode; break }
            if ($yn -match '^[Nn]$') { $codePath = $null; break }
            Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
        }
    } else {
        Write-Host ""
        Write-Host "  [提示] 已配置 VSCode: $savedCode（路径不存在，请重新输入）" -ForegroundColor Yellow
        $codePath = $null
    }
}

if (-not $codePath) {
    Write-Host ""
    Write-Host "  [提示] 未在常见安装路径找到 VSCode" -ForegroundColor Yellow
    Write-Host "  请手动输入 Code.exe 的完整路径（含文件名）" -ForegroundColor Yellow
    Write-Host "  示例: E:\...\Code.exe" -ForegroundColor DarkGray
    Write-Host "  查看方法: 命令行执行 where code" -ForegroundColor DarkGray
    $manualCode = Read-Host "  Code.exe 完整路径（直接回车=取消安装）"
    if ($manualCode -and (Test-Path $manualCode)) { $codePath = $manualCode }
}
if (-not $codePath) {
    Write-Host "  [错误] 未提供有效的 VSCode 路径，无法继续安装" -ForegroundColor Red
    Read-Host "  按回车退出"
    exit 1
}
Write-Host "  [OK] VSCode: $codePath" -ForegroundColor Green

# 3. 复制脚本到文档目录
Write-Host ""
Write-Host "  正在安装到: $installDir" -ForegroundColor Cyan
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
$scripts = @("vscode-main.ps1","vscode-select-ext.ps1","vscode-select-env.ps1","vscode-select-workspace.ps1","vscode-run.ps1")
foreach ($s in $scripts) {
    $src = Join-Path $scriptDir $s
    if (Test-Path $src) {
        Copy-Item $src $installDir -Force
        Write-Host "    [OK] $s" -ForegroundColor Green
    }
}

# 4. 创建配置目录
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

# 5. 创建桌面快捷方式
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Visual Studio Code.lnk"
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$installDir\vscode-main.ps1`""
$shortcut.WorkingDirectory = $installDir
$shortcut.IconLocation = "$codePath,0"
$shortcut.Description = "VSCode 启动器（选扩展/环境/工作区）"
$shortcut.Save()
Write-Host "  [OK] 桌面快捷方式已创建" -ForegroundColor Green

# 6. 配置 VSCode 全局设置（PyCharm 风格）
$settingsDir = "$env:APPDATA\Code\User"
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }
$settingsFile = "$settingsDir\settings.json"
$settings = [PSCustomObject]@{}
if (Test-Path $settingsFile) { try { $settings = Get-Content $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
$settings | Add-Member -NotePropertyName "window.restoreWindows" -NotePropertyValue "all" -Force
$settings | Add-Member -NotePropertyName "startupEditor" -NotePropertyValue "none" -Force
$settings | Add-Member -NotePropertyName "window.newWindowDimensions" -NotePropertyValue "maximized" -Force
$settings | Add-Member -NotePropertyName "terminal.integrated.defaultProfile.windows" -NotePropertyValue "PowerShell" -Force
$settings | Add-Member -NotePropertyName "python.terminal.activateEnvironment" -NotePropertyValue $true -Force
$settings | Add-Member -NotePropertyName "python.terminal.activateEnvInCurrentTerminal" -NotePropertyValue $true -Force
$settings | ConvertTo-Json -Depth 5 | Set-Content $settingsFile -Encoding UTF8
Write-Host "  [OK] VSCode 全局设置已配置" -ForegroundColor Green

Write-Host ""
Write-Host "  ================================" -ForegroundColor Green
Write-Host "    安装完成！" -ForegroundColor Green
Write-Host "  ================================" -ForegroundColor Green
Write-Host ""
Write-Host "  使用方法："
Write-Host "    1. 双击桌面 'Visual Studio Code' 快捷方式"
Write-Host "    2. 依次选择扩展、Python环境、工作区"
Write-Host "    3. 自动启动 VSCode，脚本窗口自动关闭"
Write-Host ""
Write-Host "  脚本位置: $installDir"
Write-Host "  配置文件: $configDir"
Write-Host ""
Read-Host "  按回车退出"
