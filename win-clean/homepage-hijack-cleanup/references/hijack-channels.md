# 劫持通道判定手册（每条含实测命令）

> 通用流程与清理顺序见 SKILL.md。所有命令只读，可直接照抄。
> 劫持站正则（按需扩充）：`hao\.360\.com|hao123|2345\.com|so\.com|dhres|daohang`
> 跳转域特征：`go\.<域名>/go/<渠道码>`（本次实测 `go.huanyuroad.cn/go/aV3aJ5mN`，302 落地 `hao.360.com?src=lm&ls=<码>`）。

## 1. Chrome 配置篡改（最常见）

Preferences 约 20MB 且含大量 null/二进制，**用 json 解析取键，不要裸 grep**。

```bash
python -c "
import json, os
base = os.path.expandvars(r'%LOCALAPPDATA%\Google\Chrome\User Data\Default')
for fn in ['Preferences', 'Secure Preferences']:
    d = json.load(open(os.path.join(base, fn), encoding='utf-8'))
    print(fn)
    print('  homepage:', d.get('homepage'))
    print('  restore_on_startup:', d.get('session', {}).get('restore_on_startup'))  # 4=打开特定网页
    print('  startup_urls:', d.get('session', {}).get('startup_urls'))
    dsp = d.get('default_search_provider_data', {}).get('template_url_data', {})
    print('  default_search:', dsp.get('short_name'), dsp.get('url'))
    print('  extensions:', len(d.get('extensions', {}).get('settings', {})))
"
```

实测要点：

- **权威存储是 `Secure Preferences`**（受 HMAC 保护），`Preferences` 里 startup_urls 为 None 不代表干净。
- `restore_on_startup` 取值：4=打开特定网页（劫持常用）、1=恢复上次会话、5=新标签页。
- 搜索引擎与启动页是**两个独立设置**：实测搜索仍是 Bing、只有启动页被改。
- 多 profile 机器要遍历 User Data 下所有含 Preferences 的目录。

**修复**：chrome://settings/onStartup 改启动页、chrome://settings/search 改搜索引擎。改完等 5 秒读回 `Secure Preferences` 确认落盘。

## 2. 启动注入（拉起带参浏览器）

```powershell
Get-CimInstance Win32_Process -Filter "name='chrome.exe'" |
  Where-Object { $_.CommandLine -match 'https?://' -and $_.CommandLine -notmatch '--type=' } |
  ForEach-Object { '{0} PID={1} parent={2}' -f $_.CommandLine, $_.ProcessId, $_.ParentProcessId }
```

实测要点：

- 主进程命令行 = `chrome.exe https://go.huanyuroad.cn/go/aV3aJ5mN`，落地 360导航——**这就是"明明设置改回来了还是 360"的真相**。
- 父进程查询（`Win32_Process -Filter "ProcessId=<parent>"`）显示 explorer.exe 时，是 ShellExecute 代理**不是真凶**；但可做 PID 存活时间校验：父进程 CreationDate 早于子进程且未重启，则确为 explorer 直接拉起（用户点击或代理打开）。
- 真凶定位靠**时间相关性**：数据 INI 的 LastWriteTime ≈ 开机时刻 + 几分钟 → 查该时刻启动的自启项（见第 6 节）。

## 3. 快捷方式改参（经典通道，必须排查）

```powershell
$sh = New-Object -ComObject WScript.Shell
$paths = @([Environment]::GetFolderPath('Desktop'),
  [Environment]::GetFolderPath('CommonDesktopDirectory'),
  [Environment]::GetFolderPath('StartMenu'),
  [Environment]::GetFolderPath('CommonStartMenu'),
  "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch")   # 递归含 User Pinned\TaskBar
foreach ($p in $paths) {
  Get-ChildItem $p -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $lnk = $sh.CreateShortcut($_.FullName)
    if ($lnk.Arguments) { '{0}  Target={1}  Args=[{2}]' -f $_.FullName, $lnk.TargetPath, $lnk.Arguments }
  }
}
```

实测要点：本例全部干净——**快捷方式干净 ≠ 没有劫持**，别在这里止步。桌面 `.url` 文件一并看一眼。

## 4. 策略锁 / IFEO

```powershell
# 策略（三处都查）
reg query "HKCU\SOFTWARE\Policies\Google\Chrome" /s
reg query "HKLM\SOFTWARE\Policies\Google\Chrome" /s
reg query "HKLM\SOFTWARE\WOW6432Node\Policies\Google\Chrome" /s
# IFEO Debugger 劫持
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\chrome.exe"
reg query "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\chrome.exe"
```

实测：本例均为空。策略命中时删对应键值即可（需管理员）。

## 5. 恶意扩展

Preferences 的 `extensions.settings` 计数 + chrome://extensions 人工过一遍。实测本例为 0。

## 6. 持久化宿主四查 + 时间相关性

```powershell
# 计划任务：只看近 2 天真跑过的，[Running] 状态重点怀疑
Get-ScheduledTask | ForEach-Object {
  $i = $_ | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
  if ($i -and $i.LastRunTime -gt (Get-Date).AddDays(-2)) {
    '{0} [{1}] {2} -> {3}' -f $i.LastRunTime, $_.State, $_.TaskName, ($_ .Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments })
  }
}
# Run 键
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
# 服务（含驱动）：安装路径反查
Get-CimInstance Win32_Service | Where-Object { $_.PathName -match '<嫌疑词>' }
reg query HKLM\SYSTEM\CurrentControlSet\Services /f <嫌疑词> /k
# 卸载表反查身份（三处）
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
  Where-Object { $_.InstallLocation -match '<安装目录名>' } |
  ForEach-Object { '{0} -> {1}' -f $_.DisplayName, $_.UninstallString }
```

实测要点：`Get-ScheduledTaskInfo` 的 LastRunTime 是定位真凶的钥匙（开机 08:33 → 劫持 INI 08:36）。

## 7. hosts / 代理兜底（低概率）

```powershell
Select-String -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Pattern 'hao\.360|2345|hao123'
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable, ProxyServer
```

## 8. 抓现行的两种运行时手段（静态定位失败时用）

- **Procmon**：`procmon /Quiet /Minimized /BackingFile log.pml` 挂后台，等复发后停止，Filter → Path contains `LockHomePage.ini`，直接看到写入进程。
- **SACL 审计**（原生，出 Event 4663 带进程名）：`auditpol /set /subcategory:"File System" /success:enable` + 对文件加 FileSystemAuditRule（Everyone / Modify / Success），事件查看器 Security 日志看 4663。需管理员。
