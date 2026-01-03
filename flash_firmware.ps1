#
# SledLink Quick Flash Script for Windows
# Flashes pre-compiled firmware - no compilation required!
#

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Detect firmware directory location
# Release package root: firmware/ directory at same level as script
# Release package tools/: firmware/ directory at parent level
# Repo: firmware_binaries/ directory at root

if (Test-Path (Join-Path $ScriptDir "firmware")) {
    # Script is at release root
    $FirmwareDir = Join-Path $ScriptDir "firmware"
} elseif (Test-Path (Join-Path $ScriptDir ".." "firmware")) {
    # Script is in tools/ subdirectory
    $FirmwareDir = Join-Path (Split-Path -Parent $ScriptDir) "firmware"
} elseif (Test-Path (Join-Path $ScriptDir "firmware_binaries")) {
    # Development mode - use compiled binaries directly
    $FirmwareDir = Join-Path $ScriptDir "firmware_binaries"
} else {
    Write-Host ""
    Write-Host "ERROR: Firmware directory not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script should be run from the SledLink release package." -ForegroundColor Yellow
    Write-Host "Make sure you extracted the entire ZIP file with all directories." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Find esptool.exe
$EsptoolPath = Join-Path $FirmwareDir "tools" "esptool.exe"
if (-not (Test-Path $EsptoolPath)) {
    # Try alternative location in release package
    $EsptoolPath = Join-Path (Split-Path -Parent $FirmwareDir) "firmware" "tools" "esptool.exe"
}

#############################################################################
# Helper Functions
#############################################################################

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        SledLink Quick Flash Tool" -ForegroundColor White
    Write-Host "        Pre-Compiled Firmware (No Compilation Required)" -ForegroundColor Gray
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Get-SerialPorts {
    # Get COM ports using .NET which is most reliable
    $ports = @()

    try {
        # Get all available COM ports
        $comPorts = [System.IO.Ports.SerialPort]::GetPortNames()

        if ($comPorts -and $comPorts.Count -gt 0) {
            # Try to get friendly names from WMI
            try {
                $devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.Name -match "COM\d+" }
                $deviceMap = @{}
                foreach ($device in $devices) {
                    if ($device.Name -match "(COM\d+)") {
                        $deviceMap[$Matches[1]] = $device.Name
                    }
                }
            } catch {
                $deviceMap = @{}
            }

            # Create port objects with both Port and Name
            foreach ($comPort in $comPorts) {
                $displayName = if ($deviceMap.ContainsKey($comPort)) {
                    $deviceMap[$comPort]
                } else {
                    $comPort
                }

                $ports += @{
                    Port = $comPort
                    Name = $displayName
                }
            }
        }
    } catch {}

    # If no ports found, try WMI as fallback
    if ($ports.Count -eq 0) {
        try {
            $devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.Name -match "COM\d+" }
            foreach ($device in $devices) {
                if ($device.Name -match "(COM\d+)") {
                    $ports += @{
                        Port = $Matches[1]
                        Name = $device.Name
                    }
                }
            }
        } catch {}
    }

    return , $ports
}

function Select-Controller {
    Write-Host "Which controller do you want to flash?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) SLED Controller" -ForegroundColor White
    Write-Host "     - Goes on the sled with the measuring wheel" -ForegroundColor Gray
    Write-Host "     - Has the encoder connected" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2) JUDGE Controller" -ForegroundColor White
    Write-Host "     - Stays at the judge's table" -ForegroundColor Gray
    Write-Host "     - Displays distance measurements" -ForegroundColor Gray
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Select controller (1 or 2)"

        switch ($choice) {
            "1" { return "SledController" }
            "2" { return "JudgeController" }
            default {
                Write-Host "Please enter 1 or 2" -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
}

function Select-Port {
    Write-Host ""
    Write-Host "Connecting to device..." -ForegroundColor Cyan
    Write-Host "Make sure your controller is connected via USB." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press ENTER to scan for devices..."
    $null = Read-Host

    Write-Host "Scanning for USB devices..." -ForegroundColor Cyan

    $ports = Get-SerialPorts

    if ($ports.Count -eq 0) {
        Write-Host ""
        Write-Error-Custom "ERROR: No USB devices found!"
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Try a different USB cable (some are charge-only)" -ForegroundColor Yellow
        Write-Host "  2. Try a different USB port on your computer" -ForegroundColor Yellow
        Write-Host "  3. Wait a few seconds and try again" -ForegroundColor Yellow
        Write-Host "  4. Install USB drivers (CP210x or CH340)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "For more help, see UPLOAD_GUIDE.md in the release package." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    if ($ports.Count -eq 1) {
        $port = $ports[0].Port
        Write-Success "✓ Found device on $port"
        return $port
    }

    # Multiple ports - let user choose
    Write-Host ""
    Write-Host "Multiple devices found:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ports.Count; $i++) {
        Write-Host "  $($i+1)) $($ports[$i].Port) - $($ports[$i].Name)" -ForegroundColor White
    }
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Select device (1-$($ports.Count))"

        if ($choice -ge 1 -and $choice -le $ports.Count) {
            $port = $ports[$choice - 1].Port
            Write-Success "✓ Selected $port"
            return $port
        } else {
            Write-Host "Please enter a number between 1 and $($ports.Count)" -ForegroundColor Yellow
        }
    }
}

