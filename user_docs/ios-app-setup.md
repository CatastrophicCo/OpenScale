# LineScale iOS App Setup Guide

## Requirements

- macOS with Xcode 15.0 or later
- iOS 16.0+ device (iPhone or iPad)
- Apple Developer account (free or paid)

## Project Setup

1. **Open the Project**
   - Navigate to `ios-app/LineScale/`
   - Open `LineScale.xcodeproj` in Xcode

2. **Configure Signing**
   - Select the LineScale project in the navigator
   - Select the "LineScale" target
   - Go to "Signing & Capabilities"
   - Select your Team from the dropdown
   - Xcode will auto-generate a provisioning profile

3. **Build and Run**
   - Connect your iPhone via USB
   - Select your device in the Xcode toolbar
   - Press Cmd+R or click the Run button

## App Features

### Weight Tab
- **Real-time weight display** with large, easy-to-read numbers
- **Unit switching** (grams, kilograms, pounds)
- **Peak weight tracking** with reset option
- **Tare/Zero** button to zero the scale
- **Record** button to start/stop data recording

### Graph Tab
- **Live force graph** showing weight over time
- **Area chart** with gradient fill
- Toggle between **last 10 seconds** or **full history**
- Clear graph option

### Sessions Tab
- **View recorded training sessions**
- Session details: date, duration, peak, average
- **Tap to view** detailed graphs
- Swipe to delete sessions

### Settings Tab
- **Bluetooth device management**
- **Unit preferences**
- **Sample rate adjustment** (1-80 Hz)
- Calibration controls

## BLE Protocol Reference

The app communicates with the ESP32 using these characteristics:

| Characteristic | UUID | Type | Description |
|----------------|------|------|-------------|
| Weight | `BEB5483E-...` | Notify | Float (4 bytes) in grams |
| Tare | `1C95D5E3-...` | Write | Any byte triggers tare |
| Sample Rate | `A8985FAE-...` | Read/Write | UInt8 (1-80 Hz) |
| Calibration | `D5875408-...` | Read/Write | Float (4 bytes) |

## Troubleshooting

### Device Not Found
- Ensure ESP32 is powered and advertising
- Check that iPhone Bluetooth is enabled
- Try restarting both devices
- Verify ESP32 shows "BLE advertising started" in Serial Monitor

### Connection Drops
- Stay within Bluetooth range (~10m)
- Check battery level on ESP32
- The app auto-reconnects on disconnect

### Wrong Weight Readings
- Calibrate the load cell using the calibration sketch
- Use the Tare button before measurements
- Ensure load cell is mounted securely

### Graph Not Updating
- Check that notifications are enabled (auto on connect)
- Verify sample rate is set appropriately
- Ensure recording is active for historical data

## Customization

### Change App Icon
1. Create a 1024x1024 PNG image
2. Open `Assets.xcassets`
3. Replace the AppIcon

### Modify Colors
- Edit `AccentColor.colorset` in Assets
- Or modify SwiftUI color values directly in views

### Add New Features
Key files to modify:
- `BluetoothManager.swift` - BLE communication
- `WeightData.swift` - Data models
- `Views/` - UI components

## Building for Distribution

### TestFlight (Recommended for Beta)
1. Archive the app (Product → Archive)
2. Distribute to App Store Connect
3. Upload to TestFlight
4. Invite testers

### Ad Hoc Distribution
1. Create Ad Hoc provisioning profile
2. Archive and export for Ad Hoc
3. Install via Apple Configurator or OTA

## Privacy

The app requests Bluetooth permission on first launch. This is required to:
- Scan for LineScale devices
- Connect and communicate with the scale
- Maintain background connection (optional)

No data is collected or transmitted to external servers. All session data is stored locally on the device.
