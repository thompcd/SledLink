/*
 * SledLink Judge Controller
 *
 * Tractor pull judge display unit. Receives distance data wirelessly
 * from Sled Controller via ESP-NOW and displays on LCD.
 *
 * Note: Reset is controlled only on the Sled Controller.
 *
 * Hardware:
 *   - ESP32 DevKit
 *   - 16x2 LCD (4-bit mode)
 *     - RS -> GPIO 19, E -> GPIO 23
 *     - D4-D7 -> GPIO 18, 17, 16, 15
 *   - Status LED on GPIO 4 (optional)
 *
 * Serial output: 115200 baud
 */

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
// CONFIGURATION
// ============================================================================
const unsigned long UPDATE_RATE_MS = 100;           // 10 Hz update rate
const unsigned long CONNECTION_TIMEOUT_MS = 2000;   // 2 second timeout
const unsigned long LED_BLINK_SLOW_MS = 500;        // Slow blink (waiting)
const unsigned long LED_BLINK_FAST_MS = 100;        // Fast blink (init)

// ============================================================================
// DATA STRUCTURES
// ============================================================================
// Distance data packet received from Sled Controller
typedef struct {
  float distance;        // Distance in feet (4 bytes)
  uint32_t timestamp;    // Milliseconds since sled boot (4 bytes)
} DistanceData;

// System states
enum SystemState {
  STATE_INIT,
  STATE_WAITING,
  STATE_CONNECTED,
  STATE_SIGNAL_LOST,
  STATE_ERROR
};

// ============================================================================
// GLOBAL STATE
// ============================================================================
// System state
SystemState currentState = STATE_INIT;

// Received data
volatile float receivedDistance = 0.0;
volatile uint32_t receivedTimestamp = 0;
volatile bool newDataReceived = false;
unsigned long lastReceiveTime = 0;

// Display state
float lastDisplayedDistance = -1.0;
unsigned long lastUpdateTime = 0;

// LED state
unsigned long lastLedToggle = 0;
bool ledState = false;

// Wireless state
bool espNowInitialized = false;

// LCD object
LiquidCrystal lcd(LCD_RS, LCD_EN, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================
void setupLCD();
void setupStatusLED();
void setupWireless();
void updateState();
void updateLCD();
void updateLED();
void onDataReceive(const esp_now_recv_info_t *info, const uint8_t *data, int len);

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.print("\r\n");
  Serial.print("========================================\r\n");
  Serial.print("  SledLink Judge Controller ");
  Serial.print(FIRMWARE_DISPLAY_VERSION);
  Serial.print("\r\n");
  Serial.print("  Tractor Pull Distance Display\r\n");
  Serial.print("  Build: ");
  Serial.print(BUILD_VERSION);
  Serial.print("\r\n");
  Serial.print("========================================\r\n");
  Serial.print("\r\n");

  Serial.print("Configuration:\r\n");
  Serial.printf("  LCD RS: GPIO %d\r\n", LCD_RS);
  Serial.printf("  LCD EN: GPIO %d\r\n", LCD_EN);
  Serial.printf("  LCD D4-D7: GPIO %d, %d, %d, %d\r\n", LCD_D4, LCD_D5, LCD_D6, LCD_D7);
  Serial.printf("  Status LED: GPIO %d\r\n", STATUS_LED_PIN);
  Serial.printf("  Connection timeout: %lu ms\r\n", CONNECTION_TIMEOUT_MS);
  Serial.print("\r\n");

  // Initialize components
  setupLCD();
  lcd.clear();
  lcd.print("SledLink Judge");
  lcd.setCursor(0, 1);
  lcd.print("Initializing...");

  setupStatusLED();
  setupWireless();

  // Transition to waiting state
  currentState = STATE_WAITING;
  lcd.clear();
  lcd.print("Waiting...");
  lcd.setCursor(0, 1);
  lcd.print("-- No Signal --");

  Serial.print("\r\nInitialization complete.\r\n");
  Serial.print("Waiting for signal from Sled Controller...\r\n");
  Serial.print("\r\n");
  Serial.print("Distance   | Status     | Timestamp\r\n");
  Serial.print("-----------|------------|----------\r\n");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  unsigned long currentTime = millis();

  // Update state machine
  updateState();

  // Update display at fixed rate
  if (currentTime - lastUpdateTime >= UPDATE_RATE_MS) {
    lastUpdateTime = currentTime;
    updateLCD();
  }

  // Update LED continuously for proper blinking
  updateLED();
}

