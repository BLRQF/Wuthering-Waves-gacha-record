$urlFound = $null
$checkedDirectories = @()

Write-Output "自动查找鸣潮抽卡链接..."

$pythonEnvPath = ".venv\Scripts\python.exe"
$pythonScriptPath = "main.py"

function LogCheck {
    param([Parameter(Mandatory = $true)][string]$GamePath)

    $urlToCopy = $null
    $gachaLogPath = "D:\Wuthering Waves\Wuthering Waves Game\Client\Saved\Logs\Client.log"
    # $gachaLogPath = Join-Path -Path $GamePath -ChildPath "Client\Saved\Logs\Client.log"

    if (Test-Path $gachaLogPath) {
        $gachaUrlEntry = Get-Content $gachaLogPath -Encoding UTF8 -ErrorAction SilentlyContinue | 
        Select-String -Pattern "https://aki-gm-resources(-oversea)?\.aki-game\.(net|com)/aki/gacha/index\.html#/record[^`" ]*" | 
        Select-Object -Last 1
        if ($gachaUrlEntry) {
            $urlToCopy = [regex]::Match($gachaUrlEntry.Line, "https://aki-gm-resources(-oversea)?\.aki-game\.(net|com)/aki/gacha/index\.html#/record[^`" ]*").Value
        }
    }

    if ($urlToCopy) {
        Write-Host "✅ 找到抽卡链接：$urlToCopy`n" -ForegroundColor Green
        return $urlToCopy
    }
    else {
        Write-Host "❌ 在路径 '$GamePath' 未找到抽卡链接。`n" -ForegroundColor Yellow
    }
    return $null
}


if (!$urlFound) {
    try {
        $muiCachePath = "Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
        $entries = (Get-ItemProperty -Path $muiCachePath -ErrorAction Stop).PSObject.Properties | 
        Where-Object { $_.Value -match "wuthering" -and $_.Name -match "client-win64-shipping.exe" }

        foreach ($entry in $entries) {
            $gamePath = ($entry.Name -split '\\client\\', 2)[0]
            if ($gamePath -notmatch "OneDrive" -and $gamePath -notin $checkedDirectories) {
                $checkedDirectories += $gamePath
                $urlFound = LogCheck -GamePath $gamePath
                if ($urlFound) { break }
            }
        }
    }
    catch {
        Write-Host "ℹ️  注册表查找游戏路径失败，尝试磁盘自动查找..." -ForegroundColor Cyan
    }
}

if ($urlFound) {
    Write-Host "🔄 正在启动Python程序抓取抽卡记录..." -ForegroundColor Cyan
    & $pythonEnvPath $pythonScriptPath $urlFound
    Write-Host "`n🎉 任务执行完成！" -ForegroundColor Green
}
else {
    Write-Host "❌ 未找到任何抽卡链接，请先在游戏内打开一次抽卡记录页面！" -ForegroundColor Red
}

Read-Host "`n操作完成，按回车退出"