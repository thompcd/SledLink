#!/bin/bash
#
# SledLink Release Build Script
# Compiles firmware and packages everything for a GitHub release
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version handling with validation
if [ -n "$1" ]; then
  VERSION="$1"
  # Validate semantic version format (v1.2.3) or date format (YYYY.MM.DD)
  if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]] && \
     [[ ! "$VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]]; then
    echo "ERROR: Invalid version format: $VERSION"
    echo "Expected: v1.2.3, v1.2.3-beta, or YYYY.MM.DD"
    exit 1
  fi
else
  VERSION="$(date +%Y.%m.%d)"
fi

RELEASE_DIR="$SCRIPT_DIR/release"
RELEASE_NAME="SledLink-$VERSION"
OUTPUT_DIR="$RELEASE_DIR/$RELEASE_NAME"

echo ""
echo "========================================"
echo "  SledLink Release Builder"
echo "  Version: $VERSION"
echo "========================================"
echo ""

# Check for arduino-cli
if ! command -v arduino-cli &> /dev/null; then
    echo "ERROR: arduino-cli is not installed."
    echo ""
    echo "Install it with:"
    echo "  Mac:   brew install arduino-cli"
    echo "  Linux: curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh"
    echo ""
    exit 1
fi

# Ensure ESP32 core is installed
echo "Checking ESP32 board support..."
if ! arduino-cli core list 2>/dev/null | grep -q "esp32:esp32"; then
    echo "Installing ESP32 board support..."
    arduino-cli config init 2>/dev/null || true
    arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
    arduino-cli core update-index
    arduino-cli core install esp32:esp32
fi

# Ensure LiquidCrystal library is installed
if ! arduino-cli lib list 2>/dev/null | grep -q "LiquidCrystal"; then
    echo "Installing LiquidCrystal library..."
    arduino-cli lib install "LiquidCrystal"
fi

# Clean and create release directory
echo ""
echo "Creating release directory..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/firmware/SledController"
mkdir -p "$OUTPUT_DIR/firmware/JudgeController"
mkdir -p "$OUTPUT_DIR/firmware/tools"
mkdir -p "$OUTPUT_DIR/tools"
mkdir -p "$OUTPUT_DIR/source"

# Copy flash tools (main method for users)
echo "Copying flash tools..."
cp "$SCRIPT_DIR/Flash Firmware.bat" "$OUTPUT_DIR/"
cp "$SCRIPT_DIR/flash_firmware.ps1" "$OUTPUT_DIR/"
chmod +x "$OUTPUT_DIR/flash_firmware.ps1"

# Copy compile/upload tools (advanced method for developers)
echo "Copying advanced compile tools..."
cp "$SCRIPT_DIR/upload_firmware.sh" "$OUTPUT_DIR/tools/"
cp "$SCRIPT_DIR/upload_firmware.ps1" "$OUTPUT_DIR/tools/"
cp "$SCRIPT_DIR/Upload Firmware (Windows).bat" "$OUTPUT_DIR/tools/Compile Firmware (Windows).bat"
chmod +x "$OUTPUT_DIR/tools/upload_firmware.sh"

# Copy source code
echo "Copying source code..."
cp -r "$SCRIPT_DIR/arduino" "$OUTPUT_DIR/source/"

# Compile firmware binaries
echo ""
echo "Compiling firmware binaries..."
echo "  SledController..."
arduino-cli compile --fqbn esp32:esp32:esp32 --export-binaries \
  --output-dir "$SCRIPT_DIR/firmware_binaries/SledController" \
  "$SCRIPT_DIR/arduino/SledController" 2>&1 | grep -E "(Compiling|Archiving|Sketch uses|Global variables)" || true

echo "  JudgeController..."
arduino-cli compile --fqbn esp32:esp32:esp32 --export-binaries \
  --output-dir "$SCRIPT_DIR/firmware_binaries/JudgeController" \
  "$SCRIPT_DIR/arduino/JudgeController" 2>&1 | grep -E "(Compiling|Archiving|Sketch uses|Global variables)" || true

# Package binaries into release
echo "Packaging firmware binaries..."
for controller in SledController JudgeController; do
  BIN_DIR="$SCRIPT_DIR/firmware_binaries/$controller"
  OUT_DIR="$OUTPUT_DIR/firmware/$controller"

  if [ -f "$BIN_DIR/${controller}.ino.bin" ]; then
    cp "$BIN_DIR/${controller}.ino.bin" "$OUT_DIR/firmware.bin"
    cp "$BIN_DIR/${controller}.ino.bootloader.bin" "$OUT_DIR/bootloader.bin"
    cp "$BIN_DIR/${controller}.ino.partitions.bin" "$OUT_DIR/partitions.bin"
    echo "  ✓ $controller"
  else
    echo "  ✗ $controller - binaries not found!"
  fi
done

# Extract and copy esptool
echo "Extracting esptool for Windows..."
ESPTOOL_DIR=$(find ~/.arduino15/packages/esp32/tools/esptool_py -type d -maxdepth 2 2>/dev/null | head -1)
if [ -f "$ESPTOOL_DIR/esptool.exe" ]; then
  cp "$ESPTOOL_DIR/esptool.exe" "$OUTPUT_DIR/firmware/tools/"
  echo "  ✓ esptool.exe bundled"
else
  echo "  ⚠ esptool.exe not found - Windows flashing may not work"
fi

# Copy documentation
echo "Copying documentation..."
cp "$SCRIPT_DIR/UPLOAD_GUIDE.md" "$OUTPUT_DIR/"
cp "$SCRIPT_DIR/docs/README.md" "$OUTPUT_DIR/docs_README.md" 2>/dev/null || true

# Create release README
cat > "$OUTPUT_DIR/README.txt" << HEREDOC
================================================================================
  SledLink Firmware Release $VERSION
  Tractor Pull Distance Measurement System
================================================================================

RELEASE INFORMATION
-------------------
  Version:        $VERSION
  Firmware:       v1.0.0
  Build Date:     $(date +%Y-%m-%d)
  Download:       https://github.com/thompcd/SledLink/releases/tag/$VERSION

This release contains PRE-COMPILED firmware ready to flash instantly!

CONTENTS
--------
  firmware/           - Pre-compiled firmware binaries (ready to flash)
    SledController/   - Sled controller binaries
    JudgeController/  - Judge controller binaries
    tools/            - esptool.exe for Windows

  Flash Firmware.bat  - Main method: Double-click to flash firmware instantly

  source/             - Arduino source code (for advanced users and developers)
    arduino/SledController/ - Sled controller source
    arduino/JudgeController/ - Judge controller source

  tools/              - Advanced tools (for developers)
    Compile Firmware (Windows).bat - Compile and upload from source code
    upload_firmware.sh             - Mac/Linux compile and upload script
    upload_firmware.ps1            - Windows PowerShell compile and upload script


QUICK START - FLASH FIRMWARE (RECOMMENDED)
-------------------------------------------
Pre-compiled firmware flashes in ~10 seconds - no compilation needed!

Windows:
  1. Connect the controller via USB
  2. Double-click "Flash Firmware.bat"
  3. Select controller type (1=Sled, 2=Judge)
  4. Firmware flashes automatically!
  5. Controller restarts automatically


WHICH CONTROLLER IS WHICH?
--------------------------
SLED Controller:
  - Goes ON THE SLED
  - Has the measuring wheel encoder attached
  - SENDS distance to the judge wirelessly

JUDGE Controller:
  - Stays at the JUDGE'S TABLE
  - RECEIVES and displays distance
  - No encoder attached


TROUBLESHOOTING
---------------
See UPLOAD_GUIDE.md for detailed troubleshooting steps.

Common issues:
  - "No device found" - Try a different USB cable (some are charge-only)
  - "Flash failed" - Hold BOOT button on ESP32 during flash
  - Driver issues - Install CP210x or CH340 USB driver for your OS


SUPPORT
-------
For issues, visit: https://github.com/thompcd/SledLink/issues

================================================================================
HEREDOC

# Create the flash script for pre-compiled binaries
cat > "$OUTPUT_DIR/flash_firmware.sh" << 'FLASHSCRIPT'
#!/bin/bash
#
# SledLink Firmware Flash Script
# Flashes pre-compiled firmware using esptool
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_DIR="$SCRIPT_DIR/firmware"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}           SledLink Firmware Flash Tool                       ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           Flash Pre-Compiled Firmware                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_esptool() {
    if command -v esptool.py &> /dev/null; then
        ESPTOOL="esptool.py"
        return 0
    elif command -v esptool &> /dev/null; then
        ESPTOOL="esptool"
        return 0
    elif python3 -m esptool version &> /dev/null 2>&1; then
        ESPTOOL="python3 -m esptool"
        return 0
    elif python -m esptool version &> /dev/null 2>&1; then
        ESPTOOL="python -m esptool"
        return 0
    fi
    return 1
}

install_esptool() {
    echo -e "${YELLOW}esptool is not installed.${NC}"
    echo ""
    echo "esptool is required to flash pre-compiled firmware."
    echo ""

    if command -v pip3 &> /dev/null; then
        echo -e "${BOLD}Install esptool now?${NC} (yes/no): "
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            echo ""
            echo "Installing esptool..."
            pip3 install esptool
            return 0
        fi
    elif command -v pip &> /dev/null; then
        echo -e "${BOLD}Install esptool now?${NC} (yes/no): "
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            echo ""
            echo "Installing esptool..."
            pip install esptool
            return 0
        fi
    else
        echo "Python pip is required to install esptool."
        echo ""
        echo "Install Python from: https://www.python.org/downloads/"
        echo "Then run: pip install esptool"
    fi
    return 1
}

get_serial_ports() {
    case "$(uname -s)" in
        Darwin*)
            for port in /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB* /dev/cu.usbmodem*; do
                [ -e "$port" ] && echo "$port"
            done
            ;;
        *)
            for port in /dev/ttyUSB* /dev/ttyACM*; do
                [ -e "$port" ] && echo "$port"
            done
            ;;
    esac
}

