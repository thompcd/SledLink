/*
 * SledLink Sled Controller
 *
 * Tractor pull distance measurement system using rotary encoder.
 * Reads quadrature encoder, calculates distance (positive only),
 * displays on LCD, and transmits wirelessly to Judge Controller.
 *
 * Button behavior cycles through states:
 *   ACCUMULATING -> HOLD -> RESET -> ACCUMULATING
 *
 * Hardware:
 *   - ESP32 DevKit
 *   - GHW38 incremental encoder (1000 PPR, quadrature A/B, NPN open-collector)
 *     - Phase A (Green) -> GPIO 32
 *     - Phase B (White) -> GPIO 33
 *     - Vcc (Red) -> 5V
 *     - GND (Black) -> GND
 *   - 16x2 LCD (4-bit mode)
 *     - RS -> GPIO 19, E -> GPIO 23
 *     - D4-D7 -> GPIO 18, 17, 16, 15
 *   - Button on GPIO 27 (active low, internal pullup)
 *   - Status LED on GPIO 4 (optional)
 *
 * Serial output: 115200 baud
 */

#include "driver/pcnt.h"
#include <WiFi.h>
#include <esp_now.h>
#include <LiquidCrystal.h>

// ============================================================================
// VERSION INFORMATION
// ============================================================================
#define FIRMWARE_DISPLAY_VERSION "v1.0.0"  // User-facing version on LCD
#ifndef BUILD_VERSION
  #define BUILD_VERSION "dev"               // Injected during release build
#endif

// ============================================================================
// PIN DEFINITIONS
// ============================================================================
// Encoder pins
const int ENCODER_PIN_A = 32;           // Phase A (Green wire)
const int ENCODER_PIN_B = 33;           // Phase B (White wire)

// Button
const int BUTTON_PIN = 27;

// LCD pins (4-bit mode)
const int LCD_RS = 19;
const int LCD_EN = 23;
const int LCD_D4 = 18;
const int LCD_D5 = 17;
const int LCD_D6 = 16;
const int LCD_D7 = 15;

// Status LED (optional)
const int STATUS_LED_PIN = 4;

// ============================================================================
// CONFIGURATION - Modify these values as needed
// ============================================================================
// Encoder configuration - GHW38 with 1000 PPR
const int ENCODER_PPR = 1000;           // Pulses per revolution
const int COUNTS_PER_REV = ENCODER_PPR * 4;  // 4x quadrature = 4000 counts/rev
const float WHEEL_DIAMETER_INCHES = 2.5;
const float WHEEL_CIRCUMFERENCE_INCHES = WHEEL_DIAMETER_INCHES * 3.14159265;
const float INCHES_PER_FOOT = 12.0;

// Timing configuration
const unsigned long UPDATE_RATE_MS = 100;       // 10 Hz update rate
const unsigned long DEBOUNCE_DELAY = 50;        // Button debounce delay
const unsigned long RESET_DISPLAY_MS = 500;     // Show RESET message duration

