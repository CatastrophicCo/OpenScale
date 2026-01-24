/*
 * LineScale Calibration Utility
 *
 * Use this sketch to calibrate your load cell.
 *
 * Instructions:
 * 1. Upload this sketch to your ESP32C6
 * 2. Open Serial Monitor at 115200 baud
 * 3. Remove all weight from the scale
 * 4. Press 't' to tare
 * 5. Place a known weight on the scale
 * 6. Enter the known weight value
 * 7. Adjust calibration factor with '+'/'-' until reading matches
 * 8. Note the calibration factor and update config.h
 *
 * Serial Commands:
 *   t - Tare (zero) the scale
 *   + - Increase calibration factor by 10
 *   - - Decrease calibration factor by 10
 *   ] - Increase calibration factor by 100
 *   [ - Decrease calibration factor by 100
 *   r - Print raw reading
 *   c - Print current calibration factor
 *   0-9 - Enter known weight (then press Enter)
 */

#include <HX711.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// Pin Definitions for XIAO ESP32C6
#define HX711_DT_PIN    D4
#define HX711_SCK_PIN   D5
#define I2C_SDA_PIN     D1
#define I2C_SCL_PIN     D0

// OLED Configuration (128x32 display)
#define SCREEN_WIDTH    128
#define SCREEN_HEIGHT   32
#define OLED_RESET      -1
#define OLED_ADDRESS    0x3C

// Global Objects
HX711 scale;
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Calibration factor - start with a reasonable default
float calibrationFactor = 420.0f;
String inputBuffer = "";

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n========================================");
  Serial.println("LineScale Calibration Utility");
  Serial.println("========================================\n");

  // Initialize I2C and display
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  if (display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Calibration Mode");
    display.display();
  }

  // Initialize HX711
  Serial.println("Initializing HX711...");
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);

  // Wait for HX711 to be ready
  int timeout = 0;
  while (!scale.is_ready() && timeout < 100) {
    delay(50);
    timeout++;
  }

  if (!scale.is_ready()) {
    Serial.println("ERROR: HX711 not found!");
    Serial.println("Check wiring:");
    Serial.println("  DT  -> D4");
    Serial.println("  SCK -> D5");
    Serial.println("  VCC -> 3.3V");
    Serial.println("  GND -> GND");
    while (1) {
      delay(1000);
    }
  }

  Serial.println("HX711 found!\n");

  // Read raw value to verify connection
  long rawValue = scale.read();
  Serial.printf("Raw reading: %ld\n\n", rawValue);

  // Set initial calibration and tare
  scale.set_scale(calibrationFactor);
  Serial.println("Remove all weight and press 't' to tare...\n");

  printHelp();
}

void printHelp() {
  Serial.println("Commands:");
  Serial.println("  t - Tare (zero) the scale");
  Serial.println("  + - Calibration factor +10");
  Serial.println("  - - Calibration factor -10");
  Serial.println("  ] - Calibration factor +100");
  Serial.println("  [ - Calibration factor -100");
  Serial.println("  r - Print raw reading");
  Serial.println("  c - Print calibration factor");
  Serial.println("  h - Print this help");
  Serial.println("  Enter number - Set known weight\n");
}

void loop() {
  // Read current weight
  float weight = 0;
  if (scale.is_ready()) {
    weight = scale.get_units(5);  // Average 5 readings
  }

  // Update display
  updateDisplay(weight);

  // Print weight to serial periodically
  static unsigned long lastPrint = 0;
  if (millis() - lastPrint > 500) {
    lastPrint = millis();
    Serial.printf("Weight: %.1f g  |  Cal Factor: %.1f  |  Raw: %ld\n",
                  weight, calibrationFactor, scale.read_average(3));
  }

  // Handle serial input
  while (Serial.available()) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      // Process buffered input
      if (inputBuffer.length() > 0) {
        processInput(inputBuffer);
        inputBuffer = "";
      }
    } else if (c == 't') {
      // Tare
      Serial.println("\nTaring... keep scale empty");
      scale.tare(10);
      Serial.println("Tare complete!\n");
    } else if (c == '+') {
      calibrationFactor += 10;
      scale.set_scale(calibrationFactor);
      Serial.printf("Calibration factor: %.1f\n", calibrationFactor);
    } else if (c == '-') {
      calibrationFactor -= 10;
      scale.set_scale(calibrationFactor);
      Serial.printf("Calibration factor: %.1f\n", calibrationFactor);
    } else if (c == ']') {
      calibrationFactor += 100;
      scale.set_scale(calibrationFactor);
      Serial.printf("Calibration factor: %.1f\n", calibrationFactor);
    } else if (c == '[') {
      calibrationFactor -= 100;
      scale.set_scale(calibrationFactor);
      Serial.printf("Calibration factor: %.1f\n", calibrationFactor);
    } else if (c == 'r') {
      Serial.printf("Raw reading: %ld\n", scale.read());
    } else if (c == 'c') {
      Serial.printf("\n*** Calibration Factor: %.1f ***\n\n", calibrationFactor);
      Serial.println("Copy this to config.h:");
      Serial.printf("#define CALIBRATION_FACTOR  %.1ff\n\n", calibrationFactor);
    } else if (c == 'h') {
      printHelp();
    } else if ((c >= '0' && c <= '9') || c == '.' || c == '-') {
      inputBuffer += c;
    }
  }

  delay(10);
}

void processInput(String input) {
  float knownWeight = input.toFloat();
  if (knownWeight != 0) {
    Serial.printf("\nSetting known weight: %.1f g\n", knownWeight);
    Serial.println("Adjust calibration with +/- until reading matches.\n");
  }
}

void updateDisplay(float weight) {
  display.clearDisplay();

  // Weight in pounds (primary) and grams
  float weightLbs = weight / 453.592f;

  // Current weight - large text
  display.setTextSize(2);
  display.setCursor(0, 0);
  display.printf("%5.1f", weightLbs);

  display.setTextSize(1);
  display.setCursor(72, 4);
  display.print("lbs");

  // Calibration factor on bottom row
  display.setCursor(0, 24);
  display.printf("Cal:%.0f  %.0fg", calibrationFactor, weight);

  display.display();
}
