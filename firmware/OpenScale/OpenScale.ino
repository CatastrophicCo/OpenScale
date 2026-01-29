/*
 * OpenScale - Bluetooth Hangboard Training Scale
 *
 * Hardware: XIAO ESP32C6, HX711, 4-pin strain gauge, I2C OLED, Button
 *
 * Pin Connections:
 *   HX711:  DT->D4, SCK->D5
 *   OLED:   SCL->D0, SDA->D1
 *   Button: D2 (to GND)
 *
 * Button Functions:
 *   - Short press: Tare the scale
 *   - Long press (awake): Toggle units (lbs/kg)
 *   - Long press (from sleep): Wake up
 *   - Sequence (S-S-S-L-S-S-S): Enter calibration mode
 *
 * Power Management:
 *   - Enters deep sleep after 10 minutes of inactivity
 *   - Wake with long button press
 *
 * See config.h for all configurable settings.
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <HX711.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <esp_mac.h>
#include <esp_sleep.h>
#include <Preferences.h>

#include "config.h"

// =============================================================================
// Global Objects
// =============================================================================
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
HX711 scale;
Preferences preferences;

BLEServer* pServer = nullptr;
BLECharacteristic* pWeightCharacteristic = nullptr;
BLECharacteristic* pTareCharacteristic = nullptr;
BLECharacteristic* pSampleRateCharacteristic = nullptr;
BLECharacteristic* pCalibrationCharacteristic = nullptr;
BLECharacteristic* pDeviceNameCharacteristic = nullptr;

// =============================================================================
// Global Variables
// =============================================================================
bool deviceConnected = false;
bool oldDeviceConnected = false;
float currentWeight = 0.0f;
float previousWeight = 0.0f;
float peakWeight = 0.0f;
float calibrationFactor = CALIBRATION_FACTOR;
uint8_t sampleRateHz = DEFAULT_SAMPLE_RATE_HZ;
unsigned long lastSampleTime = 0;
unsigned long sampleInterval = 1000 / DEFAULT_SAMPLE_RATE_HZ;

String customDeviceName = "";
String activeDeviceName = "";

// Display unit (0 = lbs, 1 = kg)
uint8_t displayUnit = UNIT_LBS;

// Power management
unsigned long lastActivityTime = 0;

// Button handling
bool buttonPressed = false;
unsigned long buttonPressStart = 0;
unsigned long lastButtonRelease = 0;
uint8_t buttonSequence[CALIBRATION_SEQUENCE_LENGTH];
uint8_t sequenceIndex = 0;

// Double-press detection
uint8_t shortPressCount = 0;
unsigned long lastShortPressTime = 0;
const unsigned long DOUBLE_PRESS_WINDOW_MS = 400;  // Time window for double press

// Calibration mode
bool calibrationMode = false;
bool calibrationWaitingForWeight = false;

// Unit preview during long press
bool showingUnitPreview = false;

// =============================================================================
// Forward Declarations
// =============================================================================
void performTare();
void saveCalibration();
void resetPeakWeight();
void showUnitPreview();

// =============================================================================
// BLE Server Callbacks
// =============================================================================
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    lastActivityTime = millis();  // Reset inactivity timer
    Serial.println("Client connected");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Client disconnected");
  }
};

// =============================================================================
// Tare Characteristic Callback
// =============================================================================
class TareCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    Serial.println("Tare command received");
    performTare();
  }
};

// =============================================================================
// Sample Rate Characteristic Callback
// =============================================================================
class SampleRateCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    uint8_t* data = pCharacteristic->getData();
    if (data != nullptr && pCharacteristic->getLength() >= 1) {
      uint8_t newRate = data[0];
      if (newRate >= MIN_SAMPLE_RATE_HZ && newRate <= MAX_SAMPLE_RATE_HZ) {
        sampleRateHz = newRate;
        sampleInterval = 1000 / sampleRateHz;
        Serial.printf("Sample rate set to %d Hz\n", sampleRateHz);
      }
    }
  }

  void onRead(BLECharacteristic* pCharacteristic) {
    pCharacteristic->setValue(&sampleRateHz, 1);
  }
};

// =============================================================================
// Calibration Characteristic Callback
// =============================================================================
// Special values for BLE calibration control:
//   0.0  = Start calibration step 1 (tare with no weight)
//  -1.0  = Complete calibration step 2 (calculate factor from known weight)
//  > 0   = Directly set calibration factor (legacy behavior)
// =============================================================================
class CalibrationCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    uint8_t* data = pCharacteristic->getData();
    size_t len = pCharacteristic->getLength();
    if (data != nullptr && len >= sizeof(float)) {
      float value;
      memcpy(&value, data, sizeof(float));

      if (value == 0.0f) {
        // Start calibration step 1: tare with no weight
        Serial.println("BLE Calibration: Starting step 1 (tare)");
        scale.set_scale(1.0);  // Reset to raw readings
        scale.tare(20);  // Tare with more readings for accuracy
        calibrationMode = true;
        calibrationWaitingForWeight = true;

        // Update display
        display.clearDisplay();
        display.setTextSize(1);
        display.setCursor(0, 0);
        display.println("CALIBRATION MODE");
        display.println("");
        display.printf("Place %.0f lbs", CALIBRATION_WEIGHT_LBS);
        display.setCursor(0, 24);
        display.println("Then complete in app");
        display.display();
      } else if (value == -1.0f) {
        // Complete calibration step 2: calculate factor from known weight
        if (calibrationMode && calibrationWaitingForWeight) {
          Serial.println("BLE Calibration: Completing step 2");
          delay(500);  // Let weight settle
          float rawReading = scale.get_units(20);  // Get average raw reading

          if (rawReading != 0) {
            calibrationFactor = rawReading / CALIBRATION_WEIGHT_GRAMS;
            scale.set_scale(calibrationFactor);
            saveCalibration();

            // Update BLE characteristic with new factor
            pCalibrationCharacteristic->setValue((uint8_t*)&calibrationFactor, sizeof(float));

            // Show success
            display.clearDisplay();
            display.setTextSize(1);
            display.setCursor(0, 0);
            display.println("CALIBRATION DONE!");
            display.println("");
            display.printf("Factor: %.2f", calibrationFactor);
            display.display();

            Serial.printf("BLE Calibration complete! Factor: %.2f\n", calibrationFactor);
            delay(2000);
          } else {
            // Error - no reading
            display.clearDisplay();
            display.setCursor(0, 8);
            display.println("ERROR: No reading");
            display.display();
            Serial.println("BLE Calibration error: No reading");
            delay(2000);
          }

          calibrationMode = false;
          calibrationWaitingForWeight = false;
        } else {
          Serial.println("BLE Calibration: Not in calibration mode");
        }
      } else if (value > 0) {
        // Direct calibration factor set (legacy behavior)
        calibrationFactor = value;
        scale.set_scale(calibrationFactor);
        saveCalibration();
        Serial.printf("Calibration factor set to %.2f\n", calibrationFactor);
      }
    }
  }

  void onRead(BLECharacteristic* pCharacteristic) {
    pCharacteristic->setValue((uint8_t*)&calibrationFactor, sizeof(float));
  }
};

// =============================================================================
// Device Name Characteristic Callback
// =============================================================================
class DeviceNameCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() > 0 && value.length() <= MAX_DEVICE_NAME_LENGTH) {
      customDeviceName = value;

      // Save to NVS
      preferences.begin(NVS_NAMESPACE, false);
      preferences.putString(NVS_KEY_DEVICE_NAME, customDeviceName);
      preferences.end();

      Serial.printf("Device name set to: %s\n", customDeviceName.c_str());
      Serial.println("Note: Restart device for new name to take effect in BLE advertising");
    }
  }

  void onRead(BLECharacteristic* pCharacteristic) {
    pCharacteristic->setValue(activeDeviceName.c_str());
  }
};

// =============================================================================
// Perform Tare
// =============================================================================
void performTare() {
  scale.tare(10);  // Average 10 readings for tare
  peakWeight = 0.0f;  // Reset peak weight
  lastActivityTime = millis();  // Reset inactivity timer
  Serial.println("Scale tared");
}

// =============================================================================
// Save Calibration to NVS
// =============================================================================
void saveCalibration() {
  preferences.begin(NVS_NAMESPACE, false);
  preferences.putFloat(NVS_KEY_CALIBRATION, calibrationFactor);
  preferences.end();
  Serial.printf("Calibration saved: %.2f\n", calibrationFactor);
}

// =============================================================================
// Load Calibration from NVS
// =============================================================================
void loadCalibration() {
  preferences.begin(NVS_NAMESPACE, true);
  calibrationFactor = preferences.getFloat(NVS_KEY_CALIBRATION, CALIBRATION_FACTOR);
  preferences.end();
  Serial.printf("Loaded calibration: %.2f\n", calibrationFactor);
}

// =============================================================================
// Save Display Unit to NVS
// =============================================================================
void saveDisplayUnit() {
  preferences.begin(NVS_NAMESPACE, false);
  preferences.putUChar(NVS_KEY_DISPLAY_UNIT, displayUnit);
  preferences.end();
  Serial.printf("Display unit saved: %s\n", displayUnit == UNIT_LBS ? "lbs" : "kg");
}

// =============================================================================
// Load Display Unit from NVS
// =============================================================================
void loadDisplayUnit() {
  preferences.begin(NVS_NAMESPACE, true);
  displayUnit = preferences.getUChar(NVS_KEY_DISPLAY_UNIT, UNIT_LBS);
  preferences.end();
  Serial.printf("Loaded display unit: %s\n", displayUnit == UNIT_LBS ? "lbs" : "kg");
}

// =============================================================================
// Reset Peak Weight
// =============================================================================
void resetPeakWeight() {
  peakWeight = 0.0f;
  lastActivityTime = millis();  // Reset inactivity timer
  Serial.println("Peak weight reset");

  // Show brief feedback on display
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(15, 12);
  display.print("PEAK RESET");
  display.display();
  delay(300);
}

// =============================================================================
// Toggle Display Unit
// =============================================================================
void toggleDisplayUnit() {
  displayUnit = (displayUnit == UNIT_LBS) ? UNIT_KG : UNIT_LBS;
  saveDisplayUnit();
  lastActivityTime = millis();  // Reset inactivity timer
  showingUnitPreview = false;
  Serial.printf("Unit changed to: %s\n", displayUnit == UNIT_LBS ? "lbs" : "kg");
}

// =============================================================================
// Show Unit Preview (called while button is held)
// =============================================================================
void showUnitPreview() {
  // Show what unit will be selected when button is released
  uint8_t previewUnit = (displayUnit == UNIT_LBS) ? UNIT_KG : UNIT_LBS;

  display.clearDisplay();
  display.setTextSize(2);
  display.setCursor(20, 4);
  display.print(previewUnit == UNIT_LBS ? "LBS" : "KG");
  display.setTextSize(1);
  display.setCursor(15, 24);
  display.print("Release to set");
  display.display();
}

// =============================================================================
// Initialize Display
// =============================================================================
void initDisplay() {
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    Serial.println("SSD1306 allocation failed!");
    return;
  }

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("OpenScale");
  display.println("Initializing...");
  display.display();

  Serial.println("Display initialized");
}

// =============================================================================
// Initialize HX711 Scale
// =============================================================================
void initScale() {
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);

  // Wait for HX711 to be ready
  unsigned long timeout = millis() + 3000;
  while (!scale.is_ready() && millis() < timeout) {
    delay(10);
  }

  if (!scale.is_ready()) {
    Serial.println("HX711 not found!");
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("ERROR:");
    display.println("HX711 not found!");
    display.display();
    return;
  }

  scale.set_scale(calibrationFactor);
  scale.tare(10);  // Average 10 readings for tare

  Serial.println("Scale initialized and tared");
}

// =============================================================================
// Initialize Button
// =============================================================================
void initButton() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.println("Button initialized on pin D2");
}

// =============================================================================
// Load Custom Device Name from NVS
// =============================================================================
void loadDeviceName() {
  preferences.begin(NVS_NAMESPACE, true);  // Read-only mode
  customDeviceName = preferences.getString(NVS_KEY_DEVICE_NAME, "");
  preferences.end();

  if (customDeviceName.length() > 0) {
    Serial.printf("Loaded custom device name from NVS: %s\n", customDeviceName.c_str());
  }
}

// =============================================================================
// Get Unique Device Name (includes last 4 chars of MAC address)
// =============================================================================
String getUniqueDeviceName() {
  // If custom name is set, use it
  if (customDeviceName.length() > 0) {
    return customDeviceName;
  }

  // Otherwise, generate from MAC address
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_BT);
  char suffix[5];
  snprintf(suffix, sizeof(suffix), "%02X%02X", mac[4], mac[5]);
  return String(DEVICE_NAME) + "-" + String(suffix);
}

// =============================================================================
// Initialize BLE
// =============================================================================
void initBLE() {
  activeDeviceName = getUniqueDeviceName();
  Serial.printf("Device name: %s\n", activeDeviceName.c_str());
  BLEDevice::init(activeDeviceName.c_str());

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Create BLE Service
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Create Weight Characteristic (Notify + Read)
  pWeightCharacteristic = pService->createCharacteristic(
    WEIGHT_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pWeightCharacteristic->addDescriptor(new BLE2902());

  // Create Tare Characteristic (Write)
  pTareCharacteristic = pService->createCharacteristic(
    TARE_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pTareCharacteristic->setCallbacks(new TareCallbacks());

  // Create Sample Rate Characteristic (Read + Write)
  pSampleRateCharacteristic = pService->createCharacteristic(
    SAMPLE_RATE_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pSampleRateCharacteristic->setCallbacks(new SampleRateCallbacks());
  pSampleRateCharacteristic->setValue(&sampleRateHz, 1);

  // Create Calibration Characteristic (Read + Write)
  pCalibrationCharacteristic = pService->createCharacteristic(
    CALIBRATION_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pCalibrationCharacteristic->setCallbacks(new CalibrationCallbacks());
  pCalibrationCharacteristic->setValue((uint8_t*)&calibrationFactor, sizeof(float));

  // Create Device Name Characteristic (Read + Write)
  pDeviceNameCharacteristic = pService->createCharacteristic(
    DEVICE_NAME_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
  );
  pDeviceNameCharacteristic->setCallbacks(new DeviceNameCallbacks());
  pDeviceNameCharacteristic->setValue(activeDeviceName.c_str());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE advertising started");
}

// =============================================================================
// Update Display
// =============================================================================
void updateDisplay() {
  display.clearDisplay();

  // Convert weight based on current unit
  float displayWeight, displayPeak;
  const char* unitStr;

  if (displayUnit == UNIT_LBS) {
    displayWeight = currentWeight * GRAMS_TO_LBS;
    displayPeak = peakWeight * GRAMS_TO_LBS;
    unitStr = "lbs";
  } else {
    displayWeight = currentWeight * GRAMS_TO_KG;
    displayPeak = peakWeight * GRAMS_TO_KG;
    unitStr = "kg";
  }

  // Current weight - large text (top portion)
  display.setTextSize(2);
  display.setCursor(0, 0);
  display.printf("%6.1f", displayWeight);

  // Units label
  display.setTextSize(1);
  display.setCursor(85, 4);
  display.print(unitStr);

  // Connection status indicator
  display.setCursor(SCREEN_WIDTH - 12, 0);
  if (deviceConnected) {
    display.print("BT");
  } else {
    display.print("--");
  }

  // Bottom row: Peak weight
  display.setCursor(0, 24);
  display.printf("Peak: %.1f %s", displayPeak, unitStr);

  display.display();
}

// =============================================================================
// Display Calibration Mode Screen
// =============================================================================
void displayCalibrationScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("CALIBRATION MODE");
  display.println("");

  if (calibrationWaitingForWeight) {
    display.printf("Place %.0f lbs", CALIBRATION_WEIGHT_LBS);
    display.setCursor(0, 24);
    display.println("Press btn when ready");
  } else {
    display.println("Remove all weight");
    display.setCursor(0, 24);
    display.println("Press btn to start");
  }

  display.display();
}

// =============================================================================
// Handle Calibration Mode
// =============================================================================
void handleCalibrationMode() {
  if (!calibrationWaitingForWeight) {
    // First step: tare with no weight
    scale.set_scale(1.0);  // Reset to raw readings
    scale.tare(20);  // Tare with more readings for accuracy
    calibrationWaitingForWeight = true;
    Serial.println("Calibration: Scale tared, waiting for weight...");
  } else {
    // Second step: apply known weight and calculate factor
    delay(500);  // Let weight settle
    float rawReading = scale.get_units(20);  // Get average raw reading

    if (rawReading != 0) {
      calibrationFactor = rawReading / CALIBRATION_WEIGHT_GRAMS;
      scale.set_scale(calibrationFactor);
      saveCalibration();

      // Show success
      display.clearDisplay();
      display.setTextSize(1);
      display.setCursor(0, 0);
      display.println("CALIBRATION DONE!");
      display.println("");
      display.printf("Factor: %.2f", calibrationFactor);
      display.display();

      Serial.printf("Calibration complete! Factor: %.2f\n", calibrationFactor);
      delay(2000);
    } else {
      // Error - no reading
      display.clearDisplay();
      display.setCursor(0, 8);
      display.println("ERROR: No reading");
      display.display();
      delay(2000);
    }

    // Exit calibration mode
    calibrationMode = false;
    calibrationWaitingForWeight = false;
  }
}

// =============================================================================
// Check Calibration Sequence
// =============================================================================
bool checkCalibrationSequence() {
  if (sequenceIndex < CALIBRATION_SEQUENCE_LENGTH) {
    return false;
  }

  for (int i = 0; i < CALIBRATION_SEQUENCE_LENGTH; i++) {
    if (buttonSequence[i] != CALIBRATION_SEQUENCE[i]) {
      return false;
    }
  }

  return true;
}

// =============================================================================
// Handle Button Press
// =============================================================================
void handleButton() {
  bool currentState = digitalRead(BUTTON_PIN) == LOW;  // Active LOW
  unsigned long currentTime = millis();

  // Debounce
  static unsigned long lastStateChange = 0;
  static bool lastState = false;
  static bool pendingSinglePress = false;

  // Check if button is being held for long press preview
  if (buttonPressed && !calibrationMode) {
    unsigned long holdDuration = currentTime - buttonPressStart;
    if (holdDuration >= LONG_PRESS_MS && !showingUnitPreview) {
      // Show unit preview when long press threshold is reached
      showingUnitPreview = true;
      showUnitPreview();
      // Cancel any pending single press since this is now a long press
      pendingSinglePress = false;
      shortPressCount = 0;
    }
  }

  // Check for pending single press (tare) after double-press window expires
  if (pendingSinglePress && !buttonPressed && (currentTime - lastShortPressTime > DOUBLE_PRESS_WINDOW_MS)) {
    // Single press confirmed - perform tare
    Serial.println("Single press: Tare");
    performTare();
    pendingSinglePress = false;
    shortPressCount = 0;
    lastActivityTime = currentTime;
  }

  if (currentState != lastState) {
    if (currentTime - lastStateChange > DEBOUNCE_MS) {
      lastStateChange = currentTime;
      lastState = currentState;

      if (currentState) {
        // Button pressed
        buttonPressed = true;
        buttonPressStart = currentTime;
        showingUnitPreview = false;
      } else {
        // Button released
        if (buttonPressed) {
          unsigned long pressDuration = currentTime - buttonPressStart;
          buttonPressed = false;
          showingUnitPreview = false;

          // Check sequence timeout
          if (currentTime - lastButtonRelease > SEQUENCE_TIMEOUT_MS) {
            sequenceIndex = 0;  // Reset sequence
          }
          lastButtonRelease = currentTime;

          // Determine press type
          bool isLongPress = pressDuration >= LONG_PRESS_MS;
          bool isShortPress = pressDuration < SHORT_PRESS_MAX_MS;

          // Handle calibration mode button press
          if (calibrationMode) {
            handleCalibrationMode();
            return;
          }

          // Add to sequence for calibration detection
          if (sequenceIndex < CALIBRATION_SEQUENCE_LENGTH) {
            buttonSequence[sequenceIndex++] = isLongPress ? 1 : 0;

            // Check if calibration sequence is complete
            if (checkCalibrationSequence()) {
              Serial.println("Calibration sequence detected!");
              calibrationMode = true;
              calibrationWaitingForWeight = false;
              sequenceIndex = 0;
              pendingSinglePress = false;
              shortPressCount = 0;
              return;
            }
          }

          // Normal button actions
          if (isLongPress) {
            Serial.println("Long press: Toggle units");
            toggleDisplayUnit();
            sequenceIndex = 0;  // Reset sequence after action
            pendingSinglePress = false;
            shortPressCount = 0;
          } else if (isShortPress) {
            // Check for double press
            if (currentTime - lastShortPressTime <= DOUBLE_PRESS_WINDOW_MS) {
              shortPressCount++;
            } else {
              shortPressCount = 1;
            }
            lastShortPressTime = currentTime;

            if (shortPressCount >= 2) {
              // Double press detected - reset peak
              Serial.println("Double press: Reset peak");
              resetPeakWeight();
              pendingSinglePress = false;
              shortPressCount = 0;
            } else {
              // First short press - wait to see if it's a double press
              pendingSinglePress = true;
            }
          }

          lastActivityTime = currentTime;  // Reset inactivity timer
        }
      }
    }
  }
}

// =============================================================================
// Enter Deep Sleep
// =============================================================================
void enterDeepSleep() {
  Serial.println("Entering deep sleep...");

  // Show sleep message
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(20, 8);
  display.println("SLEEPING...");
  display.setCursor(8, 20);
  display.println("Long press to wake");
  display.display();
  delay(1000);

  // Turn off display
  display.clearDisplay();
  display.display();
  display.ssd1306_command(SSD1306_DISPLAYOFF);

  // Configure wake-up source (button press)
  // ESP32-C6 uses GPIO wakeup (not ext0 which is for original ESP32)
  esp_deep_sleep_enable_gpio_wakeup(1ULL << BUTTON_PIN, ESP_GPIO_WAKEUP_GPIO_LOW);

  // Enter deep sleep
  esp_deep_sleep_start();
}

// =============================================================================
// Check for Inactivity
// =============================================================================
void checkInactivity() {
  unsigned long currentTime = millis();

  // Check for weight change activity
  if (abs(currentWeight - previousWeight) > ACTIVITY_THRESHOLD) {
    lastActivityTime = currentTime;
    previousWeight = currentWeight;
  }

  // Check if connected (activity)
  if (deviceConnected) {
    lastActivityTime = currentTime;
  }

  // Check for inactivity timeout
  if (currentTime - lastActivityTime >= INACTIVITY_TIMEOUT_MS) {
    enterDeepSleep();
  }
}

// =============================================================================
// Read Weight from Scale
// =============================================================================
float readWeight() {
  if (!scale.is_ready()) {
    return currentWeight;  // Return last reading if not ready
  }

  float weight = scale.get_units(READINGS_TO_AVERAGE);

  // Filter out small noise when near zero
  if (abs(weight) < NOISE_THRESHOLD) {
    weight = 0.0f;
  }

  return weight;
}

// =============================================================================
// Send Weight via BLE
// =============================================================================
void sendWeightBLE() {
  if (deviceConnected && pWeightCharacteristic != nullptr) {
    // Always send weight in grams
    pWeightCharacteristic->setValue((uint8_t*)&currentWeight, sizeof(float));
    pWeightCharacteristic->notify();
  }
}

// =============================================================================
// Setup
// =============================================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n\nOpenScale Starting...");

  // Check wake reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT0) {
    Serial.println("Woke up from button press");

    // Wait for button release (long press to wake)
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    unsigned long wakeStart = millis();
    while (digitalRead(BUTTON_PIN) == LOW) {
      if (millis() - wakeStart > LONG_PRESS_MS) {
        break;  // Long press confirmed
      }
      delay(10);
    }
  }

  // Load saved settings from NVS
  loadDeviceName();
  loadDisplayUnit();
  loadCalibration();

  // Initialize components
  initButton();
  initDisplay();
  delay(100);

  initScale();
  delay(100);

  initBLE();

  // Initialize activity timer
  lastActivityTime = millis();
  previousWeight = 0.0f;

  // Update display with initial state
  updateDisplay();

  Serial.println("Setup complete!");
}

// =============================================================================
// Main Loop
// =============================================================================
void loop() {
  unsigned long currentTime = millis();

  // Handle button input
  handleButton();

  // Handle calibration mode display
  if (calibrationMode) {
    displayCalibrationScreen();
    delay(100);
    return;
  }

  // Read and process weight at the configured sample rate
  if (currentTime - lastSampleTime >= sampleInterval) {
    lastSampleTime = currentTime;

    // Read weight
    currentWeight = readWeight();

    // Update peak weight
    if (currentWeight > peakWeight) {
      peakWeight = currentWeight;
    }

    // Send via BLE
    sendWeightBLE();
  }

  // Update display less frequently to avoid flicker
  static unsigned long lastDisplayUpdate = 0;
  if (currentTime - lastDisplayUpdate >= (1000 / DISPLAY_UPDATE_RATE_HZ)) {
    lastDisplayUpdate = currentTime;
    updateDisplay();
  }

  // Check for inactivity (power management)
  checkInactivity();

  // Handle BLE reconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);  // Give the Bluetooth stack time to get ready
    pServer->startAdvertising();
    Serial.println("Started advertising");
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  // Small delay to prevent watchdog issues
  delay(1);
}