// ============================================================================
// STATE MACHINE
// ============================================================================
void updateState() {
  unsigned long currentTime = millis();

  switch (currentState) {
    case STATE_WAITING:
      if (newDataReceived) {
        newDataReceived = false;
        lastReceiveTime = currentTime;
        currentState = STATE_CONNECTED;
        Serial.printf("%7.2f ft | CONNECTED  | %lu\r\n", receivedDistance, receivedTimestamp);
      }
      break;

    case STATE_CONNECTED:
      if (newDataReceived) {
        newDataReceived = false;
        lastReceiveTime = currentTime;
        if (abs(receivedDistance - lastDisplayedDistance) >= 0.1) {
          Serial.printf("%7.2f ft | RX         | %lu\r\n", receivedDistance, receivedTimestamp);
        }
      }
      if (currentTime - lastReceiveTime > CONNECTION_TIMEOUT_MS) {
        currentState = STATE_SIGNAL_LOST;
        Serial.print("           | SIGNAL LOST|\r\n");
      }
      break;

    case STATE_SIGNAL_LOST:
      if (newDataReceived) {
        newDataReceived = false;
        lastReceiveTime = currentTime;
        currentState = STATE_CONNECTED;
        Serial.printf("%7.2f ft | RESTORED   | %lu\r\n", receivedDistance, receivedTimestamp);
      }
      break;

    case STATE_ERROR:
      // Stay in error state - requires reboot
      break;

    default:
      break;
  }
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

void updateLCD() {
  switch (currentState) {
    case STATE_WAITING:
      lcd.setCursor(0, 0);
      lcd.print("Waiting...      ");
      lcd.setCursor(0, 1);
      lcd.print("-- No Signal -- ");
      break;

    case STATE_CONNECTED:
      if (abs(receivedDistance - lastDisplayedDistance) >= 0.01) {
        lcd.setCursor(0, 0);
        lcd.print("Pull Distance:  ");
        lcd.setCursor(0, 1);
        char buf[17];
        snprintf(buf, sizeof(buf), "%-7.2f ft      ", receivedDistance);
        lcd.print(buf);
        lastDisplayedDistance = receivedDistance;
      }
      break;

    case STATE_SIGNAL_LOST:
      lcd.setCursor(0, 0);
      lcd.print("** NO SIGNAL ** ");
      lcd.setCursor(0, 1);
      char lostBuf[17];
      snprintf(lostBuf, sizeof(lostBuf), "Last: %.2f ft   ", lastDisplayedDistance);
      lcd.print(lostBuf);
      break;

    case STATE_ERROR:
      lcd.setCursor(0, 0);
      lcd.print("** ERROR **     ");
      lcd.setCursor(0, 1);
      lcd.print("Check Wiring    ");
      break;

    default:
      break;
  }
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

void updateLED() {
  unsigned long currentTime = millis();

  switch (currentState) {
    case STATE_INIT:
      // Fast blink during initialization
      if (currentTime - lastLedToggle >= LED_BLINK_FAST_MS) {
        lastLedToggle = currentTime;
        ledState = !ledState;
        digitalWrite(STATUS_LED_PIN, ledState ? HIGH : LOW);
      }
      break;

    case STATE_WAITING:
    case STATE_SIGNAL_LOST:
      // Slow blink when waiting or signal lost
      if (currentTime - lastLedToggle >= LED_BLINK_SLOW_MS) {
        lastLedToggle = currentTime;
        ledState = !ledState;
        digitalWrite(STATUS_LED_PIN, ledState ? HIGH : LOW);
      }
      break;

    case STATE_CONNECTED:
      // Solid ON when connected
      digitalWrite(STATUS_LED_PIN, HIGH);
      ledState = true;
      break;

    case STATE_ERROR:
      // LED OFF on error
      digitalWrite(STATUS_LED_PIN, LOW);
      ledState = false;
      break;

    default:
      break;
  }
}

// ============================================================================
// WIRELESS FUNCTIONS (ESP-NOW)
// ============================================================================
void setupWireless() {
  Serial.print("Initializing ESP-NOW wireless...\r\n");

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  Serial.print("  Judge MAC Address: ");
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.print("  ERROR: ESP-NOW initialization failed!\r\n");
    currentState = STATE_ERROR;
    lcd.clear();
    lcd.print("ESP-NOW Failed!");
    lcd.setCursor(0, 1);
    lcd.print("Check Wiring");
    while (1) { delay(1000); }
  }
  espNowInitialized = true;
  Serial.print("  ESP-NOW initialized\r\n");

  // Register receive callback (receive-only, no peer needed)
  esp_now_register_recv_cb(onDataReceive);

  Serial.print("  Wireless initialization complete\r\n");
}

void onDataReceive(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  if (len == sizeof(DistanceData)) {
    DistanceData* packet = (DistanceData*)data;
    receivedDistance = packet->distance;
    receivedTimestamp = packet->timestamp;
    newDataReceived = true;
  }
}
