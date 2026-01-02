# SledLink Development Backlog

This backlog outlines the work required to complete the SledLink MVP—a wireless tractor pull distance measurement system. Tasks are organized by phase with dependencies clearly noted.

---

## Legend

| Status | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Completed |
| `[!]` | Blocked |

**Priority**: P0 = Critical path, P1 = High, P2 = Medium, P3 = Nice to have

---

## Phase 1: Hardware Assembly

Hardware must be assembled before software can be developed and tested. The sled unit has more complex hardware dependencies due to the encoder and level shifter.

### 1.1 Judge Controller Hardware

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| HW-J1 | Acquire ESP32-WROOM-32E DevKitC board | P0 | [ ] | None | Same board as sled unit |
| HW-J2 | Acquire 16x2 character LCD (5V, 4-bit parallel) | P0 | [ ] | None | HD44780 compatible |
| HW-J3 | Acquire momentary push button (normally open) | P0 | [ ] | None | For reset function |
| HW-J4 | Acquire 10kΩ resistor for button pull-up | P0 | [ ] | None | GPIO 34 has no internal pull-up |
| HW-J5 | Acquire 5mm LED and 220Ω resistor | P2 | [ ] | None | Optional status indicator |
| HW-J6 | Acquire breadboard and jumper wires | P0 | [ ] | None | For prototyping |
| HW-J7 | Acquire 5V USB power adapter (2A) | P0 | [ ] | None | Powers entire unit |
| HW-J8 | Wire LCD to ESP32 (GPIO 19,23,18,17,16,15) | P0 | [ ] | HW-J1, HW-J2, HW-J6 | 4-bit parallel mode |
| HW-J9 | Wire reset button with pull-up to GPIO 34 | P0 | [ ] | HW-J1, HW-J3, HW-J4 | Active LOW configuration |
| HW-J10 | Wire status LED to GPIO 4 | P2 | [ ] | HW-J1, HW-J5 | Optional but useful |
| HW-J11 | Verify all connections with multimeter | P1 | [ ] | HW-J8, HW-J9 | Before first power-on |
| HW-J12 | Test power delivery to all components | P0 | [ ] | HW-J7, HW-J11 | Confirm 5V and 3.3V rails |

### 1.2 Sled Controller Hardware

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| HW-S1 | Acquire ESP32-WROOM-32E DevKitC board | P0 | [ ] | None | Same board as judge unit |
| HW-S2 | Acquire 16x2 character LCD (5V, 4-bit parallel) | P0 | [ ] | None | HD44780 compatible |
| HW-S3 | Acquire GHW38-06G1000BMC526-200 encoder (1000 PPR) | P0 | [ ] | None | Quadrature output |
| HW-S4 | Acquire 74HCT245 level shifter IC | P0 | [ ] | None | 5-12V to 3.3V conversion |
| HW-S5 | Acquire 10kΩ resistors (x3) for encoder pull-ups | P0 | [ ] | None | Signal conditioning |
| HW-S6 | Acquire 0.1µF capacitors (x3) for noise filtering | P0 | [ ] | None | Signal conditioning |
| HW-S7 | Acquire 12-inch measuring wheel | P0 | [ ] | None | Standard tractor pull size |
| HW-S8 | Acquire 5mm LED and 220Ω resistor | P2 | [ ] | None | Optional status indicator |
| HW-S9 | Acquire breadboard and jumper wires | P0 | [ ] | None | For prototyping |
| HW-S10 | Acquire 5V USB power adapter (2A) | P0 | [ ] | None | Powers entire unit |
| HW-S11 | Build encoder signal conditioning circuit | P0 | [ ] | HW-S4, HW-S5, HW-S6 | Pull-ups → caps → 74HCT245 |
| HW-S12 | Wire encoder to level shifter inputs | P0 | [ ] | HW-S3, HW-S11 | Phase A, B, Z signals |
| HW-S13 | Wire level shifter outputs to ESP32 (GPIO 32,33,25) | P0 | [ ] | HW-S1, HW-S11 | PCNT peripheral pins |
| HW-S14 | Wire LCD to ESP32 (GPIO 19,23,18,17,16,15) | P0 | [ ] | HW-S1, HW-S2, HW-S9 | 4-bit parallel mode |
| HW-S15 | Wire status LED to GPIO 4 | P2 | [ ] | HW-S1, HW-S8 | Optional but useful |
| HW-S16 | Mount encoder to measuring wheel | P0 | [ ] | HW-S3, HW-S7 | Mechanical assembly |
| HW-S17 | Verify all connections with multimeter | P1 | [ ] | HW-S13, HW-S14 | Before first power-on |
| HW-S18 | Test power delivery to all components | P0 | [ ] | HW-S10, HW-S17 | Confirm 5V and 3.3V rails |

