import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/weight_data.dart';

/// Connection state enumeration
enum ConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

/// OpenScale BLE service for handling Bluetooth communication
class OpenScaleBluetoothService extends ChangeNotifier {
  // BLE UUIDs (must match firmware)
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String weightCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String tareCharUuid = '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e';
  static const String sampleRateCharUuid = 'a8985fae-51a4-4e28-b0a2-6c1aeede3f3d';
  static const String calibrationCharUuid = 'd5875408-fa51-4e89-a0f7-3c7e8e8c5e41';
  static const String deviceNameCharUuid = '8a2c5f47-b91e-4d36-a6c8-9f0e7d3b1c28';

  // Connection state
  ConnectionState _connectionState = ConnectionState.disconnected;
  ConnectionState get connectionState => _connectionState;

  // Connected device
  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;
  String get deviceName => _device?.platformName ?? '';

  // Discovered devices
  List<ScanResult> _discoveredDevices = [];
  List<ScanResult> get discoveredDevices => _discoveredDevices;

  // Characteristics
  BluetoothCharacteristic? _weightChar;
  BluetoothCharacteristic? _tareChar;
  BluetoothCharacteristic? _sampleRateChar;
  BluetoothCharacteristic? _calibrationChar;
  BluetoothCharacteristic? _deviceNameChar;

  // Weight data
  double _currentWeight = 0.0;
  double get currentWeight => _currentWeight;

  double _peakWeight = 0.0;
  double get peakWeight => _peakWeight;

  // Device settings
  int _sampleRate = 10;
  int get sampleRate => _sampleRate;

  double _calibrationFactor = 420.0;
  double get calibrationFactor => _calibrationFactor;

  String _customDeviceName = '';
  String get customDeviceName => _customDeviceName;

  // Weight history for graphing
  final List<WeightDataPoint> _weightHistory = [];
  List<WeightDataPoint> get weightHistory => List.unmodifiable(_weightHistory);
  static const int maxHistoryLength = 300; // 30 seconds at 10Hz

  // Recording state
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  DateTime? _recordingStartTime;

  // User preferences
  WeightUnit _unit = WeightUnit.pounds;
  WeightUnit get unit => _unit;

  // Subscriptions
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _weightSubscription;

