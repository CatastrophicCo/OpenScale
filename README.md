# LineScale - Bluetooth Hangboard Training Scale

A Bluetooth-enabled line scale designed for climbing training, specifically for hangboard exercises. The device measures force/weight in real-time and transmits data to an iPhone app for visualization and analysis.

## Project Status

**Current Version:** 1.0.0 (Initial Development)

### Completed Features

- [x] ESP32 firmware with BLE connectivity
- [x] HX711 load cell integration
- [x] 128x32 OLED display (weight in pounds)
- [x] iOS app with SwiftUI
- [x] Real-time weight streaming via BLE
- [x] Live force graphing with Swift Charts
- [x] Training session recording and playback
- [x] Multi-device support (unique device names)
- [x] Tare/zero functionality
- [x] Adjustable sample rate (1-80 Hz)
- [x] Calibration utility sketch

### Next Steps

- [ ] Test hardware assembly and BLE connectivity
- [ ] Calibrate load cell with known weights
- [ ] Test iOS app on physical device
- [ ] Add app icon and launch screen
- [ ] Implement data export (CSV/JSON)
- [ ] Add rest timer between sets
- [ ] Create 3D printable enclosure design
- [ ] Battery power support with sleep mode
- [ ] Add training programs/protocols

## Hardware Components

| Component | Description | Approx. Cost |
|-----------|-------------|--------------|
| **XIAO ESP32C6** | Microcontroller with BLE support | $5 |
| **HX711** | 24-bit ADC for load cell amplification | $2 |
| **4-Pin Strain Gauge** | Load cell for force measurement (50-200kg) | $5-15 |
| **128x32 I2C OLED** | Mini display for local readout | $3 |

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

## Multi-Device Support

LineScale supports multiple devices in the same room. Each device advertises with a unique name based on its MAC address:

- `LineScale-A1B2`
- `LineScale-C3D4`
- etc.

Users select their specific device from the list in the iOS app. This allows climbing gyms or training groups to use multiple LineScales simultaneously without interference.

## Features

### Device (ESP32)
- Real-time weight/force measurement in pounds
- Local OLED display showing current and peak weight
- BLE (Bluetooth Low Energy) connectivity
- Unique device naming for multi-device environments
- Configurable sample rate (up to 80Hz with HX711)
- Tare/zero functionality
- Low power consumption

### iPhone App
- Connect to LineScale via Bluetooth
- Device selection for multi-scale environments
- Real-time weight display (lbs, kg, or grams)
- Live graph of force over time
- Session recording and playback
- Peak force tracking
- Training session history

## Project Structure

```
LineScale/
├── README.md                 # This file
├── firmware/                 # ESP32 Arduino code
│   ├── LineScale/
│   │   ├── LineScale.ino     # Main firmware
│   │   └── config.h          # Configuration
│   └── Calibration/
│       └── Calibration.ino   # Calibration utility
├── ios-app/                  # iPhone application
│   └── LineScale/
│       ├── LineScale.xcodeproj
│       └── LineScale/
│           ├── Models/       # BLE & data models
│           └── Views/        # SwiftUI views
├── docs/                     # Documentation
│   ├── firmware-setup.md
│   └── ios-app-setup.md
└── website/                  # GitHub Pages site
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
5. Calibrate your load cell (see docs/firmware-setup.md)
6. Update `CALIBRATION_FACTOR` in `config.h`
7. Upload `firmware/LineScale/LineScale.ino`

### 2. iOS App Setup
1. Open `ios-app/LineScale/LineScale.xcodeproj` in Xcode
2. Configure signing with your Apple Developer account
3. Build and deploy to your iPhone
4. Enable Bluetooth when prompted

### 3. First Use
1. Power on your LineScale device
2. Open the iOS app and go to Settings
3. Tap "Scan for Devices"
4. Select your LineScale (e.g., "LineScale-A1B2")
5. Use the Tare button to zero the scale
6. Start training!

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

## Development Log

### January 24, 2026
- Created project structure and documentation
- Implemented ESP32 firmware with:
  - HX711 load cell reading
  - 128x32 OLED display (pounds)
  - BLE service with 4 characteristics
  - Unique device naming for multi-device support
- Implemented iOS app with:
  - SwiftUI interface with 4 tabs
  - CoreBluetooth integration
  - Real-time weight display
  - Live graphing with Swift Charts
  - Session recording and history
  - Multi-device selection
- Created calibration utility sketch
- Created setup documentation

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - Feel free to use and modify for your training needs.

## Acknowledgments

- Inspired by the Tindeq Progressor and similar climbing training tools
- Built with the ESP32 Arduino framework
- Uses the excellent HX711 library by bogde
