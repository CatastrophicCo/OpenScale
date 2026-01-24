# OpenScale Firmware Setup Guide

## Prerequisites

### Arduino IDE Setup

1. **Install Arduino IDE 2.x** from [arduino.cc](https://www.arduino.cc/en/software)

2. **Add ESP32 Board Support:**
   - Open Arduino IDE
   - Go to File → Preferences
   - In "Additional Boards Manager URLs" add:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
   - Go to Tools → Board → Boards Manager
   - Search for "esp32" and install "esp32 by Espressif Systems"

3. **Select Your Board:**
   - Go to Tools → Board → esp32
   - Select "XIAO_ESP32C6"

### Required Libraries

Install these libraries via Tools → Manage Libraries:

| Library | Author | Description |
|---------|--------|-------------|
| **HX711** | bogde | Load cell amplifier driver |
| **Adafruit SSD1306** | Adafruit | OLED display driver |
| **Adafruit GFX Library** | Adafruit | Graphics library for display |

The ESP32 BLE libraries are included with the ESP32 board package.

## Hardware Connections

### XIAO ESP32C6 Pinout Reference

```
        ┌─────────┐
    5V ─┤         ├─ GND
   GND ─┤         ├─ 3V3
   D10 ─┤  XIAO   ├─ D0 (SCL) ← OLED
    D9 ─┤ ESP32C6 ├─ D1 (SDA) ← OLED
    D8 ─┤         ├─ D2 (BTN) ← Button
    D7 ─┤         ├─ D3
    D6 ─┤         ├─ D4 (DT)  ← HX711
   RST ─┤         ├─ D5 (SCK) ← HX711
        └─────────┘
```

### HX711 Wiring

| HX711 Pin | ESP32C6 Pin | Wire Color (typical) |
|-----------|-------------|---------------------|
| VCC | 3.3V | Red |
| GND | GND | Black |
| DT (Data) | D4 | Yellow |
| SCK (Clock) | D5 | Orange |

### Load Cell to HX711

| Load Cell Wire | HX711 Terminal |
|----------------|----------------|
| Red (E+) | E+ |
| Black (E-) | E- |
| White (A-) | A- |
| Green (A+) | A+ |

Note: Wire colors may vary. Check your load cell datasheet.

### OLED Display Wiring

| OLED Pin | ESP32C6 Pin |
|----------|-------------|
| VCC | 3.3V |
| GND | GND |
| SCL | D0 |
| SDA | D1 |

### Button Wiring

| Button | ESP32C6 Pin |
|--------|-------------|
| One terminal | D2 |
| Other terminal | GND |

Use a simple momentary tactile button. The internal pull-up resistor is enabled, so no external resistor is needed.

## Button Functions

| Action | Function |
|--------|----------|
| Short press (<0.5s) | Tare/zero the scale |
| Long press (>1s) | Toggle display units (lbs ↔ kg) |
| Long press from sleep | Wake device |
| S-S-S-L-S-S-S | Enter calibration mode |

**Calibration Sequence**: Press short-short-short-LONG-short-short-short to enter calibration mode. Follow the on-screen prompts to calibrate with a 10 lb weight.

## Power Management

OpenScale includes automatic power management:
- **Sleep**: Device enters deep sleep after 10 minutes of inactivity
- **Wake**: Long-press the button to wake from sleep
- **Activity detection**: Weight changes, BLE connections, and button presses reset the timer

In deep sleep mode, power consumption drops to ~10µA.

## Uploading Firmware

1. Connect your XIAO ESP32C6 via USB-C
2. Select the correct COM port in Tools → Port
3. Open `firmware/OpenScale/OpenScale.ino`
4. Click Upload (→ button)

### First Boot

On first boot, the device will:
1. Initialize the display (shows "OpenScale Initializing...")
2. Initialize the HX711 and perform an auto-tare
3. Start BLE advertising as "OpenScale-XXXX" (where XXXX is from MAC address)

## Calibration

**Before using the scale, you must calibrate it!**

### Quick Calibration

1. Upload `firmware/Calibration/Calibration.ino`
2. Open Serial Monitor (115200 baud)
3. Remove all weight from the scale
4. Press 't' to tare
5. Place a known weight (e.g., 1kg = 1000g)
6. Use '+' and '-' to adjust until the reading matches
7. Press 'c' to print the calibration factor
8. Update `CALIBRATION_FACTOR` in `config.h`
9. Upload the main `OpenScale.ino` sketch

### Calibration Tips

- Use an accurate known weight (kitchen scale, calibration weights)
- Calibrate in the weight range you'll be using
- The calibration factor can be positive or negative
- Temperature affects load cell readings slightly

## Device Naming

OpenScale supports custom device naming via NVS (Non-Volatile Storage):

- Default name: `OpenScale-XXXX` (derived from MAC address)
- Custom names persist across power cycles
- Set via any app's settings screen
- Maximum 20 characters

## Troubleshooting

### HX711 Not Found

- Check wiring connections
- Verify 3.3V power to HX711
- Try swapping DT and SCK pins (sometimes mislabeled)

### Display Not Working

- Check I2C address (try 0x3D instead of 0x3C)
- Verify SDA/SCL connections
- Run I2C scanner sketch to detect display

### Unstable Readings

- Secure all mechanical connections
- Shield load cell wires from electrical noise
- Increase `READINGS_TO_AVERAGE` in config.h
- Add decoupling capacitor to HX711 power

### BLE Not Connecting

- Ensure device Bluetooth is enabled
- Reset ESP32 and try again
- Check that device is advertising (Serial Monitor shows status)
- On Android: Grant location permission for BLE scanning

## Power Consumption

| Mode | Current Draw |
|------|--------------|
| Active + BLE | ~50-80mA |
| Active (no BLE) | ~30-40mA |
| Deep Sleep | ~10µA |

For battery operation, consider adding deep sleep functionality when idle.
