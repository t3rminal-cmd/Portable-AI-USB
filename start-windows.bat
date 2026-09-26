@echo off
setlocal
title Portable AI - Keep this window open while you chat
color 0A

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-core.ps1"
set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" (
    echo.
    echo Something went wrong - see the messages above.
    pause
    exit /b %RESULT%
)
timeout /t 3 >nul
exit /b 0