---

## Phase 2: Core Software Infrastructure

Foundational code that both controllers depend on. Must be completed before unit-specific features.

### 2.1 Development Environment Setup

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-ENV1 | Install Arduino IDE 2.x or PlatformIO | P0 | [ ] | None | Dev environment |
| SW-ENV2 | Install ESP32 Arduino Core v2.0.x+ | P0 | [ ] | SW-ENV1 | Board support |
| SW-ENV3 | Configure board as ESP32 Dev Module | P0 | [ ] | SW-ENV2 | 240 MHz, 4MB Flash |
| SW-ENV4 | Create project folder structure | P0 | [ ] | SW-ENV1 | Separate sled/judge folders |
| SW-ENV5 | Add .gitignore for build artifacts | P1 | [ ] | SW-ENV4 | Clean repo |

### 2.2 Shared Libraries & Definitions

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-CORE1 | Define DistanceData packet struct (8 bytes) | P0 | [ ] | SW-ENV4 | float distance + uint32_t timestamp |
| SW-CORE2 | Define reset command constant (0xAA) | P0 | [ ] | SW-ENV4 | Single byte command |
| SW-CORE3 | Create shared configuration header | P1 | [ ] | SW-ENV4 | WiFi channel, timing constants |
| SW-CORE4 | Document MAC address exchange procedure | P0 | [ ] | None | Required for ESP-NOW pairing |

---

## Phase 3: Sled Controller Software

Software for the sled unit. Depends on sled hardware assembly and core infrastructure.

### 3.1 LCD Display Module

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-S-LCD1 | Include LiquidCrystal.h library | P0 | [ ] | SW-ENV2 | Standard Arduino library |
| SW-S-LCD2 | Initialize LCD in 4-bit mode | P0 | [ ] | HW-S14, SW-S-LCD1 | GPIO 19,23,18,17,16,15 |
| SW-S-LCD3 | Create displayDistance(float) function | P0 | [ ] | SW-S-LCD2 | Format: "Distance: XXX.XX ft" |
| SW-S-LCD4 | Create displayStartup() function | P1 | [ ] | SW-S-LCD2 | Show init progress |
| SW-S-LCD5 | Create displayReset() function | P0 | [ ] | SW-S-LCD2 | Show "RESET" for 1 second |
| SW-S-LCD6 | Create displayError(String) function | P1 | [ ] | SW-S-LCD2 | Error state display |

### 3.2 Encoder Reading Module (PCNT)

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-S-ENC1 | Include driver/pcnt.h header | P0 | [ ] | SW-ENV2 | ESP32 pulse counter |
| SW-S-ENC2 | Configure PCNT unit 0 for quadrature mode | P0 | [ ] | HW-S13, SW-S-ENC1 | 4x resolution |
| SW-S-ENC3 | Set digital filter value (1023 APB cycles) | P0 | [ ] | SW-S-ENC2 | Noise rejection |
| SW-S-ENC4 | Create initEncoder() function | P0 | [ ] | SW-S-ENC2, SW-S-ENC3 | Complete PCNT setup |
| SW-S-ENC5 | Create readEncoderCount() function | P0 | [ ] | SW-S-ENC4 | Returns int32_t count |
| SW-S-ENC6 | Create resetEncoderCount() function | P0 | [ ] | SW-S-ENC4 | Clears PCNT to zero |
| SW-S-ENC7 | Handle counter overflow/underflow | P1 | [ ] | SW-S-ENC5 | Extend to 32-bit range |
| SW-S-ENC8 | Test encoder accuracy at 1000 RPM | P1 | [ ] | SW-S-ENC5, HW-S16 | Verify 99.9% accuracy |

### 3.3 Distance Calculation Module

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-S-DIST1 | Define WHEEL_DIAMETER_INCHES constant (12.0) | P0 | [ ] | SW-ENV4 | User-configurable |
| SW-S-DIST2 | Define ENCODER_PPR constant (1000) | P0 | [ ] | SW-ENV4 | Fixed for this encoder |
| SW-S-DIST3 | Implement distance formula | P0 | [ ] | SW-S-ENC5, SW-S-DIST1, SW-S-DIST2 | (count/4000) × (π×d/12) |
| SW-S-DIST4 | Create calculateDistance() function | P0 | [ ] | SW-S-DIST3 | Returns float in feet |
| SW-S-DIST5 | Ensure non-negative distance values | P1 | [ ] | SW-S-DIST4 | abs() or clamp to 0 |
| SW-S-DIST6 | Test distance accuracy with known rotation | P1 | [ ] | SW-S-DIST4, HW-S16 | 1 revolution = π×12/12 ft |

