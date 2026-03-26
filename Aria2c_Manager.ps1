#Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:aria2cProcess = $null
$script:logReadTimer = $null
$script:lastReadLength = 0
$script:allowClose = $false
$script:trayIcon = $null
$script:consoleTextBox = $null
$script:statusLabel = $null
$script:restartButton = $null
$script:mainForm = $null

$script:Config = @{
    Aria2cPath = Join-Path $PSScriptRoot "aria2c.exe"
    ConfigPath = "F:\aria2\aria2.conf"
    LogPath = "F:\aria2\aria2.log"
    WebGuiPath = Join-Path $PSScriptRoot "index.html"
    IconPath = Join-Path $PSScriptRoot "aria2.ico"
    LogPollInterval = 1000
}

function Load-Config {
    $configFile = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path $configFile -PathType Leaf)) { return }
    
    try {
        $json = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        if (-not [string]::IsNullOrWhiteSpace($json.Aria2cPath)) {
            $script:Config.Aria2cPath = Convert-RelativePath $json.Aria2cPath
        }
        if (-not [string]::IsNullOrWhiteSpace($json.ConfigPath)) {
            $script:Config.ConfigPath = Convert-RelativePath $json.ConfigPath
        }
        if (-not [string]::IsNullOrWhiteSpace($json.LogPath)) {
            $script:Config.LogPath = Convert-RelativePath $json.LogPath
        }
        if (-not [string]::IsNullOrWhiteSpace($json.WebGuiPath)) {
            $script:Config.WebGuiPath = Convert-RelativePath $json.WebGuiPath
        }
        if (-not [string]::IsNullOrWhiteSpace($json.IconPath)) {
            $script:Config.IconPath = Convert-RelativePath $json.IconPath
        }
        if ($json.LogPollInterval -and $json.LogPollInterval -gt 0) {
            $script:Config.LogPollInterval = [int]$json.LogPollInterval
        }
    } catch {
        Write-Warning "配置文件解析失败: $_"
    }
}

function Convert-RelativePath($path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $PSScriptRoot $path
}