print_header

echo "This tool flashes pre-compiled firmware to your SledLink controller."
echo "No compilation needed - just select your controller type and port."
echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read -r

# Check for esptool
if ! check_esptool; then
    if ! install_esptool; then
        echo -e "${RED}Cannot continue without esptool.${NC}"
        exit 1
    fi
    check_esptool
fi

echo -e "${GREEN}✓ esptool found${NC}"
echo ""

# Select controller
echo -e "${BOLD}Which controller do you want to flash?${NC}"
echo ""
echo "  1) SLED Controller - goes on the sled, has encoder"
echo "  2) JUDGE Controller - judge's table display"
echo ""
while true; do
    echo -n "Enter 1 or 2: "
    read -r choice
    case "$choice" in
        1) CONTROLLER="SledController"; break ;;
        2) CONTROLLER="JudgeController"; break ;;
        *) echo "Please enter 1 or 2" ;;
    esac
done

echo ""
echo -e "${GREEN}✓ Selected: $CONTROLLER${NC}"
echo ""

# Check firmware exists
if [ ! -f "$FIRMWARE_DIR/$CONTROLLER.bin" ]; then
    echo -e "${RED}ERROR: Firmware file not found: $FIRMWARE_DIR/$CONTROLLER.bin${NC}"
    exit 1
