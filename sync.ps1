#Requires -Version 5.1
<#
mskill sync: junction this repo's skills into the host skills dir
  scanned: every first-level dir (except vendor and dot-dirs), then any
  second-level dir containing SKILL.md counts as a skill
  opt-in: a domain dir containing a .nosync marker is NOT synced by default;
  install on demand with -Include <domain> (e.g. -Include win-clean)
  junction needs no admin rights; vendor/ is never linked
usage:
  powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1          link all default skills (skip existing)
  powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1 -List    show what would be linked
  powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1 -Include win-clean   also link opt-in domains
  powershell -ExecutionPolicy Bypass -NoProfile -File sync.ps1 -Remove  remove junctions pointing into this repo
#>
[CmdletBinding()]
param(
    [switch]$Remove,
    [switch]$List,
    [string[]]$Include = @(),
    [string]$Dest = (Join-Path $HOME '.agents\skills')
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

function Get-SkillDirs {
    Get-ChildItem -LiteralPath $Root -Directory -Force |
        Where-Object { $_.Name -ne 'vendor' -and -not $_.Name.StartsWith('.') } |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory -Force } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
        Where-Object {
            $domain = $_.Parent.Name
            -not (Test-Path -LiteralPath (Join-Path $_.Parent.FullName '.nosync')) -or
            $Include -contains $domain -or
            $Include -contains ($domain + '/' + $_.Name)
        }
}

function Test-OwnJunction($item) {
    ($item.LinkType -eq 'Junction') -and $item.Target -and
    ([string]$item.Target).StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)
}

if ($Remove) {
    if (-not (Test-Path -LiteralPath $Dest)) { Write-Host "dest not found, nothing to remove."; exit 0 }
    $removed = 0
    Get-ChildItem -LiteralPath $Dest -Force | Where-Object { Test-OwnJunction $_ } | ForEach-Object {
        $_.Delete()
        Write-Host "[rm] $($_.Name)"
        $removed++
    }
    Write-Host "done, $removed removed."
    exit 0
}

if (-not (Test-Path -LiteralPath $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

$linked = 0
foreach ($skill in Get-SkillDirs) {
    $link = Join-Path $Dest $skill.Name
    if (Test-Path -LiteralPath $link) {
        $item = Get-Item -Force -LiteralPath $link
        if (Test-OwnJunction $item) {
            Write-Host "[skip] $($skill.Name) already linked"
        } else {
            Write-Warning "[skip] $($skill.Name) exists at dest and is not this repo's junction"
        }
    } elseif ($List) {
        Write-Host "[will link] $($skill.Name) -> $($skill.FullName)"
    } else {
        New-Item -ItemType Junction -Path $link -Value $skill.FullName | Out-Null
        Write-Host "[link] $($skill.Name) -> $($skill.FullName)"
        $linked++
    }
}
if ($List) { Write-Host "done (list only)." } else { Write-Host "done, $linked linked." }
