# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenScale is a Bluetooth-enabled force measurement device for climbing/hangboard training. It consists of:
- **ESP32 firmware** (Arduino): Reads load cell, displays weight on OLED, streams data via BLE, single-button interface
- **Mobile app** (Flutter): Cross-platform app for iOS and Android with BLE connection, real-time display, graphing
- **Web app** (Web Bluetooth): Browser-based app for Chrome/Edge/Opera with live display and graphing

### Hardware
Two hardware variants exist:

**Prototype (XIAO dev board):**
- XIAO ESP32C6, HX711, 4-pin strain gauge, I2C OLED (SSD1306), tactile button
- Wiring: HX711 (DT→D4, SCK→D5), OLED (SCL→D0, SDA→D1), Button (D2→GND)

**Custom PCB (production):**
- ESP32-C6-MINI-1 module, HX711 IC, WO1602M-TFH-AT LCD (DigiKey), USB-C, LiPo charging
- See `hardware/kicad/README.md` for full schematic and BOM
- LCD uses ST7032 controller at I2C address 0x3E (not SSD1306)

### Button Functions
- **Single press**: Tare the scale (zero the current reading)
- **Double press**: Reset peak weight display
- **Long press**: Toggle display units (lbs ↔ kg) - shows preview of new unit while held
- **Long press from sleep**: Wake device
- **S-S-S-L-S-S-S sequence**: Enter calibration mode

### Power Management
Device enters deep sleep after 10 minutes of inactivity. Wake with long button press.

## Build Commands

### Firmware (Arduino)
```bash
# Requires Arduino IDE or arduino-cli with ESP32 board support
# Board: Seeed XIAO ESP32C6 (prototype) or ESP32-C6 (custom PCB)

# Required libraries (prototype with OLED):
#   HX711 (bogde), Adafruit SSD1306, Adafruit GFX
# Required libraries (custom PCB with LCD):
#   HX711 (bogde), ST7032 or LiquidCrystal_I2C

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

The load cell requires calibration. There are multiple methods:

**Method 1: Button Sequence (on device)**
- Press S-S-S-L-S-S-S (short-short-short-long-short-short-short)
- Remove all weight, press button
- Place 10 lb known weight, press button
- Calibration is saved to NVS automatically

**Method 2: Auto Calibration (from app - custom weight)**
Both web and Flutter apps support auto calibration with any known weight:
1. Enter your known weight value and unit (lbs or kg)
2. Start calibration (scale tares with no weight)
3. Place your known weight on the scale
4. Complete calibration - the app calculates the factor using your custom weight

The apps send `0.0` to start calibration, then calculate the factor locally using the raw reading and user's weight, then send the factor directly to the device.

**Method 3: Manual Calibration Factor (from app)**
Both apps allow directly setting a known calibration factor:
- Web: Use the "Manual" tab in calibration settings
- Flutter: Tap the edit icon next to "Current Calibration Factor"

**Method 4: Serial Calibration Utility**
Use `firmware/Calibration/Calibration.ino` with Serial Monitor at 115200 baud. Apply known weight and adjust factor with +/- keys until reading matches. Note the value and update `CALIBRATION_FACTOR` in `config.h`, or set via BLE.

**BLE Calibration Protocol:**
| Value | Action |
|-------|--------|
| `0.0` | Start calibration step 1 (tare with no weight, set scale to 1.0) |
| `-1.0` | Complete calibration step 2 (legacy: calculate factor from 10 lb weight) |
| `> 0` | Directly set calibration factor |

All calibration methods save to NVS and persist after power cycles.

### Force Graph

Both web and Flutter apps include a force graph with time range controls:
- **All Time**: Shows entire session since connecting
- **Recent**: Last 30 sec, 1 min, 5 min (default), or 10 min
- **Custom Range**: Enter start/end times in seconds since connection

The web app additionally supports:
- Drag-to-zoom on the chart
- Mouse wheel zoom
- Double-click to reset zoom

Data is stored for up to 1 hour at the configured sample rate.

### Device Emulator

Both web and Flutter apps include a device emulator for testing without physical hardware.

#### Web App Emulator

1. Scroll down to the **Settings** section
2. Find the **Device Emulator** section at the bottom
3. Click **Connect Emulator**
4. The status will change to "Emulator Connected" and weight data will start streaming
5. Adjust simulation settings:
   - **Simulation Mode**: Choose the type of simulated data
   - **Manual Weight**: Set specific weight (only in Manual mode)
   - **Noise Level**: Adjust random noise amplitude
6. Click **Disconnect Emulator** to stop

#### Flutter App Emulator

1. Tap **Connect** to open the device list
2. At the top of the list, select **OpenScale-EMU (Emulator)**
3. The app connects immediately without Bluetooth
4. When connected to the emulator, additional controls appear below the force graph
5. Adjust simulation mode, weight, and noise from these controls

#### Simulation Modes

| Mode | Description |
|------|-------------|
| **Idle (Noise)** | Random fluctuations around zero - tests display stability |
| **Climbing Pulls** | Realistic climbing pattern: 2-5s rest → quick load to 15-40kg → hold 3-10s with fatigue → quick release. Repeats continuously. |
| **Sustained Hold** | Ramps to 20kg and holds with gradual fatigue simulation |
| **Ramp Up/Down** | 10-second cycles smoothly ramping 0→30kg→0 |
| **Manual** | Set exact weight via slider (0-50kg) with minimal noise |

#### Emulator Files

- `docs/js/emulator.js` - Web emulator implementation
- `flutter-app/open_scale/lib/services/emulator_service.dart` - Flutter emulator
- `flutter-app/open_scale/lib/services/scale_service.dart` - Unified service switching between real/emulator

#### Use Cases

- **UI Development**: Test app UI without hardware
- **Demo Mode**: Show the app to others without a physical device
- **Automated Testing**: Consistent, repeatable data for tests
- **Graph Testing**: Verify chart behavior with known patterns
