# SledLink Arduino Projects

Arduino-based firmware for the SledLink tractor pull distance measurement system.

## System Overview

SledLink consists of two ESP32 units communicating wirelessly via ESP-NOW:

```
┌─────────────────────┐    ESP-NOW    ┌─────────────────────┐
│   SLED CONTROLLER   │ ───────────►  │  JUDGE CONTROLLER   │
│   (on the sled)     │  <distance>   │  (at judge's table) │
│                     │               │                     │
│ - Rotary encoder    │               │ - LCD display       │
│ - Distance calc     │               │                     │
│ - LCD display       │               │                     │
│ - Reset button      │               │                     │
└─────────────────────┘               └─────────────────────┘
```

---

## SledController

The sled controller reads a quadrature encoder attached to the measuring wheel, calculates distance, displays on LCD, and transmits wirelessly to the Judge Controller.

### Hardware

| Component | Wire/Pin | ESP32 GPIO | Notes |
|-----------|----------|------------|-------|
| Encoder Phase A | Green | GPIO 32 | PCNT pulse input |
| Encoder Phase B | White | GPIO 33 | PCNT direction |
| Encoder Vcc | Red | 5V | |
| Encoder GND | Black | GND | |
| Reset Button | - | GPIO 27 | Active LOW, internal pullup |
| LCD RS | - | GPIO 19 | Register select |
| LCD EN | - | GPIO 23 | Enable |
| LCD D4-D7 | - | GPIO 18,17,16,15 | 4-bit data |

### Encoder: GHW38 Series

- **Resolution:** 1000 PPR (4000 counts/rev with 4x quadrature)
- **Output:** NPN open-collector (uses ESP32 internal pull-ups)
- **Supply:** 5V (from ESP32 USB power)

### Measuring Wheel

- **Diameter:** 2.5 inches (configurable)
- **Circumference:** 7.85 inches
- **Resolution:** ~0.002 inches per count

### Features

- Hardware quadrature decoding using ESP32 PCNT peripheral
- Accumulating mode (positive distance only, backward motion ignored)
- Button cycles through states: ACCUMULATING → HOLD → RESET
- 16x2 LCD display showing distance and state
- ESP-NOW wireless transmission at 10 Hz
- Serial output at 115200 baud

---

## JudgeController

The judge controller receives distance data wirelessly from the Sled Controller and displays on LCD. It is a receive-only display unit.

### Hardware

| Component | ESP32 GPIO | Notes |
|-----------|------------|-------|
| LCD RS | GPIO 19 | Register select |
| LCD EN | GPIO 23 | Enable |
| LCD D4-D7 | GPIO 18,17,16,15 | 4-bit data |

### LCD Wiring (16x2 HD44780)

Both controllers use the same LCD pinout. Cable colors (pin 1 to 16):

| Pin | Function | Wire Color | Connection |
|-----|----------|------------|------------|
| 1 | VSS | Brown | GND |
| 2 | VDD | Red | 5V |
| 3 | V0 | Orange | Contrast (10K pot or GND) |
| 4 | RS | Yellow | GPIO 19 |
| 5 | RW | Green | GND (write only) |
| 6 | E | Blue | GPIO 23 |
| 7 | D0 | Violet | (not used in 4-bit mode) |
| 8 | D1 | Grey | (not used in 4-bit mode) |
| 9 | D2 | White | (not used in 4-bit mode) |
| 10 | D3 | Black | (not used in 4-bit mode) |
| 11 | D4 | Brown | GPIO 18 |
| 12 | D5 | Red | GPIO 17 |
| 13 | D6 | Orange | GPIO 16 |
| 14 | D7 | Yellow | GPIO 15 |
| 15 | A | Green | 5V (backlight +) |
| 16 | K | Blue | GND (backlight -) |

### Features

- ESP-NOW wireless reception at 10 Hz
- 16x2 LCD display showing pull distance
- Connection status monitoring (2-second timeout)
- Serial output at 115200 baud

