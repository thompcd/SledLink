#
# SledLink Firmware Upload Script for Windows
# This script guides non-technical users through uploading firmware
# to the SledLink Judge or Sled Controller.
#

# Ensure we stop on errors
$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# The Arduino source is in the source/ folder at the release root
# Script is in tools/, so go up one level and into source/
$ReleaseRoot = Split-Path -Parent $ScriptDir
$ArduinoDir = Join-Path (Join-Path $ReleaseRoot "source") "arduino"

# Global variables
$script:SelectedPort = ""
$script:SelectedController = ""
$script:ArduinoCli = ""

#############################################################################
# Helper Functions
#############################################################################

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        SledLink Firmware Upload Tool for Windows" -ForegroundColor White
    Write-Host "        For Tractor Pull Distance Measurement" -ForegroundColor Gray
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Blue
    Write-Host $Text -ForegroundColor White
    Write-Host "----------------------------------------------------------------" -ForegroundColor Blue
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "[X] $Text" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Text)
    Write-Host ">>> $Text" -ForegroundColor Cyan
}

function Wait-ForEnter {
    Write-Host ""
    Write-Host "Press ENTER to continue..." -ForegroundColor Yellow
    Read-Host
}

function Ask-YesNo {
    param([string]$Prompt)
    while ($true) {
        $response = Read-Host "$Prompt (yes/no)"
        switch -Regex ($response) {
            "^[Yy](es)?$" { return $true }
            "^[Nn]o?$" { return $false }
            default { Write-Host "Please type 'yes' or 'no'" }
        }
    }
}

#############################################################################
# Arduino CLI Installation
#############################################################################

function Test-ArduinoCli {
    Write-Step "Step 1: Checking for Arduino CLI"

    # Check if arduino-cli is in PATH
    $cli = Get-Command "arduino-cli" -ErrorAction SilentlyContinue
    if ($cli) {
        $script:ArduinoCli = $cli.Source
        Write-Success "Arduino CLI found: $($script:ArduinoCli)"
        return $true
    }

    # Check common installation locations
    $commonPaths = @(
        "$env:LOCALAPPDATA\Arduino15\arduino-cli.exe",
        "$env:USERPROFILE\bin\arduino-cli.exe",
        "$env:USERPROFILE\arduino-cli\arduino-cli.exe",
        "C:\Program Files\Arduino CLI\arduino-cli.exe",
        "C:\arduino-cli\arduino-cli.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $script:ArduinoCli = $path
            Write-Success "Arduino CLI found: $path"
            return $true
        }
    }

    Write-Warning-Custom "Arduino CLI is not installed."
    Write-Host ""
    return $false
}

function Install-ArduinoCli {
    Write-Step "Installing Arduino CLI"

    Write-Host "Arduino CLI is the tool that uploads firmware to the controller."
    Write-Host "We need to install it on your computer."
    Write-Host ""

    if (-not (Ask-YesNo "Would you like to download and install Arduino CLI?")) {
        return $false
    }

    Write-Host ""
    Write-Info "Downloading Arduino CLI..."

    # Create installation directory
    $installDir = "$env:USERPROFILE\arduino-cli"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir | Out-Null
    }

    $zipPath = "$env:TEMP\arduino-cli.zip"
    $downloadUrl = "https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip"

    try {
        # Download the CLI
        Write-Info "Downloading from Arduino..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

        # Extract the ZIP
        Write-Info "Extracting files..."
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

        # Clean up
        Remove-Item $zipPath -ErrorAction SilentlyContinue

        $script:ArduinoCli = Join-Path $installDir "arduino-cli.exe"

        if (Test-Path $script:ArduinoCli) {
            Write-Success "Arduino CLI installed to: $installDir"
            Write-Host ""
            Write-Warning-Custom "Note: You may want to add $installDir to your PATH"
            Write-Warning-Custom "      for easier use in the future."
            return $true
        } else {
            Write-Error-Custom "Installation completed but arduino-cli.exe not found"
            return $false
        }
    }
    catch {
        Write-Error-Custom "Download failed: $_"
        Write-Host ""
        Write-Host "You can install Arduino CLI manually from:" -ForegroundColor Yellow
        Write-Host "https://arduino.github.io/arduino-cli/installation/" -ForegroundColor Cyan
        return $false
    }
}

