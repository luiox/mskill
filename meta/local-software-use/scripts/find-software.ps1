<#
.SYNOPSIS
  用 Everything CLI (es.exe) 快速定位本机已安装软件的可执行文件。

.DESCRIPTION
  读取 ../assets/software-map.json，把软件别名映射到 exe 名，调用 es 搜索并默认过滤
  Prefetch / WER / 回收站等噪音路径。查不到映射时按字面 exe/文件名搜索。
  仅在 PowerShell（powershell.exe / pwsh）下运行；不要用 cmd 或 Git Bash 调用。

.EXAMPLE
  pwsh -File find-software.ps1 uv
  pwsh -File find-software.ps1 java 7z -Top 5
  pwsh -File find-software.ps1 "my-tool.exe"   # 不在映射表时按字面名搜索
  pwsh -File find-software.ps1 node -Raw       # 不过滤噪音路径
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Name,
    [int]$Top = 10,
    [switch]$Raw
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------- 定位 es.exe ----------
$es = (Get-Command es -ErrorAction SilentlyContinue).Source
if (-not $es) { $es = Join-Path $env:LOCALAPPDATA 'Programs\es\es.exe' }
if (-not (Test-Path -LiteralPath $es)) {
    Write-Host "es.exe 未安装。请按 SKILL.md 安装：" -ForegroundColor Red
    Write-Host @"
从 https://www.voidtools.com/zh-cn/downloads/#cli 取最新 ES x64 zip（版本以下载页为准），
解压到 `$env:LOCALAPPDATA\Programs\es ，并把该目录加入用户 PATH。
Everything 本体也必须安装并运行。
"@
    exit 1
}
Write-Host "es: $es" -ForegroundColor DarkGray

# ---------- 确认 Everything 在运行（es 退出码 8 = IPC 窗口不存在） ----------
& $es -n 1 es.exe 2>$null | Out-Null
if ($LASTEXITCODE -eq 8) {
    Write-Host "Everything 未运行，尝试自动启动..." -ForegroundColor Yellow
    foreach ($p in @((Join-Path $env:ProgramFiles 'Everything\Everything.exe'),
                     (Join-Path ${env:ProgramFiles(x86)} 'Everything\Everything.exe'))) {
        if (Test-Path -LiteralPath $p) { Start-Process $p; Start-Sleep -Seconds 3; break }
    }
    & $es -n 1 es.exe 2>$null | Out-Null
    if ($LASTEXITCODE -eq 8) {
        Write-Host "Everything 仍未运行（es 退出码 8）。请手动启动 Everything 后重试。" -ForegroundColor Red
        exit 8
    }
}

# ---------- 加载映射表 ----------
$mapPath = Join-Path $PSScriptRoot '..\assets\software-map.json'
if (-not (Test-Path -LiteralPath $mapPath)) { Write-Error "找不到映射表: $mapPath"; exit 1 }
$map = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json

$excl = @()
if (-not $Raw) { $excl = @($map.noise_paths | ForEach-Object { "!path:$_" }) }

function Resolve-Tool([string]$q) {
    $ql = $q.ToLowerInvariant()
    foreach ($t in $map.tools) {
        if ($t.name -eq $ql) { return $t }
        if (@($t.aliases) -contains $ql) { return $t }
        foreach ($e in @($t.executables)) {
            if ($e.ToLowerInvariant() -eq $ql -or [IO.Path]::GetFileNameWithoutExtension($e).ToLowerInvariant() -eq $ql) { return $t }
        }
    }
    return $null
}

function Invoke-Es([string[]]$Terms) {
    # 搜索词必须逐个作为独立参数传给 es，不能拼成一个带空格的字符串；
    # -w 全词匹配，避免 cmake.exe 子串误中 bscmake.exe 这类假阳性
    $out = & $es -n $Top -w @Terms @excl 2>$null
    if ($LASTEXITCODE -eq 8) { Write-Host "  Everything 连接中断（退出码 8）" -ForegroundColor Red }
    return @($out | Where-Object { $_ })
}

$foundAny = $false

foreach ($q in $Name) {
    $builtin = @($map.builtin_windows_get_command_first)
    $ql = $q.ToLowerInvariant()
    if ($builtin -contains $ql -or $builtin -contains "$ql.exe") {
        Write-Host "`n===== $q =====" -ForegroundColor Cyan
        Write-Host "Windows 自带工具，不需要 es 搜索，直接 Get-Command：" -ForegroundColor Yellow
        $cmd = Get-Command $q -ErrorAction SilentlyContinue
        if ($cmd) { $cmd | Select-Object -ExpandProperty Source; $foundAny = $true }
        else { Write-Host "    (Get-Command 未命中)" -ForegroundColor DarkGray }
        continue
    }

    $tool = Resolve-Tool $q
    if ($tool) {
        Write-Host "`n===== $($tool.name)  (matched: $q → $($tool.executables -join ', ')) =====" -ForegroundColor Cyan
        foreach ($exe in @($tool.executables)) {
            $hits = Invoke-Es @($exe)
            Write-Host "  [$exe]" -ForegroundColor White
            if ($hits.Count) { $hits | ForEach-Object { Write-Host "    $_" }; $foundAny = $true }
            else { Write-Host "    (no results)" -ForegroundColor DarkGray }
        }
        $vArgs = @($tool.version_args) -join ' '
        $vNote = if ($tool.version_stderr) { "（输出在 stderr，需 2>&1 捕获）" } else { "" }
        if ($vArgs) { Write-Host "  验证版本: & `"<上面任一路径>`" $vArgs $vNote" -ForegroundColor DarkGray }
        if ($tool.notes) { Write-Host "  note: $($tool.notes)" -ForegroundColor DarkGray }
    }
    else {
        # 字面搜索：带扩展名按原样搜；不带则加 ext:exe 降噪
        Write-Host "`n===== (unmapped) $q =====" -ForegroundColor Cyan
        $terms = if ($q -like '*.*') { @($q) } else { @($q, 'ext:exe') }
        $hits = Invoke-Es $terms
        if ($hits.Count) { $hits | ForEach-Object { Write-Host "    $_" }; $foundAny = $true }
        else { Write-Host "    (no results) 可能未安装，或 exe 名与猜测不符；可对照 assets/software-map.json" -ForegroundColor DarkGray }
    }
}

exit $(if ($foundAny) { 0 } else { 2 })