---

## Wireless Pairing

Both controllers must know each other's MAC addresses. Follow these steps:

### Step 1: Upload Firmware

Upload the firmware to both ESP32 units without modifying MAC addresses yet.

### Step 2: Get MAC Addresses

Open serial monitor (115200 baud) for each unit and note the MAC address printed at startup:

**Sled Controller output:**
```
Initializing ESP-NOW wireless...
  Sled MAC Address: AA:BB:CC:DD:EE:FF
```

**Judge Controller output:**
```
Initializing ESP-NOW wireless...
  Judge MAC Address: 11:22:33:44:55:66
```

### Step 3: Update Firmware with MAC Addresses

Edit both sketches with the exchanged MAC addresses:

**In SledController.ino:**
```cpp
// Replace with your Judge Controller's MAC address
uint8_t judgeMAC[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66};
```

**In JudgeController.ino:**
```cpp
// Replace with your Sled Controller's MAC address
uint8_t sledMAC[] = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF};
```

### Step 4: Re-upload Both

Upload the updated firmware to both units. They should now communicate.

---

## Connection Behavior

ESP-NOW is **connectionless** (like UDP) - there's no connection to establish or maintain. The Sled continuously broadcasts at 10 Hz, and the Judge listens and displays whatever it receives.

### Automatic Recovery

| Scenario | Behavior |
|----------|----------|
| Judge starts first | Shows "Waiting..." until Sled transmits |
| Sled starts first | Transmits to air, Judge picks up when powered on |
| Sled loses power | Judge shows "No Signal" after 2 sec, auto-recovers when Sled returns |
| Judge loses power | Immediately receives Sled data when powered back on |
| Units go out of range | Judge shows "No Signal", auto-recovers when back in range |

**No reconnection logic needed** - the system automatically recovers from any interruption.

### Testing Checklist

1. Power on Judge first → Shows "Waiting..." / "No Signal"
2. Power on Sled → Judge shows distance within 1 second
3. Unplug Sled → Judge shows "No Signal" after 2 seconds
4. Plug Sled back in → Judge auto-recovers, shows distance
5. Walk Sled out of range → Judge shows "No Signal"
6. Walk back in range → Auto-recovers

---

## Building and Uploading

### Option 1: Arduino IDE

#### Setup (One Time)

