#!/bin/bash
#
# SledLink Firmware Flash Script
# Flashes pre-compiled firmware using esptool
#
# This script is for use with the release package containing
# pre-compiled .bin files. For compiling from source, use upload_firmware.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_DIR="$SCRIPT_DIR/firmware"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ ! -t 1 ]; then
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

ESPTOOL=""
SELECTED_PORT=""
SELECTED_CONTROLLER=""

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

    local pip_cmd=""
    if command -v pip3 &> /dev/null; then
        pip_cmd="pip3"
    elif command -v pip &> /dev/null; then
        pip_cmd="pip"
    fi

    if [ -n "$pip_cmd" ]; then
        echo -e "${BOLD}Install esptool now?${NC} (yes/no): "
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            echo ""
            echo "Installing esptool..."
            $pip_cmd install esptool
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

select_controller() {
    echo -e "${BOLD}Which controller do you want to flash?${NC}"
    echo ""
    echo "  1) SLED Controller - goes on the sled, has encoder"
    echo "  2) JUDGE Controller - judge's table display"
    echo ""

    while true; do
        echo -n "Enter 1 or 2: "
        read -r choice
        case "$choice" in
            1)
                SELECTED_CONTROLLER="SledController"
                echo -e "${GREEN}✓ Selected: SLED Controller${NC}"
                return
                ;;
            2)
                SELECTED_CONTROLLER="JudgeController"
                echo -e "${GREEN}✓ Selected: JUDGE Controller${NC}"
                return
                ;;
            *)
                echo -e "${RED}Please enter 1 or 2${NC}"
                ;;
        esac
    done
}

select_port() {
    echo ""
    echo -e "${YELLOW}Connect the controller via USB, then press ENTER${NC}"
    read -r

    echo "Scanning for devices..."
    local ports=($(get_serial_ports))

    if [ ${#ports[@]} -eq 0 ]; then
        echo -e "${RED}✗ No serial devices found!${NC}"
        echo ""
        echo "Try:"
        echo "  - Different USB cable (some are charge-only)"
        echo "  - Different USB port"
        echo "  - Install USB driver (CP210x or CH340)"

        if [ "$(uname -s)" = "Linux" ]; then
            echo ""
            echo "Linux users: You may need to add yourself to the dialout group:"
            echo "  sudo usermod -a -G dialout \$USER"
            echo "Then log out and back in."
        fi
        return 1
    fi

    if [ ${#ports[@]} -eq 1 ]; then
        SELECTED_PORT="${ports[0]}"
        echo -e "${GREEN}✓ Found: $SELECTED_PORT${NC}"
    else
        echo "Multiple devices found:"
        for i in "${!ports[@]}"; do
            echo "  $((i+1))) ${ports[$i]}"
        done
        while true; do
            echo -n "Select device (1-${#ports[@]}): "
            read -r choice
            if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le ${#ports[@]} ]; then
                SELECTED_PORT="${ports[$((choice-1))]}"
                echo -e "${GREEN}✓ Selected: $SELECTED_PORT${NC}"
                break
            else
                echo -e "${RED}Please enter a number between 1 and ${#ports[@]}${NC}"
            fi
        done
    fi
    return 0
}

flash_firmware() {
    local firmware_path="$FIRMWARE_DIR/$SELECTED_CONTROLLER.bin"
    local bootloader_path="$FIRMWARE_DIR/$SELECTED_CONTROLLER.bootloader.bin"
    local partitions_path="$FIRMWARE_DIR/$SELECTED_CONTROLLER.partitions.bin"

    # Check if firmware directory exists
    if [ ! -d "$FIRMWARE_DIR" ]; then
        echo -e "${RED}✗ Firmware directory not found: $FIRMWARE_DIR${NC}"
        echo ""
        echo "This script expects pre-compiled firmware in a 'firmware' folder."
        echo "If you want to compile from source, use upload_firmware.sh instead."
        return 1
    fi

    if [ ! -f "$firmware_path" ]; then
        echo -e "${RED}✗ Firmware file not found: $firmware_path${NC}"
        return 1
    fi

    echo ""
    echo -e "${BOLD}Ready to flash:${NC}"
    echo "  Controller: $SELECTED_CONTROLLER"
    echo "  Port: $SELECTED_PORT"
    echo "  Firmware: $firmware_path"
    echo ""
    echo -e "${YELLOW}Do NOT disconnect during flash!${NC}"
    echo ""
    echo -n "Start flash? (yes/no): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Cancelled."
        return 1
    fi

    echo ""
    echo "Flashing firmware..."
    echo ""

    # Flash the firmware
    $ESPTOOL --chip esp32 --port "$SELECTED_PORT" --baud 460800 \
        --before default_reset --after hard_reset \
        write_flash -z \
        --flash_mode dio --flash_freq 40m --flash_size detect \
        0x1000 "$bootloader_path" \
        0x8000 "$partitions_path" \
        0x10000 "$firmware_path"

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  FIRMWARE FLASH COMPLETE!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "The controller will restart automatically."
    return 0
}

# Main
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
    if ! check_esptool; then
        echo -e "${RED}esptool installation failed.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ esptool found${NC}"
echo ""

# Select controller
select_controller

# Select port
if ! select_port; then
    exit 1
fi

# Flash
flash_firmware
