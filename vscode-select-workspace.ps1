# VSCode 工作区选择器（单独运行，只改工作区路径，不启动 VSCode）

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
$configDir  = "$env:USERPROFILE\.vscode-launcher"
$configFile = "$configDir\last.json"

# 常用项目根目录（扫描其子文件夹作为候选）
$projectRoots = @(
    "$env:USERPROFILE\Desktop"
)

# 读取记录
$lastEnv = $null
if (Test-Path $configFile) { try { $lastEnv = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }

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

Write-Host ""
Write-Host "  VSCode 工作区选择器" -ForegroundColor Cyan
Write-Host "  ====================" -ForegroundColor DarkGray

$selectedPath = ""

# 有上次记录时问是否继续
if ($lastEnv -and $lastEnv.WorkspacePath -and (Test-Path $lastEnv.WorkspacePath)) {
    Write-Host ""
    Write-Host ("  上次工作区: {0}" -f $lastEnv.WorkspacePath) -ForegroundColor Yellow
    Write-Host ""
    while ($true) {
        $yn = Read-Host "  是否继续上次工作区? (y/n)"
        if ($yn -match '^[Yy]$') { $selectedPath = $lastEnv.WorkspacePath; break }
        if ($yn -match '^[Nn]$') { break }
        Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
    }
}

# 没选 → 显示候选列表
while (-not $selectedPath) {
    $candidates = @()
    foreach ($root in $projectRoots) {
        if (Test-Path $root) {
            $subs = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^\.' }
            foreach ($s in $subs) { $candidates += $s.FullName }
        }
    }
    $candidates = $candidates | Select-Object -Unique

    Write-Host ""
    Write-Host "  可用工作区:" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host ("  {0,2}. {1}" -f ($i + 1), $candidates[$i])
    }
    $customIdx = $candidates.Count + 1
    Write-Host ("  {0,2}. 手动输入路径" -f $customIdx) -ForegroundColor Green
    Write-Host ""
    $input = Read-Host "  选择编号"

    $idx = -1
    if (-not [int]::TryParse($input, [ref]$idx)) { Write-Host "  输入无效，请输入数字编号" -ForegroundColor Red; continue }
    $idx = $idx - 1
    if ($idx -ge 0 -and $idx -lt $candidates.Count) {
        $candidatePath = $candidates[$idx]
        Write-Host ""
        Write-Host "  ===== 选择确认 =====" -ForegroundColor Yellow
        Write-Host ("  编号: {0}" -f ($idx + 1))
        Write-Host ("  路径: {0}" -f $candidatePath)
        Write-Host "  ====================" -ForegroundColor Yellow
        Write-Host ""
        $wsConfirmed = $false
        while ($true) {
            $cf = Read-Host "  确认选择? (y=确认, n=返回重新选择)"
            if ($cf -match '^[Yy]$') { $wsConfirmed = $true; break }
            if ($cf -match '^[Nn]$') { $wsConfirmed = $false; break }
            Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
        }
        if (-not $wsConfirmed) { continue }
        $selectedPath = $candidatePath
    } elseif ($idx -eq $candidates.Count) {
        $p = Read-Host "  输入完整路径"
        if ($p -and (Test-Path $p)) {
            $candidatePath = (Resolve-Path $p).Path
            Write-Host ""
            Write-Host "  ===== 选择确认 =====" -ForegroundColor Yellow
            Write-Host ("  路径: {0}" -f $candidatePath)
            Write-Host "  ====================" -ForegroundColor Yellow
            Write-Host ""
            $wsConfirmed = $false
            while ($true) {
                $cf = Read-Host "  确认选择? (y=确认, n=返回重新选择)"
                if ($cf -match '^[Yy]$') { $wsConfirmed = $true; break }
                if ($cf -match '^[Nn]$') { $wsConfirmed = $false; break }
                Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
            }
            if (-not $wsConfirmed) { continue }
            $selectedPath = $candidatePath
        } else { Write-Host "  路径无效" -ForegroundColor Red }
    } else { Write-Host "  编号超出范围" -ForegroundColor Red }
}

Save-ConfigFields ([PSCustomObject]@{ WorkspacePath = $selectedPath })

Write-Host ""
Write-Host "  工作区已保存" -ForegroundColor Green
Write-Host ("  路径: {0}" -f $selectedPath)
Write-Host ""