  /// Start scanning for OpenScale devices
  Future<void> startScanning() async {
    if (_connectionState == ConnectionState.scanning) return;

    _connectionState = ConnectionState.scanning;
    _discoveredDevices = [];
    notifyListeners();

    try {
      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isSupported) {
        throw Exception('Bluetooth not supported on this device');
      }

      // Turn on Bluetooth if needed (Android only)
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      // Start scanning
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices = results
            .where((r) => r.advertisementData.serviceUuids
                .any((uuid) => uuid.toString().toLowerCase() == serviceUuid))
            .toList();
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 10),
      );

      // Stop scanning after timeout
      await Future.delayed(const Duration(seconds: 10));
      await stopScanning();
    } catch (e) {
      debugPrint('Scanning error: $e');
      _connectionState = ConnectionState.disconnected;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_connectionState == ConnectionState.scanning) {
      _connectionState = ConnectionState.disconnected;
      notifyListeners();
    }
  }

  /// Connect to a device
  Future<void> connect(BluetoothDevice device) async {
    await stopScanning();
    _connectionState = ConnectionState.connecting;
    _device = device;
    notifyListeners();

    try {
      // Connect to device
      await device.connect(timeout: const Duration(seconds: 10));

      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? openScaleService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == serviceUuid,
        orElse: () => throw Exception('OpenScale service not found'),
      );

      // Get characteristics
      for (var char in openScaleService.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == weightCharUuid) {
          _weightChar = char;
        } else if (uuid == tareCharUuid) {
          _tareChar = char;
        } else if (uuid == sampleRateCharUuid) {
          _sampleRateChar = char;
        } else if (uuid == calibrationCharUuid) {
          _calibrationChar = char;
        } else if (uuid == deviceNameCharUuid) {
          _deviceNameChar = char;
        }
      }

      // Subscribe to weight notifications
      if (_weightChar != null) {
        await _weightChar!.setNotifyValue(true);
        _weightSubscription = _weightChar!.onValueReceived.listen((data) {
          if (data.length >= 4) {
            final bytes = Uint8List.fromList(data);
            final weight = ByteData.view(bytes.buffer).getFloat32(0, Endian.little);
            _updateWeight(weight);
          }
        });
      }

      // Read initial values
      await _readSampleRate();
      await _readCalibration();
      await _readDeviceName();

      _connectionState = ConnectionState.connected;
      notifyListeners();
    } catch (e) {
      debugPrint('Connection error: $e');
      await disconnect();
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _weightSubscription?.cancel();
    _weightSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_device != null) {
      await _device!.disconnect();
    }

    _handleDisconnect();
  }

  void _handleDisconnect() {
    _device = null;
    _weightChar = null;
    _tareChar = null;
    _sampleRateChar = null;
    _calibrationChar = null;
    _deviceNameChar = null;
    _customDeviceName = '';
    _connectionState = ConnectionState.disconnected;
    notifyListeners();
  }

  void _updateWeight(double weight) {
    _currentWeight = weight;
    if (weight > _peakWeight) {
      _peakWeight = weight;
    }

    // Add to history
    _weightHistory.add(WeightDataPoint(
      timestamp: DateTime.now(),
      weight: weight,
    ));

    // Trim history
    while (_weightHistory.length > maxHistoryLength) {
      _weightHistory.removeAt(0);
    }

    notifyListeners();
  }

  /// Send tare command
  Future<void> tare() async {
    if (_tareChar == null) return;
    try {
      await _tareChar!.write([0x01], withoutResponse: false);
      _peakWeight = 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Tare error: $e');
    }
  }

  /// Reset peak weight
  void resetPeak() {
    _peakWeight = 0.0;
    notifyListeners();
  }

  /// Clear weight history
  void clearHistory() {
    _weightHistory.clear();
    notifyListeners();
  }

  /// Read sample rate from device
  Future<void> _readSampleRate() async {
    if (_sampleRateChar == null) return;
    try {
      final data = await _sampleRateChar!.read();
      if (data.isNotEmpty) {
        _sampleRate = data[0];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Read sample rate error: $e');
    }
  }

  /// Set sample rate (1-80 Hz)
  Future<void> setSampleRate(int rate) async {
    if (_sampleRateChar == null) return;
    rate = rate.clamp(1, 80);
    try {
      await _sampleRateChar!.write([rate], withoutResponse: false);
      _sampleRate = rate;
      notifyListeners();
    } catch (e) {
      debugPrint('Set sample rate error: $e');
    }
  }

  /// Read calibration factor from device
  Future<void> _readCalibration() async {
    if (_calibrationChar == null) return;
    try {
      final data = await _calibrationChar!.read();
      if (data.length >= 4) {
        final bytes = Uint8List.fromList(data);
        _calibrationFactor = ByteData.view(bytes.buffer).getFloat32(0, Endian.little);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Read calibration error: $e');
    }
  }

  /// Set calibration factor directly (legacy)
  Future<void> setCalibration(double factor) async {
    if (_calibrationChar == null) return;
    try {
      final bytes = ByteData(4);
      bytes.setFloat32(0, factor, Endian.little);
      await _calibrationChar!.write(bytes.buffer.asUint8List(), withoutResponse: false);
      _calibrationFactor = factor;
      notifyListeners();
    } catch (e) {
      debugPrint('Set calibration error: $e');
    }
  }

  /// Start calibration process (step 1: tare with no weight)
  /// Device will tare and wait for known weight to be placed
  Future<void> startCalibration() async {
    if (_calibrationChar == null) return;
    try {
      final bytes = ByteData(4);
      bytes.setFloat32(0, 0.0, Endian.little); // 0.0 = start calibration
      await _calibrationChar!.write(bytes.buffer.asUint8List(), withoutResponse: false);
      debugPrint('Calibration started - place 10 lbs on scale');
    } catch (e) {
      debugPrint('Start calibration error: $e');
      rethrow;
    }
  }

  /// Complete calibration process (step 2: calculate factor from 10 lb weight)
  /// Call this after placing the known weight on the scale
  /// Returns the new calibration factor
  Future<double?> completeCalibration() async {
    if (_calibrationChar == null) return null;
    try {
      final bytes = ByteData(4);
      bytes.setFloat32(0, -1.0, Endian.little); // -1.0 = complete calibration
      await _calibrationChar!.write(bytes.buffer.asUint8List(), withoutResponse: false);
      debugPrint('Calibration completion requested');

      // Wait for device to calculate and save calibration
      await Future.delayed(const Duration(seconds: 3));

      // Read back the new calibration factor
      await _readCalibration();
      return _calibrationFactor;
    } catch (e) {
      debugPrint('Complete calibration error: $e');
      rethrow;
    }
  }

  /// Read device name
  Future<void> _readDeviceName() async {
    if (_deviceNameChar == null) return;
    try {
      final data = await _deviceNameChar!.read();
      _customDeviceName = String.fromCharCodes(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Read device name error: $e');
    }
  }

  /// Set device name (max 20 characters)
  Future<void> setDeviceName(String name) async {
    if (_deviceNameChar == null) return;
    name = name.length > 20 ? name.substring(0, 20) : name;
    try {
      await _deviceNameChar!.write(name.codeUnits, withoutResponse: false);
      _customDeviceName = name;
      notifyListeners();
    } catch (e) {
      debugPrint('Set device name error: $e');
    }
  }

  /// Set weight unit
  void setUnit(WeightUnit unit) {
    _unit = unit;
    notifyListeners();
  }

  /// Start recording
  void startRecording() {
    _weightHistory.clear();
    _recordingStartTime = DateTime.now();
    _isRecording = true;
    notifyListeners();
  }

  /// Stop recording
  void stopRecording() {
    _isRecording = false;
    _recordingStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