function Setup-ArduinoCli {
    Write-Step "Step 2: Setting up Arduino CLI for ESP32"

    Write-Host "Checking if ESP32 board support is installed..."
    Write-Host ""

    try {
        # Initialize config if needed
        $configPath = "$env:LOCALAPPDATA\Arduino15\arduino-cli.yaml"
        if (-not (Test-Path $configPath)) {
            Write-Info "Initializing Arduino CLI configuration..."
            & $script:ArduinoCli config init 2>$null
        }

        # Check if ESP32 URL is already added
        $configOutput = & $script:ArduinoCli config dump 2>&1 | Out-String
        if ($configOutput -notmatch "espressif") {
            Write-Info "Adding ESP32 board support URL..."
            & $script:ArduinoCli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
        }

        # Check if ESP32 core is installed
        $coreList = & $script:ArduinoCli core list 2>&1 | Out-String
        if ($coreList -notmatch "esp32:esp32") {
            Write-Info "Installing ESP32 board support (this may take several minutes)..."
            Write-Host ""
            Write-Host "Please wait - downloading ESP32 tools and libraries..." -ForegroundColor Yellow
            & $script:ArduinoCli core update-index
            & $script:ArduinoCli core install esp32:esp32
            Write-Success "ESP32 board support installed!"
        } else {
            Write-Success "ESP32 board support is already installed."
        }

        # Check if LiquidCrystal library is installed
        $libList = & $script:ArduinoCli lib list 2>&1 | Out-String
        if ($libList -notmatch "LiquidCrystal") {
            Write-Info "Installing LCD library..."
            & $script:ArduinoCli lib install "LiquidCrystal"
            Write-Success "LCD library installed!"
        } else {
            Write-Success "LCD library is already installed."
        }

        Write-Host ""
        Write-Success "Arduino CLI is fully configured!"
        return $true
    }
    catch {
        Write-Error-Custom "Setup failed: $_"
        return $false
    }
}

#############################################################################
# Controller Selection
#############################################################################

function Select-Controller {
    Write-Step "Step 3: Select Controller Type"

    Write-Host "Which controller do you want to upload firmware to?"
    Write-Host ""
    Write-Host "  1) SLED Controller" -ForegroundColor White
    Write-Host "     - This goes ON THE SLED" -ForegroundColor Gray
    Write-Host "     - Has the measuring wheel encoder attached" -ForegroundColor Gray
    Write-Host "     - Sends distance to the judge" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2) JUDGE Controller" -ForegroundColor White
    Write-Host "     - This stays at the JUDGE'S TABLE" -ForegroundColor Gray
    Write-Host "     - Receives and displays distance" -ForegroundColor Gray
    Write-Host "     - No encoder attached" -ForegroundColor Gray
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Enter 1 for SLED or 2 for JUDGE"
        switch ($choice) {
            "1" {
                $script:SelectedController = "SledController"
                Write-Success "Selected: SLED Controller"
                return
            }
            "2" {
                $script:SelectedController = "JudgeController"
                Write-Success "Selected: JUDGE Controller"
                return
            }
            default {
                Write-Error-Custom "Please enter 1 or 2"
            }
        }
    }
}

#############################################################################
# Port Detection
#############################################################################

