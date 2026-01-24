# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenScale is a Bluetooth-enabled force measurement device for climbing/hangboard training. It consists of:
- **ESP32 firmware** (Arduino): Reads load cell, displays weight on OLED, streams data via BLE, single-button interface
- **Mobile app** (Flutter): Cross-platform app for iOS and Android with BLE connection, real-time display, graphing
- **Web app** (Web Bluetooth): Browser-based app for Chrome/Edge/Opera with live display and graphing

### Hardware
- XIAO ESP32C6, HX711, 4-pin strain gauge, I2C OLED, tactile button
- Wiring: HX711 (DT→D4, SCK→D5), OLED (SCL→D0, SDA→D1), Button (D2→GND)

### Button Functions
- **Short press**: Tare the scale
- **Long press**: Toggle display units (lbs ↔ kg)
- **Long press from sleep**: Wake device
- **S-S-S-L-S-S-S sequence**: Enter calibration mode (10 lb weight)

### Power Management
Device enters deep sleep after 10 minutes of inactivity. Wake with long button press.

## Build Commands

### Firmware (Arduino)
```bash
# Requires Arduino IDE or arduino-cli with ESP32 board support
# Board: Seeed XIAO ESP32C6
# Required libraries: HX711 (bogde), Adafruit SSD1306, Adafruit GFX

# Compile (arduino-cli)
arduino-cli compile --fqbn esp32:esp32:XIAO_ESP32C6 firmware/OpenScale

# Upload
arduino-cli upload -p COM_PORT --fqbn esp32:esp32:XIAO_ESP32C6 firmware/OpenScale
```

### Flutter App (iOS & Android)
```bash
# Navigate to Flutter app directory
cd flutter-app/open_scale

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build Android APK
flutter build apk --release

# Build iOS (requires macOS with Xcode)
flutter build ios --release
```

### Web App
The web app is served via GitHub Pages. Files are in `docs/` and include:
- `docs/app.html` - Main web application
- `docs/js/bluetooth.js` - Web Bluetooth API wrapper
- `docs/js/app.js` - Application logic

## Architecture

### BLE Protocol
The firmware and apps communicate via BLE using a custom service. **UUIDs must match exactly** across all components.

| Characteristic | UUID | Data Type | Direction |
|----------------|------|-----------|-----------|
| Weight | `BEB5483E-36E1-4688-B7F5-EA07361B26A8` | float32 (grams) | Device → App (notify) |
| Tare | `1C95D5E3-D8F7-413A-BF3D-7A2E5D7BE87E` | any byte | App → Device (write) |
| Sample Rate | `A8985FAE-51A4-4E28-B0A2-6C1AEEDE3F3D` | uint8 (1-80 Hz) | Bidirectional |
| Calibration | `D5875408-FA51-4E89-A0F7-3C7E8E8C5E41` | float32 (see below) | Bidirectional |
| **Device Name** | `8A2C5F47-B91E-4D36-A6C8-9F0E7D3B1C28` | string (max 20) | Bidirectional |

Weight is always transmitted in **grams** over BLE. Apps convert to user's preferred unit (lbs/kg/g). The ESP32 display shows **pounds**.

### Multi-Device Support
Each ESP32 advertises as `OpenScale-XXXX` where XXXX is derived from the device's MAC address, or a custom name if set. This allows multiple devices in the same room. Apps do NOT auto-connect; users must manually select their device.

### Device Renaming
The firmware supports persistent device renaming via NVS (Non-Volatile Storage). Custom names survive power cycles and are stored using the ESP32 Preferences library.

### Key Files
- `firmware/OpenScale/config.h` - All hardware pin mappings and BLE UUIDs
- `firmware/OpenScale/OpenScale.ino` - Main firmware with NVS device naming
- `flutter-app/open_scale/lib/services/bluetooth_service.dart` - Flutter BLE service
- `flutter-app/open_scale/lib/screens/home_screen.dart` - Main app screen
- `flutter-app/open_scale/lib/screens/settings_screen.dart` - Settings and device config
- `docs/js/bluetooth.js` - Web Bluetooth API wrapper
- `firmware/Calibration/Calibration.ino` - Interactive serial tool to find CALIBRATION_FACTOR

### Calibration

The load cell requires calibration. There are three methods:

**Method 1: Button Sequence (on device)**
- Press S-S-S-L-S-S-S (short-short-short-long-short-short-short)
- Remove all weight, press button
- Place 10 lb known weight, press button
- Calibration is saved to NVS automatically

**Method 2: BLE Calibration (from app)**
The calibration characteristic accepts special float32 values:
| Value | Action |
|-------|--------|
| `0.0` | Start calibration step 1 (tare with no weight) |
| `-1.0` | Complete calibration step 2 (calculate factor from 10 lb weight) |
| `> 0` | Directly set calibration factor |

**Method 3: Serial Calibration Utility**
Use `firmware/Calibration/Calibration.ino` with Serial Monitor at 115200 baud. Apply known weight and adjust factor with +/- keys until reading matches. Note the value and update `CALIBRATION_FACTOR` in `config.h`, or set via BLE.

All calibration methods save to NVS and persist after power cycles.
