#!/bin/bash
#
# SledLink Firmware Upload Script
# For Mac and Linux users
#
# This script guides non-technical users through uploading firmware
# to the SledLink Judge or Sled Controller.
#

set -e

# Colors for terminal output (will gracefully degrade if not supported)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Disable colors if not in a terminal
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARDUINO_DIR="$SCRIPT_DIR/arduino"

# Global variables
SELECTED_PORT=""
SELECTED_CONTROLLER=""
ARDUINO_CLI=""

#############################################################################
# Helper Functions
#############################################################################

print_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}           SledLink Firmware Upload Tool                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           For Tractor Pull Distance Measurement              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_info() {
    echo -e "${CYAN}→ $1${NC}"
}

wait_for_enter() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read -r
}

ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        echo -e "${BOLD}$prompt${NC} (yes/no): "
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please type 'yes' or 'no'" ;;
        esac
    done
}

#############################################################################
# System Detection
#############################################################################

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "mac" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

#############################################################################
# Arduino CLI Installation
#############################################################################

check_arduino_cli() {
    print_step "Step 1: Checking for Arduino CLI"

    # Check if arduino-cli is in PATH
    if command -v arduino-cli &> /dev/null; then
        ARDUINO_CLI="arduino-cli"
        print_success "Arduino CLI found: $(which arduino-cli)"
        return 0
    fi

    # Check common installation locations
    local common_paths=(
        "$HOME/bin/arduino-cli"
        "$HOME/.local/bin/arduino-cli"
        "/usr/local/bin/arduino-cli"
        "/opt/homebrew/bin/arduino-cli"
    )

    for path in "${common_paths[@]}"; do
        if [ -x "$path" ]; then
            ARDUINO_CLI="$path"
            print_success "Arduino CLI found: $path"
            return 0
        fi
    done

    print_warning "Arduino CLI is not installed."
    echo ""
    return 1
}

install_arduino_cli() {
    local os_type=$(detect_os)

    print_step "Installing Arduino CLI"

    echo "Arduino CLI is the tool that uploads firmware to the controller."
    echo "We need to install it on your computer."
    echo ""

    if [ "$os_type" = "mac" ]; then
        # Check for Homebrew first
        if command -v brew &> /dev/null; then
            echo "We detected Homebrew on your Mac."
            if ask_yes_no "Would you like to install Arduino CLI using Homebrew?"; then
                echo ""
                print_info "Installing Arduino CLI via Homebrew..."
                brew install arduino-cli
                ARDUINO_CLI="arduino-cli"
                print_success "Arduino CLI installed successfully!"
                return 0
            fi
        fi

        # Fall back to curl installation
        echo ""
        echo "We'll download Arduino CLI directly from Arduino."
        if ask_yes_no "Continue with installation?"; then
            echo ""
            print_info "Downloading Arduino CLI..."
            mkdir -p "$HOME/bin"
            curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR="$HOME/bin" sh
            ARDUINO_CLI="$HOME/bin/arduino-cli"

            # Add to PATH for this session
            export PATH="$HOME/bin:$PATH"

            print_success "Arduino CLI installed to $HOME/bin/"
            echo ""
            print_warning "Note: You may need to restart your terminal or add"
            print_warning "      $HOME/bin to your PATH for future use."
            return 0
        fi

    elif [ "$os_type" = "linux" ]; then
        echo "We'll download Arduino CLI directly from Arduino."
        if ask_yes_no "Continue with installation?"; then
            echo ""
            print_info "Downloading Arduino CLI..."
            mkdir -p "$HOME/bin"
            curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR="$HOME/bin" sh
            ARDUINO_CLI="$HOME/bin/arduino-cli"

            # Add to PATH for this session
            export PATH="$HOME/bin:$PATH"

            print_success "Arduino CLI installed to $HOME/bin/"
            echo ""
            print_warning "Note: You may need to restart your terminal or add"
            print_warning "      $HOME/bin to your PATH for future use."
            return 0
        fi
    fi

    print_error "Arduino CLI installation was cancelled or failed."
    echo ""
    echo "You can install it manually from: https://arduino.github.io/arduino-cli/"
    return 1
}

setup_arduino_cli() {
    print_step "Step 2: Setting up Arduino CLI for ESP32"

    echo "Checking if ESP32 board support is installed..."
    echo ""

    # Initialize config if needed
    if [ ! -f "$HOME/.arduino15/arduino-cli.yaml" ]; then
        print_info "Initializing Arduino CLI configuration..."
        "$ARDUINO_CLI" config init 2>/dev/null || true
    fi

    # Check if ESP32 URL is already added
    local has_esp32_url=false
    if "$ARDUINO_CLI" config dump 2>/dev/null | grep -q "espressif"; then
        has_esp32_url=true
    fi

    if [ "$has_esp32_url" = false ]; then
        print_info "Adding ESP32 board support URL..."
        "$ARDUINO_CLI" config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
    fi

    # Check if ESP32 core is installed
    if ! "$ARDUINO_CLI" core list 2>/dev/null | grep -q "esp32:esp32"; then
        print_info "Installing ESP32 board support (this may take a few minutes)..."
        "$ARDUINO_CLI" core update-index
        "$ARDUINO_CLI" core install esp32:esp32
        print_success "ESP32 board support installed!"
    else
        print_success "ESP32 board support is already installed."
    fi

    # Check if LiquidCrystal library is installed
    if ! "$ARDUINO_CLI" lib list 2>/dev/null | grep -q "LiquidCrystal"; then
        print_info "Installing LCD library..."
        "$ARDUINO_CLI" lib install "LiquidCrystal"
        print_success "LCD library installed!"
    else
        print_success "LCD library is already installed."
    fi

    echo ""
    print_success "Arduino CLI is fully configured!"
}

