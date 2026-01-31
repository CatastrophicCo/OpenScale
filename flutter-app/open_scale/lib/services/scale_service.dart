import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/weight_data.dart';
import 'bluetooth_service.dart';
import 'emulator_service.dart';

/// Unified scale service that can use either real Bluetooth or emulator
class OpenScaleService extends ChangeNotifier {
  final OpenScaleBluetoothService _bluetoothService = OpenScaleBluetoothService();
  final OpenScaleEmulatorService _emulatorService = OpenScaleEmulatorService();

  bool _useEmulator = false;
  bool get useEmulator => _useEmulator;

  OpenScaleService() {
    // Listen to changes from both services and forward them
    _bluetoothService.addListener(_onServiceChanged);
    _emulatorService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  /// Get the active service based on current mode
  dynamic get _activeService => _useEmulator ? _emulatorService : _bluetoothService;

  // =========================================================================
  // Forwarded properties from active service
  // =========================================================================

  ConnectionState get connectionState {
    if (_useEmulator) {
      return _emulatorService.isConnected
          ? ConnectionState.connected
          : ConnectionState.disconnected;
    }
    return _bluetoothService.connectionState;
  }

  bool get isConnected {
    if (_useEmulator) {
      return _emulatorService.isConnected;
    }
    return _bluetoothService.connectionState == ConnectionState.connected;
  }

  String get deviceName {
    if (_useEmulator) {
      return _emulatorService.deviceName;
    }
    return _bluetoothService.deviceName;
  }

  double get currentWeight {
    if (_useEmulator) {
      return _emulatorService.currentWeight;
    }
    return _bluetoothService.currentWeight;
  }

  double get peakWeight {
    if (_useEmulator) {
      return _emulatorService.peakWeight;
    }
    return _bluetoothService.peakWeight;
  }

  int get sampleRate {
    if (_useEmulator) {
      return _emulatorService.sampleRate;
    }
    return _bluetoothService.sampleRate;
  }

  double get calibrationFactor {
    if (_useEmulator) {
      return _emulatorService.calibrationFactor;
    }
    return _bluetoothService.calibrationFactor;
  }

  String get customDeviceName {
    if (_useEmulator) {
      return _emulatorService.customDeviceName;
    }
    return _bluetoothService.customDeviceName;
  }

  List<WeightDataPoint> get weightHistory {
    if (_useEmulator) {
      return _emulatorService.weightHistory;
    }
    return _bluetoothService.weightHistory;
  }

  DateTime? get connectionStartTime {
    if (_useEmulator) {
      return _emulatorService.connectionStartTime;
    }
    return _bluetoothService.connectionStartTime;
  }

  WeightUnit get unit {
    if (_useEmulator) {
      return _emulatorService.unit;
    }
    return _bluetoothService.unit;
  }

  // Bluetooth-specific properties (for device scanning)
  List<ScanResult> get discoveredDevices => _bluetoothService.discoveredDevices;

  // Emulator-specific properties
  SimulationMode get simulationMode => _emulatorService.simulationMode;
  double get manualWeight => _emulatorService.manualWeight;
  double get noiseLevel => _emulatorService.noiseLevel;

  // =========================================================================
  // Connection methods
  // =========================================================================

  /// Start scanning for real Bluetooth devices
  Future<void> startScanning() async {
    await _bluetoothService.startScanning();
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    await _bluetoothService.stopScanning();
  }

  /// Connect to a real Bluetooth device
  Future<void> connect(BluetoothDevice device) async {
    _useEmulator = false;
    await _bluetoothService.connect(device);
    notifyListeners();
  }

  /// Connect to the emulator
  Future<void> connectEmulator() async {
    _useEmulator = true;
    await _emulatorService.connect();
    notifyListeners();
  }

  /// Disconnect from the current device (real or emulator)
  Future<void> disconnect() async {
    if (_useEmulator) {
      await _emulatorService.disconnect();
    } else {
      await _bluetoothService.disconnect();
    }
    notifyListeners();
  }

  // =========================================================================
  // Scale control methods
  // =========================================================================

  Future<void> tare() async {
    if (_useEmulator) {
      await _emulatorService.tare();
    } else {
      await _bluetoothService.tare();
    }
  }

  void resetPeak() {
    if (_useEmulator) {
      _emulatorService.resetPeak();
    } else {
      _bluetoothService.resetPeak();
    }
  }

  void clearHistory() {
    if (_useEmulator) {
      _emulatorService.clearHistory();
    } else {
      _bluetoothService.clearHistory();
    }
  }

  Future<void> setSampleRate(int rate) async {
    if (_useEmulator) {
      await _emulatorService.setSampleRate(rate);
    } else {
      await _bluetoothService.setSampleRate(rate);
    }
  }

  Future<void> setCalibration(double factor) async {
    if (_useEmulator) {
      await _emulatorService.setCalibration(factor);
    } else {
      await _bluetoothService.setCalibration(factor);
    }
  }

  Future<void> startCalibration() async {
    if (_useEmulator) {
      await _emulatorService.startCalibration();
    } else {
      await _bluetoothService.startCalibration();
    }
  }

  Future<double?> completeCalibrationWithWeight(double weightGrams) async {
    if (_useEmulator) {
      return await _emulatorService.completeCalibrationWithWeight(weightGrams);
    } else {
      return await _bluetoothService.completeCalibrationWithWeight(weightGrams);
    }
  }

  Future<void> setDeviceName(String name) async {
    if (_useEmulator) {
      await _emulatorService.setDeviceName(name);
    } else {
      await _bluetoothService.setDeviceName(name);
    }
  }

  void setUnit(WeightUnit unit) {
    if (_useEmulator) {
      _emulatorService.setUnit(unit);
    } else {
      _bluetoothService.setUnit(unit);
    }
  }

  // =========================================================================
  // Emulator-specific methods
  // =========================================================================

  void setSimulationMode(SimulationMode mode) {
    _emulatorService.setSimulationMode(mode);
  }

  void setManualWeight(double weightGrams) {
    _emulatorService.setManualWeight(weightGrams);
  }

  void setNoiseLevel(double level) {
    _emulatorService.setNoiseLevel(level);
  }

  @override
  void dispose() {
    _bluetoothService.removeListener(_onServiceChanged);
    _emulatorService.removeListener(_onServiceChanged);
    _bluetoothService.dispose();
    _emulatorService.dispose();
    super.dispose();
  }
}
