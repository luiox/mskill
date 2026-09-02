#Requires -Version 5.1
<#
homepage-hijack-cleanup / detect-hijack.ps1
只读体检：浏览器主页劫持通道判定 + 已知家族（疾风/NStore 等）持久化检查。不修改任何设置。
usage: powershell -ExecutionPolicy Bypass -NoProfile -File detect-hijack.ps1
退出码: 0=未发现, 1=有命中
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$script:hits = 0
function Hit([string]$m)  { Write-Host "[HIT] $m" -ForegroundColor Red;   $script:hits++ }
function Ok([string]$m)   { Write-Host "[ok ] $m" -ForegroundColor Green }
function Info([string]$m) { Write-Host "[inf ] $m" -ForegroundColor DarkGray }

# 劫持/跳转站特征，按需扩充（家族指纹详见 references/known-hijackers.md）
$promoRe = 'hao\.360\.com|hao123|2345\.com|so\.com|dhres\.com|huanyuroad|daohang'

Write-Host '== 1. lockhomepage 数据目录（疾风/NStore 家族） =='
$lh = Join-Path $env:APPDATA 'lockhomepage'
if (Test-Path $lh) {
    Hit "数据目录存在: $lh"
    Get-ChildItem $lh -ErrorAction SilentlyContinue | ForEach-Object {
        Info ('{0}  modified {1}' -f $_.Name, $_.LastWriteTime)
    }
    Get-ChildItem $lh -Filter *.ini -ErrorAction SilentlyContinue | ForEach-Object {
        Info ("---- {0} ----" -f $_.Name)
        Get-Content $_.FullName | ForEach-Object { Info "  $_" }
    }
} else { Ok '未发现 lockhomepage 数据目录' }

Write-Host ''
Write-Host '== 2. Chrome 配置（各 profile，Preferences + Secure Preferences） =='
$ud = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
if (Test-Path $ud) {
    Get-ChildItem $ud -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'Preferences') } | ForEach-Object {
            $prof = $_.Name
            foreach ($f in 'Secure Preferences', 'Preferences') {
                $p = Join-Path $_.FullName $f
                if (-not (Test-Path $p)) { continue }
                try { $j = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Info "[$prof/$f] JSON 解析失败"; continue }
                $ros  = $j.session.restore_on_startup
                $urls = $j.session.startup_urls
                $hp   = $j.homepage
                $dsp  = $j.default_search_provider_data.template_url_data.short_name
                $exts = $j.extensions.settings
                $extN = if ($exts) { @($exts.PSObject.Properties).Count } else { 0 }
                if ($urls) {
                    $u = ($urls -join ' | ')
                    if ($u -match $promoRe) { Hit "[$prof/$f] startup_urls 疑似劫持: $u" }
                    else { Info "[$prof/$f] startup_urls: $u" }
                }
                if ($ros -ne $null) { Info "[$prof/$f] restore_on_startup=$ros (4=打开特定网页)" }
                if ($hp -and $hp -match $promoRe) { Hit "[$prof/$f] homepage 疑似劫持: $hp" }
                if ($dsp) { Info "[$prof/$f] 默认搜索引擎: $dsp" }
                Info "[$prof/$f] 扩展数: $extN"
            }
        }
} else { Info '未找到 Chrome User Data' }

Write-Host ''
Write-Host '== 3. 快捷方式参数（Desktop / StartMenu / Quick Launch 含任务栏固定） =='
$sh = New-Object -ComObject WScript.Shell
$lnkPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('StartMenu'),
    [Environment]::GetFolderPath('CommonStartMenu'),
    (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
foreach ($dir in $lnkPaths) {
    Get-ChildItem $dir -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try { $lnk = $sh.CreateShortcut($_.FullName) } catch { return }
        if ($lnk.Arguments -match 'https?://') {
            if ($lnk.Arguments -match $promoRe) {
                Hit ('快捷方式带劫持URL: {0}  Args=[{1}]' -f $_.FullName, $lnk.Arguments)
            } else {
                Info ('快捷方式带URL(人工过目): {0}  Args=[{1}]' -f $_.FullName, $lnk.Arguments)
            }
        }
    }
}

Write-Host ''
Write-Host '== 4. 运行中浏览器的启动注入 =='
$browserProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(chrome|msedge|quark|firefox)\.exe$' -and
                   $_.CommandLine -match 'https?://' -and $_.CommandLine -notmatch '--type=' }
