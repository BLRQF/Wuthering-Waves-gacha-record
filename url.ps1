# ========== 脚本所在目录 ==========
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# ==================================

# ========== 解密函数（生成解密文件到 temp 目录） ==========
function Decrypt-ClientLog {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "日志文件不存在: $Path"
    }

    # 在脚本同级目录下创建 temp 文件夹
    $tempDir = Join-Path -Path $ScriptDir -ChildPath "temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    # 解密后文件的保存路径
    $decryptedFile = Join-Path -Path $tempDir -ChildPath "Client_decrypted.log"

    try {
        # 将原始加密日志复制到 temp 目录（避免文件被游戏独占）
        Copy-Item -Path $Path -Destination $decryptedFile -Force -ErrorAction Stop
        Write-Host "📄 已在 temp 目录生成日志副本，开始解密..." -ForegroundColor DarkGray

        # 读取副本的所有字节
        $bytes = [System.IO.File]::ReadAllBytes($decryptedFile)

        # 逐字节解密
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if (($bytes[$i] -band 0x0F) % 2 -eq 1) {
                $bytes[$i] = $bytes[$i] -bxor 0xA5
            } else {
                $bytes[$i] = $bytes[$i] -bxor 0xEF
            }
        }

        # 将解密后的字节写回同一个文件
        [System.IO.File]::WriteAllBytes($decryptedFile, $bytes)
        Write-Host "🔓 解密完成，已保存至：$decryptedFile" -ForegroundColor Green

        # 返回解密文件路径，供后续读取
        return $decryptedFile
    }
    catch {
        throw "解密过程失败: $_"
    }
}
# ================================================================

$urlFound = $null
$checkedDirectories = @()

Write-Output "自动查找鸣潮抽卡链接..."

$pythonEnvPath = ".venv\Scripts\python.exe"
$pythonScriptPath = "main.py"

function LogCheck {
    param([Parameter(Mandatory = $true)][string]$GamePath)

    $urlToCopy = $null
    $gachaLogPath = "D:\Wuthering Waves\Wuthering Waves Game\Client\Saved\Logs\Client.log"

    if (Test-Path $gachaLogPath) {
        try {
            Write-Host "🔓 正在解密日志文件..." -ForegroundColor Cyan
            # 调用解密函数，得到解密后的文件路径
            $decryptedFile = Decrypt-ClientLog -Path $gachaLogPath

            # 读取解密后的文件内容（UTF-8）
            $plainText = Get-Content -Path $decryptedFile -Raw -Encoding UTF8

            # 在明文中搜索抽卡链接（取最后一条）
            # 按行分割，找出所有包含抽卡链接特征的行
            $lines = $plainText -split '\r?\n' | Where-Object { $_ -match 'aki/gacha/index\.html' }
            $lastLine = $lines | Select-Object -Last 1

            if ($lastLine) {
                # 从最后一行中提取完整的 URL（防止行内还有其他字符）
                $urlToCopy = [regex]::Match($lastLine, 'https?://[^\s"]*aki/gacha/index\.html[^\s"]*').Value
            }
        }
        catch {
            Write-Host "❌ 解密日志文件时出错: $_" -ForegroundColor Red
        }
    }

    if ($urlToCopy) {
        Write-Host "✅ 找到抽卡链接：$urlToCopy`n" -ForegroundColor Green
        Set-Clipboard -Value $urlToCopy
        Write-Host "📋 链接已复制到剪贴板！`n" -ForegroundColor Green
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