1. Install [Arduino IDE 2.x](https://www.arduino.cc/en/software)
2. Add ESP32 board support:
   - File → Preferences → Additional Board Manager URLs
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
3. Tools → Board → Boards Manager → Search "esp32" → Install "esp32 by Espressif"
4. Install LiquidCrystal library:
   - Tools → Manage Libraries → Search "LiquidCrystal" → Install "LiquidCrystal by Arduino"

#### Build and Upload

1. Open `arduino/SledController/SledController.ino` or `arduino/JudgeController/JudgeController.ino`
2. Select board: Tools → Board → ESP32 Arduino → "ESP32 Dev Module"
3. Select port: Tools → Port → COM3 (your port)
4. Click Upload (→ button)

### Option 2: Arduino CLI

#### Setup (One Time)

```bash
# Install Arduino CLI
# Windows: winget install ArduinoSA.CLI
# Mac: brew install arduino-cli
# Linux: curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh

# Configure ESP32 support
arduino-cli config init
arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
arduino-cli core update-index
arduino-cli core install esp32:esp32

# Install required libraries
arduino-cli lib install "LiquidCrystal"
```

#### Build and Upload

```bash
# Compile Sled Controller
arduino-cli compile --fqbn esp32:esp32:esp32 arduino/SledController

# Compile Judge Controller
arduino-cli compile --fqbn esp32:esp32:esp32 arduino/JudgeController

# Upload (replace COM3 with your port)
arduino-cli upload -p COM3 --fqbn esp32:esp32:esp32 arduino/SledController
arduino-cli upload -p COM4 --fqbn esp32:esp32:esp32 arduino/JudgeController

# Monitor serial output
arduino-cli monitor -p COM3 -c baudrate=115200
```

---

## Serial Monitor

After uploading, open a serial monitor at **115200 baud** to see output.

### Arduino IDE
Tools → Serial Monitor → Set baud to 115200

### Arduino CLI
```bash
arduino-cli monitor -p COM3 -c baudrate=115200
```

### PuTTY
- Connection type: Serial
- Serial line: COM3 (your port)
- Speed: 115200

---

## Expected Output

### Sled Controller

```
========================================
  SledLink Sled Controller v2.0
  Tractor Pull Distance Measurement
========================================

Configuration:
  Encoder Phase A: GPIO 32 (Green)
  Encoder Phase B: GPIO 33 (White)
  Reset Button: GPIO 27
  Encoder: 1000 PPR x4 = 4000 counts/rev
  Wheel diameter: 2.50 inches
  Mode: Quadrature (direction detection enabled)

Initializing LCD display...
  LCD initialized
Initializing PCNT quadrature encoder...
  Initial pin states: A=1, B=1 (should be 1,1 with pull-ups)
  PCNT quadrature encoder initialized successfully
Initializing reset button on GPIO 27...
  Button initialized
Initializing ESP-NOW wireless...
  Sled MAC Address: AA:BB:CC:DD:EE:FF
  ESP-NOW initialized
  Judge peer added
  Wireless initialization complete

Initialization complete.
Spin encoder to see distance. Press button to reset.

Count      | Distance   | TX Status
-----------|------------|----------
      4000 |    0.65 ft | TX
      8000 |    1.31 ft | TX
         0 |    0.00 ft | RESET
```

### Judge Controller

```
========================================
  SledLink Judge Controller v2.0
  Tractor Pull Distance Display
========================================

Configuration:
  LCD RS: GPIO 19
  LCD EN: GPIO 23
  LCD D4-D7: GPIO 18, 17, 16, 15
  Connection timeout: 2000 ms

Initializing LCD display...
  LCD initialized
Initializing ESP-NOW wireless...
  Judge MAC Address: 11:22:33:44:55:66
  ESP-NOW initialized
  Sled peer added
  Wireless initialization complete

Initialization complete.
Waiting for signal from Sled Controller...

Distance   | Status     | Timestamp
-----------|------------|----------
   0.65 ft | CONNECTED  | 1234
   1.31 ft | RX         | 1334
   0.00 ft | RX         | 1534
```

---

## Troubleshooting

### Build error: LiquidCrystal.h not found
- The LiquidCrystal library is not bundled with ESP32 core
- Install it: `arduino-cli lib install "LiquidCrystal"`
- Or in Arduino IDE: Tools → Manage Libraries → Search "LiquidCrystal" → Install

### No serial output
- Check COM port is correct
- Check baud rate is 115200
- Press EN/Reset button on ESP32

### Encoder not counting
- Verify GND is connected (encoder and ESP32 must share ground)
- Check Vcc is connected to 5V
- Initial pin states should show `A=1, B=1`

### Count oscillating 0-1 (no encoder connected)
- This is noise on floating pins
- Connect encoder or ignore until hardware ready

### Wrong distance displayed
- Verify `ENCODER_PPR` matches your encoder (1000 for GHW38)
- Verify `WHEEL_DIAMETER_INCHES` matches your wheel (2.5)

### Button not working (Sled Controller)
- Button should connect GPIO 27 to GND when pressed
- Internal pull-up keeps pin HIGH when not pressed

### No wireless communication
- Verify MAC addresses are correctly entered in both sketches
- Both units must be powered and initialized
- Check serial output for "ESP-NOW initialized" and "peer added" messages
- Ensure units are within range (~100 feet line of sight)

### Judge shows "No Signal"
- Sled Controller may not be powered or transmitting
- Check MAC address configuration
- Connection timeout is 2 seconds - wait for signal to resume
