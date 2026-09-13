# VSCode 终端环境名修复器（检测终端不显示 conda 环境名的原因，并选择修复）
# 单独运行：右键 -> 使用 PowerShell 运行

$ErrorActionPreference = "Stop"
# ===== 运行异常记录 =====
$script:ErrorLogFile = Join-Path $PSScriptRoot "error.log"
trap {
    $errTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errName = $MyInvocation.MyCommand.Name
    $errMsg  = $_.Exception.Message
    $errPos  = $_.InvocationInfo.PositionMessage
    $errStack = $_.ScriptStackTrace
    $logEntry = "[$errTime] 脚本: $errName`n错误: $errMsg`n位置: $errPos`n堆栈: $errStack`n---"
    try { Set-Content -Path $script:ErrorLogFile -Value $logEntry -Encoding UTF8 } catch { }
    Write-Host ""
    Write-Host "  [运行异常] 错误已记录到: $script:ErrorLogFile" -ForegroundColor Red
    Write-Host "  错误: $errMsg" -ForegroundColor Red
    Write-Host ""
    Read-Host "  按回车关闭窗口"
    break
}

Write-Host ""
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host "    VSCode 终端环境名修复器" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# ===== 路径变量（不写死具体安装位置，优先 D 盘、无 D 盘回退用户目录） =====
$baseDir = "vscode-launcher"
$configDir = $(if (Test-Path "D:\") { "D:\$baseDir\VSCodeLauncher" } else { "$env:USERPROFILE\$baseDir\VSCodeLauncher" })
$condaCandidates = @(
    "$env:USERPROFILE\anaconda3\Scripts\conda.exe",
    "$env:USERPROFILE\miniconda3\Scripts\conda.exe",
    "C:\ProgramData\anaconda3\Scripts\conda.exe",
    "C:\ProgramData\miniconda3\Scripts\conda.exe"
)
$legacyProfiles = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)
$vsSettings = "$env:APPDATA\Code\User\settings.json"

# ===== 1. 检测 conda =====
$condaExe = $null
$pmFile = "$configDir\package-managers.json"
if (Test-Path $pmFile) {
    try { $pms = @(Get-Content $pmFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $pms = @() }
    foreach ($pm in $pms) { if ($pm.Type -eq "conda" -and (Test-Path $pm.Path)) { $condaExe = $pm.Path; break } }
}
if (-not $condaExe) {
    foreach ($gp in $condaCandidates) {
        if (Test-Path $gp) { $condaExe = $gp; break }
    }
}
if ($condaExe) { Write-Host "  1. conda:           [OK] $condaExe" -ForegroundColor Green }
else { Write-Host "  1. conda:           [缺失] 未找到 conda.exe" -ForegroundColor Red }

# ===== 2. 检测 PowerShell 真实 profile（按系统 Documents 位置，可能被重定向到其他盘） =====
$realProfile = $PROFILE
if (Test-Path $realProfile) { Write-Host "  2. PS profile:      [OK] $realProfile" -ForegroundColor Green }
else {
    Write-Host "  2. PS profile:      [缺失] $realProfile" -ForegroundColor Red
    Write-Host "                        （Documents 可能被重定向到其他盘，实际加载的 profile 在此路径）" -ForegroundColor DarkGray
}
$legacyFound = $false
foreach ($lp in $legacyProfiles) {
    if ($lp -ne $realProfile -and (Test-Path $lp)) {
        if (-not $legacyFound) { $legacyFound = $true; Write-Host "  注意: 旧位置 profile 存在但不被加载:" -ForegroundColor Yellow }
        Write-Host "        $lp" -ForegroundColor Yellow
    }
}
if ($legacyFound) { Write-Host "        真实 profile 在: $realProfile" -ForegroundColor Yellow }

# ===== 3. 检测 conda 初始化方式（读取真实 profile） =====
$hasStdInit = $false; $hasOldInit = $false
if (Test-Path $realProfile) {
    try { $pfContent = Get-Content $realProfile -Raw -Encoding UTF8 } catch { $pfContent = "" }
    if ($pfContent -match 'shell\.powershell.*Invoke-Expression|conda initialize') { $hasStdInit = $true }
    if ($pfContent -match 'conda-hook\.ps1') { $hasOldInit = $true }
}
if ($hasStdInit) { Write-Host "  3. conda 初始化:   [OK] 标准初始化（conda init 方式）" -ForegroundColor Green }
elseif ($hasOldInit) { Write-Host "  3. conda 初始化:   [过时] 旧式 conda-hook 写法，可能不兼容当前 conda 版本" -ForegroundColor Yellow }
else { Write-Host "  3. conda 初始化:   [缺失] 未配置（终端激活环境后不显示名称的主要原因）" -ForegroundColor Red }

# ===== 4. 检测 VSCode 终端设置 =====
$vsProfile = ""; $vsAct = $null
if (Test-Path $vsSettings) {
    try { $s = Get-Content $vsSettings -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $s = $null }
    $vsProfile = $s.'terminal.integrated.defaultProfile.windows'
    $vsAct = $s.'python.terminal.activateEnvironment'
    Write-Host ("  4. VSCode 终端:     profile=[{0}]  activateEnvironment=[{1}]" -f $vsProfile, $vsAct)
    if ($vsProfile -eq "PowerShell") { Write-Host "  5. 终端默认 PS:     [OK] PowerShell" -ForegroundColor Green }
    else { Write-Host ("  5. 终端默认 PS:     [缺失] 当前=[{0}]" -f $vsProfile) -ForegroundColor Red }
} else {
    Write-Host "  4. VSCode 终端设置: [缺失] $vsSettings" -ForegroundColor Red
    Write-Host "  5. 终端默认 PS:     [缺失] 未设置" -ForegroundColor Red
}

# ===== 5. 汇总问题 =====
$issues = @()
if (-not $condaExe) { $issues += "未找到 conda.exe（先在启动器选择/添加包管理器，或安装到常见路径）" }
if (-not (Test-Path $realProfile)) { $issues += "PowerShell profile 不存在: $realProfile" }
if (-not $hasStdInit -and $hasOldInit) { $issues += "conda 初始化是旧式 conda-hook 写法，需更新为 conda init 标准方式" }
if (-not $hasStdInit -and -not $hasOldInit) { $issues += "profile 未配置 conda 初始化（终端激活环境后不显示名称的主要原因）" }
if (-not (Test-Path $vsSettings) -or $vsProfile -ne "PowerShell") { $issues += "VSCode 终端默认不是 PowerShell" }
if ($vsAct -ne $true) { $issues += "python.terminal.activateEnvironment 未开启" }

Write-Host ""
if ($issues.Count -eq 0) {
    Write-Host "  检测结果: 未发现问题" -ForegroundColor Green
    Write-Host "  若终端仍不显示环境名，请重启 VSCode 或重新打开终端后验证" -ForegroundColor DarkGray
    Read-Host "  按回车退出"
    exit 0
}
Write-Host ("  检测到 {0} 个问题:" -f $issues.Count) -ForegroundColor Yellow
for ($i = 0; $i -lt $issues.Count; $i++) { Write-Host ("    {0}. {1}" -f ($i + 1), $issues[$i]) }

# ===== 6. 选择修复方式 =====
Write-Host ""
Write-Host "  修复方式:" -ForegroundColor Cyan
Write-Host "    1. 自动修复（创建/更新真实 profile 为标准 conda 初始化 + 配置 VSCode 终端）"
Write-Host "    2. 仅修复 profile（只更新 conda 初始化方式）"
Write-Host "    3. 跳过（手动修复）"
Write-Host ""
while ($true) {
    $fixChoice = Read-Host "  选择编号"
    if ($fixChoice -eq "1" -or $fixChoice -eq "2" -or $fixChoice -eq "3") { break }
    Write-Host "  输入无效，请输入 1、2 或 3" -ForegroundColor Red
}
if ($fixChoice -eq "3") { Write-Host "  已跳过修复" -ForegroundColor DarkGray; Read-Host "  按回车退出"; exit 0 }

# ===== 7. 执行修复 =====
$fixed = @()
if ($fixChoice -eq "1" -or $fixChoice -eq "2") {
    # 7a. 创建/更新真实 profile 为标准 conda 初始化
    if ($condaExe) {
        $targetProfile = $PROFILE
        $tDir = Split-Path $targetProfile
        if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
        $lines = @()
        if (Test-Path $targetProfile) { $lines = @(Get-Content $targetProfile -Encoding UTF8) }
        $newLines = @()
        foreach ($ln in $lines) {
            if ($ln -match 'conda-hook\.ps1|# conda初始化|conda initialize|shell\.powershell|# region conda|# endregion|# !! Contents') { continue }
            $newLines += $ln
        }
        $stdBlock = @(
            "# region conda initialize"
            "# !! Contents within this block are managed by 'conda init' !!"
            "(& `"$condaExe`" `"shell.powershell`" `"hook`") | Out-String | Invoke-Expression"
            "# endregion"
        )
        $newLines += ""
        $newLines += $stdBlock
        Set-Content -Path $targetProfile -Value $newLines -Encoding UTF8
        $fixed += "已创建/更新 profile: $targetProfile"
        $fixed += "已写入标准 conda 初始化（conda init 方式）"
    } else { $fixed += "未找到 conda.exe，无法配置初始化" }
}
if ($fixChoice -eq "1") {
    # 7b. 配置 VSCode 终端设置
    $settingsDir = Split-Path $vsSettings
    if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }
    $settings = [PSCustomObject]@{}
    if (Test-Path $vsSettings) { try { $settings = Get-Content $vsSettings -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    $settings | Add-Member -NotePropertyName "terminal.integrated.defaultProfile.windows" -NotePropertyValue "PowerShell" -Force
    $settings | Add-Member -NotePropertyName "python.terminal.activateEnvironment" -NotePropertyValue $true -Force
    $settings | Add-Member -NotePropertyName "python.terminal.activateEnvInCurrentTerminal" -NotePropertyValue $true -Force
    $settings | ConvertTo-Json -Depth 5 | Set-Content $vsSettings -Encoding UTF8
    $fixed += "已配置 VSCode 终端: 默认 PowerShell + 自动激活运行环境"
}

# ===== 8. 完成提示 =====
Write-Host ""
Write-Host "  ===== 修复完成 =====" -ForegroundColor Green
foreach ($msg in $fixed) { Write-Host ("    [OK] " + $msg) -ForegroundColor Green }
Write-Host "  ====================" -ForegroundColor Green
Write-Host ""
Write-Host "  重要：请重启 VSCode（或重开终端）后验证" -ForegroundColor Yellow
Write-Host "  验证方法: 启动器启动项目后，终端提示符应显示 (环境名) 前缀，如 (vscode_cs01) PS ..." -ForegroundColor DarkGray
Write-Host "  再次运行本脚本可重新检测" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  按回车关闭窗口"