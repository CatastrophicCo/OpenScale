/*
 * LineScale - Bluetooth Hangboard Training Scale
 *
 * Hardware: XIAO ESP32C6, HX711, 4-pin strain gauge, I2C OLED
 *
 * Pin Connections:
 *   HX711: DT->D4, SCK->D5
 *   OLED:  SCL->D0, SDA->D1
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

#include "config.h"

// =============================================================================
// Global Objects
// =============================================================================
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
HX711 scale;

BLEServer* pServer = nullptr;
BLECharacteristic* pWeightCharacteristic = nullptr;
BLECharacteristic* pTareCharacteristic = nullptr;
BLECharacteristic* pSampleRateCharacteristic = nullptr;
BLECharacteristic* pCalibrationCharacteristic = nullptr;

// =============================================================================
// Global Variables
// =============================================================================
bool deviceConnected = false;
bool oldDeviceConnected = false;
float currentWeight = 0.0f;
float peakWeight = 0.0f;
float calibrationFactor = CALIBRATION_FACTOR;
uint8_t sampleRateHz = DEFAULT_SAMPLE_RATE_HZ;
unsigned long lastSampleTime = 0;
unsigned long sampleInterval = 1000 / DEFAULT_SAMPLE_RATE_HZ;

// =============================================================================
// BLE Server Callbacks
// =============================================================================
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
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
    scale.tare(10);  // Average 10 readings for tare
    peakWeight = 0.0f;  // Reset peak weight
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
class CalibrationCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    uint8_t* data = pCharacteristic->getData();
    size_t len = pCharacteristic->getLength();
    if (data != nullptr && len >= sizeof(float)) {
      memcpy(&calibrationFactor, data, sizeof(float));
      scale.set_scale(calibrationFactor);
      Serial.printf("Calibration factor set to %.2f\n", calibrationFactor);
    }
  }

  void onRead(BLECharacteristic* pCharacteristic) {
    pCharacteristic->setValue((uint8_t*)&calibrationFactor, sizeof(float));
  }
};

// =============================================================================
// Initialize Display
// =============================================================================
void initDisplay() {
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    Serial.println("SSD1306 allocation failed!");
    // Continue anyway - device works without display
    return;
  }

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("LineScale");
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
// Get Unique Device Name (includes last 4 chars of MAC address)
// =============================================================================
String getUniqueDeviceName() {
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
  String uniqueName = getUniqueDeviceName();
  Serial.printf("Device name: %s\n", uniqueName.c_str());
  BLEDevice::init(uniqueName.c_str());

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

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // For iPhone connection
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE advertising started");
}

// =============================================================================
// Update Display (128x32 OLED - Weight in Pounds)
// =============================================================================
void updateDisplay() {
  display.clearDisplay();

  // Convert weight to pounds
  float weightLbs = currentWeight * GRAMS_TO_LBS;
  float peakLbs = peakWeight * GRAMS_TO_LBS;

  // Current weight - large text (top portion)
  display.setTextSize(2);
  display.setCursor(0, 0);
  display.printf("%6.1f", weightLbs);

  // Units label
  display.setTextSize(1);
  display.setCursor(85, 4);
  display.print("lbs");

  // Connection status indicator
  display.setCursor(SCREEN_WIDTH - 12, 0);
  if (deviceConnected) {
    display.print("BT");
  } else {
    display.print("--");
  }

  // Bottom row: Peak weight
  display.setCursor(0, 24);
  display.printf("Peak: %.1f lbs", peakLbs);

  display.display();
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
    // Send weight as float (4 bytes)
    pWeightCharacteristic->setValue((uint8_t*)&currentWeight, sizeof(float));
    pWeightCharacteristic->notify();
  }
}

// =============================================================================
// Setup
// =============================================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n\nLineScale Starting...");

  // Initialize components
  initDisplay();
  delay(100);

  initScale();
  delay(100);

  initBLE();

  // Update display with initial state
  updateDisplay();

  Serial.println("Setup complete!");
}

// =============================================================================
// Main Loop
// =============================================================================
void loop() {
  unsigned long currentTime = millis();

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

    // Debug output (show both grams and pounds)
    float lbs = currentWeight * GRAMS_TO_LBS;
    float peakLbs = peakWeight * GRAMS_TO_LBS;
    Serial.printf("Weight: %.1f lbs / %.0f g (Peak: %.1f lbs)\n", lbs, currentWeight, peakLbs);
  }

  // Update display less frequently to avoid flicker
  static unsigned long lastDisplayUpdate = 0;
  if (currentTime - lastDisplayUpdate >= (1000 / DISPLAY_UPDATE_RATE_HZ)) {
    lastDisplayUpdate = currentTime;
    updateDisplay();
  }

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