### 3.4 ESP-NOW Transmission Module

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-S-TX1 | Include WiFi.h and esp_now.h headers | P0 | [ ] | SW-ENV2 | ESP-NOW libraries |
| SW-S-TX2 | Initialize WiFi in STA mode (no connect) | P0 | [ ] | SW-S-TX1 | MAC address handling |
| SW-S-TX3 | Initialize ESP-NOW protocol | P0 | [ ] | SW-S-TX2 | esp_now_init() |
| SW-S-TX4 | Print own MAC address to serial | P1 | [ ] | SW-S-TX2 | For pairing setup |
| SW-S-TX5 | Add Judge controller as ESP-NOW peer | P0 | [ ] | SW-S-TX3, SW-CORE4 | Hardcoded MAC address |
| SW-S-TX6 | Create transmitDistance(float, uint32_t) function | P0 | [ ] | SW-S-TX5, SW-CORE1 | Sends DistanceData packet |
| SW-S-TX7 | Implement 10 Hz transmission loop | P0 | [ ] | SW-S-TX6, SW-S-DIST4 | 100ms intervals |
| SW-S-TX8 | Register send callback for error handling | P1 | [ ] | SW-S-TX6 | Log transmission failures |

### 3.5 Reset Command Reception

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-S-RX1 | Register ESP-NOW receive callback | P0 | [ ] | SW-S-TX3 | OnDataRecv function |
| SW-S-RX2 | Validate incoming packet (1 byte, 0xAA) | P0 | [ ] | SW-S-RX1, SW-CORE2 | Security check |
| SW-S-RX3 | Call resetEncoderCount() on valid reset | P0 | [ ] | SW-S-RX2, SW-S-ENC6 | Zero the counter |
| SW-S-RX4 | Display reset confirmation on LCD | P0 | [ ] | SW-S-RX3, SW-S-LCD5 | 1 second display |
| SW-S-RX5 | Resume normal operation after reset | P0 | [ ] | SW-S-RX4 | No hang on reset |

### 3.6 Sled Main Program

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-S-MAIN1 | Create setup() function with init sequence | P0 | [ ] | All SW-S init tasks | 5 second max startup |
| SW-S-MAIN2 | Create loop() with 100ms update cycle | P0 | [ ] | SW-S-MAIN1 | Read → Calculate → Display → Transmit |
| SW-S-MAIN3 | Implement INIT → RUNNING state machine | P1 | [ ] | SW-S-MAIN1 | Clean state management |
| SW-S-MAIN4 | Add serial debug output | P2 | [ ] | SW-S-MAIN2 | Development aid |
| SW-S-MAIN5 | Test continuous operation (1+ hour) | P1 | [ ] | SW-S-MAIN2 | Stability check |

---

## Phase 4: Judge Controller Software

Software for the judge unit. Depends on judge hardware assembly and core infrastructure.

### 4.1 LCD Display Module

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-J-LCD1 | Include LiquidCrystal.h library | P0 | [ ] | SW-ENV2 | Standard Arduino library |
| SW-J-LCD2 | Initialize LCD in 4-bit mode | P0 | [ ] | HW-J8, SW-J-LCD1 | GPIO 19,23,18,17,16,15 |
| SW-J-LCD3 | Create displayDistance(float) function | P0 | [ ] | SW-J-LCD2 | Format: "Pull: XXX.XX ft" |
| SW-J-LCD4 | Create displayWaiting() function | P0 | [ ] | SW-J-LCD2 | "Waiting for signal..." |
| SW-J-LCD5 | Create displayNoSignal() function | P0 | [ ] | SW-J-LCD2 | "-- No Signal --" |
| SW-J-LCD6 | Create displayResetSent() function | P0 | [ ] | SW-J-LCD2 | "Reset Sent!" (1 sec) |
| SW-J-LCD7 | Create displayStartup() function | P1 | [ ] | SW-J-LCD2 | Show init progress |
| SW-J-LCD8 | Create displayError(String) function | P1 | [ ] | SW-J-LCD2 | Error state display |

