@echo off
rem ============================================================
rem mskill sync: junction this repo's skills into the host dir
rem   - scanned layers: meta\* and <domain>\* (dirs with SKILL.md)
rem   - vendor\ is NEVER linked (reference-only submodules)
rem   - junction needs no admin rights on Windows
rem usage: sync.cmd            link all (skip existing)
rem        sync.cmd --remove   remove junctions created by this repo
rem ============================================================
setlocal enabledelayedexpansion
set "DEST=C:\Users\Canrad\.agents\skills"
set "SRC=%~dp0"

if "%~1"=="--remove" goto :remove

if not exist "%DEST%" mkdir "%DEST%"

set LINKED=0
for /d %%d in ("%SRC%meta\*" "%SRC%stm32\*") do (
  if exist "%%~d\SKILL.md" (
    if exist "%DEST%\%%~nxd" (
      echo [skip] %%~nxd already exists
    ) else (
      mklink /J "%DEST%\%%~nxd" "%%~d" >nul 2>&1
      if errorlevel 1 (
        echo [FAIL] %%~nxd
      ) else (
        echo [link] %%~nxd --^> %%~d
        set /a LINKED+=1
      )
    )
  )
)
echo done, !LINKED! linked.
exit /b 0

:remove
for /d %%d in ("%SRC%meta\*" "%SRC%stm32\*") do (
  if exist "%%~d\SKILL.md" (
    fsutil reparsepoint query "%DEST%\%%~nxd" >nul 2>&1
    if not errorlevel 1 (
      rmdir "%DEST%\%%~nxd"
      echo [rm] %%~nxd
    )
  )
)
echo done.
exit /b 0