function Get-SerialPorts {
    # Get COM ports from WMI
    $ports = @()

    # Method 1: Check for USB Serial devices
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

    # Method 2: Fallback to checking all COM ports
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

function Select-Port {
    Write-Step "Step 4: Connect the Controller"

    Write-Host "Now we need to connect to the controller."
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor White
    Write-Host "  1. Get a USB cable (micro-USB for most ESP32 boards)"
    Write-Host "  2. Plug one end into the controller board"
    Write-Host "  3. Plug the other end into this computer"
    Write-Host ""
    Write-Host "Windows Users:" -ForegroundColor Yellow
    Write-Host "  If this is your first time connecting an ESP32, Windows" -ForegroundColor Gray
    Write-Host "  may need to install a driver. This usually happens" -ForegroundColor Gray
    Write-Host "  automatically. Wait a few seconds after plugging in." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  If no port appears, you may need to install a driver from:" -ForegroundColor Gray
    Write-Host "  https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers" -ForegroundColor Cyan
    Write-Host ""

    while ($true) {
        if (Ask-YesNo "Is the controller connected via USB?") {
            Write-Host ""
            Write-Info "Scanning for connected devices..."
            Write-Host ""

            $ports = Get-SerialPorts

            if ($ports.Count -eq 0) {
                Write-Error-Custom "No serial devices found!"
                Write-Host ""
                Write-Host "Possible issues:" -ForegroundColor Yellow
                Write-Host "  - USB cable might be charge-only (try a different cable)"
                Write-Host "  - USB driver might not be installed"
                Write-Host "  - Try a different USB port on your computer"
                Write-Host "  - Wait a few seconds for Windows to detect the device"
                Write-Host ""
                if (-not (Ask-YesNo "Would you like to try again?")) {
                    return $false
                }
                continue
            }

            if ($ports.Count -eq 1) {
                $script:SelectedPort = $ports[0].Port
                $displayName = if ($ports[0].Name -and $ports[0].Name -ne $ports[0].Port) {
                    "$($ports[0].Port) - $($ports[0].Name)"
                } else {
                    $ports[0].Port
                }
                Write-Success "Found device: $displayName"
                Write-Host ""
                if (Ask-YesNo "Use this device?") {
                    return $true
                }
            } else {
                Write-Host "Multiple devices found:" -ForegroundColor White
                Write-Host ""
                for ($i = 0; $i -lt $ports.Count; $i++) {
                    $displayName = if ($ports[$i].Name -and $ports[$i].Name -ne $ports[$i].Port) {
                        "$($ports[$i].Port) - $($ports[$i].Name)"
                    } else {
                        $ports[$i].Port
                    }
                    Write-Host "  $($i + 1)) $displayName"
                }
                Write-Host ""

                while ($true) {
                    $choice = Read-Host "Enter the number of the device to use"
                    $choiceNum = 0
                    if ([int]::TryParse($choice, [ref]$choiceNum) -and $choiceNum -ge 1 -and $choiceNum -le $ports.Count) {
                        $script:SelectedPort = $ports[$choiceNum - 1].Port
                        Write-Success "Selected: $($ports[$choiceNum - 1].Name)"
                        return $true
                    } else {
                        Write-Error-Custom "Please enter a number between 1 and $($ports.Count)"
                    }
                }
            }
        } else {
            Write-Host ""
            Write-Host "Please connect the controller and try again."
            Write-Host ""
        }
    }
}

#############################################################################
# Firmware Upload
#############################################################################

function Upload-Firmware {
    Write-Step "Step 5: Upload Firmware"

    $firmwarePath = Join-Path $ArduinoDir $script:SelectedController

    if (-not (Test-Path $firmwarePath)) {
        Write-Error-Custom "Firmware folder not found: $firmwarePath"
        return $false
    }

    Write-Host "Ready to upload firmware:"
    Write-Host ""
    Write-Host "  Controller: $($script:SelectedController)" -ForegroundColor White
    Write-Host "  Port:       $($script:SelectedPort)" -ForegroundColor White
    Write-Host "  Firmware:   $firmwarePath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "  - Do NOT disconnect the USB cable during upload"
    Write-Host "  - The upload takes about 30-60 seconds"
    Write-Host "  - The controller will restart automatically when done"
    Write-Host ""

    if (-not (Ask-YesNo "Start the upload?")) {
        Write-Warning-Custom "Upload cancelled."
        return $false
    }

    Write-Host ""
    Write-Info "Compiling firmware (this may take a minute)..."
    Write-Host ""

    try {
        # Compile the firmware
        $compileOutput = & $script:ArduinoCli compile --fqbn esp32:esp32:esp32 $firmwarePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Compilation failed!"
            Write-Host $compileOutput -ForegroundColor Red
            Write-Host ""
            Write-Host "This might mean there's a problem with the firmware files."
            Write-Host "Please contact support for help."
            return $false
        }

        Write-Host ""
        Write-Success "Compilation successful!"
        Write-Host ""
        Write-Info "Uploading to controller..."
        Write-Host ""

        # Upload the firmware
        $uploadOutput = & $script:ArduinoCli upload -p $script:SelectedPort --fqbn esp32:esp32:esp32 $firmwarePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Upload failed!"
            Write-Host $uploadOutput -ForegroundColor Red
            Write-Host ""
            Write-Host "Possible issues:" -ForegroundColor Yellow
            Write-Host "  - Try unplugging and replugging the USB cable"
            Write-Host "  - Try holding the BOOT button on the ESP32 during upload"
            Write-Host "  - Try a different USB cable"
            Write-Host "  - Make sure no other program is using the serial port"
            return $false
        }

        Write-Host ""
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "  FIRMWARE UPLOAD COMPLETE!" -ForegroundColor Green
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    catch {
        Write-Error-Custom "Error during upload: $_"
        return $false
    }
}