function Flash-Firmware {
    param(
        [string]$Controller,
        [string]$Port
    )

    $controllerDir = Join-Path $FirmwareDir $Controller
    $appBin = Join-Path $controllerDir "firmware.bin"
    $bootBin = Join-Path $controllerDir "bootloader.bin"
    $partBin = Join-Path $controllerDir "partitions.bin"

    # Verify firmware files exist
    if (-not (Test-Path $appBin)) {
        Write-Host ""
        Write-Error-Custom "ERROR: Firmware file not found!"
        Write-Host "Expected: $appBin" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The release package may be incomplete. Re-download from:" -ForegroundColor Yellow
        Write-Host "https://github.com/thompcd/SledLink/releases" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    if (-not (Test-Path $EsptoolPath)) {
        Write-Host ""
        Write-Error-Custom "ERROR: esptool.exe not found!"
        Write-Host "Expected: $EsptoolPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The release package may be incomplete. Make sure you extracted" -ForegroundColor Yellow
        Write-Host "the entire ZIP file with all directories." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    # Show confirmation
    Write-Host ""
    Write-Host "Ready to flash:" -ForegroundColor Cyan
    Write-Host "  Controller: $Controller" -ForegroundColor White
    Write-Host "  Port:       $Port" -ForegroundColor White
    Write-Host "  Firmware:   $appBin" -ForegroundColor Gray
    Write-Host ""
    Write-Host "DO NOT disconnect the USB cable during flashing!" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (yes/no)"
    if ($confirm -ne "yes" -and $confirm -ne "y") {
        Write-Host ""
        Write-Host "Flash cancelled." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }

    # Flash the firmware
    Write-Host ""
    Write-Host "Flashing firmware..." -ForegroundColor Cyan
    Write-Host "This may take 10-30 seconds..." -ForegroundColor Gray
    Write-Host ""

    try {
        # Build esptool command
        $esptoolArgs = @(
            "--chip", "esp32",
            "--port", $Port,
            "--baud", "460800",
            "--before", "default_reset",
            "--after", "hard_reset",
            "write_flash",
            "-z",
            "--flash_mode", "dio",
            "--flash_freq", "40m",
            "--flash_size", "detect",
            "0x1000", $bootBin,
            "0x8000", $partBin,
            "0x10000", $appBin
        )

        # Execute esptool
        & $EsptoolPath $esptoolArgs
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  FLASH SUCCESSFUL!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Your controller will restart automatically." -ForegroundColor White
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "  1. The controller should boot up in a few seconds" -ForegroundColor White
            Write-Host "  2. The LCD display should show SledLink" -ForegroundColor White
            Write-Host "  3. Your system is ready to use!" -ForegroundColor White
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } else {
            Write-Host ""
            Write-Error-Custom "Flash failed! (Exit code: $exitCode)"
            Write-Host ""
            Write-Host "Troubleshooting:" -ForegroundColor Yellow
            Write-Host "  1. Hold the BOOT button on the ESP32 while flashing" -ForegroundColor Yellow
            Write-Host "  2. Try a different USB cable (charge-only cables won't work)" -ForegroundColor Yellow
            Write-Host "  3. Try a different USB port" -ForegroundColor Yellow
            Write-Host "  4. Close other programs using the serial port" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "For more help, see UPLOAD_GUIDE.md in the release package." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    } catch {
        Write-Host ""
        Write-Error-Custom "Error during flashing: $_"
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

#############################################################################
# Main Script
#############################################################################

Write-Header

Write-Host "This tool flashes pre-compiled firmware to your SledLink controller." -ForegroundColor White
Write-Host "Flashing takes about 10 seconds - no compilation needed!" -ForegroundColor White
Write-Host ""

# Step 1: Select controller
$controller = Select-Controller

# Step 2: Select port
$port = Select-Port

# Step 3: Flash firmware
Flash-Firmware -Controller $controller -Port $port