function Get-Aria2cBinary {
    $aria2cPath = $script:Config.Aria2cPath
    
    if (Test-Path $aria2cPath -PathType Leaf) {
        return $true
    }
    
    $result = [Windows.Forms.MessageBox]::Show(
        "未找到 aria2c.exe`n`n是否自动从 GitHub 下载最新版本？`n`n下载地址：`nhttps://github.com/aria2/aria2/releases",
        "aria2c.exe 不存在",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -ne [Windows.Forms.DialogResult]::Yes) {
        return $false
    }
    
    $progressForm = New-Object Windows.Forms.Form
    $progressForm.Text = "下载 aria2c"
    $progressForm.Size = New-Object Drawing.Size(450, 150)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $progressForm.MaximizeBox = $false
    $progressForm.MinimizeBox = $false
    $progressForm.ControlBox = $false
    
    $statusLabel = New-Object Windows.Forms.Label
    $statusLabel.Location = New-Object Drawing.Point(20, 15)
    $statusLabel.Size = New-Object Drawing.Size(400, 25)
    $statusLabel.Text = "正在获取最新版本信息..."
    $statusLabel.Font = New-Object Drawing.Font("Microsoft YaHei UI", 9)
    $progressForm.Controls.Add($statusLabel)
    
    $progressBar = New-Object Windows.Forms.ProgressBar
    $progressBar.Location = New-Object Drawing.Point(20, 45)
    $progressBar.Size = New-Object Drawing.Size(390, 25)
    $progressBar.Style = [Windows.Forms.ProgressBarStyle]::Continuous
    $progressForm.Controls.Add($progressBar)
    
    $progressLabel = New-Object Windows.Forms.Label
    $progressLabel.Location = New-Object Drawing.Point(20, 80)
    $progressLabel.Size = New-Object Drawing.Size(400, 25)
    $progressLabel.Text = "准备下载..."
    $progressLabel.Font = New-Object Drawing.Font("Microsoft YaHei UI", 8)
    $progressLabel.ForeColor = [Drawing.Color]::FromArgb(100, 100, 100)
    $progressForm.Controls.Add($progressLabel)
    
    $progressForm.Show()
    [Windows.Forms.Application]::DoEvents()
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $tempDir = Join-Path $PSScriptRoot "temp_aria2"
        $zipPath = Join-Path $tempDir "aria2.zip"
        
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        $apiUrl = "https://api.github.com/repos/aria2/aria2/releases/latest"
        $headers = @{ "User-Agent" = "Aria2-Manager" }
        
        $downloadUrl = $null
        try {
            $statusLabel.Text = "正在连接 GitHub API..."
            [Windows.Forms.Application]::DoEvents()
            $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing
            $downloadUrl = $release.assets | Where-Object { $_.name -like "*win-64bit*.zip" } | Select-Object -First 1 -ExpandProperty browser_download_url
            $version = $release.tag_name
            $statusLabel.Text = "获取到版本: $version"
            [Windows.Forms.Application]::DoEvents()
        } catch {
            $downloadUrl = "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip"
        }
        
        if (-not $downloadUrl) {
            $downloadUrl = "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip"
        }
        
        $statusLabel.Text = "正在下载 aria2c..."
        $progressLabel.Text = "正在连接服务器..."
        [Windows.Forms.Application]::DoEvents()
        
        $webClient = New-Object System.Net.WebClient
        
        $totalBytes = 0
        $downloadedBytes = 0
        
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier "DownloadProgress" -Action {
            $global:DownloadProgress = $EventArgs.ProgressPercentage
            $global:DownloadedBytes = $EventArgs.BytesReceived
            $global:TotalBytes = $EventArgs.TotalBytesToReceive
        } | Out-Null
        
        Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -SourceIdentifier "DownloadComplete" -Action {
            $global:DownloadComplete = $true
        } | Out-Null
        
        $global:DownloadProgress = 0
        $global:DownloadComplete = $false
        
        $webClient.DownloadFileAsync($downloadUrl, $zipPath)
        
        while (-not $global:DownloadComplete) {
            [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
            
            if ($global:DownloadProgress -gt 0) {
                $progressBar.Value = $global:DownloadProgress
                $downloadedMB = [math]::Round($global:DownloadedBytes / 1MB, 2)
                $totalMB = [math]::Round($global:TotalBytes / 1MB, 2)
                $progressLabel.Text = "已下载: $downloadedMB MB / $totalMB MB ($($global:DownloadProgress)%)"
            }
        }
        
        Unregister-Event -SourceIdentifier "DownloadProgress" -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier "DownloadComplete" -ErrorAction SilentlyContinue
        $webClient.Dispose()
        
        $progressBar.Value = 100
        $statusLabel.Text = "正在解压文件..."
        $progressLabel.Text = "请稍候..."
        [Windows.Forms.Application]::DoEvents()
        
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($zipPath)
        $dest = $shell.NameSpace($tempDir)
        $dest.CopyHere($zip.Items(), 0x14)
        
        $statusLabel.Text = "正在复制文件..."
        [Windows.Forms.Application]::DoEvents()
        
        $extractedDir = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "aria2*" } | Select-Object -First 1
        if ($extractedDir) {
            $extractedExe = Join-Path $extractedDir.FullName "aria2c.exe"
            if (Test-Path $extractedExe) {
                Copy-Item $extractedExe $aria2cPath -Force
            }
        }
        
        $statusLabel.Text = "正在清理临时文件..."
        [Windows.Forms.Application]::DoEvents()
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        $progressForm.Close()
        
        if (Test-Path $aria2cPath -PathType Leaf) {
            [Windows.Forms.MessageBox]::Show("aria2c.exe 下载完成！", "成功", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information)
            return $true
        } else {
            throw "解压后未找到 aria2c.exe"
        }
        
    } catch {
        $progressForm.Close()
        Unregister-Event -SourceIdentifier "DownloadProgress" -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier "DownloadComplete" -ErrorAction SilentlyContinue
        [Windows.Forms.MessageBox]::Show("下载 aria2c 失败:`n$_`n`n请手动下载：`nhttps://github.com/aria2/aria2/releases", "错误", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Add-ConsoleLog {
    param([string]$Message)
    if (-not $script:consoleTextBox) { return }
    if ($script:consoleTextBox.InvokeRequired) {
        $script:consoleTextBox.Invoke([Action[string]]{ param($msg) Add-ConsoleLog $msg }, $Message)
        return
    }
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $script:consoleTextBox.AppendText("[$timestamp] $Message`r`n")
    $script:consoleTextBox.SelectionStart = $script:consoleTextBox.TextLength
    $script:consoleTextBox.ScrollToCaret()
}

function Start-LogPolling {
    if (-not (Test-Path $script:Config.LogPath)) {
        Add-ConsoleLog "日志文件不存在: $($script:Config.LogPath)"
        return
    }
    
    $script:lastReadLength = (Get-Item $script:Config.LogPath).Length
    $script:logReadTimer = New-Object System.Windows.Forms.Timer
    $script:logReadTimer.Interval = $script:Config.LogPollInterval
    
    $script:logReadTimer.Add_Tick({
        try {
            $file = Get-Item $script:Config.LogPath -ErrorAction Stop
            if ($file.Length -gt $script:lastReadLength) {
                $fs = $file.OpenRead()
                $fs.Seek($script:lastReadLength, 'Begin') | Out-Null
                $reader = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
                $newContent = $reader.ReadToEnd()
                $reader.Dispose()
                $fs.Dispose()
                
                $lines = $newContent -split "`r`n|`n" | Where-Object { $_ -ne "" }
                foreach ($line in $lines) { Add-ConsoleLog $line }
                
                $script:lastReadLength = $file.Length
            }
        } catch {
            Add-ConsoleLog "读取日志失败: $_"
        }
    })
    
    $script:logReadTimer.Start()
    Add-ConsoleLog "日志监控已启动"
}

function Stop-LogPolling {
    if ($script:logReadTimer) {
        $script:logReadTimer.Stop()
        $script:logReadTimer.Dispose()
        $script:logReadTimer = $null
    }
}

function Find-Aria2cProcess {
    $processes = Get-Process -Name "aria2c" -ErrorAction SilentlyContinue
    if (-not $processes) { return $null }
    
    foreach ($proc in $processes) {
        try {
            $cmdLine = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" |
                       Select-Object -ExpandProperty CommandLine
            if ($cmdLine -match [regex]::Escape($script:Config.ConfigPath)) {
                return $proc
            }
        } catch { continue }
    }
    return $null
}

function Start-Aria2cProcess {
    $existing = Find-Aria2cProcess
    if ($existing) {
        $script:aria2cProcess = $existing
        Add-ConsoleLog "已关联现有进程 (PID: $($existing.Id))"
        Update-Status
        return $true
    }
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.Aria2cPath
        $psi.Arguments = "--conf-path=`"$($script:Config.ConfigPath)`""
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $script:aria2cProcess = New-Object System.Diagnostics.Process
        $script:aria2cProcess.StartInfo = $psi
        $script:aria2cProcess.Start() | Out-Null
        
        Add-ConsoleLog "已启动新进程 (PID: $($script:aria2cProcess.Id))"
        Update-Status
        return $true
    } catch {
        Add-ConsoleLog "启动进程失败: $_"
        return $false
    }
}

function Stop-Aria2cProcess {
    if ($script:aria2cProcess -and -not $script:aria2cProcess.HasExited) {
        try {
            $pid = $script:aria2cProcess.Id
            $script:aria2cProcess.Kill()
            $script:aria2cProcess.WaitForExit(3000)
            Add-ConsoleLog "已终止进程 (PID: $pid)"
        } catch {
            Add-ConsoleLog "终止进程失败: $_"
        }
    }
    $script:aria2cProcess = $null
}

function Restart-Aria2cProcess {
    if (-not $script:restartButton) { return }
    $script:restartButton.Enabled = $false
    if ($script:statusLabel) {
        $script:statusLabel.Text = "状态: 重启中..."
        $script:statusLabel.ForeColor = [Drawing.Color]::FromArgb(255, 152, 0)
    }
    
    Stop-Aria2cProcess
    Start-Sleep -Milliseconds 500
    $result = Start-Aria2cProcess
    
    if ($result -and $script:trayIcon) {
        $script:trayIcon.ShowBalloonTip(2000, "Aria2c 管理工具", "进程已重启 (PID: $($script:aria2cProcess.Id))", [Windows.Forms.ToolTipIcon]::Info)
    }
    
    $script:restartButton.Enabled = $true
}

function Update-Status {
    if (-not $script:statusLabel) { return }
    if ($script:aria2cProcess -and -not $script:aria2cProcess.HasExited) {
        $script:statusLabel.Text = "状态: 运行中 (PID: $($script:aria2cProcess.Id))"
        $script:statusLabel.ForeColor = [Drawing.Color]::FromArgb(76, 175, 80)
    } else {
        $script:statusLabel.Text = "状态: 未运行"
        $script:statusLabel.ForeColor = [Drawing.Color]::FromArgb(244, 67, 54)
    }
}

function New-DefaultIcon {
    $bmp = New-Object Drawing.Bitmap(32, 32)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([Drawing.Color]::Transparent)
    
    $brush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(33, 150, 243))
    $g.FillEllipse($brush, 2, 2, 28, 28)
    
    $arrowBrush = New-Object Drawing.SolidBrush([Drawing.Color]::White)
    $points = @(
        (New-Object Drawing.Point -ArgumentList 10, 8),
        (New-Object Drawing.Point -ArgumentList 22, 16),
        (New-Object Drawing.Point -ArgumentList 10, 24)
    )
    $g.FillPolygon($arrowBrush, $points)
    
    $brush.Dispose()
    $arrowBrush.Dispose()
    $g.Dispose()
    
    $hIcon = $bmp.GetHicon()
    $icon = [Drawing.Icon]::FromHandle($hIcon)
    $bmp.Dispose()
    
    return $icon
}

function New-MainForm {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Aria2c 管理工具"
    $form.Size = New-Object Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object Drawing.Size(800, 600)
    
    if (Test-Path $script:Config.IconPath -PathType Leaf) {
        try { $form.Icon = New-Object Drawing.Icon($script:Config.IconPath) }
        catch { $form.Icon = [Drawing.SystemIcons]::Application }
    } else {
        $form.Icon = New-DefaultIcon
    }
    
    $toolStrip = New-Object Windows.Forms.ToolStrip
    $toolStrip.Dock = [Windows.Forms.DockStyle]::Top
    $toolStrip.BackColor = [Drawing.Color]::FromArgb(240, 240, 240)
    $toolStrip.GripStyle = [Windows.Forms.ToolStripGripStyle]::Hidden
    $toolStrip.Padding = New-Object Windows.Forms.Padding(10, 5, 10, 5)
    
    $script:statusLabel = New-Object Windows.Forms.ToolStripLabel
    $script:statusLabel.Text = "状态: 未启动"
    $script:statusLabel.Font = New-Object Drawing.Font("Microsoft YaHei UI", 9)
    $script:statusLabel.ForeColor = [Drawing.Color]::FromArgb(100, 100, 100)
    
    $separator = New-Object Windows.Forms.ToolStripSeparator
    
    $script:restartButton = New-Object Windows.Forms.ToolStripButton
    $script:restartButton.Text = "重启进程"
    $script:restartButton.DisplayStyle = [Windows.Forms.ToolStripItemDisplayStyle]::Text
    $script:restartButton.Font = New-Object Drawing.Font("Microsoft YaHei UI", 9, [Drawing.FontStyle]::Bold)
    $script:restartButton.ForeColor = [Drawing.Color]::FromArgb(33, 150, 243)
    $script:restartButton.Add_Click({
        $result = [Windows.Forms.MessageBox]::Show(
            "确定要重启 Aria2c 进程吗？`n这可能会中断正在进行的下载任务。",
            "确认重启",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq [Windows.Forms.DialogResult]::Yes) { Restart-Aria2cProcess }
    })
    
    $openLogBtn = New-Object Windows.Forms.ToolStripButton
    $openLogBtn.Text = "打开日志"
    $openLogBtn.DisplayStyle = [Windows.Forms.ToolStripItemDisplayStyle]::Text
    $openLogBtn.Font = New-Object Drawing.Font("Microsoft YaHei UI", 9)
    $openLogBtn.ForeColor = [Drawing.Color]::FromArgb(100, 100, 100)
    $openLogBtn.Add_Click({
        if (Test-Path $script:Config.LogPath) {
            Start-Process "notepad.exe" -ArgumentList $script:Config.LogPath
        } else {
            [Windows.Forms.MessageBox]::Show("日志文件不存在", "提示")
        }
    })
    
    $openConfigBtn = New-Object Windows.Forms.ToolStripButton
    $openConfigBtn.Text = "打开配置"
    $openConfigBtn.DisplayStyle = [Windows.Forms.ToolStripItemDisplayStyle]::Text
    $openConfigBtn.Font = New-Object Drawing.Font("Microsoft YaHei UI", 9)
    $openConfigBtn.ForeColor = [Drawing.Color]::FromArgb(100, 100, 100)
    $openConfigBtn.Add_Click({
        if (Test-Path $script:Config.ConfigPath) {
            Start-Process "notepad.exe" -ArgumentList $script:Config.ConfigPath
        }
    })
    
    $toolStrip.Items.AddRange(@($script:statusLabel, $separator, $script:restartButton, $openLogBtn, $openConfigBtn))
    $form.Controls.Add($toolStrip)
    
    $tabControl = New-Object Windows.Forms.TabControl
    $tabControl.Dock = [Windows.Forms.DockStyle]::Fill
    
    $webGuiTab = New-Object Windows.Forms.TabPage
    $webGuiTab.Text = "WebGUI"
    $webBrowser = New-Object Windows.Forms.WebBrowser
    $webBrowser.Dock = [Windows.Forms.DockStyle]::Fill
    $webBrowser.ScriptErrorsSuppressed = $true
    
    if (Test-Path $script:Config.WebGuiPath -PathType Leaf) {
        $rpcSecret = "P3TERX"
        $rpcPort = "6800"
        $url = "file:///$($script:Config.WebGuiPath -replace '\\', '/')#!/settings/rpc/set/wallet?protocol=http&host=localhost&port=$rpcPort&secret=$rpcSecret"
        $webBrowser.Url = New-Object Uri($url)
    } else {
        $webBrowser.DocumentText = "<html><body style='padding:20px;font-family:Microsoft YaHei;'><h2 style='color:#d32f2f;'>未找到 WebGUI 文件</h2><p>请确保 index.html 存在</p></body></html>"
    }
    $webGuiTab.Controls.Add($webBrowser)
    $tabControl.TabPages.Add($webGuiTab)
    
    $consoleTab = New-Object Windows.Forms.TabPage
    $consoleTab.Text = "控制台"
    $script:consoleTextBox = New-Object Windows.Forms.TextBox
    $script:consoleTextBox.Multiline = $true
    $script:consoleTextBox.ReadOnly = $true
    $script:consoleTextBox.Dock = [Windows.Forms.DockStyle]::Fill
    $script:consoleTextBox.Font = New-Object Drawing.Font("Consolas", 10)
    $script:consoleTextBox.BackColor = [Drawing.Color]::FromArgb(30, 30, 30)
    $script:consoleTextBox.ForeColor = [Drawing.Color]::LightGray
    $consoleTab.Controls.Add($script:consoleTextBox)
    $tabControl.TabPages.Add($consoleTab)
    
    $aboutTab = New-Object Windows.Forms.TabPage
    $aboutTab.Text = "关于"
    $aboutBrowser = New-Object Windows.Forms.WebBrowser
    $aboutBrowser.Dock = [Windows.Forms.DockStyle]::Fill
    $aboutBrowser.ScriptErrorsSuppressed = $true
    $aboutBrowser.DocumentText = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<style>
