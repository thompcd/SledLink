#
# SledLink Firmware Flash Script for Windows
# Flashes pre-compiled firmware using esptool
#

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FirmwareDir = Join-Path $ScriptDir "firmware"

$script:Esptool = ""
$script:SelectedPort = ""
$script:SelectedController = ""

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        SledLink Firmware Flash Tool for Windows" -ForegroundColor White
    Write-Host "        Flash Pre-Compiled Firmware" -ForegroundColor Gray
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Esptool {
    # Check if esptool is in PATH
    $esptoolExe = Get-Command "esptool" -ErrorAction SilentlyContinue
    if ($esptoolExe) {
        $script:Esptool = "esptool"
        return $true
    }

    $esptoolPy = Get-Command "esptool.py" -ErrorAction SilentlyContinue
    if ($esptoolPy) {
        $script:Esptool = "esptool.py"
        return $true
    }

    # Try Python module
    try {
        $result = & python -m esptool version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:Esptool = "python -m esptool"
            return $true
        }
    } catch {}

    try {
        $result = & python3 -m esptool version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:Esptool = "python3 -m esptool"
            return $true
        }
    } catch {}

    return $false
}

function Install-Esptool {
    Write-Host "esptool is not installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "esptool is required to flash pre-compiled firmware."
    Write-Host ""

    $hasPip = Get-Command "pip" -ErrorAction SilentlyContinue
    if (-not $hasPip) {
        $hasPip = Get-Command "pip3" -ErrorAction SilentlyContinue
    }

    if ($hasPip) {
        $response = Read-Host "Install esptool now? (yes/no)"
        if ($response -match "^[Yy]") {
            Write-Host ""
            Write-Host "Installing esptool..." -ForegroundColor Cyan
            & pip install esptool
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
    } else {
        Write-Host "Python is required to install esptool." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Install Python from: https://www.python.org/downloads/" -ForegroundColor Cyan
        Write-Host "Make sure to check 'Add Python to PATH' during installation!"
        Write-Host ""
        Write-Host "After installing Python, run: pip install esptool"
    }
    return $false
}

function Get-SerialPorts {
    $ports = @()
    try {
        $usbPorts = Get-WmiObject Win32_PnPEntity | Where-Object {
            $_.Name -match "COM\d+" -and (
                $_.Name -match "USB" -or
                $_.Name -match "Serial" -or
                $_.Name -match "CH340" -or
                $_.Name -match "CP210" -or
                $_.Name -match "FTDI" -or
                $_.Name -match "Silicon Labs"
            )
        }
        foreach ($port in $usbPorts) {
            if ($port.Name -match "(COM\d+)") {
                $ports += @{
                    Port = $Matches[1]
                    Name = $port.Name
                }
            }
        }
    } catch {}

    if ($ports.Count -eq 0) {
        try {
            $comPorts = [System.IO.Ports.SerialPort]::GetPortNames()
            foreach ($port in $comPorts) {
                $ports += @{
                    Port = $port
                    Name = $port
                }
            }
        } catch {}
    }
    return $ports
}

function Select-Controller {
    Write-Host "Which controller do you want to flash?" -ForegroundColor White
    Write-Host ""
    Write-Host "  1) SLED Controller - goes on the sled, has encoder" -ForegroundColor Gray
    Write-Host "  2) JUDGE Controller - judge's table display" -ForegroundColor Gray
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Enter 1 or 2"
        switch ($choice) {
            "1" {
                $script:SelectedController = "SledController"
                Write-Host "[OK] Selected: SLED Controller" -ForegroundColor Green
                return
            }
            "2" {
                $script:SelectedController = "JudgeController"
                Write-Host "[OK] Selected: JUDGE Controller" -ForegroundColor Green
                return
            }
            default {
                Write-Host "Please enter 1 or 2" -ForegroundColor Red
            }
        }
    }
}

