@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0HomeButler-2.0.0-Package\Setup.ps1" -Action Install
set "result=%errorlevel%"
echo.
pause
exit /b %result%
