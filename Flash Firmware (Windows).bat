@echo off
REM =====================================================
REM  SledLink Firmware Flash Tool - Windows Launcher
REM  Double-click this file to flash pre-compiled firmware
REM =====================================================

echo.
echo ============================================
echo   SledLink Firmware Flash Tool
echo   (Pre-compiled firmware)
echo ============================================
echo.
echo Starting the firmware flash wizard...
echo.

REM Change to the directory where this script is located
cd /d "%~dp0"

REM Check if we're in the release folder (firmware subfolder exists)
if exist "%~dp0firmware" (
    REM We're in the release package
    PowerShell -ExecutionPolicy Bypass -File "%~dp0flash_firmware.ps1"
) else if exist "%~dp0tools\flash_firmware.ps1" (
    REM Try tools subfolder
    PowerShell -ExecutionPolicy Bypass -File "%~dp0tools\flash_firmware.ps1"
) else (
    echo.
    echo ERROR: flash_firmware.ps1 not found!
    echo.
    echo This script should be run from a SledLink release package
    echo that contains the firmware folder with pre-compiled binaries.
    echo.
    echo If you want to compile from source instead, use:
    echo   "Upload Firmware (Windows).bat"
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
