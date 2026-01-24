/*
 * OpenScale Configuration
 *
 * Adjust these values for your specific hardware setup
 */

#ifndef CONFIG_H
#define CONFIG_H

// =============================================================================
// Pin Definitions for XIAO ESP32C6
// =============================================================================

// HX711 Load Cell Amplifier
#define HX711_DT_PIN    D4    // Data pin (DT/DOUT)
#define HX711_SCK_PIN   D5    // Clock pin (SCK/PD_SCK)

// I2C OLED Display
#define I2C_SDA_PIN     D1    // SDA
#define I2C_SCL_PIN     D0    // SCL

// Button (active LOW - connect button between pin and GND)
#define BUTTON_PIN      D2    // Multi-function button

// =============================================================================
// Button Configuration
// =============================================================================

#define LONG_PRESS_MS           1000    // Duration for long press (ms)
#define SHORT_PRESS_MAX_MS      500     // Maximum duration for short press (ms)
#define DEBOUNCE_MS             50      // Button debounce time (ms)
#define SEQUENCE_TIMEOUT_MS     3000    // Timeout between button presses in sequence (ms)

// Calibration sequence: short, short, short, long, short, short, short
// Encoded as: 0=short, 1=long
#define CALIBRATION_SEQUENCE_LENGTH 7
const uint8_t CALIBRATION_SEQUENCE[CALIBRATION_SEQUENCE_LENGTH] = {0, 0, 0, 1, 0, 0, 0};

// Known calibration weight in grams (10 lbs = 4535.92 grams)
#define CALIBRATION_WEIGHT_GRAMS    4535.92f
#define CALIBRATION_WEIGHT_LBS      10.0f

// =============================================================================
// Power Management Configuration
// =============================================================================

#define INACTIVITY_TIMEOUT_MS   600000  // 10 minutes in milliseconds
#define WAKE_BUTTON_PIN         BUTTON_PIN  // Wake from deep sleep on this pin

// Weight change threshold to reset inactivity timer (grams)
#define ACTIVITY_THRESHOLD      50.0f

// =============================================================================
// OLED Display Configuration
// =============================================================================

#define SCREEN_WIDTH    128
#define SCREEN_HEIGHT   32    // 128x32 OLED display
#define OLED_RESET      -1    // -1 if sharing Arduino reset pin
#define OLED_ADDRESS    0x3C  // Common addresses: 0x3C or 0x3D

// =============================================================================
// HX711 / Load Cell Configuration
// =============================================================================

// Calibration factor - MUST BE CALIBRATED FOR YOUR LOAD CELL
// Use the calibration sketch or button sequence to determine this value
// Positive values = reading increases when weight is applied
// Negative values = reading decreases when weight is applied
#define CALIBRATION_FACTOR  420.0f

// Number of readings to average for each measurement
// Higher = more stable, but slower response
// Recommended: 1-4 for fast response, 5-10 for stability
#define READINGS_TO_AVERAGE 2

// HX711 Gain setting
// 128 = Channel A, gain 128 (most sensitive)
// 64  = Channel A, gain 64
// 32  = Channel B, gain 32
#define HX711_GAIN          128

// Noise threshold - readings below this are set to zero
#define NOISE_THRESHOLD     5.0f

// =============================================================================
// BLE Configuration
// =============================================================================

#define DEVICE_NAME "OpenScale"

// UUID for the OpenScale service
// You can generate your own at https://www.uuidgenerator.net/
#define SERVICE_UUID                "4FAFC201-1FB5-459E-8FCC-C5C9C331914B"

// Characteristic UUIDs
#define WEIGHT_CHAR_UUID            "BEB5483E-36E1-4688-B7F5-EA07361B26A8"
#define TARE_CHAR_UUID              "1C95D5E3-D8F7-413A-BF3D-7A2E5D7BE87E"
#define SAMPLE_RATE_CHAR_UUID       "A8985FAE-51A4-4E28-B0A2-6C1AEEDE3F3D"
#define CALIBRATION_CHAR_UUID       "D5875408-FA51-4E89-A0F7-3C7E8E8C5E41"
#define DEVICE_NAME_CHAR_UUID       "8A2C5F47-B91E-4D36-A6C8-9F0E7D3B1C28"

// Maximum length for custom device name (excluding null terminator)
#define MAX_DEVICE_NAME_LENGTH      20

// NVS namespace for persistent storage
#define NVS_NAMESPACE               "openscale"
#define NVS_KEY_DEVICE_NAME         "device_name"
#define NVS_KEY_DISPLAY_UNIT        "display_unit"
#define NVS_KEY_CALIBRATION         "calibration"

// =============================================================================
// Sampling Configuration
// =============================================================================

#define DEFAULT_SAMPLE_RATE_HZ  10    // Default samples per second
#define MAX_SAMPLE_RATE_HZ      80    // HX711 max is 80Hz in high-speed mode
#define MIN_SAMPLE_RATE_HZ      1

// Display update rate (Hz) - independent of sample rate
#define DISPLAY_UPDATE_RATE_HZ  10

// =============================================================================
// Unit Conversions
// =============================================================================

#define GRAMS_TO_KG     0.001f
#define GRAMS_TO_LBS    0.00220462f
#define GRAMS_TO_OZ     0.035274f

// Display unit options
#define UNIT_LBS        0
#define UNIT_KG         1

#endif // CONFIG_H
