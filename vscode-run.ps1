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

# ===== 启动后验证 =====
Start-Sleep -Seconds 3

$errors = @()
$warnings = @()

# 1. 工作区路径
if (-not (Test-Path $projectDir)) {
    $errors += "工作区路径不存在: $projectDir"
}

# 2. Python 环境写入验证
if ($lastEnv -and $lastEnv.PythonPath) {
    $wsSettings = Join-Path $projectDir ".vscode\settings.json"
    if (Test-Path $wsSettings) {
        try {
            $ws = Get-Content $wsSettings -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($ws.python.defaultInterpreterPath -ne $lastEnv.PythonPath) {
                $errors += "工作区 Python 解释器不匹配: 写入=$($ws.python.defaultInterpreterPath), 期望=$($lastEnv.PythonPath)"
            }
        } catch { $errors += "工作区 settings.json 解析失败" }
    } else { $errors += "工作区 settings.json 未创建" }
    if (-not (Test-Path $lastEnv.PythonPath)) {
        $errors += "Python 解释器文件不存在: $($lastEnv.PythonPath)"
    }
}

# 3. 扩展启用验证
if ($lastEnv -and $lastEnv.Ext) {
    $recordedExt = Resolve-SelectedExt $lastEnv.Ext
    if ($recordedExt.Count -ne $selectedExt.Count) {
        $errors += "扩展数量不匹配: 记录=$($recordedExt.Count), 实际启用=$($selectedExt.Count)"
    }
    foreach ($e in $recordedExt) {
        if ($selectedExt -notcontains $e) { $errors += "扩展未启用: $e" }
    }
}

# 4. VSCode 进程存活
$vscodeProc = Get-Process -Name "Code" -ErrorAction SilentlyContinue
if (-not $vscodeProc) {
    $errors += "VSCode 进程未启动（可能启动失败）"
}

# 5. 终端环境提醒（无法自动验证，人工确认）
if ($lastEnv -and $lastEnv.PythonName) {
    $warnings += "请确认 VSCode 终端提示符显示环境名（如 (envname)），如未显示请检查 conda 初始化"
}
$warnings += "请确认左下角 Python 版本和右下角扩展状态与选择一致"

# 输出结果
Write-Host ""
if ($errors.Count -gt 0) {
    Write-Host "  ===== 启动异常 ($($errors.Count) 项) =====" -ForegroundColor Red
    for ($i = 0; $i -lt $errors.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $errors[$i]) -ForegroundColor Red
    }
    Write-Host "  ================================" -ForegroundColor Red
} else {
    Write-Host "  [OK] 工作区、Python环境、扩展配置、进程启动 全部正常" -ForegroundColor Green
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "  人工确认项:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $warnings.Count; $i++) {
        Write-Host ("  - {0}" -f $warnings[$i]) -ForegroundColor Yellow
    }
}

# 覆盖式写入运行日志（只保留最近一次）
$runLog = Join-Path $PSScriptRoot "last-run.log"
$logLines = @()
$logLines += "=== VSCode启动器 运行记录 ==="
$logLines += "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$logLines += "工作区: $projectDir"
if ($lastEnv -and $lastEnv.PythonName) { $logLines += "Python: $($lastEnv.PythonName)" }
if ($lastEnv -and $lastEnv.PythonPath) { $logLines += "Python路径: $($lastEnv.PythonPath)" }
$logLines += "启用扩展: $($selectedExt.Count) 个"
if ($selectedExt.Count -gt 0) {
    $selNames = ($extensions | Where-Object { $selectedExt -contains $_.Id } | ForEach-Object { $_.Name }) -join ", "
    $logLines += "扩展列表: $selNames"
}
$logLines += "---"
if ($errors.Count -gt 0) {
    $logLines += "异常 ($($errors.Count) 项):"
    for ($i = 0; $i -lt $errors.Count; $i++) { $logLines += "  $($i+1). $($errors[$i])" }
} else {
    $logLines += "检测结果: 全部正常"
}
if ($warnings.Count -gt 0) {
    $logLines += "人工确认项:"
    foreach ($w in $warnings) { $logLines += "  - $w" }
}
$logLines += "=============================="
try { Set-Content -Path $runLog -Value $logLines -Encoding UTF8 } catch { }

# 无论正常异常都停窗，按回车关闭
Write-Host ""
Write-Host "  运行日志: $runLog" -ForegroundColor DarkGray
Read-Host "  按回车关闭窗口（VSCode 仍在运行）"