### 4.2 ESP-NOW Reception Module

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-J-RX1 | Include WiFi.h and esp_now.h headers | P0 | [ ] | SW-ENV2 | ESP-NOW libraries |
| SW-J-RX2 | Initialize WiFi in STA mode (no connect) | P0 | [ ] | SW-J-RX1 | MAC address handling |
| SW-J-RX3 | Initialize ESP-NOW protocol | P0 | [ ] | SW-J-RX2 | esp_now_init() |
| SW-J-RX4 | Print own MAC address to serial | P1 | [ ] | SW-J-RX2 | For pairing setup |
| SW-J-RX5 | Add Sled controller as ESP-NOW peer | P0 | [ ] | SW-J-RX3, SW-CORE4 | Hardcoded MAC address |
| SW-J-RX6 | Register ESP-NOW receive callback | P0 | [ ] | SW-J-RX3 | OnDataRecv function |
| SW-J-RX7 | Parse incoming DistanceData packet | P0 | [ ] | SW-J-RX6, SW-CORE1 | Extract float + timestamp |
| SW-J-RX8 | Validate sender MAC address | P1 | [ ] | SW-J-RX7 | Security check |
| SW-J-RX9 | Store last received distance and timestamp | P0 | [ ] | SW-J-RX7 | For display and timeout |
| SW-J-RX10 | Process received data within 10ms | P1 | [ ] | SW-J-RX7 | Performance requirement |

### 4.3 Connection Status Monitoring

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-J-CONN1 | Define CONNECTION_TIMEOUT_MS (2000) | P0 | [ ] | SW-ENV4 | 2 second timeout |
| SW-J-CONN2 | Track lastReceiveTime variable | P0 | [ ] | SW-J-RX9 | millis() timestamp |
| SW-J-CONN3 | Create isConnected() function | P0 | [ ] | SW-J-CONN1, SW-J-CONN2 | Check timeout |
| SW-J-CONN4 | Implement connection state machine | P0 | [ ] | SW-J-CONN3 | WAITING ↔ CONNECTED ↔ LOST |
| SW-J-CONN5 | Update status LED based on state | P2 | [ ] | SW-J-CONN4, HW-J10 | Solid/blink patterns |
| SW-J-CONN6 | Update LCD on state transitions | P0 | [ ] | SW-J-CONN4, SW-J-LCD4, SW-J-LCD5 | Show appropriate message |

### 4.4 Reset Button Module

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-J-BTN1 | Configure GPIO 34 as input | P0 | [ ] | HW-J9 | Input-only GPIO |
| SW-J-BTN2 | Define BUTTON_DEBOUNCE_MS (50) | P0 | [ ] | SW-ENV4 | 50ms debounce |
| SW-J-BTN3 | Implement software debounce logic | P0 | [ ] | SW-J-BTN1, SW-J-BTN2 | Prevent false triggers |
| SW-J-BTN4 | Detect falling edge (HIGH→LOW) | P0 | [ ] | SW-J-BTN3 | Button press detection |
| SW-J-BTN5 | Create buttonPressed() function | P0 | [ ] | SW-J-BTN3, SW-J-BTN4 | Returns true once per press |

### 4.5 Reset Command Transmission

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-J-TX1 | Create sendResetCommand() function | P0 | [ ] | SW-J-RX5, SW-CORE2 | Sends 0xAA byte |
| SW-J-TX2 | Call sendResetCommand() on button press | P0 | [ ] | SW-J-BTN5, SW-J-TX1 | Trigger on press |
| SW-J-TX3 | Display "Reset Sent!" confirmation | P0 | [ ] | SW-J-TX2, SW-J-LCD6 | 1 second display |
| SW-J-TX4 | Clear local distance display to 0.00 | P0 | [ ] | SW-J-TX2 | Immediate feedback |
| SW-J-TX5 | Register send callback for error handling | P1 | [ ] | SW-J-TX1 | Log transmission failures |
| SW-J-TX6 | Transmit reset within 50ms of button press | P1 | [ ] | SW-J-TX2 | Performance requirement |

### 4.6 Judge Main Program

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| SW-J-MAIN1 | Create setup() function with init sequence | P0 | [ ] | All SW-J init tasks | 5 second max startup |
| SW-J-MAIN2 | Create loop() with button polling | P0 | [ ] | SW-J-MAIN1 | Check button each cycle |
| SW-J-MAIN3 | Update display at 100ms intervals max | P0 | [ ] | SW-J-MAIN2 | 10 Hz refresh |
| SW-J-MAIN4 | Check connection timeout each loop | P0 | [ ] | SW-J-MAIN2, SW-J-CONN3 | Detect signal loss |
| SW-J-MAIN5 | Implement state machine (INIT→WAITING→CONNECTED→LOST) | P1 | [ ] | SW-J-MAIN1 | Clean state management |
| SW-J-MAIN6 | Add serial debug output | P2 | [ ] | SW-J-MAIN2 | Development aid |
| SW-J-MAIN7 | Test continuous operation (1+ hour) | P1 | [ ] | SW-J-MAIN2 | Stability check |

---

