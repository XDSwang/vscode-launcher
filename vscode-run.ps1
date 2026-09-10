# VSCode 直接启动器（读取记录直接启动，不交互，启动后自动关闭）

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

# 配置
$configDir  = "$env:USERPROFILE\.vscode-launcher"
$configFile = "$configDir\last.json"
function Find-VSCodePath {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "C:\Program Files\Microsoft VS Code\Code.exe",
        "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    return $null
}$codePath   = Find-VSCodePath
$codeCmd    = if ($codePath) { Join-Path (Split-Path $codePath) "bin\code.cmd" } else { $null }
$extRoot    = "$env:USERPROFILE\.vscode\extensions"
if (-not $codePath) { Write-Host "  未找到 VSCode，请确认已安装" -ForegroundColor Red; exit 1 }

# 扩展中文说明
$descMap = @{
    "ms-ceintl.vscode-language-pack-zh-hans" = @{ Name = "中文语言包";  Desc = "界面汉化" }
    "ms-python.python"                      = @{ Name = "Python 核心"; Desc = "语法/运行/环境管理" }
    "ms-python.vscode-pylance"              = @{ Name = "Pylance";     Desc = "智能补全/类型检查/跳转" }
    "ms-python.debugpy"                     = @{ Name = "Debugpy";     Desc = "断点调试" }
    "continue.continue"                     = @{ Name = "Continue AI"; Desc = "AI 编程助手/补全/重构" }
    "doubao.doubao-app-share-vscode-plugin" = @{ Name = "豆包插件";    Desc = "豆包分享/协作" }
    "ritwickdey.liveserver"                 = @{ Name = "Live Server"; Desc = "网页热刷新预览" }
}

function Scan-Extensions {
    $ids = cmd /c "`"$codeCmd`" --list-extensions 2>nul"
    $result = @()
    foreach ($id in $ids) {
        $id = $id.Trim()
        if (-not $id) { continue }
        $name = $id; $desc = ""
        if ($descMap.ContainsKey($id)) { $name = $descMap[$id].Name; $desc = $descMap[$id].Desc }
        else {
            $found = Get-ChildItem $extRoot -Filter "$id-*" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($found) {
                try {
                    $pkg = Get-Content (Join-Path $found.FullName "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($pkg.displayName) { $name = $pkg.displayName }
                    if ($pkg.description) { $desc = $pkg.description }
                } catch { }
            }
        }
        $result += [PSCustomObject]@{ Id = $id; Name = $name; Desc = $desc }
    }
    return $result
}
$extensions = Scan-Extensions

# 读取记录
$lastEnv = $null
if (Test-Path $configFile) { try { $lastEnv = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }

function Resolve-SelectedExt($extIdList) {
    if ($extIdList -contains "*") { Write-Output @($extensions.Id) -NoEnumerate; return }
    $set = @{}
    foreach ($e in $extIdList) { $set[$e] = $true }
    Write-Output @($extensions | Where-Object { $set.ContainsKey($_.Id) } | ForEach-Object { $_.Id }) -NoEnumerate
}

# 确定工作区目录
$projectDir = ""
if ($lastEnv -and $lastEnv.WorkspacePath -and (Test-Path $lastEnv.WorkspacePath)) {
    $projectDir = $lastEnv.WorkspacePath
} elseif ($FileArgs) {
    foreach ($a in $FileArgs) {
        if (Test-Path $a -PathType Container) { $projectDir = (Resolve-Path $a).Path; break }
        if (Test-Path $a -PathType Leaf) { $projectDir = (Resolve-Path (Split-Path $a)).Path; break }
    }
}
if (-not $projectDir) { $projectDir = (Get-Location).Path }

# 写入 Python 解释器到工作区设置
if ($lastEnv -and $lastEnv.PythonPath -and (Test-Path $lastEnv.PythonPath)) {
    $vscodeDir = Join-Path $projectDir ".vscode"
    if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null }
    $settingsFile = Join-Path $vscodeDir "settings.json"
    $settings = [PSCustomObject]@{}
    if (Test-Path $settingsFile) { try { $settings = Get-Content $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    $settings | Add-Member -NotePropertyName "python.defaultInterpreterPath" -NotePropertyValue $lastEnv.PythonPath -Force
    $settings | Add-Member -NotePropertyName "python.terminal.activateEnvironment" -NotePropertyValue $true -Force
    $settings | Add-Member -NotePropertyName "python.terminal.activateEnvInCurrentTerminal" -NotePropertyValue $true -Force
    $settings | ConvertTo-Json -Depth 5 | Set-Content $settingsFile -Encoding UTF8
}

# 计算禁用扩展
$selectedExt = @()
if ($lastEnv) { $selectedExt = Resolve-SelectedExt $lastEnv.Ext }
$enabledSet = @{}
foreach ($e in $selectedExt) { $enabledSet[$e] = $true }
$disabledExt = $extensions | Where-Object { -not $enabledSet.ContainsKey($_.Id) }

# 构建启动参数
$argList = @()
foreach ($d in $disabledExt) { $argList += "--disable-extension"; $argList += $d.Id }
$argList += $projectDir
if ($FileArgs) { $argList += $FileArgs }

Write-Host "  工作区: $projectDir" -ForegroundColor Green
if ($lastEnv -and $lastEnv.PythonName) { Write-Host "  Python: $($lastEnv.PythonName)" -ForegroundColor Green }
Write-Host "  启用: $($selectedExt.Count) 个 / 禁用: $($disabledExt.Count) 个"

# 启动（cmd /c start 彻底分离进程）
$argStr = ($argList | ForEach-Object { "`"$_`"" }) -join " "
$fullCmd = 'start "" "' + $codePath + '" ' + $argStr
& cmd /c $fullCmd

Start-Sleep -Milliseconds 500