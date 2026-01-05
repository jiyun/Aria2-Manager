Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === 全局变量 ===
$aria2cProcess = $null
$scriptDir = $PSScriptRoot
$aria2cPath = Join-Path -Path $scriptDir -ChildPath "aria2c.exe"
$indexHtmlPath = Join-Path -Path $scriptDir -ChildPath "index.html"
$aria2cConfPath = "F:\aria2\aria2.conf"
$aria2cLogPath = "F:\aria2\aria2.log"  # 注意与aria2.conf中的log路径一致
$webBrowser = $null
$lastReadLength = 0
$logReadTimer = $null

# === 主窗口 ===
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Aria2c 管理工具（日志监控版）"
$mainForm.Size = New-Object System.Drawing.Size(1200, 800)
$mainForm.StartPosition = "CenterScreen"

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill

# WebGUI选项卡
$webGuiTab = New-Object System.Windows.Forms.TabPage
$webGuiTab.Text = "Aria2c WebGUI"
$webBrowser = New-Object System.Windows.Forms.WebBrowser
$webBrowser.Dock = [System.Windows.Forms.DockStyle]::Fill
$webBrowser.ScriptErrorsSuppressed = $true
$webGuiTab.Controls.Add($webBrowser)
$tabControl.TabPages.Add($webGuiTab)

$mainForm.Controls.Add($tabControl)

# 控制台选项卡
$consoleTab = New-Object System.Windows.Forms.TabPage
$consoleTab.Text = "Aria2c 控制台"
$consoleTextBox = New-Object System.Windows.Forms.TextBox
$consoleTextBox.Multiline = $true
$consoleTextBox.ReadOnly = $true
$consoleTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$consoleTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$consoleTextBox.BackColor = [System.Drawing.Color]::Black
$consoleTextBox.ForeColor = [System.Drawing.Color]::LightGray
$consoleTab.Controls.Add($consoleTextBox)
$tabControl.TabPages.Add($consoleTab)

# === 日志追加函数（跨线程安全） ===
function Add-ConsoleLog {
    param([string]$Log)
    if ($consoleTextBox.InvokeRequired) {
        $consoleTextBox.Invoke({ Add-ConsoleLog -Log $Log })
        return
    }
    $consoleTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Log`r`n")
    $consoleTextBox.SelectionStart = $consoleTextBox.TextLength
    $consoleTextBox.ScrollToCaret()
}


# 3. 第三个选项卡：说明/关于（Markdown 支持）
$aboutTab = New-Object System.Windows.Forms.TabPage
$aboutTab.Text = "说明/关于"

# 创建 WebBrowser 控件
$aboutBrowser = New-Object System.Windows.Forms.WebBrowser
$aboutBrowser.Dock = [System.Windows.Forms.DockStyle]::Fill
$aboutBrowser.ScriptErrorsSuppressed = $true

# 原始 Markdown 内容（直接写在脚本里）
$markdown = @"
# Aria2c 管理工具

这是一个基于 **PowerShell** 和 **WinForms** 的 Aria2c 管理工具。

<p>## 主要功能
<li>- 启动或关联已运行的 Aria2c 进程
<li>- 实时查看 Aria2c 日志输出
<li>- 内嵌 WebGUI 管理下载任务
  