#############################################################################
# Controller Selection
#############################################################################

select_controller() {
    print_step "Step 3: Select Controller Type"

    echo "Which controller do you want to upload firmware to?"
    echo ""
    echo -e "${BOLD}  1) SLED Controller${NC}"
    echo "     - This goes ON THE SLED"
    echo "     - Has the measuring wheel encoder attached"
    echo "     - Sends distance to the judge"
    echo ""
    echo -e "${BOLD}  2) JUDGE Controller${NC}"
    echo "     - This stays at the JUDGE'S TABLE"
    echo "     - Receives and displays distance"
    echo "     - No encoder attached"
    echo ""

    while true; do
        echo -e "${BOLD}Enter 1 for SLED or 2 for JUDGE:${NC} "
        read -r choice
        case "$choice" in
            1)
                SELECTED_CONTROLLER="SledController"
                print_success "Selected: SLED Controller"
                return 0
                ;;
            2)
                SELECTED_CONTROLLER="JudgeController"
                print_success "Selected: JUDGE Controller"
                return 0
                ;;
            *)
                print_error "Please enter 1 or 2"
                ;;
        esac
    done
}

#############################################################################
# Port Detection
#############################################################################

get_serial_ports() {
    local os_type=$(detect_os)
    local ports=()

    if [ "$os_type" = "mac" ]; then
        # On Mac, look for USB serial devices
        for port in /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB* /dev/tty.usbserial* /dev/tty.wchusbserial* /dev/tty.SLAB*; do
            if [ -e "$port" ]; then
                ports+=("$port")
            fi
        done
        # Also check for direct USB connections
        for port in /dev/cu.usbmodem* /dev/tty.usbmodem*; do
            if [ -e "$port" ]; then
                ports+=("$port")
            fi
        done
    else
        # On Linux, look for USB serial devices
        for port in /dev/ttyUSB* /dev/ttyACM*; do
            if [ -e "$port" ]; then
                ports+=("$port")
            fi
        done
    fi

    # Return unique ports
    printf '%s\n' "${ports[@]}" | sort -u
}

