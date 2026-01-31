# OpenScale KiCad Hardware Design v2.1

This directory contains the KiCad schematic and PCB design files for the OpenScale force measurement device.

## Design Overview

This is a custom PCB design featuring:
- ESP32-C6-MINI-1 module (not a dev board)
- USB-C connector for power and programming
- LiPo battery charging circuit (MCP73831)
- 3.3V LDO voltage regulator (AP2112K-3.3)
- HX711 24-bit ADC IC directly on board
- 16x2 I2C LCD display (WO1602M-TFH-AT from DigiKey)
- Load cell connector (JST-XH)
- Tactile push button
- I2C pull-up resistors for reliable communication

## Components

| Reference | Component | Package | Description |
|-----------|-----------|---------|-------------|
| U1 | ESP32-C6-MINI-1 | Module | Main MCU with BLE 5.0 + WiFi 6 |
| U2 | MCP73831 | SOT-23-5 | LiPo battery charger IC |
| U3 | AP2112K-3.3 | SOT-23-5 | 3.3V 600mA LDO regulator |
| U4 | HX711 | SOP-16 | 24-bit ADC for load cell |
| J1 | USB-C | USB4085 | USB Type-C receptacle |
| J2 | JST-PH 2-pin | B2B-PH-K | LiPo battery connector |
| J3 | JST-XH 4-pin | B4B-XH-A | Load cell connector |
| DISP1 | WO1602M-TFH-AT | COG | 16x2 I2C LCD (DigiKey) |
| SW1 | Tactile Button | TL3342 | User input button |
| D1 | LED | 0805 | Charge status indicator |
| R1, R2 | 5.1k | 0805 | USB-C CC resistors |
| R3 | 2k | 0805 | MCP73831 PROG (500mA charge) |
| R4 | 1k | 0805 | Charge LED current limit |
| R5 | 10k | 0805 | ESP32 EN pull-up |
| R6, R7 | 4.7k | 0805 | I2C pull-up resistors |
| C1 | 4.7uF | 0805 | USB input capacitor |
| C2 | 4.7uF | 0805 | Battery capacitor |
| C3 | 1uF | 0805 | LDO input capacitor |
| C4 | 10uF | 0805 | LDO output capacitor |
| C5 | 100nF | 0805 | ESP32 decoupling |
| C6 | 100nF | 0805 | HX711 decoupling |

## Pin Connections

### ESP32-C6-MINI-1 Pinout

| ESP32 Pin | Function | Connected To |
|-----------|----------|--------------|
| IO2 | I2C SCL | OLED SCL |
| IO3 | I2C SDA | OLED SDA |
| IO4 | Button Input | Button (to GND) |
| IO6 | HX711 Data | HX711 DOUT |
| IO7 | HX711 Clock | HX711 PD_SCK |
| IO12 | USB D- | USB-C D- |
| IO13 | USB D+ | USB-C D+ |
| 3V3 | Power | From AP2112K |
| GND | Ground | System GND |
| EN | Enable | 10k pull-up to 3V3 |

### HX711 Connections

| HX711 Pin | Connection |
|-----------|------------|
| VSUP | 3.3V |
| DVDD | 3.3V |
| AGND | GND |
| VFB | AVDD (internal regulator feedback) |
| INA+ | Load Cell Signal+ (White) |
| INA- | Load Cell Signal- (Green) |
| AVDD | Load Cell Excitation+ (via internal LDO) |
| AGND | Load Cell Excitation- |
| DOUT | ESP32 IO6 |
| PD_SCK | ESP32 IO7 |
| XI | GND (internal oscillator) |
| RATE | GND (10Hz sample rate) |

### Load Cell Connector (J3)

| Pin | Signal | Typical Wire Color |
|-----|--------|-------------------|
| 1 | E+ (Excitation+) | Red |
| 2 | E- (Excitation-) | Black |
| 3 | A- (Signal-) | Green |
| 4 | A+ (Signal+) | White |

*Note: Wire colors may vary by load cell manufacturer. Check your load cell datasheet.*

## Power Supply Architecture

```
USB-C (5V)  ──┬──► MCP73831 ──► LiPo Battery (3.7V)
              │                      │
              └───────┬──────────────┘
                      │
                      ▼
              AP2112K-3.3 LDO ──► 3.3V System Rail
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
              ESP32-C6-MINI      HX711 ADC        OLED Display
```

### Power Specifications
- **USB Input:** 5V via USB-C
- **Battery:** 3.7V single-cell LiPo
- **Charge Current:** 500mA (set by R3 = 2kΩ)
- **System Voltage:** 3.3V regulated
- **LDO Output Current:** 600mA max (AP2112K)

## USB-C Configuration

The USB-C connector is configured for UFP (Upstream Facing Port) mode:
- CC1 and CC2 pins connected to GND via 5.1kΩ resistors
- D+ and D- connected to ESP32 native USB (IO12, IO13)
- Supports USB 2.0 for programming and serial communication