<p>
## 关于作者
<li>- 作者：急云
<li>- 项目地址：[GitHub](https://github.com/jiyun/Aria2-Manager)
<li>- 官方文档：[Aria2 ](https://github.com/aria2/aria2)
<li>- 官方文档：[AriaNg](https://github.com/mayswind/AriaNg)
<li>- 官方文档：[aria2.conf](https://github.com/P3TERX/aria2.conf)

"@

# Markdown 转 HTML 函数
function ConvertFrom-MarkdownToHtml {
    param([string]$Markdown)

    # 替换标题
    $Markdown = $Markdown -replace '^#{6} (.*)$', '<h6>$1</h6>'
    $Markdown = $Markdown -replace '^#{5} (.*)$', '<h5>$1</h5>'
    $Markdown = $Markdown -replace '^#{4} (.*)$', '<h4>$1</h4>'
    $Markdown = $Markdown -replace '^#{3} (.*)$', '<h3>$1</h3>'
    $Markdown = $Markdown -replace '^#{2} (.*)$', '<h2>$1</h2>'
    $Markdown = $Markdown -replace '^#{1} (.*)$', '<h1>$1</h1>'

    # 替换无序列表
    $Markdown = $Markdown -replace '^[\*-] (.*)$', '<li>$1</li>'
    $Markdown = $Markdown -replace '(<li>.*?</li>)+', '<ul>$0</ul>'

    # 替换粗体
    $Markdown = $Markdown -replace '\*\*(.*?)\*\*', '<strong>$1</strong>'

    # 替换斜体
    $Markdown = $Markdown -replace '\*(.*?)\*', '<em>$1</em>'

    # 替换链接
    $Markdown = $Markdown -replace '\[(.*?)\]\((.*?)\)', '<a href="$2">$1</a>'

    # 段落
    $Markdown = $Markdown -replace '^(?!<h|<ul|<li|<p|<a|<strong|<em).+', '<p>$0</p>'

    return $Markdown
}

# 转换 Markdown 为 HTML
$html = ConvertFrom-MarkdownToHtml -Markdown $markdown

# 包裹 HTML 头部和样式
$fullHtml = @"
<html>
<head>
<meta charset='utf-8'>
<style>
body { font-family: Microsoft YaHei, sans-serif; margin: 20px; }
h1, h2, h3, h4, h5, h6 { color: #333; }
p { line-height: 1.6; }
ul { margin-left: 20px; }
a { color: #0066cc; text-decoration: none; }
a:hover { text-decoration: underline; }
</style>
</head>
<body>
$html
</body>
</html>
"@

# 显示 HTML
$aboutBrowser.DocumentText = $fullHtml

# 点击链接在默认浏览器打开
$aboutBrowser.Add_Navigating({
    param($sender, $e)
    if ($e.Url.AbsoluteUri -notlike "about:*") {
        Start-Process $e.Url.AbsoluteUri
        $e.Cancel = $true
    }
})

# 添加到选项卡
$aboutTab.Controls.Add($aboutBrowser)
$tabControl.TabPages.Add($aboutTab)
# === 启动或关联aria2c进程 ===
function Start-Or-Attach-Aria2cProcess {
    # 先尝试关联现有进程
    $existingProc = Get-Process -Name "aria2c" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $cmdLine = Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" | Select-Object -ExpandProperty CommandLine
            $cmdLine -match [regex]::Escape($aria2cConfPath)
        } catch {
            $false
        }
    }
    if ($existingProc) {
        $script:aria2cProcess = $existingProc
        Add-ConsoleLog "已关联现有aria2c进程（PID: $($existingProc.Id)）"
        return
    }

    # 启动新进程
    if (-not (Test-Path -Path $aria2cPath -PathType Leaf)) {
        Add-ConsoleLog "未找到aria2c.exe"
        [System.Windows.Forms.MessageBox]::Show("未找到aria2c.exe", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $mainForm.Close()
        exit
    }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $aria2cPath
        $psi.Arguments = "--conf-path=`"$aria2cConfPath`" "
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $script:aria2cProcess = New-Object System.Diagnostics.Process
        $script:aria2cProcess.StartInfo = $psi
        $script:aria2cProcess.Start() | Out-Null
        Add-ConsoleLog "已启动aria2c进程（PID: $($aria2cProcess.Id)）"
    } catch {
        Add-ConsoleLog "启动aria2c失败: $_"
        [System.Windows.Forms.MessageBox]::Show("启动aria2c失败: $_", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $mainForm.Close()
        exit
    }
}

# === 加载WebGUI ===
function Load-WebGui {
    if (Test-Path -Path $indexHtmlPath) {
        $localUrl = "file:///$($indexHtmlPath -replace '\\', '/')"
        $webBrowser.Url = New-Object System.Uri($localUrl)
    } else {
        $webBrowser.DocumentText = "<h1 style='color:red;'>未找到index.html</h1>"
    }
}

# === 定时读取日志文件末尾新内容 ===
function Start-LogPolling {
    if (-not (Test-Path -Path $aria2cLogPath)) {
        Add-ConsoleLog "日志文件不存在: $aria2cLogPath"
        return
    }

    $script:lastReadLength = (Get-Item $aria2cLogPath).Length

    $script:logReadTimer = New-Object System.Windows.Forms.Timer
    $logReadTimer.Interval = 1000  # 每秒读取一次
    $logReadTimer.Add_Tick({
        try {
            $file = Get-Item $aria2cLogPath -ErrorAction Stop
            if ($file.Length -gt $script:lastReadLength) {
                # 读取新增内容
                $content = Get-Content -Path $file.FullName -Encoding UTF8 -Raw
                $newContent = $content.Substring($script:lastReadLength)
                $newLines = $newContent -split "`r`n" | Where-Object { $_ -ne "" }
                foreach ($line in $newLines) {
                    Add-ConsoleLog $line
                }
                $script:lastReadLength = $file.Length
            }
        } catch {
            Add-ConsoleLog "读取日志失败: $_"
        }
    })
    $logReadTimer.Start()
}

# === 窗口关闭事件 ===
$mainForm.Add_FormClosing({
    if ($logReadTimer) {
        $logReadTimer.Stop()
        $logReadTimer.Dispose()
    }
})

# === 主程序入口 ===
Start-Or-Attach-Aria2cProcess
Start-LogPolling
Load-WebGui
$mainForm.ShowDialog() | Out-Null