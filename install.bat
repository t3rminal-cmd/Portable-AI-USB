@echo off
setlocal
title Portable AI - Setup
color 0E

echo ===================================================
echo     PORTABLE AI - USB SETUP (Windows)
echo ===================================================
echo.
echo This downloads the AI engine, the chat app and the
echo AI model(s) you choose onto this drive.
echo.
echo  - Drive must be exFAT or NTFS (not FAT32)
echo  - Minimum free space: 16 GB (32 GB recommended)
echo  - Needs a good internet connection for setup only
echo.
pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-core.ps1"
set "RESULT=%ERRORLEVEL%"

echo.
if "%RESULT%"=="0" (
    echo ===================================================
    echo     SETUP COMPLETE - double-click start-windows.bat
    echo ===================================================
) else (
    echo ===================================================
    echo     SETUP DID NOT FINISH - see the messages above.
    echo     Run install.bat again to continue.
    echo ===================================================
)
echo.
pause
exit /b %RESULT%
