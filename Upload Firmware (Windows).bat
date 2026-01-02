@echo off
REM =====================================================
REM  SledLink Firmware Upload Tool - Windows Launcher
REM  Double-click this file to start the upload process
REM =====================================================

echo.
echo ============================================
echo   SledLink Firmware Upload Tool
echo ============================================
echo.
echo Starting the firmware upload wizard...
echo.

REM Change to the directory where this script is located
cd /d "%~dp0"

REM Check if we're in a release package (tools subdirectory exists) or local repo
if exist "%~dp0tools\upload_firmware.ps1" (
    REM Release package structure
    PowerShell -ExecutionPolicy Bypass -File "%~dp0tools\upload_firmware.ps1"
) else if exist "%~dp0upload_firmware.ps1" (
    REM Local repository structure
    PowerShell -ExecutionPolicy Bypass -File "%~dp0upload_firmware.ps1"
) else (
    echo.
    echo ============================================
    echo   ERROR: upload_firmware.ps1 not found!
    echo ============================================
    echo.
    echo Could not find the PowerShell script in:
    echo   - %~dp0tools\upload_firmware.ps1 (release package)
    echo   - %~dp0upload_firmware.ps1 (local repo)
    echo.
    echo Make sure you're running this from the correct directory.
    echo.
    pause
    exit /b 1
)

REM If PowerShell failed, show error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================
    echo   There was a problem running the script
    echo ============================================
    echo.
    echo If you see a security error, try:
    echo   1. Right-click this file
    echo   2. Select "Run as administrator"
    echo.
    pause
)
