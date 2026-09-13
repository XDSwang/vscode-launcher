# VSCode 扩展选择器（单独运行，只改扩展配置，不启动 VSCode）

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

# 配置
$configDir  = $(if (Test-Path "D:\") { "D:\VSCodeLauncher" } else { "$env:USERPROFILE\.vscode-launcher" })
$configFile = "$configDir\last.json"
function Save-VSCodePath($path) {
    $configDir = $(if (Test-Path "D:\") { "D:\VSCodeLauncher" } else { "$env:USERPROFILE\.vscode-launcher" })
    $configFile = "$configDir\config.json"
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $cfg = [PSCustomObject]@{}
    if (Test-Path $configFile) { try { $cfg = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    $cfg | Add-Member -NotePropertyName "VSCodePath" -NotePropertyValue $path -Force
    $cfg | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding UTF8
}
function Get-VSCodePath {
    $configDir = $(if (Test-Path "D:\") { "D:\VSCodeLauncher" } else { "$env:USERPROFILE\.vscode-launcher" })
    $configFile = "$configDir\config.json"
    $savedPath = $null
    if (Test-Path $configFile) {
        try {
            $cfg = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.VSCodePath -and (Test-Path $cfg.VSCodePath)) { $savedPath = $cfg.VSCodePath }
        } catch { }
    }
    if ($savedPath) {
        Write-Host ""
        Write-Host "  记录的 VSCode: $savedPath" -ForegroundColor Yellow
        while ($true) {
            $yn = Read-Host "  使用记录的路径? (y/n)"
            if ($yn -match '^[Yy]$') { return $savedPath }
            if ($yn -match '^[Nn]$') { break }
            Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
        }
    }
    while ($true) {
        Write-Host ""
        Write-Host "  1. 自动扫描常见位置"
        Write-Host "  2. 手动输入 Code.exe 路径"
        $choice = Read-Host "  选择"
        if ($choice -eq "1") {
            $candidates = @(
                "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
                "C:\Program Files\Microsoft VS Code\Code.exe",
                "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
            )
            foreach ($p in $candidates) { if (Test-Path $p) { Save-VSCodePath $p; Write-Host "  找到: $p" -ForegroundColor Green; return $p } }
            Write-Host "  常见位置未找到，请手动输入" -ForegroundColor Yellow
        } elseif ($choice -eq "2") {
            $p = Read-Host "  输入 Code.exe 完整路径"
            if ($p -and (Test-Path $p)) { Save-VSCodePath $p; return $p }
            Write-Host "  路径无效" -ForegroundColor Red
        } else { Write-Host "  输入无效，请输入 1 或 2" -ForegroundColor Red }
    }
}
$codePath   = Get-VSCodePath
$codeCmd    = Join-Path (Split-Path $codePath) "bin\code.cmd"
$extRoot    = "$env:USERPROFILE\.vscode\extensions"

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

# 扫描扩展
function Scan-Extensions {
    $ids = cmd /c "`"$codeCmd`" --list-extensions 2>nul"
    $result = @()
    foreach ($id in $ids) {
        $id = $id.Trim()
        if (-not $id) { continue }
        $name = $id; $desc = ""
        if ($descMap.ContainsKey($id)) {
            $name = $descMap[$id].Name; $desc = $descMap[$id].Desc
        } else {
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

# 覆盖式保存（只删自己的字段）
function Save-ConfigFields($fields) {
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $data = [PSCustomObject]@{}
    if (Test-Path $configFile) { try { $data = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    # 标记自己管理的字段名（含 Time）
    $myNames = @{}
    foreach ($prop in $fields.PSObject.Properties) { $myNames[$prop.Name] = $true }
    $myNames["Time"] = $true
    # 重建对象：只保留非自己字段，杜绝同级重复
    $newData = [PSCustomObject]@{}
    foreach ($prop in $data.PSObject.Properties) {
        if (-not $myNames.ContainsKey($prop.Name)) {
            $newData | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
        }
    }
    # 写入自己的新字段
    foreach ($prop in $fields.PSObject.Properties) {
        $newData | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
    }
    $newData | Add-Member -NotePropertyName "Time" -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $newData | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding UTF8
}

if ($extensions.Count -eq 0) {
    Write-Host "  未检测到已安装的扩展" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "  VSCode 扩展选择器" -ForegroundColor Cyan
Write-Host "  ==================" -ForegroundColor DarkGray

$selectedExt = @(); $selectedName = ""
if ($lastEnv) {
    $prevExt = Resolve-SelectedExt $lastEnv.Ext
    $prevNames = ($extensions | Where-Object { $prevExt -contains $_.Id } | ForEach-Object { $_.Name }) -join "、"
    Write-Host ""
    Write-Host ("  上次使用: {0}" -f $lastEnv.Name) -ForegroundColor Yellow
    if ($prevNames) { Write-Host "  已选: $prevNames" -ForegroundColor DarkGray }
    Write-Host ""
    while ($true) {
        $yn = Read-Host "  是否继续上次扩展? (y/n)"
        if ($yn -match '^[Yy]$') { $selectedExt = @($prevExt); $selectedName = $lastEnv.Name; break }
        if ($yn -match '^[Nn]$') { break }
        Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
    }
}

$modified = $false
while ($true) {
    $enabledSet = @{}
    foreach ($e in $selectedExt) { $enabledSet[$e] = $true }
    $unselected = @($extensions | Where-Object { -not $enabledSet.ContainsKey($_.Id) })
    if ($unselected.Count -eq 0) { Write-Host ""; Write-Host "  所有扩展已选择完毕" -ForegroundColor Green; break }
    Write-Host ""
    if ($selectedExt.Count -gt 0) {
        $selNames = ($extensions | Where-Object { $selectedExt -contains $_.Id } | ForEach-Object { $_.Name }) -join "、"
        Write-Host ("  当前已选 ({0}): {1}" -f $selectedExt.Count, $selNames) -ForegroundColor Green
    } else { Write-Host "  当前已选 (0): 无" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host ("  未选择的扩展 ({0}):" -f $unselected.Count) -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $unselected.Count; $i++) {
        $e = $unselected[$i]
        $descText = if ($e.Desc) { " - $($e.Desc)" } else { "" }
        Write-Host ("  {0,2}. {1,-16}{2}" -f ($i + 1), $e.Name, $descText)
    }
    Write-Host ""
    $userInput = Read-Host "  输入编号添加（逗号分隔），回车=不添加并完成"
    if ([string]::IsNullOrWhiteSpace($userInput)) { break }
    $nums = $userInput -split "[,，\s]+" | Where-Object { $_ -match "^\d+$" }
    if ($nums.Count -eq 0) { Write-Host "  输入无效，请输入数字编号" -ForegroundColor Red; continue }
    $toAdd = @()
    foreach ($n in $nums) {
        $ni = [int]$n - 1
        if ($ni -ge 0 -and $ni -lt $unselected.Count) { $toAdd += $unselected[$ni] }
    }
    if ($toAdd.Count -eq 0) { Write-Host "  编号超出范围" -ForegroundColor Red; continue }
    # 确认添加
    Write-Host ""
    Write-Host "  ===== 添加确认 =====" -ForegroundColor Yellow
    foreach ($t in $toAdd) {
        $origIdx = [array]::IndexOf($extensions.Id, $t.Id)
        Write-Host ("  编号: {0}  {1}" -f ($origIdx + 1), $t.Name)
    }
    Write-Host "  ====================" -ForegroundColor Yellow
    Write-Host ""
    $addConfirmed = $false
    while ($true) {
        $ac = Read-Host "  确认添加? (y=确认, n=取消)"
        if ($ac -match '^[Yy]$') { $addConfirmed = $true; break }
        if ($ac -match '^[Nn]$') { $addConfirmed = $false; break }
        Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
    }
    if (-not $addConfirmed) { continue }
    foreach ($t in $toAdd) { $selectedExt += $t.Id }
    $modified = $true
    Write-Host ""
    Write-Host ("  已添加: {0}" -f (($toAdd | ForEach-Object { $_.Name }) -join "、")) -ForegroundColor Green
    Write-Host ""
    $doContinue = $false
    while ($true) {
        $yn2 = Read-Host "  是否继续添加? (y=继续, n=完成)"
        if ($yn2 -match '^[Yy]$') { $doContinue = $true; break }
        if ($yn2 -match '^[Nn]$') { $doContinue = $false; break }
        Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
    }
    if (-not $doContinue) { break }
}

if (-not $selectedName -or $modified) { $selectedName = "自定义 ($($selectedExt.Count) 个扩展)" }

Save-ConfigFields ([PSCustomObject]@{ Name = $selectedName; Ext = @($selectedExt) })

Write-Host ""
Write-Host "  扩展选择已保存" -ForegroundColor Green
Write-Host ("  配置: {0}（启用 {1} 个扩展）" -f $selectedName, $selectedExt.Count)
Write-Host ""
