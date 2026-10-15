@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0HomeButler-2.0.0-Package\Launch.ps1" -Action Launch
if errorlevel 1 pause
