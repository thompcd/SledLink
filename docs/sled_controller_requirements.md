# SLED CONTROLLER - TECHNICAL REQUIREMENTS DOCUMENT

**Project:** Tractor Pull Distance Measurement System  
**Component:** Sled Controller Unit  
**Version:** 1.0  
**Date:** December 29, 2025  
**Author:** Corey Thompson / Tulsa Software

---

## 1. OVERVIEW

### 1.1 Purpose
The Sled Controller is mounted on the tractor pull sled and serves as the primary distance measurement unit. It reads rotary encoder input from a measuring wheel, calculates real-time pull distance, displays the distance locally, and transmits distance data wirelessly to the Judge Controller.

### 1.2 Scope
This document defines hardware specifications, software requirements, functional behaviors, performance criteria, and test requirements for the Sled Controller MVP.

---

## 2. HARDWARE SPECIFICATIONS

### 2.1 Microcontroller
- **Model:** ESP32-WROOM-32E on DevKitC development board
- **CPU:** Dual-core Xtensa LX6, 240 MHz
- **RAM:** 520 KB SRAM
- **Flash:** 4 MB
- **Operating Voltage:** 3.3V logic
- **Power Input:** 5V via USB or VIN pin

### 2.2 Rotary Encoder Interface
- **Encoder Model:** GHW38-06G1000BMC526-200
- **Type:** Incremental rotary encoder with quadrature output
- **Resolution:** 1000 PPR (Pulses Per Revolution)
- **Output Signals:** 
  - Phase A (quadrature)
  - Phase B (quadrature)  
  - Phase Z (index/home position, optional)
- **Output Voltage:** 5V
- **Signal Type:** NPN open-collector (uses ESP32 internal pull-ups)

### 2.3 Display
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

### 2.4 Reset Button
- **Type:** Momentary push button, normally open (NO)
- **Configuration:** Active LOW with external 10kΩ pull-up resistor to 3.3V
- **Debouncing:** Software debounce (50ms minimum delay)
- **Mounting:** Panel-mount or breadboard-friendly tactile switch
- **Purpose:** Zero the encoder and distance measurement for the next pull

**Note:** GPIO 34 is input-only and has no internal pull-up, so external pull-up resistor is required.

### 2.5 Power Supply
- **MVP Configuration:** 5V USB power supply
- **Current Budget:**
  - ESP32: ~160mA (ESP-NOW active), ~240mA (peak WiFi)
  - Encoder: ~60mA @ 12V (separate supply for production)
  - LCD with backlight: ~50mA
  - **Total MVP (5V rail):** ~250-300mA
  - **Recommended Supply:** 5V 2A USB adapter

