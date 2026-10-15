@echo off
if not exist "%~dp0BepInEx\LogOutput.log" (
 echo Log not found. Start the game once first.
 pause
 exit /b 1
)
start "" notepad.exe "%~dp0BepInEx\LogOutput.log"
