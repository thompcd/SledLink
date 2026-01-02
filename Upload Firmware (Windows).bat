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

REM Run the PowerShell script with bypass execution policy
PowerShell -ExecutionPolicy Bypass -File "%~dp0upload_firmware.ps1"

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
