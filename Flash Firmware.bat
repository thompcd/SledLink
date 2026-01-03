@echo off
REM =====================================================
REM  SledLink Quick Flash Tool - Windows Launcher
REM  Flash pre-compiled firmware - no compilation!
REM =====================================================

setlocal enabledelayedexpansion

echo.
echo ============================================
echo   SledLink Quick Flash Tool
echo   Pre-compiled firmware ready to flash
echo ============================================
echo.

REM Change to the script directory
cd /d "%~dp0"

REM Check for flash script
if exist "%~dp0flash_firmware.ps1" (
    echo Launching flash tool...
    echo.
    PowerShell -ExecutionPolicy Bypass -File "%~dp0flash_firmware.ps1"
) else (
    if exist "%~dp0tools\flash_firmware.ps1" (
        echo Launching flash tool...
        echo.
        PowerShell -ExecutionPolicy Bypass -File "%~dp0tools\flash_firmware.ps1"
    ) else (
        echo.
        echo ERROR: flash_firmware.ps1 not found!
        echo.
        echo Make sure you extracted the entire release ZIP file with
        echo all directories and files intact.
        echo.
        echo The flash script should be at:
        echo   - flash_firmware.ps1 (in release root), or
        echo   - tools\flash_firmware.ps1 (in release tools folder)
        echo.
        pause
        exit /b 1
    )
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================
    echo   Flash tool exited with an error
    echo ============================================
    echo.
)

endlocal
