@echo off
setlocal
title Cap nhat link tai game
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\update-download-links.ps1"
set "update_exit_code=%errorlevel%"
echo.
pause
exit /b %update_exit_code%