// ============================================================================
// JUDGE CONTROLLER MAC ADDRESS - Update with your Judge's MAC address
// ============================================================================
uint8_t judgeMAC[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// ============================================================================
// DATA STRUCTURES
// ============================================================================
// Distance data packet sent to Judge Controller
typedef struct {
  float distance;        // Distance in feet (4 bytes)
  uint32_t timestamp;    // Milliseconds since boot (4 bytes)
} DistanceData;


// System states
enum SledState {
  STATE_ACCUMULATING,    // Counting distance (positive only)
  STATE_HOLD,            // Frozen for judge to record
  STATE_RESET            // Resetting to zero (auto-transitions to ACCUMULATING)
};

// ============================================================================
// PCNT CONFIGURATION
// ============================================================================
const pcnt_unit_t PCNT_UNIT = PCNT_UNIT_0;
const int16_t PCNT_HIGH_LIMIT = 10000;
const int16_t PCNT_LOW_LIMIT = -10000;

// ============================================================================
// GLOBAL STATE
// ============================================================================
// System state
SledState currentState = STATE_ACCUMULATING;

// Encoder state
volatile int32_t encoderOverflowCount = 0;
int32_t lastRawCount = 0;
int32_t accumulatedCount = 0;    // Only positive accumulation
float heldDistance = 0.0;        // Distance when HOLD state entered

// Button state
bool lastButtonState = HIGH;
bool buttonPressed = false;
unsigned long lastDebounceTime = 0;

// Wireless state
bool espNowInitialized = false;
bool peerAdded = false;

// Display state
float lastDisplayedDistance = -1.0;
unsigned long lastUpdateTime = 0;
unsigned long resetStartTime = 0;

// LCD object
LiquidCrystal lcd(LCD_RS, LCD_EN, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================
void setupEncoder();
void setupButton();
void setupLCD();
void setupWireless();
void setupStatusLED();
int32_t getRawEncoderCount();
void clearEncoder();
float calculateDistance(int32_t counts);
void transmitDistance(float distance);
void updateLCD(float distance, const char* line1, const char* line2);
void handleButtonPress();
void updateAccumulator();
void IRAM_ATTR pcntOverflowHandler(void* arg);
void onDataReceive(const esp_now_recv_info_t *info, const uint8_t *data, int len);

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.print("\r\n");
  Serial.print("========================================\r\n");
  Serial.print("  SledLink Sled Controller ");
  Serial.print(FIRMWARE_DISPLAY_VERSION);
  Serial.print("\r\n");
  Serial.print("  Tractor Pull Distance Measurement\r\n");
  Serial.print("  Build: ");
  Serial.print(BUILD_VERSION);
  Serial.print("\r\n");
  Serial.print("========================================\r\n");
  Serial.print("\r\n");

  Serial.print("Configuration:\r\n");
  Serial.printf("  Encoder Phase A: GPIO %d\r\n", ENCODER_PIN_A);
  Serial.printf("  Encoder Phase B: GPIO %d\r\n", ENCODER_PIN_B);
  Serial.printf("  Button: GPIO %d\r\n", BUTTON_PIN);
  Serial.printf("  Encoder: %d PPR x4 = %d counts/rev\r\n", ENCODER_PPR, COUNTS_PER_REV);
  Serial.printf("  Wheel diameter: %.2f inches\r\n", WHEEL_DIAMETER_INCHES);
  Serial.print("  Mode: Accumulating (positive only)\r\n");
  Serial.print("\r\n");
  Serial.print("Button cycles: ACCUMULATING -> HOLD -> RESET -> ACCUMULATING\r\n");
  Serial.print("\r\n");

  // Initialize LCD first for status display
  setupLCD();
  lcd.clear();
  lcd.print("SledLink v3.0");
  lcd.setCursor(0, 1);
  lcd.print("Initializing...");

  // Initialize other components
  setupEncoder();
  setupButton();
  setupStatusLED();
  setupWireless();

  // Show ready status
  updateLCD(0.0, "ACCUMULATING", "0.00 ft");

  Serial.print("\r\nInitialization complete.\r\n");
  Serial.print("\r\n");
  Serial.print("State        | Distance   | Status\r\n");
  Serial.print("-------------|------------|--------\r\n");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  // Handle button presses
  handleButtonPress();

  // Update accumulator (only in ACCUMULATING state)
  updateAccumulator();

  // Handle RESET state auto-transition
  if (currentState == STATE_RESET) {
    if (millis() - resetStartTime >= RESET_DISPLAY_MS) {
      // Auto-transition to ACCUMULATING
      currentState = STATE_ACCUMULATING;
      updateLCD(0.0, "ACCUMULATING", "0.00 ft");
      Serial.print("ACCUMULATING |    0.00 ft | AUTO\r\n");
    }
  }

  // Update at fixed rate
  unsigned long currentTime = millis();
  if (currentTime - lastUpdateTime >= UPDATE_RATE_MS) {
    lastUpdateTime = currentTime;

    float distance;
    if (currentState == STATE_HOLD) {
      distance = heldDistance;
    } else if (currentState == STATE_RESET) {
      distance = 0.0;
    } else {
      distance = calculateDistance(accumulatedCount);
    }

    // Transmit distance
    transmitDistance(distance);

    // Update LCD if distance changed (only in ACCUMULATING state)
    if (currentState == STATE_ACCUMULATING) {
      if (abs(distance - lastDisplayedDistance) >= 0.01) {
        char buf[16];
        snprintf(buf, sizeof(buf), "%.2f ft", distance);
        updateLCD(distance, "ACCUMULATING", buf);
        lastDisplayedDistance = distance;
        Serial.printf("ACCUMULATING | %7.2f ft | TX\r\n", distance);
      }
    }
  }
}

// ============================================================================
// BUTTON HANDLING
// ============================================================================
void handleButtonPress() {
  bool buttonState = digitalRead(BUTTON_PIN);

  // Track state changes for debounce
  if (buttonState != lastButtonState) {
    lastDebounceTime = millis();
    lastButtonState = buttonState;
  }

  // After debounce delay, check if button is pressed (LOW)
  if (!buttonPressed && buttonState == LOW && (millis() - lastDebounceTime) > DEBOUNCE_DELAY) {
    buttonPressed = true;

    // State machine transitions
    switch (currentState) {
      case STATE_ACCUMULATING:
        // Freeze the current distance
        heldDistance = calculateDistance(accumulatedCount);
        currentState = STATE_HOLD;
        {
          char buf[16];
          snprintf(buf, sizeof(buf), "%.2f ft", heldDistance);
          updateLCD(heldDistance, "** HOLD **", buf);
        }
        Serial.printf("HOLD         | %7.2f ft | BUTTON\r\n", heldDistance);
        break;

      case STATE_HOLD:
        // Reset the counter
        accumulatedCount = 0;
        clearEncoder();
        currentState = STATE_RESET;
        resetStartTime = millis();
        updateLCD(0.0, "** RESET **", "Zeroing...");
        Serial.print("RESET        |    0.00 ft | BUTTON\r\n");
        break;

      case STATE_RESET:
        // Already in reset, ignore (will auto-transition)
        break;
    }
  }

  // Reset flag when button released
  if (buttonState == HIGH) {
    buttonPressed = false;
  }
}

// ============================================================================
// ACCUMULATOR - Positive only counting
// ============================================================================
void updateAccumulator() {
  if (currentState != STATE_ACCUMULATING) return;

  int32_t rawCount = getRawEncoderCount();
  int32_t delta = rawCount - lastRawCount;
  lastRawCount = rawCount;

  // Only accumulate positive movement
  if (delta > 0) {
    accumulatedCount += delta;
  }
  // Negative movement is ignored (wheel rolled backward)
}

// ============================================================================
// ENCODER FUNCTIONS
// ============================================================================
void setupEncoder() {
  Serial.print("Initializing PCNT quadrature encoder...\r\n");

  pinMode(ENCODER_PIN_A, INPUT_PULLUP);
  pinMode(ENCODER_PIN_B, INPUT_PULLUP);

  Serial.printf("  Initial pin states: A=%d, B=%d\r\n",
                digitalRead(ENCODER_PIN_A), digitalRead(ENCODER_PIN_B));

  // Configure PCNT for full quadrature decoding (4x resolution)
  pcnt_config_t pcntConfig = {};
  pcntConfig.pulse_gpio_num = ENCODER_PIN_A;
  pcntConfig.ctrl_gpio_num = ENCODER_PIN_B;
  pcntConfig.lctrl_mode = PCNT_MODE_REVERSE;
  pcntConfig.hctrl_mode = PCNT_MODE_KEEP;
  pcntConfig.pos_mode = PCNT_COUNT_INC;
  pcntConfig.neg_mode = PCNT_COUNT_DEC;
  pcntConfig.counter_h_lim = PCNT_HIGH_LIMIT;
  pcntConfig.counter_l_lim = PCNT_LOW_LIMIT;
  pcntConfig.unit = PCNT_UNIT;
  pcntConfig.channel = PCNT_CHANNEL_0;
  pcnt_unit_config(&pcntConfig);

  // Channel 1 for full 4x quadrature
  pcntConfig.pulse_gpio_num = ENCODER_PIN_B;
  pcntConfig.ctrl_gpio_num = ENCODER_PIN_A;
  pcntConfig.pos_mode = PCNT_COUNT_DEC;
  pcntConfig.neg_mode = PCNT_COUNT_INC;
  pcntConfig.channel = PCNT_CHANNEL_1;
  pcnt_unit_config(&pcntConfig);

  // Configure filter
  pcnt_set_filter_value(PCNT_UNIT, 100);
  pcnt_filter_enable(PCNT_UNIT);

  // Enable overflow interrupts
  pcnt_event_enable(PCNT_UNIT, PCNT_EVT_H_LIM);
  pcnt_event_enable(PCNT_UNIT, PCNT_EVT_L_LIM);
  pcnt_isr_service_install(0);
  pcnt_isr_handler_add(PCNT_UNIT, pcntOverflowHandler, NULL);

  // Initialize counter
  pcnt_counter_pause(PCNT_UNIT);
  pcnt_counter_clear(PCNT_UNIT);
  pcnt_counter_resume(PCNT_UNIT);

  Serial.print("  PCNT encoder initialized (accumulating mode)\r\n");
}

void IRAM_ATTR pcntOverflowHandler(void* arg) {
  uint32_t status;
  pcnt_get_event_status(PCNT_UNIT, &status);

  if (status & PCNT_EVT_H_LIM) {
    encoderOverflowCount++;
  }
  if (status & PCNT_EVT_L_LIM) {
    encoderOverflowCount--;
  }
}

int32_t getRawEncoderCount() {
  int16_t count;
  pcnt_get_counter_value(PCNT_UNIT, &count);
  return (encoderOverflowCount * PCNT_HIGH_LIMIT) + count;
}

void clearEncoder() {
  pcnt_counter_pause(PCNT_UNIT);
  pcnt_counter_clear(PCNT_UNIT);
  encoderOverflowCount = 0;
  lastRawCount = 0;
  pcnt_counter_resume(PCNT_UNIT);
}

float calculateDistance(int32_t counts) {
  float revolutions = (float)counts / COUNTS_PER_REV;
  float inches = revolutions * WHEEL_CIRCUMFERENCE_INCHES;
  float feet = inches / INCHES_PER_FOOT;
  return feet;
}

// ============================================================================
// BUTTON FUNCTIONS
// ============================================================================
void setupButton() {
  Serial.printf("Initializing button on GPIO %d...\r\n", BUTTON_PIN);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.print("  Button initialized\r\n");
}

// ============================================================================
// LCD FUNCTIONS
// ============================================================================
void setupLCD() {
  Serial.print("Initializing LCD display...\r\n");
  lcd.begin(16, 2);
  lcd.clear();
  Serial.print("  LCD initialized\r\n");
}

void updateLCD(float distance, const char* line1, const char* line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
  lastDisplayedDistance = distance;
}

// ============================================================================
// STATUS LED FUNCTIONS
// ============================================================================
void setupStatusLED() {
  Serial.printf("Initializing status LED on GPIO %d...\r\n", STATUS_LED_PIN);
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);
  Serial.print("  Status LED initialized\r\n");
}