## Charging Indicator

- **LED On:** Battery charging
- **LED Off:** Charge complete or no battery

## Opening the Project

1. Install KiCad 7.0 or later (tested with KiCad 9.0)
2. Open `OpenScale.kicad_pro` in KiCad
3. The schematic is in `OpenScale.kicad_sch`
4. Run ERC (Electrical Rules Check) to verify connections
5. Create PCB from schematic using "Update PCB from Schematic"

### Display Footprint
The WO1602M-TFH-AT is a COG (Chip-on-Glass) LCD module. Before creating the PCB:
1. Download the footprint from DigiKey or create one based on the datasheet
2. The display dimensions are 51.2 x 20.7 mm with FPC connector
3. Import the footprint into the project library as `OpenScale:WO1602M-TFH-AT`

## Schematic Status

The schematic includes:
- All component symbols with correct footprints
- Wire connections between all components
- Power symbols (GND, +3V3) at appropriate nodes
- Junction markers at wire intersections
- Net labels for signal routing

### After Opening in KiCad

1. **Annotate Schematic** - Run Tools → Annotate Schematic to assign reference designators
2. **Run ERC** - Check for any unconnected pins or electrical errors
3. **Assign Footprints** - Verify all components have correct footprints assigned
4. **Generate Netlist** - Create netlist for PCB layout

## Notes

- The HX711 uses its internal oscillator (XI pin tied to GND)
- RATE pin tied to GND for 10Hz sample rate (tie to DVDD for 80Hz)
- Button uses ESP32 internal pull-up resistor
- LCD display uses I2C address 0x3E (ST7032 controller)
- All SMD components are 0805 size for hand soldering
- I2C pull-up resistors (R6, R7) are required for reliable communication
- LCD reset pin is tied to VDD for normal operation

## Important: Verify After Opening

After opening in KiCad, verify these critical connections:
1. **USB-C VBUS** → C1 → MCP73831 VIN → R4/D1 (charge indicator)
2. **USB-C CC1/CC2** → R1/R2 (5.1k) → GND
3. **MCP73831 VBAT** → Battery connector J2 → C2 → LDO VIN
4. **MCP73831 PROG** → R3 (2k) → GND (sets 500mA charge current)
5. **LDO VOUT** → C4 → 3.3V rail → ESP32/HX711/OLED
6. **ESP32 EN** → R5 (10k) → 3V3
7. **ESP32 IO4** → Button SW1 → GND
8. **ESP32 IO6** → HX711 DOUT
9. **ESP32 IO7** → HX711 PD_SCK
10. **ESP32 IO2/IO3** → OLED SCL/SDA
11. **HX711 AVDD** → Load cell E+ (excitation)
12. **HX711 AGND** → Load cell E- (excitation)
13. **HX711 INA+/INA-** → Load cell A+/A- (signal)

## BOM (Bill of Materials)

### ICs
1. ESP32-C6-MINI-1 WiFi/BLE Module
2. MCP73831T-2ACI/OT LiPo Charger (SOT-23-5)
3. AP2112K-3.3TRG1 LDO Regulator (SOT-23-5)
4. HX711 Load Cell ADC (SOP-16)

### Connectors
5. USB-C Receptacle (GCT USB4085)
6. JST-PH 2-pin connector (battery)
7. JST-XH 4-pin connector (load cell)
8. 1x4 pin header 2.54mm (OLED)

### Passives
9. 5.1kΩ Resistor x2 (0805)
10. 2kΩ Resistor (0805)
11. 1kΩ Resistor (0805)
12. 10kΩ Resistor (0805)
13. 4.7kΩ Resistor x2 (0805) - I2C pull-ups
14. 4.7µF Capacitor x2 (0805)
15. 1µF Capacitor (0805)
16. 10µF Capacitor (0805)
17. 100nF Capacitor x2 (0805)

### Other
18. 0805 LED (any color)
19. 6x6mm Tactile Push Button (TL3342 or similar)
20. 4-wire Strain Gauge Load Cell
21. WO1602M-TFH-AT 16x2 I2C LCD Display (DigiKey)
22. 3.7V LiPo Battery with JST-PH connector

## Firmware Compatibility

This board is compatible with the existing OpenScale firmware with the following updates needed:

### Display Library Change
The WO1602M-TFH-AT uses the ST7032 controller (not SSD1306). Update the display library:
- Use ST7032 or LiquidCrystal_I2C library instead of Adafruit SSD1306
- I2C address: 0x3E (not 0x3C)
- Display is 16x2 character LCD (not 128x32 OLED graphics)

### ESP32-C6-MINI-1 Pinout
The ESP32-C6-MINI-1 module uses the same chip as the XIAO ESP32C6:
- Native USB on IO12/IO13 (same as XIAO internal)
- Same GPIO mapping available

Key differences from XIAO:
- No USB-C on the module itself (USB is on the PCB)
- Direct access to all GPIO pins