## Phase 5: Integration & Testing

End-to-end testing of both units working together.

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| INT-1 | Exchange MAC addresses between units | P0 | [ ] | SW-S-TX4, SW-J-RX4 | Serial output |
| INT-2 | Update hardcoded MAC addresses in code | P0 | [ ] | INT-1 | Both units |
| INT-3 | Test basic wireless link (power on both) | P0 | [ ] | INT-2 | Verify ESP-NOW connection |
| INT-4 | Verify distance data transmission at 10 Hz | P0 | [ ] | INT-3 | Check packet rate |
| INT-5 | Verify distance display matches on both LCDs | P0 | [ ] | INT-4 | End-to-end accuracy |
| INT-6 | Test reset button clears both displays | P0 | [ ] | INT-5 | Full reset flow |
| INT-7 | Test connection timeout detection (unplug sled) | P0 | [ ] | INT-5 | 2 second timeout |
| INT-8 | Test reconnection after timeout | P0 | [ ] | INT-7 | Recovery behavior |
| INT-9 | Test at maximum range (~100 feet) | P1 | [ ] | INT-5 | Range verification |
| INT-10 | Test with wheel rotation at various speeds | P1 | [ ] | INT-5 | Accuracy under load |
| INT-11 | Measure end-to-end latency (<100ms) | P1 | [ ] | INT-5 | Performance requirement |
| INT-12 | Run 8+ hour continuous operation test | P1 | [ ] | INT-5 | Reliability requirement |

---

## Phase 6: Documentation & Polish

Final documentation and cleanup tasks.

| ID | Task | Priority | Status | Dependencies | Notes |
|----|------|----------|--------|--------------|-------|
| DOC-1 | Document wheel diameter configuration | P1 | [ ] | SW-S-DIST1 | User guide |
| DOC-2 | Create MAC address setup guide | P0 | [ ] | INT-2 | Required for pairing |
| DOC-3 | Create wiring diagram images | P1 | [ ] | All HW tasks | Visual reference |
| DOC-4 | Write troubleshooting guide | P1 | [ ] | INT-12 | Common issues |
| DOC-5 | Create calibration procedure | P1 | [ ] | INT-10 | Accuracy verification |
| DOC-6 | Record demo video of system operation | P2 | [ ] | INT-12 | MVP deliverable |
| DOC-7 | Clean up code comments | P2 | [ ] | All SW tasks | Code quality |
| DOC-8 | Verify no compiler warnings | P1 | [ ] | All SW tasks | Code quality |
| DOC-9 | Final README update with setup instructions | P1 | [ ] | DOC-2 | Getting started |

---

## Dependency Graph Overview

```
Hardware Assembly
       │
       ├── Sled Hardware (HW-S*) ──────┐
       │                               │
       └── Judge Hardware (HW-J*) ──┐  │
                                    │  │
Core Infrastructure (SW-ENV*, SW-CORE*)
       │                            │  │
       ├───────────────────────────┬┘  │
       │                           │   │
       ▼                           ▼   │
Sled Software (SW-S-*)      Judge Software (SW-J-*)
       │                           │
       └─────────┬─────────────────┘
                 │
                 ▼
        Integration Testing (INT-*)
                 │
                 ▼
        Documentation (DOC-*)
```

---

## Sprint Suggestions

### Sprint 1: Foundation (Hardware + Environment)
- All Phase 1 tasks (HW-J*, HW-S*)
- Phase 2 environment setup (SW-ENV*)
- Phase 2 shared definitions (SW-CORE*)

### Sprint 2: Sled Controller MVP
- Sled LCD module (SW-S-LCD*)
- Encoder reading (SW-S-ENC*)
- Distance calculation (SW-S-DIST*)
- Sled main program basics (SW-S-MAIN1, SW-S-MAIN2)

### Sprint 3: Sled Wireless + Judge LCD
- Sled ESP-NOW transmission (SW-S-TX*)
- Sled reset reception (SW-S-RX*)
- Judge LCD module (SW-J-LCD*)

### Sprint 4: Judge Controller MVP
- Judge ESP-NOW reception (SW-J-RX*)
- Connection monitoring (SW-J-CONN*)
- Reset button (SW-J-BTN*)
- Reset transmission (SW-J-TX*)
- Judge main program (SW-J-MAIN*)

### Sprint 5: Integration & Documentation
- All integration tests (INT-*)
- All documentation tasks (DOC-*)

---

## Notes

- Tasks marked P0 are on the critical path and block other work
- Hardware acquisition may have lead times; order early
- MAC address exchange (INT-1, INT-2) is a common stumbling block
- Test wireless range early to catch antenna issues
