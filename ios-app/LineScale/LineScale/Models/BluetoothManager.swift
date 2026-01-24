import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE UUIDs (must match ESP32 firmware)
struct LineScaleBLE {
    static let serviceUUID = CBUUID(string: "4FAFC201-1FB5-459E-8FCC-C5C9C331914B")
    static let weightCharUUID = CBUUID(string: "BEB5483E-36E1-4688-B7F5-EA07361B26A8")
    static let tareCharUUID = CBUUID(string: "1C95D5E3-D8F7-413A-BF3D-7A2E5D7BE87E")
    static let sampleRateCharUUID = CBUUID(string: "A8985FAE-51A4-4E28-B0A2-6C1AEEDE3F3D")
    static let calibrationCharUUID = CBUUID(string: "D5875408-FA51-4E89-A0F7-3C7E8E8C5E41")
}

// MARK: - Connection State
enum ConnectionState: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning..."
    case connecting = "Connecting..."
    case connected = "Connected"

    var color: String {
        switch self {
        case .disconnected: return "red"
        case .scanning: return "orange"
        case .connecting: return "yellow"
        case .connected: return "green"
        }
    }
}

// MARK: - Bluetooth Manager
class BluetoothManager: NSObject, ObservableObject {
    // MARK: Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var currentWeight: Float = 0.0
    @Published var peakWeight: Float = 0.0
    @Published var sampleRate: UInt8 = 10
    @Published var isRecording: Bool = false
    @Published var weightHistory: [WeightDataPoint] = []
    @Published var discoveredDevices: [CBPeripheral] = []

    // MARK: Private Properties
    private var centralManager: CBCentralManager!
    private var lineScalePeripheral: CBPeripheral?
    private var weightCharacteristic: CBCharacteristic?
    private var tareCharacteristic: CBCharacteristic?
    private var sampleRateCharacteristic: CBCharacteristic?
    private var calibrationCharacteristic: CBCharacteristic?

    private var recordingStartTime: Date?
    private let maxHistoryPoints = 6000 // 10 minutes at 10Hz

    // MARK: Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: Public Methods

    /// Start scanning for LineScale devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready")
            return
        }

        discoveredDevices.removeAll()
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [LineScaleBLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 10 seconds if nothing found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.connectionState == .scanning {
                self?.stopScanning()
            }
        }
    }

    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    /// Connect to a specific device
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        lineScalePeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    /// Disconnect from current device
    func disconnect() {
        if let peripheral = lineScalePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        lineScalePeripheral = nil
        connectionState = .disconnected
    }

    /// Send tare command to zero the scale
    func tare() {
        guard let characteristic = tareCharacteristic,
              let peripheral = lineScalePeripheral else {
            print("Cannot tare: not connected")
            return
        }

        let data = Data([0x01])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        peakWeight = 0.0
        print("Tare command sent")
    }

    /// Set the sample rate (1-80 Hz)
    func setSampleRate(_ rate: UInt8) {
        guard let characteristic = sampleRateCharacteristic,
              let peripheral = lineScalePeripheral else {
            print("Cannot set sample rate: not connected")
            return
        }

        let clampedRate = min(max(rate, 1), 80)
        let data = Data([clampedRate])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        sampleRate = clampedRate
        print("Sample rate set to \(clampedRate) Hz")
    }

    /// Start recording weight data
    func startRecording() {
        weightHistory.removeAll()
        recordingStartTime = Date()
        isRecording = true
        print("Recording started")
    }

    /// Stop recording
    func stopRecording() {
        isRecording = false
        recordingStartTime = nil
        print("Recording stopped with \(weightHistory.count) data points")
    }

    /// Reset peak weight
    func resetPeak() {
        peakWeight = 0.0
    }

    /// Clear weight history
    func clearHistory() {
        weightHistory.removeAll()
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            connectionState = .disconnected
        case .unauthorized:
            print("Bluetooth unauthorized")
        case .unsupported:
            print("Bluetooth not supported")
        case .resetting:
            print("Bluetooth resetting")
        case .unknown:
            print("Bluetooth state unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        print("Discovered: \(peripheral.name ?? "Unknown") - RSSI: \(RSSI)")

        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }

        // Note: No auto-connect - users must manually select their device
        // This allows multiple LineScale devices to coexist in the same room
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([LineScaleBLE.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown")")
        connectionState = .disconnected
        lineScalePeripheral = nil
        weightCharacteristic = nil
        tareCharacteristic = nil
        sampleRateCharacteristic = nil
        calibrationCharacteristic = nil

        // Attempt reconnection
        if error != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startScanning()
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionState = .disconnected
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == LineScaleBLE.serviceUUID {
                print("Found LineScale service")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case LineScaleBLE.weightCharUUID:
                weightCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to weight notifications")

            case LineScaleBLE.tareCharUUID:
                tareCharacteristic = characteristic
                print("Found tare characteristic")

            case LineScaleBLE.sampleRateCharUUID:
                sampleRateCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                print("Found sample rate characteristic")

            case LineScaleBLE.calibrationCharUUID:
                calibrationCharacteristic = characteristic
                print("Found calibration characteristic")

            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            print("Error reading characteristic: \(error!.localizedDescription)")
            return
        }

        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case LineScaleBLE.weightCharUUID:
            if data.count >= 4 {
                let weight = data.withUnsafeBytes { $0.load(as: Float.self) }
                DispatchQueue.main.async { [weak self] in
                    self?.currentWeight = weight
                    if weight > self?.peakWeight ?? 0 {
                        self?.peakWeight = weight
                    }

                    // Record data point if recording
                    if self?.isRecording == true,
                       let startTime = self?.recordingStartTime {
                        let timestamp = Date().timeIntervalSince(startTime)
                        let dataPoint = WeightDataPoint(timestamp: timestamp, weight: weight)
                        self?.weightHistory.append(dataPoint)

                        // Limit history size
                        if let count = self?.weightHistory.count,
                           let max = self?.maxHistoryPoints,
                           count > max {
                            self?.weightHistory.removeFirst()
                        }
                    }
                }
            }

        case LineScaleBLE.sampleRateCharUUID:
            if data.count >= 1 {
                let rate = data[0]
                DispatchQueue.main.async { [weak self] in
                    self?.sampleRate = rate
                }
            }

        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Error writing characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote to characteristic")
        }
    }
}
