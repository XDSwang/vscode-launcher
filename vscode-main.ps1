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
    try { Add-Content -Path $script:ErrorLogFile -Value $logEntry -Encoding UTF8 } catch { }
    Write-Host ""
    Write-Host "  [运行异常] 错误已记录到: $script:ErrorLogFile" -ForegroundColor Red
    Write-Host "  错误: $errMsg" -ForegroundColor Red
    Write-Host ""
    Read-Host "  按回车关闭窗口"
    break
}
$scriptDir = $PSScriptRoot

Write-Host ""
Write-Host "  VSCode 启动器" -ForegroundColor Cyan
Write-Host "  脚本位置: C:\Users\dxx\Documents\VSCode启动器" -ForegroundColor DarkGray
Write-Host "  （单独运行: vscode-select-ext.ps1 选扩展, vscode-select-env.ps1 选环境, vscode-select-workspace.ps1 选工作区, vscode-run.ps1 直接启动）" -ForegroundColor DarkGray

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