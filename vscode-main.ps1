# VSCode 启动器（主入口：依次调用 选扩展 → 选环境 → 选工作区 → 启动）

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FileArgs
)

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
$scriptDir = $PSScriptRoot

# 每次运行清空错误日志（覆盖式，只保留本次运行）
try { Set-Content -Path $script:ErrorLogFile -Value "" -Encoding UTF8 } catch { }

Write-Host ""
Write-Host "  VSCode 启动器" -ForegroundColor Cyan
Write-Host "  脚本位置: $scriptDir" -ForegroundColor DarkGray
Write-Host "  （单独运行: vscode-select-ext.ps1 选扩展, vscode-select-env.ps1 选环境, vscode-select-workspace.ps1 选工作区, vscode-run.ps1 直接启动）" -ForegroundColor DarkGray

# 扩展中文映射（用于一键复用显示）
$extNameMap = @{
    "ms-ceintl.vscode-language-pack-zh-hans" = "中文语言包"
    "ms-python.python"                      = "Python 核心"
    "ms-python.vscode-pylance"              = "Pylance"
    "ms-python.debugpy"                     = "Debugpy"
    "continue.continue"                     = "Continue AI"
    "doubao.doubao-app-share-vscode-plugin" = "豆包插件"
    "ritwickdey.liveserver"                 = "Live Server"
}
function Get-ExtDisplayName($id) {
    if ($extNameMap.ContainsKey($id)) { return $extNameMap[$id] }
    return $id
}

# ===== 一键复用上次记录 =====
$configDir  = "$env:USERPROFILE\.vscode-launcher"
$configFile = "$configDir\last.json"
$lastEnv = $null
if (Test-Path $configFile) { try { $lastEnv = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }

$hasExt = ($lastEnv -and $lastEnv.Ext -and $lastEnv.Ext.Count -gt 0)
$hasEnv = ($lastEnv -and $lastEnv.PythonPath)
$hasWs  = ($lastEnv -and $lastEnv.WorkspacePath -and (Test-Path $lastEnv.WorkspacePath))
$allReady = ($hasExt -and $hasEnv -and $hasWs)

if ($allReady) {
    Write-Host ""
    Write-Host "  检测到完整上次记录:" -ForegroundColor Green
    if ($lastEnv.Ext -and $lastEnv.Ext.Count -gt 0) {
        $extNames = ($lastEnv.Ext | ForEach-Object { Get-ExtDisplayName $_ }) -join "、"
        Write-Host "    扩展: $extNames ($($lastEnv.Ext.Count)个)"
    } elseif ($lastEnv.Name) { Write-Host "    扩展: $($lastEnv.Name)" }
    if ($lastEnv.PythonName) { Write-Host "    环境: $($lastEnv.PythonName)" }
    if ($lastEnv.WorkspacePath) { Write-Host "    工作区: $($lastEnv.WorkspacePath)" }
    Write-Host ""
    while ($true) {
        $yn = Read-Host "  一键使用上次记录直接启动? (y/n)"
        if ($yn -match '^[Yy]$') {
            Write-Host ""
            Write-Host "  第四步：启动 VSCode" -ForegroundColor Cyan
            Write-Host "  ==============" -ForegroundColor DarkGray
            & "$scriptDir\vscode-run.ps1" @FileArgs
            exit 0
        }
        if ($yn -match '^[Nn]$') { break }
        Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
    }
} else {
    $missing = @()
    if (-not $hasExt) { $missing += "扩展" }
    if (-not $hasEnv) { $missing += "Python环境" }
    if (-not $hasWs)  { $missing += "工作区" }
    Write-Host ""
    Write-Host "  记录缺失（$($missing -join '、')），不能一键启动，将逐步选择" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  第一步：选择扩展" -ForegroundColor Cyan
Write-Host "  ==============" -ForegroundColor DarkGray
& "$scriptDir\vscode-select-ext.ps1"

Write-Host ""
Write-Host "  第二步：选择 Python 环境" -ForegroundColor Cyan
Write-Host "  =====================" -ForegroundColor DarkGray
& "$scriptDir\vscode-select-env.ps1"

Write-Host ""
Write-Host "  第三步：选择工作区" -ForegroundColor Cyan
Write-Host "  ==============" -ForegroundColor DarkGray
& "$scriptDir\vscode-select-workspace.ps1"

Write-Host ""
Write-Host "  第四步：启动 VSCode" -ForegroundColor Cyan
Write-Host "  ==============" -ForegroundColor DarkGray
& "$scriptDir\vscode-run.ps1" @FileArgs

exit 0