# JUDGE CONTROLLER - TECHNICAL REQUIREMENTS DOCUMENT

**Project:** Tractor Pull Distance Measurement System  
**Component:** Judge Controller Unit  
**Version:** 1.0  
**Date:** December 29, 2025  
**Author:** Corey Thompson / Tulsa Software

---

## 1. OVERVIEW

### 1.1 Purpose
The Judge Controller is a stationary unit positioned at the judge's table. It receives real-time distance data wirelessly from the Sled Controller and displays the pull distance. The reset button is located on the Sled Controller for local operation.

### 1.2 Scope
This document defines hardware specifications, software requirements, functional behaviors, performance criteria, and test requirements for the Judge Controller MVP.

---

## 2. HARDWARE SPECIFICATIONS

### 2.1 Microcontroller
- **Model:** ESP32-WROOM-32E on DevKitC development board
- **CPU:** Dual-core Xtensa LX6, 240 MHz
- **RAM:** 520 KB SRAM
- **Flash:** 4 MB
- **Operating Voltage:** 3.3V logic
- **Power Input:** 5V via USB or VIN pin

### 2.2 Display
- **Type:** 16x2 Character LCD (parallel interface)
- **Interface:** 4-bit parallel mode
- **Operating Voltage:** 5V
- **Backlight:** LED with current limiting resistor (220Î© recommended)
- **Contrast Control:** 10kÎ© potentiometer or fixed resistor

**Pin Connections:**
- RS (Register Select)
- E (Enable)
- D4, D5, D6, D7 (Data lines)
- RW tied to GND (write-only mode)
- VSS to GND, VDD to 5V
- A (backlight anode), K (backlight cathode)

### 2.3 Power Supply
- **MVP Configuration:** 5V USB power adapter (wall power)
- **Current Budget:**
  - ESP32: ~80mA (ESP-NOW receiving mode)
  - LCD with backlight: ~50mA
  - **Total:** ~130mA
  - **Recommended Supply:** 5V 2A USB wall adapter

