# OpenScale - Bluetooth Hangboard Training Scale

A Bluetooth-enabled line scale designed for climbing training, specifically for hangboard exercises. The device measures force/weight in real-time and transmits data to mobile and web apps for visualization and analysis.

## Project Status

**Current Version:** 1.0.0

### Features

- [x] ESP32 firmware with BLE connectivity
- [x] HX711 load cell integration
- [x] 128x32 OLED display (weight in pounds)
- [x] Cross-platform mobile app (Flutter - iOS & Android)
- [x] Web app with Web Bluetooth API
- [x] Real-time weight streaming via BLE
- [x] Live force graphing
- [x] Training session recording
- [x] Multi-device support (unique device names)
- [x] Device renaming (persistent via NVS)
- [x] Tare/zero functionality
- [x] Adjustable sample rate (1-80 Hz)
- [x] Calibration utility sketch

## Hardware Components

| Component | Description | Approx. Cost |
|-----------|-------------|--------------|
| **XIAO ESP32C6** | Microcontroller with BLE support | $5 |
| **HX711** | 24-bit ADC for load cell amplification | $2 |
| **4-Pin Strain Gauge** | Load cell for force measurement (50-200kg) | $5-15 |
| **128x32 I2C OLED** | Mini display for local readout | $3 |
| **Tactile Button** | Momentary push button for tare/wake/settings | $0.10 |

**Total estimated cost:** $15-25

## Pin Connections

### HX711 Load Cell Amplifier
| HX711 Pin | ESP32C6 Pin |
|-----------|-------------|
| VCC | 3.3V |
| GND | GND |
| DT (Data) | D4 |
| SCK (Clock) | D5 |

### I2C OLED Display
| OLED Pin | ESP32C6 Pin |
|----------|-------------|
| VCC | 3.3V |
| GND | GND |
| SCL | D0 |
| SDA | D1 |

### Button
| Button | ESP32C6 Pin |
|--------|-------------|
| One side | D2 |
| Other side | GND |

The button uses the internal pull-up resistor. No external resistor needed.

## Button Functions

| Action | Function |
|--------|----------|
| Short press | Tare/zero the scale |
| Long press (>1s) | Toggle units (lbs ↔ kg) |
| Long press from sleep | Wake up device |
| S-S-S-L-S-S-S sequence | Enter calibration mode |

## Power Management

The OpenScale automatically enters ultra-low-power sleep mode after 10 minutes of inactivity:
- No weight change detected
- No BLE connection
- No button presses

To wake the device, perform a long button press (hold for >1 second).

## Apps

### Mobile App (Flutter - iOS & Android)
Cross-platform Flutter app with:
- Material Design 3 dark theme
- BLE connection via flutter_blue_plus
- Real-time graphing with fl_chart
- Device renaming
- Session recording and history
- Unit conversion (lbs/kg/g)

### Web App (Web Bluetooth)
Browser-based app (Chrome/Edge/Opera) with:
- No installation required
- Real-time weight display
- Live force graph
- Device configuration
- Works on HTTPS or localhost

## Multi-Device Support

OpenScale supports multiple devices in the same room. Each device advertises with a unique name based on its MAC address:

- `OpenScale-A1B2`
- `OpenScale-C3D4`
- Or a custom name you set

Users select their specific device from the list in any app. This allows climbing gyms or training groups to use multiple OpenScales simultaneously without interference.

## Project Structure

```
OpenScale/
├── README.md
├── CLAUDE.md
├── firmware/
│   ├── OpenScale/
│   │   ├── OpenScale.ino
│   │   └── config.h
│   └── Calibration/
│       └── Calibration.ino
├── flutter-app/
│   └── open_scale/
│       ├── pubspec.yaml
│       ├── android/
│       ├── ios/
│       └── lib/
│           ├── main.dart
│           ├── models/
│           ├── services/
│           ├── screens/
│           └── widgets/
├── docs/
│   ├── index.html
│   ├── app.html
│   └── js/
└── user_docs/
    ├── firmware-setup.md
    ├── mobile-app-setup.md
    └── github-pages-setup.md
```

## Getting Started

### 1. Firmware Setup
1. Install Arduino IDE or PlatformIO
2. Add ESP32 board support (Seeed XIAO ESP32C6)
3. Install required libraries:
   - HX711 by bogde
   - Adafruit SSD1306
   - Adafruit GFX Library
4. Upload `firmware/Calibration/Calibration.ino` first
5. Calibrate your load cell (see user_docs/firmware-setup.md)
6. Update `CALIBRATION_FACTOR` in `config.h`
7. Upload `firmware/OpenScale/OpenScale.ino`

### 2. Mobile App Setup (Flutter)

#### Prerequisites
- Flutter SDK 3.0 or later
- For iOS: macOS with Xcode 15+
- For Android: Android Studio with Android SDK

#### Android Build
```bash
cd flutter-app/open_scale
flutter pub get
flutter run                    # Run on connected device
flutter build apk --release    # Build release APK
```

#### iOS Build
```bash
cd flutter-app/open_scale
flutter pub get
open ios/Runner.xcworkspace    # Open in Xcode
# Configure signing in Xcode, then:
flutter run                    # Run on connected device
flutter build ios --release    # Build release IPA
```

### 3. Web App
1. Visit the hosted web app or run locally
2. Click "Connect" and select your OpenScale
3. Requires Chrome, Edge, or Opera browser

### 4. First Use
1. Power on your OpenScale device
2. Open any app and scan for devices
3. Select your OpenScale (e.g., "OpenScale-A1B2")
4. Use the Tare button to zero the scale
5. Start training!

## BLE Protocol

### Service UUID
`4FAFC201-1FB5-459E-8FCC-C5C9C331914B`

### Characteristics

| Characteristic | UUID | Properties | Description |
|----------------|------|------------|-------------|
| Weight | `BEB5483E-36E1-4688-B7F5-EA07361B26A8` | Notify, Read | Current weight in grams (float32) |
| Tare | `1C95D5E3-D8F7-413A-BF3D-7A2E5D7BE87E` | Write | Write any value to tare |
| Sample Rate | `A8985FAE-51A4-4E28-B0A2-6C1AEEDE3F3D` | Read, Write | Sample rate in Hz (uint8) |
| Calibration | `D5875408-FA51-4E89-A0F7-3C7E8E8C5E41` | Read, Write | Calibration factor (float32) |
| Device Name | `8A2C5F47-B91E-4D36-A6C8-9F0E7D3B1C28` | Read, Write | Custom device name (string, max 20 chars) |

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - Feel free to use and modify for your training needs.

## Acknowledgments

- Inspired by the Tindeq Progressor and similar climbing training tools
- Built with the ESP32 Arduino framework
- Uses the excellent HX711 library by bogde
