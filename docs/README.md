# SledLink Documentation

This folder contains design documentation and project management files for the SledLink wireless tractor pull distance measurement system.

## Contents

| File | Description |
|------|-------------|
| `design.md` | Technical requirements, hardware specifications, and software architecture |
| `system_diagram.png` | Visual diagram of the complete SledLink system |
| `BACKLOG.md` | Development backlog with all tasks and their dependencies |

---

## Releases

SledLink uses [semantic versioning](https://semver.org/). The current release is available here:

**[Download Latest Release](https://github.com/thompcd/SledLink/releases/latest)**

- **Firmware Version**: v1.0.0 (displayed on LCD)
- **Release Version**: v1.0.0+ (package version)

### Release Versioning

- Release versions (v1.0.0, v1.0.1, etc.) track the entire package
- Firmware display version (v1.0.0) is user-facing and updates with releases
- See [RELEASE_PROCESS.md](./RELEASE_PROCESS.md) for maintainer instructions

---

## About the Backlog

The **[BACKLOG.md](./BACKLOG.md)** file serves as the single source of truth for all development work required to complete the SledLink MVP. It is designed to:

### Purpose

1. **Track Progress** — Every task has a checkbox status that we update as work is completed
2. **Manage Dependencies** — Tasks are organized to show what must be done before other work can begin
3. **Prioritize Work** — P0 (critical path) through P3 (nice to have) priorities help focus effort
4. **Enable Parallel Work** — Hardware and software tasks are separated so multiple people can work simultaneously

### How We Use It

As development progresses, we will:

- Mark tasks `[~]` when work begins (in progress)
- Mark tasks `[x]` when work is verified complete
- Mark tasks `[!]` if blocked by an external dependency
- Add notes in the "Notes" column for learnings or issues encountered
- Add new tasks if scope changes or we discover additional work

### Status Legend

| Status | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Completed |
| `[!]` | Blocked |

---

## Getting Started

1. Review `design.md` to understand the system architecture
2. Check `BACKLOG.md` for current status and next tasks
3. See [Arduino README](../arduino/README.md) for build and upload instructions
4. Update the backlog as you complete work

---

## Uploading Firmware (Easy Method)

For non-technical users who need to upload firmware in the field, we provide automated scripts:

| Platform | How to Run |
|----------|------------|
| **Windows** | Double-click `Upload Firmware (Windows).bat` in the root folder |
| **Mac/Linux** | Run `./upload_firmware.sh` in a terminal |

These scripts will:
- Install Arduino CLI if needed
- Set up ESP32 board support
- Guide you through selecting the controller type
- Detect connected USB devices
- Compile and upload firmware

See **[UPLOAD_GUIDE.md](../UPLOAD_GUIDE.md)** for detailed instructions and troubleshooting.

---

## Development Environment Setup

### Prerequisites

1. **Arduino IDE 2.x** or **Arduino CLI**
2. **ESP32 Board Support** installed in Arduino
3. **PuTTY** (or Arduino Serial Monitor) for serial output

### Installing ESP32 Support

1. Open Arduino IDE
2. File → Preferences → Additional Board Manager URLs
3. Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
4. Tools → Board → Boards Manager → Search "esp32" → Install

---

## Building and Uploading (Arduino)

### Quick Start

1. Open `arduino/SledController/SledController.ino` in Arduino IDE
2. Select board: Tools → Board → ESP32 Arduino → "ESP32 Dev Module"
3. Select port: Tools → Port → COM3 (your port)
4. Click Upload

### Using Arduino CLI

```bash
# Install ESP32 support (one time)
arduino-cli config init
arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
arduino-cli core update-index
arduino-cli core install esp32:esp32

# Compile and upload
arduino-cli compile --fqbn esp32:esp32:esp32 arduino/SledController
arduino-cli upload -p COM3 --fqbn esp32:esp32:esp32 arduino/SledController

# Monitor serial output
arduino-cli monitor -p COM3 -c baudrate=115200
```

---

## Hardware Configuration

### Sled Controller Wiring

| Component | Wire Color | ESP32 Pin |
|-----------|------------|-----------|
| Encoder Phase A | Green | GPIO 32 |
| Encoder Phase B | White | GPIO 33 |
| Encoder Vcc | Red | 5V |
| Encoder GND | Black | GND |
| Reset Button | - | GPIO 27 |

### Encoder Specifications

- **Model:** GHW38 incremental encoder
- **Resolution:** 1000 PPR (4000 counts/rev with quadrature)
- **Output:** NPN open-collector (uses ESP32 internal pull-ups)
- **Voltage:** 5V

### Measuring Wheel

- **Diameter:** 2.5 inches
- **Circumference:** 7.85 inches
- **Resolution:** ~0.002 inches per count

---

## Monitoring Serial Output

### Using PuTTY

1. Open PuTTY
2. Connection type: Serial
3. Serial line: COM3 (your port)
4. Speed: 115200
5. Click Open

### Expected Output

```
========================================
  SledLink Sled Controller v1.0
  Tractor Pull Distance Measurement
========================================

Configuration:
  Encoder Phase A: GPIO 32 (Green)
  Encoder Phase B: GPIO 33 (White)
  Reset Button: GPIO 27
  Encoder: 1000 PPR x4 = 4000 counts/rev
  Wheel diameter: 2.5 inches
  Mode: Quadrature (direction detection enabled)

Initializing PCNT quadrature encoder...
  Initial pin states: A=1, B=1 (should be 1,1 with pull-ups)
  PCNT quadrature encoder initialized successfully
Initializing reset button on GPIO 27...
  Button initialized
Initialization complete.
Spin encoder to see distance. Press button to reset.

Count      | Distance   | Status
-----------|------------|--------
      4000 |    0.65 ft |
      8000 |    1.31 ft |
         0 |    0.00 ft | RESET
```

---

## Project Structure

```
SledLink/
├── arduino/
│   ├── SledController/
│   │   └── SledController.ino    # ESP32 sled controller firmware
│   ├── JudgeController/
│   │   └── JudgeController.ino   # ESP32 judge display firmware
│   └── README.md                  # Arduino build instructions
├── docs/
│   ├── README.md                  # This file
│   ├── design.md                  # System design
│   └── BACKLOG.md                 # Task tracking
│
│   # Upload Tools (compile from source)
├── upload_firmware.sh             # Mac/Linux upload script
├── upload_firmware.ps1            # Windows PowerShell upload script
├── Upload Firmware (Windows).bat  # Windows launcher (double-click)
│
│   # Flash Tools (pre-compiled binaries)
├── flash_firmware.sh              # Mac/Linux flash script
├── flash_firmware.ps1             # Windows PowerShell flash script
├── Flash Firmware (Windows).bat   # Windows launcher (double-click)
│
│   # Release & Documentation
├── build_release.sh               # Build release package with binaries
├── UPLOAD_GUIDE.md                # User guide for firmware upload
└── release/                       # Generated release packages (git-ignored)
```

## Questions?

If the design documentation doesn't answer your question, check:
- The Arduino README for build details
- The source code comments
- Create an issue in the repository for discussion
