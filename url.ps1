$urlFound = $false
$checkedDirectories = @()

Write-Output "自动查找鸣潮抽卡链接..."

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
        Set-Clipboard -Value $urlToCopy
        Write-Host "✅ 找到抽卡链接：$urlToCopy" -ForegroundColor Green
        Write-Host "📋 链接已复制到剪贴板！" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ 在路径 '$GamePath' 未找到抽卡链接。" -ForegroundColor Yellow
    }
    return $false
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


Read-Host "`n操作完成，按回车退出"