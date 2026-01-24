/*
 * LineScale Configuration
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
// Use the calibration sketch to determine this value
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

#define DEVICE_NAME "LineScale"

// UUID for the LineScale service
// You can generate your own at https://www.uuidgenerator.net/
#define SERVICE_UUID                "4FAFC201-1FB5-459E-8FCC-C5C9C331914B"

// Characteristic UUIDs
#define WEIGHT_CHAR_UUID            "BEB5483E-36E1-4688-B7F5-EA07361B26A8"
#define TARE_CHAR_UUID              "1C95D5E3-D8F7-413A-BF3D-7A2E5D7BE87E"
#define SAMPLE_RATE_CHAR_UUID       "A8985FAE-51A4-4E28-B0A2-6C1AEEDE3F3D"
#define CALIBRATION_CHAR_UUID       "D5875408-FA51-4E89-A0F7-3C7E8E8C5E41"

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

#endif // CONFIG_H