// ============================================================================
// WIRELESS FUNCTIONS (ESP-NOW)
// ============================================================================
void setupWireless() {
  Serial.print("Initializing ESP-NOW wireless...\r\n");

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  Serial.print("  Sled MAC Address: ");
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.print("  ERROR: ESP-NOW initialization failed!\r\n");
    lcd.clear();
    lcd.print("ESP-NOW Failed!");
    lcd.setCursor(0, 1);
    lcd.print("Check Wiring");
    while (1) { delay(1000); }
  }
  espNowInitialized = true;
  Serial.print("  ESP-NOW initialized\r\n");

  esp_now_register_recv_cb(onDataReceive);

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, judgeMAC, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;

  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.print("  WARNING: Failed to add Judge peer\r\n");
  } else {
    peerAdded = true;
    Serial.print("  Judge peer added\r\n");
  }

  Serial.print("  Wireless initialization complete\r\n");
}

void onDataReceive(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  // Currently not processing any incoming data from Judge
  // Reset is handled locally on the Sled only
}

void transmitDistance(float distance) {
  if (!espNowInitialized) return;

  DistanceData packet;
  packet.distance = distance;
  packet.timestamp = millis();

  esp_err_t result = esp_now_send(judgeMAC, (uint8_t*)&packet, sizeof(packet));

  if (result == ESP_OK) {
    digitalWrite(STATUS_LED_PIN, HIGH);
    delayMicroseconds(100);
    digitalWrite(STATUS_LED_PIN, LOW);
  }
}