fi

# Select port
echo -e "${BOLD}Connect the controller via USB, then press ENTER${NC}"
read -r

echo "Scanning for devices..."
ports=($(get_serial_ports))

if [ ${#ports[@]} -eq 0 ]; then
    echo -e "${RED}No serial devices found!${NC}"
    echo ""
    echo "Try:"
    echo "  - Different USB cable (some are charge-only)"
    echo "  - Different USB port"
    echo "  - Install USB driver (CP210x or CH340)"
    exit 1
fi

if [ ${#ports[@]} -eq 1 ]; then
    PORT="${ports[0]}"
    echo -e "${GREEN}Found: $PORT${NC}"
else
    echo "Multiple devices found:"
    for i in "${!ports[@]}"; do
        echo "  $((i+1))) ${ports[$i]}"
    done
    while true; do
        echo -n "Select device (1-${#ports[@]}): "
        read -r choice
        if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le ${#ports[@]} ]; then
            PORT="${ports[$((choice-1))]}"
            break
        fi
    done
fi

echo ""
echo -e "${BOLD}Ready to flash:${NC}"
echo "  Controller: $CONTROLLER"
echo "  Port: $PORT"
echo "  Firmware: $FIRMWARE_DIR/$CONTROLLER.bin"
echo ""
echo -e "${YELLOW}Do NOT disconnect during flash!${NC}"
echo ""
echo -n "Start flash? (yes/no): "
read -r confirm
if [[ ! "$confirm" =~ ^[Yy] ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Flashing firmware..."
echo ""

# Flash the firmware
$ESPTOOL --chip esp32 --port "$PORT" --baud 460800 \
    --before default_reset --after hard_reset \
    write_flash -z \
    --flash_mode dio --flash_freq 40m --flash_size detect \
    0x1000 "$FIRMWARE_DIR/$CONTROLLER.bootloader.bin" \
    0x8000 "$FIRMWARE_DIR/$CONTROLLER.partitions.bin" \
    0x10000 "$FIRMWARE_DIR/$CONTROLLER.bin"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  FIRMWARE FLASH COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "The controller will restart automatically."
echo ""
FLASHSCRIPT

chmod +x "$OUTPUT_DIR/flash_firmware.sh"

# Create ZIP file
echo ""
echo "Creating release archive..."
cd "$RELEASE_DIR"
zip -r "$RELEASE_NAME.zip" "$RELEASE_NAME"

echo ""
echo "========================================"
echo "  Release Build Complete!"
echo "========================================"
echo ""
echo "Release directory: $OUTPUT_DIR"
echo "Release archive:   $RELEASE_DIR/$RELEASE_NAME.zip"
echo ""
echo "Contents:"
ls -la "$OUTPUT_DIR"
echo ""
echo "Firmware files:"
ls -la "$OUTPUT_DIR/firmware/"
echo ""
