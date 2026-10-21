@echo off
rem Update this repo from GitHub and copy the addon into the WoW: Forever beta client.
rem Run it from anywhere (or double-click it), then restart the client, or /reload if Ticky
rem was already loaded. It only pulls what's on GitHub: push your commits first.
setlocal
set "REPO=C:\Users\addohm\Documents\_Code Projects\ticky-timers"
set "ADDON=C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\Ticky"

git -C "%REPO%" pull --ff-only
if errorlevel 1 (
  echo git pull failed, so nothing was copied.
  set "RESULT=1"
  goto done
)

rem /MIR makes the installed folder an exact copy (files no longer in the repo are deleted).
robocopy "%REPO%\Ticky" "%ADDON%" /MIR /IS /IT /XF CLAUDE.md
rem robocopy exit codes below 8 mean success.
if errorlevel 8 (
  echo Copy failed. Is the WoW folder writable, and the path above right?
  set "RESULT=1"
  goto done
)
rem Stamp the installed copy with the commit, so /ticky debug shows which build is running.
for /f %%h in ('git -C "%REPO%" rev-parse --short HEAD') do set "BUILD=%%h"
> "%ADDON%\Build.lua" (
  echo local ADDON, ns = ...
  echo ns.Build = "%BUILD%"
)
echo Installed Ticky build %BUILD% into %ADDON%
echo In game: /reload, then /ticky debug should say build %BUILD%.
set "RESULT=0"

:done
rem Keep the window open when started by double-click.
echo %cmdcmdline% | find /i "%~nx0" >nul && pause
exit /b %RESULT%