**Production Configuration (Future):**
- Same as MVP (AC power expected at judge's table)
- Optional: USB power bank for portable operation

### 2.4 Assembly
- **Prototype Platform:** Solderless breadboard (830 tie-points minimum)
- **Wiring:** 22-24 AWG jumper wires
- **Enclosure:** Basic project box (future, not MVP)

---

## 3. GPIO PIN ASSIGNMENT

### 3.1 LCD Display (4-bit Parallel)
| LCD Pin | ESP32 GPIO | Purpose |
|---------|-----------|---------|
| RS | GPIO 19 | Register Select |
| E | GPIO 23 | Enable pulse |
| D4 | GPIO 18 | Data bit 4 |
| D5 | GPIO 17 | Data bit 5 |
| D6 | GPIO 16 | Data bit 6 |
| D7 | GPIO 15 | Data bit 7 |
| RW | GND | Write mode (tied low) |

### 3.2 Reserved Pins
- GPIO 34-39: Input-only, no internal pull-ups (require external pull-ups for buttons)
- GPIO 0, 2: Used for boot mode selection (avoid or use carefully)
- GPIO 1, 3: UART TX/RX (used for programming/debug)
- GPIO 6-11: Connected to flash (do not use)

---

## 4. SOFTWARE REQUIREMENTS

### 4.1 Development Environment
- **Framework:** Arduino IDE 2.x or PlatformIO
- **Board Support:** ESP32 Arduino Core (v2.0.x or later)
- **Programming Language:** C/C++ (Arduino framework)
- **Libraries Required:**
  - `WiFi.h` (built-in, for MAC address)
  - `esp_now.h` (built-in, for wireless communication)
  - `LiquidCrystal.h` (built-in, for LCD control)
  - `Preferences.h` (built-in, for non-volatile storage - future use)

### 4.2 Functional Requirements

#### FR-J1: Distance Data Reception
- **FR-J1.1:** System SHALL receive distance data from Sled Controller via ESP-NOW
- **FR-J1.2:** System SHALL accept data packets from known Sled MAC address
- **FR-J1.3:** Received data SHALL include:
  - Distance value (float, feet)
  - Timestamp (uint32_t, milliseconds)
- **FR-J1.4:** System SHALL process received data within 10ms of reception
- **FR-J1.5:** System SHALL track time of last successful data reception
- **FR-J1.6:** System SHALL operate on WiFi channel 1 (default, configurable for future)

#### FR-J2: Distance Display
- **FR-J2.1:** System SHALL display received distance on 16x2 LCD
- **FR-J2.2:** Display format: "Pull Distance: XXX.XX ft" or similar
- **FR-J2.3:** System SHALL update display within 100ms of receiving new data
- **FR-J2.4:** Distance SHALL be displayed with 2 decimal places
- **FR-J2.5:** System SHALL display "Waiting..." or similar when no data received
- **FR-J2.6:** LCD SHALL initialize within 2 seconds of power-on

#### FR-J3: Connection Status Monitoring
- **FR-J3.1:** System SHALL monitor connection status with Sled Controller
- **FR-J3.2:** Connection considered ACTIVE if data received within last 2 seconds
- **FR-J3.3:** Connection considered INACTIVE if no data for >2 seconds
- **FR-J3.4:** System SHALL display connection status on LCD:
  - Active: Normal distance display
  - Inactive: "-- No Signal --" or similar message
#### FR-J4: Initialization and Startup
- **FR-J4.1:** System SHALL initialize all peripherals within 5 seconds of power-on
- **FR-J4.2:** System SHALL display startup message indicating initialization progress
- **FR-J4.3:** System SHALL print MAC address to serial console during startup
- **FR-J4.4:** System SHALL verify ESP-NOW initialization success
- **FR-J4.5:** System SHALL add Sled Controller as ESP-NOW peer during setup
- **FR-J4.6:** System SHALL display error message if initialization fails
- **FR-J4.7:** System SHALL transition to "Waiting for Signal" state after successful init

#### FR-J5: Error Handling
- **FR-J5.1:** System SHALL display error on LCD if ESP-NOW init fails
- **FR-J5.2:** System SHALL log errors to serial console for debugging
- **FR-J5.3:** System SHALL NOT crash or hang on communication errors

### 4.3 Non-Functional Requirements

#### NFR-J1: Performance
- **NFR-J1.1:** Display update latency SHALL NOT exceed 100ms from data reception
- **NFR-J1.2:** CPU utilization SHALL remain below 30% during normal operation
- **NFR-J1.3:** System SHALL operate continuously for 24+ hours without reboot

#### NFR-J2: Reliability
- **NFR-J2.1:** System SHALL recover from temporary wireless communication loss
- **NFR-J2.2:** System SHALL handle power interruptions gracefully
- **NFR-J2.3:** System SHALL NOT require manual reset under normal operation
- **NFR-J2.4:** MTBF (Mean Time Between Failures) target: >200 hours continuous operation

#### NFR-J3: Usability
- **NFR-J3.1:** Display text SHALL be readable from 3 feet distance (with backlight on)
- **NFR-J3.2:** System status SHALL be immediately obvious to user (connected vs. waiting)
- **NFR-J3.3:** No user training required for operation (display-only unit)

#### NFR-J4: Maintainability
- **NFR-J4.1:** Code SHALL be commented explaining all major functions
- **NFR-J4.2:** Variable names SHALL be descriptive and follow consistent naming convention
- **NFR-J4.3:** Magic numbers SHALL be avoided; use named constants
- **NFR-J4.4:** Code SHALL be structured with clear separation of concerns

#### NFR-J5: Code Quality
- **NFR-J5.1:** No compiler warnings at default warning level
- **NFR-J5.2:** Memory leaks SHALL NOT occur
- **NFR-J5.3:** Global variables SHALL be minimized
- **NFR-J5.4:** Functions SHALL NOT exceed 50 lines (guideline)

---

## 5. DATA STRUCTURES

### 5.1 Distance Data Packet (Received)
```cpp
typedef struct {
  float distance;        // Distance in feet (4 bytes)
  uint32_t timestamp;    // Milliseconds since sled boot (4 bytes)
} DistanceData;
// Total: 8 bytes
```

---

## 6. CONFIGURATION CONSTANTS

### 6.1 System Constants
```cpp
#define UPDATE_RATE_MS 100           // Display refresh rate (10 Hz)
#define CONNECTION_TIMEOUT_MS 2000   // Consider disconnected after 2 sec
```

### 6.2 Network Configuration
```cpp
uint8_t sledMAC[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};  // To be replaced with actual MAC
```

### 6.3 Display Messages
```cpp
const char* MSG_STARTUP = "Judge Display";
const char* MSG_INIT = "Initializing...";
const char* MSG_WAITING = "Waiting...";
const char* MSG_NO_SIGNAL = "-- No Signal --";
```

---

## 7. STATE MACHINE

### 7.1 System States
```
INIT â†’ WAITING_FOR_SIGNAL â†â†’ CONNECTED
  â†“                               â†“
ERROR                     SIGNAL_LOST â†’ WAITING_FOR_SIGNAL
```

**State Descriptions:**
- **INIT:** Power-on, peripheral initialization, ESP-NOW setup
- **WAITING_FOR_SIGNAL:** No data from Sled, display "Waiting..." message
- **CONNECTED:** Actively receiving distance data, display distance
- **SIGNAL_LOST:** No data received for >2 seconds, display "No Signal" message
- **ERROR:** Initialization failure, display error message, halt

**State Transitions:**
- WAITING_FOR_SIGNAL â†’ CONNECTED: First valid data packet received
- CONNECTED â†’ SIGNAL_LOST: No data for >2 seconds
- SIGNAL_LOST â†' CONNECTED: Data reception resumes

---

## 8. USER INTERFACE SPECIFICATIONS

### 8.1 LCD Display Layouts

#### Layout 1: Startup
```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚Judge Display   â”‚
â”‚Initializing... â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

#### Layout 2: Waiting for Signal
```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚Waiting...      â”‚
â”‚-- No Signal -- â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

#### Layout 3: Connected - Displaying Distance
```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚Pull Distance:  â”‚
â”‚245.67 ft       â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

#### Layout 4: Error State
```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ESP-NOW Failed! â”‚
â”‚Check Wiring    â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

---

## 9. ERROR HANDLING

### 9.1 Critical Errors (System Halt)
- ESP-NOW initialization failure
- LCD initialization failure
- Peer add failure (cannot communicate with sled)

**Behavior:** Display error message on LCD (if possible), print to serial, infinite loop/halt

### 9.2 Non-Critical Errors (Log and Continue)
- Malformed data packet received
- Connection timeout/signal loss

**Behavior:** Log to serial console, display appropriate message, continue operation

### 9.3 Recovery Mechanisms
- **Signal Loss:** Automatically reconnect when sled data resumes
- **Invalid Data:** Ignore packet, wait for next valid transmission

---

## 10. TESTING REQUIREMENTS

### 10.1 Unit Tests

#### UT-J1: Display Initialization
- **Test:** Power on Judge Controller
- **Expected:** LCD displays startup message within 2 seconds
- **Pass Criteria:** Clean text display, no garbage characters

#### UT-J2: ESP-NOW Reception
- **Test:** Sled transmits distance data
- **Expected:** Judge receives and displays distance correctly
- **Pass Criteria:** Distance matches sled within 0.01 ft

#### UT-J3: Connection Timeout
- **Test:** Power off Sled while Judge is connected
- **Expected:** After 2 seconds, Judge displays "No Signal" message
- **Pass Criteria:** Timeout occurs within 2.0-2.5 seconds

### 10.2 Integration Tests

#### IT-J1: End-to-End Communication
- **Test:** Sled and Judge both powered, simulate pull
- **Expected:** Judge displays same distance as Sled in real-time
- **Pass Criteria:** Distance match within Â±0.05 ft, <200ms latency

#### IT-J2: Reset Cycle
- **Test:** Measure distance, press reset on sled controller, measure again
- **Expected:** Sled resets to zero, Judge displays zero, new measurement accurate
- **Pass Criteria:** Clean reset, accurate subsequent measurement

#### IT-J3: Reconnection After Signal Loss
- **Test:** Power cycle Sled while Judge is running
- **Expected:** Judge detects loss, then reconnects when Sled returns
- **Pass Criteria:** Automatic reconnection within 1 second

#### IT-J4: Range Test
- **Test:** Separate units by 100 feet, verify operation
- **Expected:** Continuous communication, no dropouts
- **Pass Criteria:** >99% packet success rate over 1 minute

### 10.3 Acceptance Tests

#### AT-J1: User Experience Test
- **Test:** Non-technical user operates system for 10 pull cycles
- **Expected:** User can successfully reset and read distances
- **Pass Criteria:** No confusion, no errors, no assistance needed

#### AT-J2: Continuous Operation
- **Test:** Run Judge Controller for 8 hours continuously
- **Expected:** Stable operation, no crashes or degradation
- **Pass Criteria:** System remains responsive throughout

#### AT-J3: Multi-Pull Simulation
- **Test:** Simulate 50 consecutive pulls with resets
- **Expected:** Consistent operation, accurate resets each time
- **Pass Criteria:** 100% success rate on resets and measurements

---

## 11. POWER CONSUMPTION ANALYSIS

### 11.1 Current Draw Estimates
| Component | Typical | Peak | Notes |
|-----------|---------|------|-------|
| ESP32 (ESP-NOW RX) | 80 mA | 100 mA | Receiving mode, no TX |
| LCD with backlight | 50 mA | 60 mA | Depends on contrast |
| **Total (5V rail)** | **130 mA** | **160 mA** | |

### 11.2 Power Supply Sizing
- Minimum supply: 5V 500mA
- Recommended: 5V 2A (headroom for reliability)
- Typical consumption: 0.65W
- Daily energy: 15.6 Wh (24 hours @ 0.65W)

---

## 12. SERIAL DEBUG OUTPUT

### 12.1 Startup Messages
```
Judge Distance Display System
Initializing...
Judge MAC Address: XX:XX:XX:XX:XX:XX
ESP-NOW initialized
Sled peer added
LCD initialized
System ready - Waiting for signal...
```

### 12.2 Runtime Debug (Optional)
```
RX: Distance=123.45 ft, TS=12345
RX: Distance=156.78 ft, TS=12456
Connection lost (timeout)
RX: Distance=2.34 ft, TS=50
Connection restored
```

---

## 13. FUTURE ENHANCEMENTS (NOT MVP)

### 13.1 Hardware
- Larger display (20x4 LCD or OLED)
- Additional buttons (menu navigation, settings)
- Buzzer for audio feedback
- External antenna for extended range
- Portable battery option

### 13.2 Software
- Multi-sled support with channel selection
- On-screen configuration menu
- Pull history display (last 5-10 pulls)
- Leaderboard mode (best pull of day)
- Data export via USB
- OTA firmware updates

### 13.3 Features
- Competitor name entry and display
- Pull timer (measure pull duration)
- Speed calculation (ft/sec)
- Web dashboard integration
- Remote configuration via WiFi

---

## 14. COMPLIANCE AND STANDARDS

### 14.1 Electrical Safety
- Use UL/CE certified USB power adapter
- Ensure proper current ratings for all wiring
- Provide strain relief for cables
- Follow proper grounding practices

### 14.2 Usability Standards
- Display contrast for outdoor visibility
- Clear labeling of controls
- Intuitive operation without manual

### 14.3 Code Standards
- Follow Arduino style guide
- Use consistent indentation (2 or 4 spaces)
- Comment all non-obvious code
- Include header comments with author, date, purpose

---

## 15. DOCUMENTATION DELIVERABLES

### 15.1 Hardware Documentation
- Breadboard wiring diagram (Fritzing or schematic)
- Pin assignment table
- Component list with part numbers
- Power supply specifications

### 15.2 Software Documentation
- Source code with inline comments
- GitHub repository with README
- Firmware update procedure
- Troubleshooting flowchart

### 15.3 User Documentation
- Quick start guide
- Operating instructions (power on, read distance)
- What to do if "No Signal" appears
- Basic troubleshooting (power cycle, check connections)

---

## 16. RISK MITIGATION

### 16.1 Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ESP-NOW range insufficient | Low | Medium | Early range testing, backup plan for external antenna |
| LCD difficult to read outdoors | Medium | Low | Test contrast adjustment, consider OLED upgrade |
| Power supply failure at venue | Low | High | Use quality power adapter, provide backup |
| Wireless interference | Medium | Medium | Channel selection capability (future), shielded environment testing |

### 16.2 Contingency Plans
- If range issues: Add external antenna or WiFi repeater
- If display issues: Increase backlight, adjust contrast, shade from sun
- If power issues: Battery backup option
- If interference: Change WiFi channel, increase transmission power

---

## 17. SIGN-OFF

### 17.1 Requirements Review
- [ ] Hardware specifications reviewed and approved
- [ ] Software requirements reviewed and approved
- [ ] User interface design reviewed and approved
- [ ] Test plan reviewed and approved
- [ ] Documentation plan reviewed and approved

### 17.2 Acceptance Criteria
System is considered complete and acceptable when:
- All FR (Functional Requirements) are met
- All UT (Unit Tests) pass
- All IT (Integration Tests) pass
- All AT (Acceptance Tests) pass
- All documentation deliverables provided
- Customer demonstration successful
- User can operate without assistance

---

**Document Version:** 1.0  
**Last Updated:** December 29, 2025  
**Author:** Corey Thompson, Tulsa Software  
**Status:** Draft for Review