**Production Configuration (Future):**
- 12V battery (3S LiPo or SLA)
- LM2596 buck converter (12V â†' 5V, 3A rated)
- Encoder powered by 12V directly

### 2.6 Assembly
- **Prototype Platform:** Solderless breadboard (830 tie-points minimum)
- **Wiring:** 22-24 AWG jumper wires
- **Encoder Cable:** Shielded twisted pair recommended (3+ conductors)

---

## 3. GPIO PIN ASSIGNMENT

### 3.1 Encoder Interface
| Signal | ESP32 GPIO | Direction | Purpose |
|--------|-----------|-----------|---------|
| Encoder Phase A | GPIO 32 | Input | PCNT pulse input |
| Encoder Phase B | GPIO 33 | Input | PCNT control (direction) |
| Encoder Phase Z | GPIO 25 | Input | Index/zero reference (optional) |

**Notes:**
- GPIOs 32, 33 support ADC and can be used with PCNT peripheral
- GPIO 25 available for optional index pulse monitoring
- Encoder uses NPN open-collector outputs with ESP32 internal pull-ups enabled

### 3.2 LCD Display (4-bit Parallel)
| LCD Pin | ESP32 GPIO | Purpose |
|---------|-----------|---------|
| RS | GPIO 19 | Register Select |
| E | GPIO 23 | Enable pulse |
| D4 | GPIO 18 | Data bit 4 |
| D5 | GPIO 17 | Data bit 5 |
| D6 | GPIO 16 | Data bit 6 |
| D7 | GPIO 15 | Data bit 7 |
| RW | GND | Write mode (tied low) |

### 3.3 Reset Button
| Component | ESP32 GPIO | Configuration | Purpose |
|-----------|-----------|---------------|---------|
| Reset Button | GPIO 34 | INPUT with external pull-up | Zero distance measurement |

**Note:** GPIO 34 is input-only and has no internal pull-up, so external 10kΩ pull-up resistor to 3.3V is required.

### 3.4 Reserved Pins
- GPIO 34-39: Input-only, no internal pull-ups (avoid for buttons)
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
  - `Preferences.h` (built-in, for non-volatile storage)
  - `driver/pcnt.h` (built-in, for pulse counter peripheral)

### 4.2 Functional Requirements

#### FR-S1: Encoder Reading
- **FR-S1.1:** System SHALL read quadrature encoder signals using ESP32 PCNT peripheral
- **FR-S1.2:** System SHALL decode encoder in quadrature mode (4x resolution)
- **FR-S1.3:** System SHALL track encoder direction (forward/backward counting)
- **FR-S1.4:** System SHALL apply digital filtering to reject noise pulses (filter value â‰¥1023 APB clock cycles)
- **FR-S1.5:** System SHALL handle counter overflow/underflow gracefully
- **FR-S1.6:** System SHALL achieve counting accuracy â‰¥99.9% at speeds up to 1000 RPM

#### FR-S2: Distance Calculation
- **FR-S2.1:** System SHALL calculate distance in feet with 2 decimal precision
- **FR-S2.2:** Calculation formula: `Distance (ft) = (Encoder_Counts / 4000) Ã— (Wheel_Circumference_inches / 12)`
  - Where 4000 = 1000 PPR Ã— 4 (quadrature mode)
- **FR-S2.3:** System SHALL use configurable wheel diameter constant (default: 12.0 inches)
- **FR-S2.4:** System SHALL compute wheel circumference as `Ï€ Ã— diameter`
- **FR-S2.5:** System SHALL ensure distance never displays negative values
- **FR-S2.6:** System SHALL update distance calculation at minimum 10 Hz rate

#### FR-S3: Local Display
- **FR-S3.1:** System SHALL display current distance on 16x2 LCD
- **FR-S3.2:** Display format: "Distance: XXX.XX ft" or similar
- **FR-S3.3:** System SHALL update display at 10 Hz minimum
- **FR-S3.4:** System SHALL display initialization/status messages on startup
- **FR-S3.5:** System SHALL display reset confirmation when reset received
- **FR-S3.6:** LCD SHALL initialize within 2 seconds of power-on

#### FR-S4: Wireless Transmission (ESP-NOW)
- **FR-S4.1:** System SHALL transmit distance data via ESP-NOW protocol
- **FR-S4.2:** System SHALL send data to Judge Controller MAC address
- **FR-S4.3:** Transmission rate: Minimum 10 Hz (every 100ms)
- **FR-S4.4:** Data packet SHALL include:
  - Distance value (float, feet)
  - Timestamp (uint32_t, milliseconds since boot)
- **FR-S4.5:** System SHALL operate on WiFi channel 1 (default, configurable for future)
- **FR-S4.6:** System SHALL handle transmission failures gracefully (no system hang)

#### FR-S5: Local Reset Button
- **FR-S5.1:** System SHALL detect reset button presses on GPIO 34
- **FR-S5.2:** Upon valid button press:
  - Clear PCNT counter to zero
  - Reset distance calculation to 0.00 feet
  - Display "RESET" or similar confirmation message
  - Resume normal operation after 1 second
- **FR-S5.3:** System SHALL debounce button input (50ms minimum delay)
- **FR-S5.4:** System SHALL wait for button release before accepting next press
- **FR-S5.5:** System SHALL trigger reset only once per button press (no repeat)

#### FR-S6: Configuration Management
- **FR-S6.1:** Wheel diameter constant SHALL be easily modifiable in source code
- **FR-S6.2:** Wheel diameter SHALL be defined as preprocessor constant or global variable at top of file
- **FR-S6.3:** Comment SHALL indicate where to update wheel diameter value
- **FR-S6.4:** No recompilation SHALL be required for Judge MAC address changes in future versions

#### FR-S7: Initialization and Startup
- **FR-S7.1:** System SHALL initialize all peripherals within 5 seconds of power-on
- **FR-S7.2:** System SHALL display startup message indicating initialization progress
- **FR-S7.3:** System SHALL print MAC address to serial console during startup
- **FR-S7.4:** System SHALL verify ESP-NOW initialization success
- **FR-S7.5:** System SHALL add Judge Controller as ESP-NOW peer during setup
- **FR-S7.6:** System SHALL display error message if initialization fails

### 4.3 Non-Functional Requirements

#### NFR-S1: Performance
- **NFR-S1.1:** Display update latency SHALL NOT exceed 100ms from encoder change
- **NFR-S1.2:** Wireless transmission latency SHALL NOT exceed 50ms average
- **NFR-S1.3:** CPU utilization SHALL remain below 50% during normal operation
- **NFR-S1.4:** System SHALL operate continuously for 8+ hours without reboot

#### NFR-S2: Reliability
- **NFR-S2.1:** System SHALL recover from temporary wireless communication loss
- **NFR-S2.2:** System SHALL continue encoder reading even during wireless transmission
- **NFR-S2.3:** System SHALL handle power interruptions gracefully (no data corruption)
- **NFR-S2.4:** MTBF (Mean Time Between Failures) target: >100 hours continuous operation

#### NFR-S3: Maintainability
- **NFR-S3.1:** Code SHALL be commented explaining all major functions
- **NFR-S3.2:** Variable names SHALL be descriptive and follow consistent naming convention
- **NFR-S3.3:** Magic numbers SHALL be avoided; use named constants
- **NFR-S3.4:** Code SHALL be structured with clear separation of concerns (setup, loop, functions)

#### NFR-S4: Code Quality
- **NFR-S4.1:** No compiler warnings at default warning level
- **NFR-S4.2:** Memory leaks SHALL NOT occur
- **NFR-S4.3:** Global variables SHALL be minimized
- **NFR-S4.4:** Functions SHALL NOT exceed 50 lines (guideline)

---

## 5. DATA STRUCTURES

### 5.1 Distance Data Packet (Transmitted)
```cpp
typedef struct {
  float distance;        // Distance in feet (4 bytes)
  uint32_t timestamp;    // Milliseconds since boot (4 bytes)
} DistanceData;
// Total: 8 bytes
```

### 5.2 Reset Button
The reset button is connected to GPIO 34 with an external 10kΩ pull-up resistor.
- **Active LOW:** Button pressed = GPIO reads LOW
- **Debounce:** Software debounce with 50ms minimum delay

---

## 6. CONFIGURATION CONSTANTS

### 6.1 User-Configurable
```cpp
#define WHEEL_DIAMETER_INCHES 12.0  // Measuring wheel diameter
#define ENCODER_PPR 1000            // Encoder pulses per revolution
#define QUADRATURE_MODE 4           // 4x resolution in quadrature
```

### 6.2 System Constants
```cpp
#define PCNT_UNIT PCNT_UNIT_0
#define UPDATE_RATE_MS 100          // 10 Hz update rate
#define PCNT_FILTER_VALUE 1023      // Noise filter threshold
```

### 6.3 Network Configuration
```cpp
uint8_t judgeMAC[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};  // To be replaced with actual MAC
```

---

## 7. STATE MACHINE

### 7.1 System States
```
INIT â†’ RUNNING â†â†’ RESET_RECEIVED â†’ RUNNING
  â†“
ERROR (if init fails)
```

**State Descriptions:**
- **INIT:** Power-on, peripheral initialization, ESP-NOW setup
- **RUNNING:** Normal operation (read encoder, calculate, display, transmit)
- **RESETTING:** Reset button pressed, zero counters, display confirmation, return to RUNNING after 1 second
- **ERROR:** Initialization failure, display error message, halt

---

## 8. ERROR HANDLING

### 8.1 Critical Errors (System Halt)
- ESP-NOW initialization failure
- LCD initialization failure
- PCNT initialization failure

**Behavior:** Display error message on LCD (if possible), print to serial, infinite loop/halt

### 8.2 Non-Critical Errors (Log and Continue)
- ESP-NOW transmission failure
- Peer add failure
- Counter overflow/underflow

**Behavior:** Log to serial console, continue operation, retry if applicable

---

## 9. TESTING REQUIREMENTS

### 9.1 Unit Tests

#### UT-S1: Encoder Reading
- **Test:** Manually rotate encoder 10 full revolutions forward
- **Expected:** Counter increments by 40,000 counts (10 Ã— 4000)
- **Pass Criteria:** Count within Â±0.1% of expected

#### UT-S2: Encoder Direction
- **Test:** Rotate encoder 5 revolutions backward
- **Expected:** Counter decrements by 20,000 counts
- **Pass Criteria:** Count decreases correctly

#### UT-S3: Distance Calculation (12" wheel)
- **Test:** Simulate 40,000 counts (10 revolutions)
- **Expected:** Distance = 31.42 feet (10 Ã— Ï€ Ã— 12" / 12)
- **Pass Criteria:** Displayed distance matches within Â±0.01 ft

#### UT-S4: Display Update Rate
- **Test:** Monitor display refresh using timer
- **Expected:** Display updates every 100ms Â±10ms
- **Pass Criteria:** Consistent update timing

#### UT-S5: Reset Button Functionality
- **Test:** Press reset button on sled controller
- **Expected:** Counter and distance return to 0.00, "RESET" confirmation displayed
- **Pass Criteria:** Complete reset within 1 second, debounce prevents multiple resets

#### UT-S6: Button Debouncing
- **Test:** Rapidly press reset button 10 times in 1 second
- **Expected:** Only valid, debounced presses trigger reset
- **Pass Criteria:** Clean single reset per intentional press, 50ms minimum between resets

### 9.2 Integration Tests

#### IT-S1: End-to-End Distance Measurement
- **Test:** Roll measuring wheel exactly 10 feet
- **Expected:** Display shows 10.00 ft Â±0.05 ft
- **Pass Criteria:** Accuracy within 0.5%

#### IT-S2: Wireless Communication Range
- **Test:** Separate units by 100 feet, verify data reception
- **Expected:** Continuous data transmission without dropouts
- **Pass Criteria:** >99% packet success rate over 1 minute

#### IT-S3: Continuous Operation
- **Test:** Run system for 1 hour continuously
- **Expected:** No crashes, resets, or performance degradation
- **Pass Criteria:** Stable operation throughout test

### 9.3 Acceptance Tests

#### AT-S1: Field Simulation
- **Test:** Simulate full pull cycle: reset, measure 300 feet, reset, repeat 10 times
- **Expected:** Consistent accurate measurements each pull
- **Pass Criteria:** All measurements within Â±1% accuracy

#### AT-S2: Calibration Verification
- **Test:** Measure known distance with different wheel diameters (via code changes)
- **Expected:** Accurate distance with correct calibration constant
- **Pass Criteria:** Match known distance within Â±0.5%

---

## 10. POWER CONSUMPTION ANALYSIS

### 10.1 Current Draw Estimates
| Component | Typical | Peak | Notes |
|-----------|---------|------|-------|
| ESP32 (ESP-NOW) | 80-100 mA | 240 mA | Lower than full WiFi |
| LCD with backlight | 50 mA | 60 mA | Depends on contrast |
| **Total (5V rail)** | **130-150 mA** | **300 mA** | |

### 10.2 Battery Life Estimates (Future)
**Assuming 3S LiPo 2200mAh @ 12V with 85% buck converter efficiency:**
- Power consumption: ~0.75W (150mA @ 5V / 0.85)
- Current draw from battery: ~63mA @ 12V
- Runtime: ~35 hours (2200mAh / 63mA)

---

## 11. CALIBRATION PROCEDURE

### 11.1 Wheel Diameter Measurement
1. Measure wheel diameter with calipers (3 measurements, average)
2. Record diameter in inches to 2 decimal places
3. Update `WHEEL_DIAMETER_INCHES` constant in code
4. Recompile and upload firmware

### 11.2 Accuracy Verification
1. Mark a precise distance (50-100 feet) with measuring tape
2. Reset system to zero
3. Roll measuring wheel along marked distance
4. Compare displayed distance to actual distance
5. If error >0.5%, adjust wheel diameter:
   - `Corrected_Diameter = Current_Diameter Ã— (Actual_Distance / Displayed_Distance)`
6. Repeat until accuracy achieved

### 11.3 Documentation
- Record final calibrated wheel diameter
- Document date of calibration
- Note any environmental factors (tire pressure, temperature)

---

## 12. SERIAL DEBUG OUTPUT

### 12.1 Startup Messages
```
Sled Distance Measurement System
Initializing...
Sled MAC Address: XX:XX:XX:XX:XX:XX
PCNT initialized
ESP-NOW initialized
Judge peer added
LCD initialized
System ready
```

### 12.2 Runtime Debug (Optional)
```
Count: 12345 | Distance: 38.76 ft | TX: OK
Count: 12456 | Distance: 39.11 ft | TX: OK
RESET RECEIVED
Count: 0 | Distance: 0.00 ft | TX: OK
```

---

## 13. FUTURE ENHANCEMENTS (NOT MVP)

### 13.1 Hardware
- Battery power with auto-shutoff
- Weatherproof enclosure (IP65 rated)
- External antenna for extended range
- SD card for data logging

### 13.2 Software
- Multi-sled pairing and channel selection
- On-screen configuration menu (using buttons)
- Data logging to flash memory
- OTA (Over-The-Air) firmware updates
- Advanced diagnostics mode

### 13.3 Features
- Pull speed calculation (distance/time)
- Maximum distance tracking
- Competitor/tractor identification
- Web dashboard integration

---

## 14. COMPLIANCE AND STANDARDS

### 14.1 Electrical Safety
- Use properly rated components
- Ensure adequate current ratings for all wiring
- Provide overcurrent protection (fuses) in production
- Follow proper grounding practices

### 14.2 EMC (Electromagnetic Compatibility)
- Use shielded cables for encoder signals
- Add bypass capacitors near IC power pins
- Minimize loop areas in wiring
- Keep digital and analog grounds separate where possible

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
- Calibration guide
- Troubleshooting flowchart

### 15.3 User Documentation
- Quick start guide
- Operating instructions
- Reset procedure
- What to do if connection is lost

---

## 16. SIGN-OFF

### 16.1 Requirements Review
- [ ] Hardware specifications reviewed and approved
- [ ] Software requirements reviewed and approved
- [ ] Test plan reviewed and approved
- [ ] Documentation plan reviewed and approved

### 16.2 Acceptance Criteria
System is considered complete and acceptable when:
- All FR (Functional Requirements) are met
- All UT (Unit Tests) pass
- All IT (Integration Tests) pass
- All AT (Acceptance Tests) pass
- All documentation deliverables provided
- Customer demonstration successful

---

**Document Version:** 1.0  
**Last Updated:** December 29, 2025  
**Author:** Corey Thompson, Tulsa Software  
**Status:** Draft for Review