select_port() {
    print_step "Step 4: Connect the Controller"

    local os_type=$(detect_os)

    echo "Now we need to connect to the controller."
    echo ""
    echo -e "${BOLD}Instructions:${NC}"
    echo "  1. Get a USB cable (micro-USB for most ESP32 boards)"
    echo "  2. Plug one end into the controller board"
    echo "  3. Plug the other end into this computer"
    echo ""

    if [ "$os_type" = "mac" ]; then
        echo -e "${YELLOW}Mac Users:${NC}"
        echo "  If this is your first time connecting an ESP32, you may need"
        echo "  to install a USB driver. If no port appears, visit:"
        echo "  https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers"
        echo ""
    elif [ "$os_type" = "linux" ]; then
        echo -e "${YELLOW}Linux Users:${NC}"
        echo "  If you get permission errors, you may need to add yourself"
        echo "  to the 'dialout' group. Run this command and restart:"
        echo "  sudo usermod -a -G dialout \$USER"
        echo ""
    fi

    while true; do
        if ask_yes_no "Is the controller connected via USB?"; then
            echo ""
            print_info "Scanning for connected devices..."
            echo ""

            local ports=($(get_serial_ports))

            if [ ${#ports[@]} -eq 0 ]; then
                print_error "No serial devices found!"
                echo ""
                echo "Possible issues:"
                echo "  - USB cable might be charge-only (try a different cable)"
                echo "  - USB driver might not be installed"
                echo "  - Try a different USB port on your computer"
                echo ""
                if ! ask_yes_no "Would you like to try again?"; then
                    return 1
                fi
                continue
            fi

            if [ ${#ports[@]} -eq 1 ]; then
                SELECTED_PORT="${ports[0]}"
                print_success "Found device: $SELECTED_PORT"
                echo ""
                if ask_yes_no "Use this device?"; then
                    return 0
                fi
            else
                echo "Multiple devices found:"
                echo ""
                local i=1
                for port in "${ports[@]}"; do
                    echo "  $i) $port"
                    i=$((i + 1))
                done
                echo ""

                while true; do
                    echo -e "${BOLD}Enter the number of the device to use:${NC} "
                    read -r choice
                    if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le ${#ports[@]} ]; then
                        SELECTED_PORT="${ports[$((choice - 1))]}"
                        print_success "Selected: $SELECTED_PORT"
                        return 0
                    else
                        print_error "Please enter a number between 1 and ${#ports[@]}"
                    fi
                done
            fi
        else
            echo ""
            echo "Please connect the controller and try again."
            echo ""
        fi
    done
}

#############################################################################
# Firmware Upload
#############################################################################

upload_firmware() {
    print_step "Step 5: Upload Firmware"

    local firmware_path="$ARDUINO_DIR/$SELECTED_CONTROLLER"

    if [ ! -d "$firmware_path" ]; then
        print_error "Firmware folder not found: $firmware_path"
        return 1
    fi

    echo "Ready to upload firmware:"
    echo ""
    echo "  Controller: $SELECTED_CONTROLLER"
    echo "  Port:       $SELECTED_PORT"
    echo "  Firmware:   $firmware_path"
    echo ""
    echo -e "${YELLOW}IMPORTANT:${NC}"
    echo "  - Do NOT disconnect the USB cable during upload"
    echo "  - The upload takes about 30-60 seconds"
    echo "  - The controller will restart automatically when done"
    echo ""

    if ! ask_yes_no "Start the upload?"; then
        print_warning "Upload cancelled."
        return 1
    fi

    echo ""
    print_info "Compiling firmware (this may take a minute)..."
    echo ""

    # Compile the firmware
    if ! "$ARDUINO_CLI" compile --fqbn esp32:esp32:esp32 "$firmware_path" 2>&1; then
        print_error "Compilation failed!"
        echo ""
        echo "This might mean there's a problem with the firmware files."
        echo "Please contact support for help."
        return 1
    fi

    echo ""
    print_success "Compilation successful!"
    echo ""
    print_info "Uploading to controller..."
    echo ""

    # Upload the firmware
    if ! "$ARDUINO_CLI" upload -p "$SELECTED_PORT" --fqbn esp32:esp32:esp32 "$firmware_path" 2>&1; then
        print_error "Upload failed!"
        echo ""
        echo "Possible issues:"
        echo "  - Try unplugging and replugging the USB cable"
        echo "  - Try holding the BOOT button on the ESP32 during upload"
        echo "  - Try a different USB cable"
        echo "  - Make sure no other program is using the serial port"
        return 1
    fi

    echo ""
    print_success "════════════════════════════════════════════════════"
    print_success "  FIRMWARE UPLOAD COMPLETE!"
    print_success "════════════════════════════════════════════════════"
    echo ""
    return 0
}

#############################################################################
# Post-Upload Options
#############################################################################

post_upload_menu() {
    print_step "What would you like to do next?"

    echo "  1) Upload firmware to another controller"
    echo "  2) View serial output (for troubleshooting)"
    echo "  3) Exit"
    echo ""

    while true; do
        echo -e "${BOLD}Enter your choice (1-3):${NC} "
        read -r choice
        case "$choice" in
            1) return 0 ;;  # Loop back to start
            2)
                view_serial_output
                return 0
                ;;
            3) return 1 ;;  # Exit
            *)
                print_error "Please enter 1, 2, or 3"
                ;;
        esac
    done
}

view_serial_output() {
    print_step "Serial Monitor"

    echo "This will show you the output from the controller."
    echo "This is useful for:"
    echo "  - Checking the MAC address (for pairing)"
    echo "  - Verifying the controller is working"
    echo "  - Troubleshooting problems"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the serial monitor${NC}"
    echo ""

    if ask_yes_no "Start serial monitor?"; then
        echo ""
        print_info "Starting serial monitor at 115200 baud..."
        echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
        "$ARDUINO_CLI" monitor -p "$SELECTED_PORT" -c baudrate=115200 || true
        echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
        echo ""
        print_info "Serial monitor closed."
    fi
}

#############################################################################
# Main Program
#############################################################################

main() {
    print_header

    echo "This tool will help you upload firmware to your SledLink controller."
    echo "Just follow the prompts - no technical knowledge required!"
    echo ""

    wait_for_enter

    # Check for and install Arduino CLI if needed
    if ! check_arduino_cli; then
        if ! install_arduino_cli; then
            print_error "Cannot continue without Arduino CLI."
            exit 1
        fi
    fi

    # Setup Arduino CLI (ESP32 support, libraries)
    setup_arduino_cli

    wait_for_enter

    # Main loop - allows uploading to multiple controllers
    while true; do
        # Select which controller to upload
        select_controller
        wait_for_enter

        # Select serial port
        if ! select_port; then
            print_error "Could not find a serial port."
            if ask_yes_no "Would you like to try again?"; then
                continue
            else
                exit 1
            fi
        fi
        wait_for_enter

        # Upload the firmware
        if upload_firmware; then
            if ! post_upload_menu; then
                break
            fi
        else
            echo ""
            if ! ask_yes_no "Would you like to try again?"; then
                break
            fi
        fi
    done

    echo ""
    print_success "Thank you for using SledLink Firmware Upload Tool!"
    echo ""
}

# Run main program
main "$@"
