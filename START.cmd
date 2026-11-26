@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Practice.ps1"
if errorlevel 1 pause
start "" "http://127.0.0.1:8088/"
