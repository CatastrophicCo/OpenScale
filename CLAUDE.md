# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LineScale is a Bluetooth-enabled force measurement device for climbing/hangboard training. It consists of two components:
- **ESP32 firmware** (Arduino): Reads load cell, displays weight on OLED, streams data via BLE
- **iOS app** (SwiftUI): Connects via BLE, displays real-time weight, graphs force over time, records sessions

## Build Commands

### Firmware (Arduino)
```bash
# Requires Arduino IDE or arduino-cli with ESP32 board support
# Board: Seeed XIAO ESP32C6
# Required libraries: HX711 (bogde), Adafruit SSD1306, Adafruit GFX

# Compile (arduino-cli)
arduino-cli compile --fqbn esp32:esp32:XIAO_ESP32C6 firmware/LineScale

# Upload
arduino-cli upload -p COM_PORT --fqbn esp32:esp32:XIAO_ESP32C6 firmware/LineScale
```

### iOS App
```bash
# Open in Xcode
open ios-app/LineScale/LineScale.xcodeproj

# Build from command line
xcodebuild -project ios-app/LineScale/LineScale.xcodeproj -scheme LineScale -destination 'platform=iOS,name=iPhone'
```

## Architecture

### BLE Protocol
The firmware and iOS app communicate via BLE using a custom service. **UUIDs must match exactly** between `firmware/LineScale/config.h` and `ios-app/LineScale/LineScale/Models/BluetoothManager.swift`.

| Characteristic | Data Type | Direction |
|----------------|-----------|-----------|
| Weight | float32 (grams) | Device → App (notify) |
| Tare | any byte | App → Device (write) |
| Sample Rate | uint8 (1-80 Hz) | Bidirectional |
| Calibration | float32 | Bidirectional |

Weight is always transmitted in **grams** over BLE. The iOS app converts to user's preferred unit (lbs/kg/g). The ESP32 display shows **pounds**.

### Multi-Device Support
Each ESP32 advertises as `LineScale-XXXX` where XXXX is derived from the device's MAC address. This allows multiple devices in the same room. The iOS app does NOT auto-connect; users must manually select their device.

### Key Files
- `firmware/LineScale/config.h` - All hardware pin mappings and BLE UUIDs
- `ios-app/.../Models/BluetoothManager.swift` - BLE communication (must match firmware UUIDs)
- `ios-app/.../Models/WeightData.swift` - Data models and session persistence
- `firmware/Calibration/Calibration.ino` - Interactive serial tool to find CALIBRATION_FACTOR

### Calibration
The load cell requires calibration. Use `firmware/Calibration/Calibration.ino` with Serial Monitor at 115200 baud. Apply known weight and adjust factor until reading matches. Update `CALIBRATION_FACTOR` in `config.h`.
