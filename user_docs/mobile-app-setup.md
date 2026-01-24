# OpenScale Mobile App Setup Guide (Flutter)

## Requirements

### For Android
- Flutter SDK 3.0 or later
- Android Studio with Android SDK
- Android device or emulator (API 21+)

### For iOS
- macOS with Xcode 15.0 or later
- Flutter SDK 3.0 or later
- iOS 13.0+ device (iPhone or iPad)
- Apple Developer account (free or paid)

## Project Setup

### 1. Install Flutter

Follow the official Flutter installation guide: https://docs.flutter.dev/get-started/install

Verify installation:
```bash
flutter doctor
```

### 2. Clone and Setup

```bash
cd flutter-app/open_scale
flutter pub get
```

### 3. Android Setup

#### Run on Device/Emulator
```bash
# List available devices
flutter devices

# Run on connected Android device
flutter run

# Run on specific device
flutter run -d <device-id>
```

#### Build Release APK
```bash
# Build APK
flutter build apk --release

# Build split APKs (smaller size)
flutter build apk --split-per-abi

# Output location: build/app/outputs/flutter-apk/
```

#### Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 4. iOS Setup

#### Configure Signing
1. Open in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select the Runner project in the navigator
3. Select the "Runner" target
4. Go to "Signing & Capabilities"
5. Select your Team from the dropdown
6. Xcode will auto-generate a provisioning profile

#### Run on Device
```bash
# Run on connected iPhone
flutter run

# Run in release mode
flutter run --release
```

#### Build for Distribution
```bash
# Build iOS app
flutter build ios --release

# Then archive in Xcode for App Store/TestFlight
```

## App Features

### Home Screen
- **Real-time weight display** with large, easy-to-read numbers
- **Unit switching** (grams, kilograms, pounds)
- **Peak weight tracking** with reset option
- **Tare/Zero** button to zero the scale
- **Live force graph** showing weight over time

### Settings Screen
- **Bluetooth device management** (scan, connect, disconnect)
- **Device renaming** - set a custom name for your OpenScale
- **Sample rate adjustment** (1-80 Hz)
- **Unit preferences**
- Calibration controls

## Testing

### Run Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

### Run on Emulator/Simulator

#### Android Emulator
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator-id>

# Run app
flutter run
```

#### iOS Simulator
```bash
# Open simulator
open -a Simulator

# Run app
flutter run
```

**Note:** BLE functionality requires a physical device. Emulators/simulators do not support Bluetooth.

## BLE Protocol Reference

The app communicates with the ESP32 using these characteristics:

| Characteristic | UUID | Type | Description |
|----------------|------|------|-------------|
| Weight | `BEB5483E-...` | Notify | Float (4 bytes) in grams |
| Tare | `1C95D5E3-...` | Write | Any byte triggers tare |
| Sample Rate | `A8985FAE-...` | Read/Write | UInt8 (1-80 Hz) |
| Calibration | `D5875408-...` | Read/Write | Float (4 bytes) |
| Device Name | `8A2C5F47-...` | Read/Write | String (max 20 chars) |

## Troubleshooting

### Device Not Found
- Ensure ESP32 is powered and advertising
- Check that device Bluetooth is enabled
- On Android: Grant location permission (required for BLE scanning)
- On iOS: Grant Bluetooth permission when prompted
- Try restarting both devices

### Connection Drops
- Stay within Bluetooth range (~10m)
- Check battery level on ESP32
- The app auto-reconnects on disconnect

### Wrong Weight Readings
- Calibrate the load cell using the calibration sketch
- Use the Tare button before measurements
- Ensure load cell is mounted securely

### Build Errors

#### Android
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk
```

#### iOS
```bash
# Update pods
cd ios
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter build ios
```

### iOS Signing Issues
1. Ensure you have a valid Apple Developer account
2. Check that your device is registered in your developer portal
3. Try resetting signing in Xcode: Signing & Capabilities > Team > None, then reselect

## Customization

### Change App Icon
1. Replace icon files in:
   - Android: `android/app/src/main/res/mipmap-*/`
   - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
2. Or use the flutter_launcher_icons package

### Modify Theme Colors
Edit `lib/main.dart`:
```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF3B82F6), // Change this
    brightness: Brightness.dark,
  ),
  // ...
),
```

### Add New Features
Key files to modify:
- `lib/services/bluetooth_service.dart` - BLE communication
- `lib/models/weight_data.dart` - Data models
- `lib/screens/` - Screen UI
- `lib/widgets/` - Reusable components

## Privacy

The app requests Bluetooth and location permissions:
- **Bluetooth**: Required to scan for and connect to OpenScale devices
- **Location** (Android only): Required by Android for BLE scanning

No data is collected or transmitted to external servers. All session data is stored locally on the device.