if ($browserProcs) {
    foreach ($bp in $browserProcs) {
        $short = ($bp.CommandLine -split ' --')[0]
        if ($short -match $promoRe) {
            Hit ('带劫持URL的浏览器主进程: PID={0}  {1}' -f $bp.ProcessId, $short)
        } elseif ($short -match 'https?://') {
            Info ('浏览器带URL启动(人工过目): PID={0}  {1}' -f $bp.ProcessId, $short)
        }
        $par = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $bp.ParentProcessId) -ErrorAction SilentlyContinue
        if ($par) { Info ('  父进程: {0} (PID {1})' -f $par.Name, $par.ProcessId) }
    }
} else { Ok '运行中浏览器无带 URL 的启动注入' }

Write-Host ''
Write-Host '== 5. Chrome 策略 / IFEO =='
foreach ($rk in 'HKCU:\SOFTWARE\Policies\Google\Chrome',
                'HKLM:\SOFTWARE\Policies\Google\Chrome',
                'HKLM:\SOFTWARE\WOW6432Node\Policies\Google\Chrome') {
    if (Test-Path $rk) { Hit "存在 Chrome 策略键: $rk"; Get-ChildItem $rk -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Info $_.Name } }
}
if (-not (Test-Path 'HKCU:\SOFTWARE\Policies\Google\Chrome') -and
    -not (Test-Path 'HKLM:\SOFTWARE\Policies\Google\Chrome') -and
    -not (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Policies\Google\Chrome')) { Ok '无 Chrome 策略键' }
foreach ($rk in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\chrome.exe',
                'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\chrome.exe') {
    if (Test-Path $rk) {
        $dbg = (Get-ItemProperty $rk -ErrorAction SilentlyContinue).Debugger
        if ($dbg) { Hit "IFEO Debugger 劫持 chrome.exe: $dbg" } else { Info "IFEO 键存在但无 Debugger: $rk" }
    }
}

Write-Host ''
Write-Host '== 6. 已知家族持久化（疾风/NStore） =='
$ns = Join-Path ${env:ProgramFiles(x86)} 'NStore'
if (Test-Path $ns) { Hit "疾风软件市场安装目录存在: $ns" }
$task = Get-ScheduledTask -TaskName 'NStoreTray' -ErrorAction SilentlyContinue
if ($task) {
    Hit ('计划任务 NStoreTray [{0}]: {1}' -f $task.State,
        (($task.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join '; '))
}
$drv = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\GHallProtect' -ErrorAction SilentlyContinue
if ($drv) { Hit ('内核驱动服务 GHallProtect 存在: Start={0}  ImagePath={1}' -f $drv.Start, $drv.ImagePath) }
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.PathName -match 'NStore|Ghall' } |
    ForEach-Object { Hit ('服务 {0} [{1}]: {2}' -f $_.Name, $_.State, $_.PathName) }
Get-Process -Name Gt, Ghall, guardhp -ErrorAction SilentlyContinue |
    ForEach-Object { Hit ('家族进程运行中: {0} PID={1}' -f $_.ProcessName, $_.Id) }
$un = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match '疾风|NStore' }
if ($un) { $un | ForEach-Object { Info ('卸载项: {0} -> {1}' -f $_.DisplayName, $_.UninstallString) } }

Write-Host ''
Write-Host '== 7. hosts / 代理兜底 =='
$hLine = Select-String -Path (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts') -Pattern $promoRe -ErrorAction SilentlyContinue
if ($hLine) { Hit ('hosts 存在劫持条目: ' + (($hLine | ForEach-Object { $_.Line }) -join '; ')) } else { Ok 'hosts 干净' }
$px = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
if ($px.ProxyEnable -eq 1 -and $px.ProxyServer -match $promoRe) { Hit ('代理指向劫持域: ' + $px.ProxyServer) } else { Ok '代理未见劫持指向' }

Write-Host ''
if ($script:hits -gt 0) {
    Write-Host ("共 {0} 处命中。取证（INI 内容/任务 XML/签名）→ 按 SKILL.md 清理顺序处理；卸载前征得用户同意。" -f $script:hits) -ForegroundColor Red
    exit 1
} else {
    Write-Host '未发现劫持特征。' -ForegroundColor Green
    exit 0
}