function Select-Port {
    Write-Host ""
    Write-Host "Connect the controller via USB, then press ENTER" -ForegroundColor Yellow
    Read-Host

    Write-Host "Scanning for devices..." -ForegroundColor Cyan
    $ports = Get-SerialPorts

    if ($ports.Count -eq 0) {
        Write-Host "[X] No serial devices found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Try:" -ForegroundColor Yellow
        Write-Host "  - Different USB cable (some are charge-only)"
        Write-Host "  - Different USB port"
        Write-Host "  - Install USB driver (CP210x or CH340)"
        return $false
    }

    if ($ports.Count -eq 1) {
        $script:SelectedPort = $ports[0].Port
        Write-Host "[OK] Found: $($ports[0].Name)" -ForegroundColor Green
    } else {
        Write-Host "Multiple devices found:" -ForegroundColor White
        for ($i = 0; $i -lt $ports.Count; $i++) {
            Write-Host "  $($i + 1)) $($ports[$i].Name)"
        }
        while ($true) {
            $choice = Read-Host "Select device (1-$($ports.Count))"
            $choiceNum = 0
            if ([int]::TryParse($choice, [ref]$choiceNum) -and $choiceNum -ge 1 -and $choiceNum -le $ports.Count) {
                $script:SelectedPort = $ports[$choiceNum - 1].Port
                Write-Host "[OK] Selected: $($ports[$choiceNum - 1].Name)" -ForegroundColor Green
                break
            } else {
                Write-Host "Please enter a number between 1 and $($ports.Count)" -ForegroundColor Red
            }
        }
    }
    return $true
}

function Flash-Firmware {
    $firmwarePath = Join-Path $FirmwareDir "$($script:SelectedController).bin"
    $bootloaderPath = Join-Path $FirmwareDir "$($script:SelectedController).bootloader.bin"
    $partitionsPath = Join-Path $FirmwareDir "$($script:SelectedController).partitions.bin"

    if (-not (Test-Path $firmwarePath)) {
        Write-Host "[X] Firmware file not found: $firmwarePath" -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "Ready to flash:" -ForegroundColor White
    Write-Host "  Controller: $($script:SelectedController)"
    Write-Host "  Port: $($script:SelectedPort)"
    Write-Host "  Firmware: $firmwarePath"
    Write-Host ""
    Write-Host "Do NOT disconnect during flash!" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Start flash? (yes/no)"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return $false
    }

    Write-Host ""
    Write-Host "Flashing firmware..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # Build the esptool command
        $esptoolArgs = @(
            "--chip", "esp32",
            "--port", $script:SelectedPort,
            "--baud", "460800",
            "--before", "default_reset",
            "--after", "hard_reset",
            "write_flash", "-z",
            "--flash_mode", "dio",
            "--flash_freq", "40m",
            "--flash_size", "detect",
            "0x1000", $bootloaderPath,
            "0x8000", $partitionsPath,
            "0x10000", $firmwarePath
        )

        if ($script:Esptool -match "python") {
            # It's a Python module call
            $parts = $script:Esptool -split " "
            $python = $parts[0]
            & $python -m esptool @esptoolArgs
        } else {
            & $script:Esptool @esptoolArgs
        }

        if ($LASTEXITCODE -ne 0) {
            throw "esptool returned error code $LASTEXITCODE"
        }

        Write-Host ""
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "  FIRMWARE FLASH COMPLETE!" -ForegroundColor Green
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "The controller will restart automatically."
        return $true
    }
    catch {
        Write-Host "[X] Flash failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Try:" -ForegroundColor Yellow
        Write-Host "  - Hold the BOOT button on the ESP32 while flashing"
        Write-Host "  - Unplug and replug the USB cable"
        Write-Host "  - Use a different USB port"
        return $false
    }
}

# Main
Write-Header

Write-Host "This tool flashes pre-compiled firmware to your SledLink controller."
Write-Host "No compilation needed - just select your controller type and port."
Write-Host ""
Write-Host "Press ENTER to continue..." -ForegroundColor Yellow
Read-Host

# Check for esptool
if (-not (Test-Esptool)) {
    if (-not (Install-Esptool)) {
        Write-Host "[X] Cannot continue without esptool." -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    if (-not (Test-Esptool)) {
        Write-Host "[X] esptool installation failed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

Write-Host "[OK] esptool found" -ForegroundColor Green
Write-Host ""

# Select controller
Select-Controller

# Select port
if (-not (Select-Port)) {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Flash
Flash-Firmware

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
