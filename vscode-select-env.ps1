# VSCode Python 环境选择器（单独运行，只改环境配置，不启动 VSCode）

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
$pmConfigFile = "$configDir\package-managers.json"

# 读取记录
$lastEnv = $null
if (Test-Path $configFile) { try { $lastEnv = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }

# 覆盖式保存
function Save-ConfigFields($fields) {
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $data = [PSCustomObject]@{}
    if (Test-Path $configFile) { try { $data = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    foreach ($prop in $fields.PSObject.Properties) { if ($data.PSObject.Properties[$prop.Name]) { $data.PSObject.Properties.Remove($prop.Name) } }
    if ($data.PSObject.Properties["Time"]) { $data.PSObject.Properties.Remove("Time") }
    foreach ($prop in $fields.PSObject.Properties) { $data | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value }
    $data | Add-Member -NotePropertyName "Time" -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $data | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding UTF8
}

# 包管理器配置
function Get-PackageManagers {
    if (Test-Path $pmConfigFile) {
        try { $list = Get-Content $pmConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json; if ($list) { Write-Output @($list) -NoEnumerate; return } } catch { }
    }
    Write-Output @() -NoEnumerate
}
function Save-PackageManagers($managers) {
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $json = ConvertTo-Json -InputObject @($managers) -Depth 3
    if ($json -notmatch '^\s*\[') { $json = "[$json]" }
    $json | Set-Content $pmConfigFile -Encoding UTF8
}
function Add-PackageManager {
    Write-Host ""; Write-Host "  添加包管理器" -ForegroundColor Cyan; Write-Host "  目前支持: conda" -ForegroundColor DarkGray; Write-Host ""
    $name = Read-Host "  名称（如 Anaconda、Miniconda）"
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    $guessPaths = @("D:\dxx\software\Users\dxx\anaconda3\Scripts\conda.exe","$env:USERPROFILE\anaconda3\Scripts\conda.exe","$env:USERPROFILE\miniconda3\Scripts\conda.exe","C:\ProgramData\anaconda3\Scripts\conda.exe","C:\ProgramData\miniconda3\Scripts\conda.exe")
    $defaultPath = ""
    foreach ($gp in $guessPaths) { if (Test-Path $gp) { $defaultPath = $gp; break } }
    $path = Read-Host "  conda.exe 路径（回车=$defaultPath）"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = $defaultPath }
    if (-not $path -or -not (Test-Path $path)) { Write-Host "  路径无效: $path" -ForegroundColor Red; return $null }
    $pm = [PSCustomObject]@{ Type = "conda"; Name = $name; Path = $path }
    $managers = Get-PackageManagers; $managers += $pm; Save-PackageManagers $managers
    Write-Host ""; Write-Host "  已添加: $name ($path)" -ForegroundColor Green
    return $pm
}

# 扫描环境
function Get-PythonEnvs($pm) {
    $envs = @(); $exe = $pm.Path
    if ($pm.Type -eq "conda" -and (Test-Path $exe)) {
        $output = & $exe env list 2>$null
        foreach ($line in $output) {
            if ($line -match '^\s*(\S+)\s+(\S.+)$') {
                $name = $matches[1].Trim(); $path = $matches[2].Trim()
                $path = $path -replace '^\*\s+', ''
                if ($name -eq '#' -or $name -eq '') { continue }
                $pyPath = Join-Path $path "python.exe"
                if (Test-Path $pyPath) { $envs += [PSCustomObject]@{ Name = "$($pm.Name): $name"; Path = $pyPath; Type = $pm.Type; EnvName = $name } }
            }
        }
    }
    foreach ($p in @("C:\Python314\python.exe","C:\Python313\python.exe","C:\Python312\python.exe","C:\Python311\python.exe")) {
        if (Test-Path $p) { $ver = (Split-Path (Split-Path $p -Parent) -Leaf); $envs += [PSCustomObject]@{ Name = "系统: $ver"; Path = $p; Type = "system"; EnvName = $ver } }
    }
    return $envs
}

# 创建环境
function New-CondaEnvironment($pm) {
    $exe = $pm.Path
    Write-Host ""; Write-Host "  创建新环境（$($pm.Name)）" -ForegroundColor Cyan
    $name = Read-Host "  环境名称"
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    # 循环：选择版本 → 确认 → 创建，n 则返回重选
    while ($true) {
        Write-Host ""
        Write-Host "  正在获取可用 Python 版本（conda search 较慢，请稍候）..." -ForegroundColor DarkGray
        $allVersions = & $exe search python --override-channels -c defaults 2>$null | ForEach-Object { if ($_ -match 'python\s+(\d+\.\d+\.\d+)') { $matches[1] } } | Sort-Object -Descending -Unique
        # 每个小版本只保留最新3个补丁版
        $grouped = @{}
        foreach ($v in $allVersions) {
            $parts = $v -split '\.'
            $minor = "$($parts[0]).$($parts[1])"
            if (-not $grouped.ContainsKey($minor)) { $grouped[$minor] = @() }
            $grouped[$minor] += $v
        }
        $pyVersions = @()
        foreach ($minor in ($grouped.Keys | Sort-Object -Descending)) { $pyVersions += $grouped[$minor] | Select-Object -First 1 }
        Write-Host ""; Write-Host "  可用 Python 版本:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $pyVersions.Count; $i++) { Write-Host ("  {0,2}. {1}" -f ($i + 1), $pyVersions[$i]) }
        Write-Host ""
        $pyVer = ""
        while ($true) {
            $verInput = Read-Host "  选择版本编号（回车=最新）"
            if ([string]::IsNullOrWhiteSpace($verInput)) { break }
            $vi = -1
            if ([int]::TryParse($verInput, [ref]$vi)) {
                $vi = $vi - 1
                if ($vi -ge 0 -and $vi -lt $pyVersions.Count) { $pyVer = $pyVersions[$vi]; break }
            }
            Write-Host "  输入无效，请输入有效编号或回车选最新" -ForegroundColor Red
        }
        $displayVer = if ($pyVer) { $pyVer } else { "最新版本" }
        $pkg = if ($pyVer) { "python=$pyVer" } else { "python" }

        # 确认
        Write-Host ""
        Write-Host "  ===== 创建确认 =====" -ForegroundColor Yellow
        Write-Host ("  环境名称: {0}" -f $name)
        Write-Host ("  Python版本: {0}" -f $displayVer)
        if (-not $pyVer) { Write-Host "  （未选择具体版本，将安装最新版）" -ForegroundColor DarkGray }
        Write-Host "  ====================" -ForegroundColor Yellow
        Write-Host ""
        $createConfirmed = $false
        while ($true) {
            $confirm = Read-Host "  确认创建? (y=确认, n=返回重新选择版本)"
            if ($confirm -match '^[Yy]$') { $createConfirmed = $true; break }
            if ($confirm -match '^[Nn]$') { $createConfirmed = $false; break }
            Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
        }
        if (-not $createConfirmed) { continue }

        # 创建
        Write-Host ""; Write-Host "  正在创建环境 '$name'（$pkg）..." -ForegroundColor Yellow
        Write-Host "  conda 下载安装中，下方会显示进度..." -ForegroundColor DarkGray
        Write-Host "  ========================================" -ForegroundColor DarkGray
        Write-Host "  执行: conda create -n $name $pkg -y" -ForegroundColor DarkGray
        Start-Process -FilePath $exe -ArgumentList @("create","-n",$name,$pkg,"-y") -NoNewWindow -Wait
        Write-Host "  ========================================" -ForegroundColor DarkGray
        $envDir = & $exe env list 2>$null | Where-Object { $_ -match "^\s*$name\s+" } | ForEach-Object { ($_ -split '\s+')[-1].Trim() }
        if ($envDir) {
            $pyPath = Join-Path $envDir "python.exe"
            if (Test-Path $pyPath) {
                Write-Host ""; Write-Host "  创建成功!" -ForegroundColor Green
                Write-Host ("  环境: {0}" -f $name) -ForegroundColor Green
                Write-Host ("  Python: {0}" -f $pyPath) -ForegroundColor Green
                Write-Host ""; Read-Host "  按回车继续"
                return [PSCustomObject]@{ Name = "$($pm.Name): $name"; Path = $pyPath; Type = $pm.Type; EnvName = $name }
            }
        }
        Write-Host ""; Write-Host "  创建失败，请检查上方 conda 输出" -ForegroundColor Red
        Write-Host ""; Read-Host "  按回车返回"
        return $null
    }
}

# 删除环境
function Remove-CondaEnvironment($pm) {
    $exe = $pm.Path
    Write-Host ""; Write-Host "  删除环境（$($pm.Name)）" -ForegroundColor Cyan
    Write-Host "  （仅删除包管理器环境，项目和工作区文件不受影响）" -ForegroundColor DarkGray
    $condaEnvs = Get-PythonEnvs $pm | Where-Object { $_.Type -eq "conda" -and $_.EnvName -ne "base" }
    if ($condaEnvs.Count -eq 0) { Write-Host "  没有可删除的环境" -ForegroundColor Yellow; Read-Host "  按回车返回"; return }
    Write-Host ""
    for ($i = 0; $i -lt $condaEnvs.Count; $i++) { Write-Host ("  {0,2}. {1}" -f ($i + 1), $condaEnvs[$i].Name) }
    Write-Host ""
    while ($true) {
        $idxInput = Read-Host "  选择要删除的环境编号（回车=取消）"
        if ([string]::IsNullOrWhiteSpace($idxInput)) { return }
        $idx = -1
        if (-not [int]::TryParse($idxInput, [ref]$idx)) { Write-Host "  输入无效，请输入数字编号" -ForegroundColor Red; continue }
        $idx = $idx - 1
        if ($idx -ge 0 -and $idx -lt $condaEnvs.Count) {
            $envName = $condaEnvs[$idx].EnvName
            Write-Host ""
            while ($true) {
                $confirm = Read-Host "  确认删除 '$envName'? 此操作不可恢复 (y/n)"
                if ($confirm -match '^[Yy]$') { break }
                if ($confirm -match '^[Nn]$') { break }
                Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
            }
            if ($confirm -match '^[Yy]$') {
                Write-Host ""; Write-Host "  正在删除 '$envName'..." -ForegroundColor Yellow
                Write-Host "  执行: conda remove -n $envName --all -y" -ForegroundColor DarkGray
                Start-Process -FilePath $exe -ArgumentList @("remove","-n",$envName,"--all","-y") -NoNewWindow -Wait
                Write-Host ""; Write-Host "  已删除: $envName" -ForegroundColor Green
                Start-Sleep -Milliseconds 800
            }
            return
        }
        Write-Host "  编号超出范围" -ForegroundColor Red
    }
}

# ===== 主流程 =====
Write-Host ""
Write-Host "  VSCode Python 环境选择器" -ForegroundColor Cyan
Write-Host "  ========================" -ForegroundColor DarkGray

$managers = Get-PackageManagers
if ($managers.Count -eq 0) {
    Write-Host ""; Write-Host "  首次使用，自动检测 conda..." -ForegroundColor DarkGray
    foreach ($gp in @("D:\dxx\software\Users\dxx\anaconda3\Scripts\conda.exe","$env:USERPROFILE\anaconda3\Scripts\conda.exe","$env:USERPROFILE\miniconda3\Scripts\conda.exe","C:\ProgramData\anaconda3\Scripts\conda.exe")) {
        if (Test-Path $gp) {
            Save-PackageManagers @([PSCustomObject]@{ Type = "conda"; Name = "Anaconda"; Path = $gp })
            Write-Host "  自动添加: Anaconda ($gp)" -ForegroundColor Green; break
        }
    }
    $managers = Get-PackageManagers
}

$selectedPM = $null; $selectedPython = $null

if ($lastEnv -and $lastEnv.PMName) {
    $prevPM = $managers | Where-Object { $_.Name -eq $lastEnv.PMName } | Select-Object -First 1
    if ($prevPM) {
        Write-Host ""; Write-Host ("  上次包管理器: {0} ({1})" -f $prevPM.Name, $prevPM.Type) -ForegroundColor Yellow
        Write-Host ("  路径: {0}" -f $prevPM.Path) -ForegroundColor DarkGray
        Write-Host ""
        while ($true) {
            $yn = Read-Host "  是否继续上次包管理器? (y/n)"
            if ($yn -match '^[Yy]$') { $selectedPM = $prevPM; break }
            if ($yn -match '^[Nn]$') { break }
            Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
        }
    }
}

while (-not $selectedPM) {
    $managers = Get-PackageManagers
    Write-Host ""; Write-Host "  可用包管理器:" -ForegroundColor Cyan; Write-Host ""
    for ($i = 0; $i -lt $managers.Count; $i++) { $m = $managers[$i]; Write-Host ("  {0,2}. {1,-16} {2,-8} {3}" -f ($i + 1), $m.Name, $m.Type, $m.Path) }
    $addIdx = $managers.Count + 1; $skipIdx = $managers.Count + 2
    Write-Host ("  {0,2}. 添加新包管理器" -f $addIdx) -ForegroundColor Green
    Write-Host ("  {0,2}. 跳过（不设置Python环境）" -f $skipIdx) -ForegroundColor Yellow
    Write-Host ""
    $pmInput = Read-Host "  选择编号"
    $idx = -1
    if (-not [int]::TryParse($pmInput, [ref]$idx)) { Write-Host "  输入无效，请输入数字编号" -ForegroundColor Red; continue }
    if ($true) {
        $idx = $idx - 1
        if ($idx -ge 0 -and $idx -lt $managers.Count) { $selectedPM = $managers[$idx] }
        elseif ($idx -eq $managers.Count) { $selectedPM = Add-PackageManager }
        elseif ($idx -eq $skipIdx - 1) { break }
    }
}

if ($selectedPM) {
    if ($lastEnv -and $lastEnv.PMName -eq $selectedPM.Name -and $lastEnv.PythonPath -and (Test-Path $lastEnv.PythonPath)) {
        Write-Host ""; Write-Host ("  上次环境: {0}" -f $lastEnv.PythonName) -ForegroundColor Yellow
        Write-Host ("  路径: {0}" -f $lastEnv.PythonPath) -ForegroundColor DarkGray
        Write-Host ""
        while ($true) {
            $yn = Read-Host "  是否继续上次 Python 环境? (y/n)"
            if ($yn -match '^[Yy]$') { $selectedPython = [PSCustomObject]@{ Name = $lastEnv.PythonName; Path = $lastEnv.PythonPath; Type = $selectedPM.Type }; break }
            if ($yn -match '^[Nn]$') { break }
            Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
        }
    }
    while (-not $selectedPython) {
        $pythonEnvs = Get-PythonEnvs $selectedPM
        if ($pythonEnvs.Count -eq 0) { Write-Host "  未检测到任何 Python 环境" -ForegroundColor Yellow; break }
        Write-Host ""; Write-Host ("  可用 Python 环境 ({0}):" -f $pythonEnvs.Count) -ForegroundColor Cyan; Write-Host ""
        for ($i = 0; $i -lt $pythonEnvs.Count; $i++) { $e = $pythonEnvs[$i]; Write-Host ("  {0,2}. {1,-24} {2}" -f ($i + 1), $e.Name, $e.Path) }
        $createIdx = $pythonEnvs.Count + 1; $deleteIdx = $pythonEnvs.Count + 2; $skipIdx = $pythonEnvs.Count + 3
        Write-Host ("  {0,2}. 创建新环境" -f $createIdx) -ForegroundColor Green
        Write-Host ("  {0,2}. 删除环境" -f $deleteIdx) -ForegroundColor Red
        Write-Host ("  {0,2}. 跳过（不设置Python环境）" -f $skipIdx) -ForegroundColor Yellow
        Write-Host ""
        $pyInput = Read-Host "  选择编号"
        $idx = -1
        if (-not [int]::TryParse($pyInput, [ref]$idx)) { Write-Host "  输入无效，请输入数字编号" -ForegroundColor Red; continue }
        if ($true) {
            $idx = $idx - 1
            if ($idx -ge 0 -and $idx -lt $pythonEnvs.Count) {
                $candidate = $pythonEnvs[$idx]
                Write-Host ""
                Write-Host "  ===== 选择确认 =====" -ForegroundColor Yellow
                Write-Host ("  编号: {0}" -f ($idx + 1))
                Write-Host ("  环境: {0}" -f $candidate.Name)
                Write-Host ("  路径: {0}" -f $candidate.Path)
                Write-Host "  ====================" -ForegroundColor Yellow
                Write-Host ""
                $cfConfirmed = $false
                while ($true) {
                    $cf = Read-Host "  确认选择? (y=确认, n=返回重新选择)"
                    if ($cf -match '^[Yy]$') { $cfConfirmed = $true; break }
                    if ($cf -match '^[Nn]$') { $cfConfirmed = $false; break }
                    Write-Host "  输入无效，请输入 y 或 n" -ForegroundColor Red
                }
                if (-not $cfConfirmed) { continue }
                $selectedPython = $candidate
            }
            elseif ($idx -eq $createIdx - 1) { $selectedPython = New-CondaEnvironment $selectedPM }
            elseif ($idx -eq $deleteIdx - 1) { Remove-CondaEnvironment $selectedPM }
            elseif ($idx -eq $skipIdx - 1) { break }
        }
    }
}

Save-ConfigFields ([PSCustomObject]@{
    PMName = if ($selectedPM) { $selectedPM.Name } else { $null }
    PMType = if ($selectedPM) { $selectedPM.Type } else { $null }
    PMPath = if ($selectedPM) { $selectedPM.Path } else { $null }
    PythonPath = if ($selectedPython) { $selectedPython.Path } else { $null }
    PythonName = if ($selectedPython) { $selectedPython.Name } else { $null }
})

Write-Host ""
if ($selectedPython) {
    Write-Host "  环境选择已保存" -ForegroundColor Green
    Write-Host ("  包管理器: {0}" -f $selectedPM.Name)
    Write-Host ("  Python: {0}" -f $selectedPython.Name)
} else { Write-Host "  未设置 Python 环境" -ForegroundColor Yellow }
Write-Host ""