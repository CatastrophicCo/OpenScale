# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenScale is a Bluetooth-enabled force measurement device for climbing/hangboard training. It consists of:
- **ESP32 firmware** (Arduino): Reads load cell, displays weight on OLED, streams data via BLE
- **iOS app** (SwiftUI): Connects via BLE, displays real-time weight, graphs force over time, records sessions
- **Android app** (Flutter): Cross-platform app with BLE connection, real-time display, graphing
- **Web app** (Web Bluetooth): Browser-based app for Chrome/Edge/Opera with live display and graphing

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

### iOS App
```bash
# Open in Xcode
open ios-app/OpenScale/LineScale.xcodeproj

# Build from command line
xcodebuild -project ios-app/OpenScale/LineScale.xcodeproj -scheme LineScale -destination 'platform=iOS,name=iPhone'
```

### Flutter App (Android)
```bash
# Navigate to Flutter app directory
cd flutter-app/open_scale

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build APK
flutter build apk --release
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
| Calibration | `D5875408-FA51-4E89-A0F7-3C7E8E8C5E41` | float32 | Bidirectional |
| **Device Name** | `8A2C5F47-B91E-4D36-A6C8-9F0E7D3B1C28` | string (max 20) | Bidirectional |

Weight is always transmitted in **grams** over BLE. Apps convert to user's preferred unit (lbs/kg/g). The ESP32 display shows **pounds**.

### Multi-Device Support
Each ESP32 advertises as `OpenScale-XXXX` where XXXX is derived from the device's MAC address, or a custom name if set. This allows multiple devices in the same room. Apps do NOT auto-connect; users must manually select their device.

### Device Renaming
The firmware supports persistent device renaming via NVS (Non-Volatile Storage). Custom names survive power cycles and are stored using the ESP32 Preferences library.

### Key Files
- `firmware/OpenScale/config.h` - All hardware pin mappings and BLE UUIDs
- `firmware/OpenScale/OpenScale.ino` - Main firmware with NVS device naming
- `ios-app/OpenScale/.../BluetoothManager.swift` - iOS BLE communication
- `flutter-app/open_scale/lib/services/bluetooth_service.dart` - Flutter BLE service
- `docs/js/bluetooth.js` - Web Bluetooth API wrapper
- `firmware/Calibration/Calibration.ino` - Interactive serial tool to find CALIBRATION_FACTOR

### Calibration
The load cell requires calibration. Use `firmware/Calibration/Calibration.ino` with Serial Monitor at 115200 baud. Apply known weight and adjust factor until reading matches. Update `CALIBRATION_FACTOR` in `config.h`.