#############################################################################
# Post-Upload Options
#############################################################################

function Show-PostUploadMenu {
    Write-Step "What would you like to do next?"

    Write-Host "  1) Upload firmware to another controller"
    Write-Host "  2) View serial output (for troubleshooting)"
    Write-Host "  3) Exit"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Enter your choice (1-3)"
        switch ($choice) {
            "1" { return "continue" }
            "2" {
                Show-SerialOutput
                return "continue"
            }
            "3" { return "exit" }
            default {
                Write-Error-Custom "Please enter 1, 2, or 3"
            }
        }
    }
}

function Show-SerialOutput {
    Write-Step "Serial Monitor"

    Write-Host "This will show you the output from the controller."
    Write-Host "This is useful for:"
    Write-Host "  - Checking the MAC address (for pairing)"
    Write-Host "  - Verifying the controller is working"
    Write-Host "  - Troubleshooting problems"
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the serial monitor" -ForegroundColor Yellow
    Write-Host ""

    if (Ask-YesNo "Start serial monitor?") {
        Write-Host ""
        Write-Info "Starting serial monitor at 115200 baud..."
        Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
        try {
            & $script:ArduinoCli monitor -p $script:SelectedPort -c baudrate=115200
        } catch {}
        Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        Write-Info "Serial monitor closed."
    }
}

#############################################################################
# Main Program
#############################################################################

function Main {
    Write-Header

    Write-Host "This tool will help you upload firmware to your SledLink controller."
    Write-Host "Just follow the prompts - no technical knowledge required!"
    Write-Host ""

    Wait-ForEnter

    # Check for and install Arduino CLI if needed
    if (-not (Test-ArduinoCli)) {
        if (-not (Install-ArduinoCli)) {
            Write-Error-Custom "Cannot continue without Arduino CLI."
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }

    # Setup Arduino CLI (ESP32 support, libraries)
    if (-not (Setup-ArduinoCli)) {
        Write-Error-Custom "Failed to configure Arduino CLI."
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }

    Wait-ForEnter

    # Main loop - allows uploading to multiple controllers
    while ($true) {
        # Select which controller to upload
        Select-Controller
        Wait-ForEnter

        # Select serial port
        if (-not (Select-Port)) {
            Write-Error-Custom "Could not find a serial port."
            if (-not (Ask-YesNo "Would you like to try again?")) {
                break
            }
            continue
        }
        Wait-ForEnter

        # Upload the firmware
        if (Upload-Firmware) {
            $result = Show-PostUploadMenu
            if ($result -eq "exit") {
                break
            }
        } else {
            Write-Host ""
            if (-not (Ask-YesNo "Would you like to try again?")) {
                break
            }
        }
    }

    Write-Host ""
    Write-Success "Thank you for using SledLink Firmware Upload Tool!"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run main program
Main