body { font-family: 'Microsoft YaHei', sans-serif; margin: 30px; background: #f5f5f5; color: #333; }
.container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
h1 { color: #2196F3; border-bottom: 2px solid #2196F3; padding-bottom: 10px; }
h2 { color: #333; margin-top: 25px; }
ul { line-height: 2; }
a { color: #2196F3; text-decoration: none; }
a:hover { text-decoration: underline; }
.footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #eee; color: #666; font-size: 12px; }
</style>
</head>
<body>
<div class='container'>
<h1>Aria2c 管理工具</h1>
<p>基于 <strong>PowerShell</strong> 和 <strong>WinForms</strong> 构建的 Aria2c 下载管理工具</p>
<h2>主要功能</h2>
<ul>
<li>启动或关联已运行的 Aria2c 进程</li>
<li>实时查看 Aria2c 日志输出</li>
<li>内嵌 WebGUI 管理下载任务</li>
<li>进程状态监控与管理</li>
<li>系统托盘最小化支持</li>
<li>JSON 配置文件支持</li>
</ul>
<h2>相关链接</h2>
<ul>
<li>Aria2 官方: <a href='https://github.com/aria2/aria2'>github.com/aria2/aria2</a></li>
<li>AriaNg 项目: <a href='https://github.com/mayswind/AriaNg'>github.com/mayswind/AriaNg</a></li>
</ul>
<div class='footer'>作者: 急云 | 版本: 0.2</div>
</div>
</body>
</html>
"@
    $aboutBrowser.Add_Navigating({
        param($sender, $e)
        if ($e.Url.AbsoluteUri -notlike "about:*") {
            Start-Process $e.Url.AbsoluteUri
            $e.Cancel = $true
        }
    })
    $aboutTab.Controls.Add($aboutBrowser)
    $tabControl.TabPages.Add($aboutTab)
    
    $form.Controls.Add($tabControl)
    
    $form.Add_SizeChanged({
        if ($this.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
            $this.Visible = $false
            if ($script:trayIcon) {
                $script:trayIcon.Visible = $true
                $script:trayIcon.ShowBalloonTip(2000, "Aria2c 管理工具", "程序已最小化到系统托盘", [Windows.Forms.ToolTipIcon]::Info)
            }
        }
    })
    
    $form.Add_FormClosing({
        param($sender, $e)
        if (-not $script:allowClose) {
            $e.Cancel = $true
            $sender.Visible = $false
            if ($script:trayIcon) {
                $script:trayIcon.Visible = $true
                $script:trayIcon.ShowBalloonTip(2000, "Aria2c 管理工具", "程序已最小化到系统托盘", [Windows.Forms.ToolTipIcon]::Info)
            }
        } else {
            Stop-LogPolling
            Stop-Aria2cProcess
            if ($script:trayIcon) {
                $script:trayIcon.Visible = $false
                $script:trayIcon.Dispose()
            }
        }
    })
    
    return $form
}

function New-TrayIcon {
    $trayIcon = New-Object Windows.Forms.NotifyIcon
    if (Test-Path $script:Config.IconPath -PathType Leaf) {
        try { $trayIcon.Icon = New-Object Drawing.Icon($script:Config.IconPath) }
        catch { $trayIcon.Icon = New-DefaultIcon }
    } else {
        $trayIcon.Icon = New-DefaultIcon
    }
    $trayIcon.Text = "Aria2c 管理工具"
    $trayIcon.Visible = $true
    
    $trayMenu = New-Object Windows.Forms.ContextMenuStrip
    $showItem = New-Object Windows.Forms.ToolStripMenuItem
    $showItem.Text = "显示主窗口"
    $showItem.Add_Click({
        if ($script:mainForm) {
            $script:mainForm.Show()
            $script:mainForm.WindowState = [Windows.Forms.FormWindowState]::Normal
            $script:mainForm.Activate()
        }
    })
    
    $exitItem = New-Object Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "退出"
    $exitItem.Add_Click({
        $script:allowClose = $true
        if ($script:trayIcon) {
            $script:trayIcon.Visible = $false
        }
        if ($script:mainForm) {
            $script:mainForm.Close()
        }
    })
    
    $trayMenu.Items.AddRange(@($showItem, $exitItem))
    $trayIcon.ContextMenuStrip = $trayMenu
    
    $trayIcon.Add_DoubleClick({
        if ($script:mainForm) {
            $script:mainForm.Show()
            $script:mainForm.WindowState = [Windows.Forms.FormWindowState]::Normal
            $script:mainForm.Activate()
        }
    })
    
    return $trayIcon
}

function Main {
    try {
        Load-Config
        
        if (-not (Get-Aria2cBinary)) {
            return
        }
        
        if (-not (Test-Path $script:Config.ConfigPath -PathType Leaf)) {
            [Windows.Forms.MessageBox]::Show("配置文件不存在: $($script:Config.ConfigPath)", "错误", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        $script:trayIcon = New-TrayIcon
        $script:mainForm = New-MainForm
        
        if (-not (Start-Aria2cProcess)) {
            [Windows.Forms.MessageBox]::Show("无法启动 Aria2c 进程，请检查配置。", "错误", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        Start-LogPolling
        [Windows.Forms.Application]::Run($script:mainForm)
        
    } catch {
        [Windows.Forms.MessageBox]::Show("程序初始化失败:`n$_", "错误", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }
}

Main
