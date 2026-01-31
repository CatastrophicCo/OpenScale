import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/weight_data.dart';

/// Simulation mode for the emulator
enum SimulationMode {
  noise,    // Random noise around zero
  pulls,    // Climbing pull patterns
  hold,     // Sustained hold
  ramp,     // Slow ramp up/down
  manual,   // Manual weight setting
}

/// OpenScale device emulator for testing without physical hardware
class OpenScaleEmulatorService extends ChangeNotifier {
  // Simulated device values
  static const String _deviceName = 'OpenScale-EMU';
  int _sampleRate = 10;
  double _calibrationFactor = 420.0;
  double _currentWeight = 0.0;
  double _tareOffset = 0.0;
  double _peakWeight = 0.0;

  // Simulation settings
  SimulationMode _simulationMode = SimulationMode.pulls;
  double _manualWeight = 0.0;
  double _noiseLevel = 50.0; // grams

  // State
  bool _isConnected = false;
  Timer? _simulationTimer;
  final Random _random = Random();

  // Simulation phase tracking
  String _phase = 'rest';
  int _phaseTime = 0;
  double _targetWeight = 0;

  // Weight history for graphing
  final List<WeightDataPoint> _weightHistory = [];
  static const int maxHistoryLength = 36000;
  DateTime? _connectionStartTime;

  // User preferences
  WeightUnit _unit = WeightUnit.pounds;

  // Getters to match OpenScaleBluetoothService interface
  bool get isConnected => _isConnected;
  String get deviceName => _deviceName;
  double get currentWeight => _currentWeight;
  double get peakWeight => _peakWeight;
  int get sampleRate => _sampleRate;
  double get calibrationFactor => _calibrationFactor;
  String get customDeviceName => _deviceName;
  List<WeightDataPoint> get weightHistory => List.unmodifiable(_weightHistory);
  DateTime? get connectionStartTime => _connectionStartTime;
  WeightUnit get unit => _unit;

  // Emulator-specific getters
  SimulationMode get simulationMode => _simulationMode;
  double get manualWeight => _manualWeight;
  double get noiseLevel => _noiseLevel;

  /// Connect to the emulated device
  Future<void> connect() async {
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 500));

    _isConnected = true;
    _connectionStartTime = DateTime.now();
    _weightHistory.clear();
    _peakWeight = 0.0;

    _startSimulation();
    notifyListeners();

    debugPrint('[Emulator] Connected to $_deviceName');
  }

  /// Disconnect from the emulated device
  Future<void> disconnect() async {
    _stopSimulation();
    _isConnected = false;
    _connectionStartTime = null;
    notifyListeners();

    debugPrint('[Emulator] Disconnected');
  }

  /// Send tare command
  Future<void> tare() async {
    _tareOffset = _currentWeight + _tareOffset;
    _peakWeight = 0.0;
    notifyListeners();
    debugPrint('[Emulator] Tared, offset: $_tareOffset');
  }

  /// Reset peak weight
  void resetPeak() {
    _peakWeight = 0.0;
    notifyListeners();
  }

  /// Clear weight history
  void clearHistory() {
    _weightHistory.clear();
    _connectionStartTime = DateTime.now();
    notifyListeners();
  }

  /// Set sample rate
  Future<void> setSampleRate(int rate) async {
    _sampleRate = rate.clamp(1, 80);
    _restartSimulation();
    notifyListeners();
    debugPrint('[Emulator] Sample rate set to $_sampleRate Hz');
  }

  /// Set calibration factor
  Future<void> setCalibration(double factor) async {
    _calibrationFactor = factor;
    notifyListeners();
    debugPrint('[Emulator] Calibration set to $factor');
  }

  /// Start calibration (emulated)
  Future<void> startCalibration() async {
    debugPrint('[Emulator] Calibration started');
    _calibrationFactor = 1.0;
    notifyListeners();
  }

  /// Complete calibration with weight
  Future<double?> completeCalibrationWithWeight(double weightGrams) async {
    _calibrationFactor = 420.0;
    notifyListeners();
    debugPrint('[Emulator] Calibration complete, factor: $_calibrationFactor');
    return _calibrationFactor;
  }

  /// Set device name (no-op for emulator)
  Future<void> setDeviceName(String name) async {
    debugPrint('[Emulator] Device name change ignored (emulator uses fixed name)');
  }

  /// Set weight unit
  void setUnit(WeightUnit unit) {
    _unit = unit;
    notifyListeners();
  }

  // =========================================================================
  // Emulator-specific methods
  // =========================================================================

  /// Set simulation mode
  void setSimulationMode(SimulationMode mode) {
    _simulationMode = mode;
    _phase = 'rest';
    _phaseTime = 0;
    _targetWeight = 0;
    notifyListeners();
    debugPrint('[Emulator] Simulation mode: $mode');
  }

  /// Set manual weight (for manual mode)
  void setManualWeight(double weightGrams) {
    _manualWeight = weightGrams;
    notifyListeners();
  }

  /// Set noise level
  void setNoiseLevel(double level) {
    _noiseLevel = level;
    notifyListeners();
  }

  // =========================================================================
  // Internal simulation methods
  // =========================================================================

  void _startSimulation() {
    final interval = Duration(milliseconds: (1000 / _sampleRate).round());
    _simulationTimer = Timer.periodic(interval, (_) => _simulationTick());
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _restartSimulation() {
    _stopSimulation();
    if (_isConnected) {
      _startSimulation();
    }
  }

  void _simulationTick() {
    double weight = 0;

    switch (_simulationMode) {
      case SimulationMode.noise:
        weight = _generateNoise();
        break;
      case SimulationMode.pulls:
        weight = _generatePulls();
        break;
      case SimulationMode.hold:
        weight = _generateHold();
        break;
      case SimulationMode.ramp:
        weight = _generateRamp();
        break;
      case SimulationMode.manual:
        weight = _manualWeight + _addNoise(0, _noiseLevel * 0.1);
        break;
    }

    // Apply tare offset
    _currentWeight = weight - _tareOffset;

    // Update peak
    if (_currentWeight > _peakWeight) {
      _peakWeight = _currentWeight;
    }

    // Add to history
    _weightHistory.add(WeightDataPoint(
      timestamp: DateTime.now(),
      weight: _currentWeight,
    ));

    // Trim history
    while (_weightHistory.length > maxHistoryLength) {
      _weightHistory.removeAt(0);
    }

    notifyListeners();
  }

  double _generateNoise() {
    return _addNoise(0, _noiseLevel);
  }

  double _generatePulls() {
    final ticksPerSecond = _sampleRate;
    _phaseTime++;

    switch (_phase) {
      case 'rest':
        if (_phaseTime > ticksPerSecond * (2 + _random.nextDouble() * 3)) {
          _phase = 'loading';
          _phaseTime = 0;
          _targetWeight = 15000 + _random.nextDouble() * 25000;
        }
        return _addNoise(0, _noiseLevel);

      case 'loading':
        final loadDuration = ticksPerSecond * (0.3 + _random.nextDouble() * 0.2);
        final loadProgress = min(1.0, _phaseTime / loadDuration);
        final loadWeight = _targetWeight * _easeOutQuad(loadProgress);

        if (loadProgress >= 1) {
          _phase = 'holding';
          _phaseTime = 0;
        }
        return _addNoise(loadWeight, _noiseLevel);

      case 'holding':
        if (_phaseTime > ticksPerSecond * (3 + _random.nextDouble() * 7)) {
          _phase = 'releasing';
          _phaseTime = 0;
        }
        final fatigue = 1 - (_phaseTime / (ticksPerSecond * 15)) * 0.1;
        return _addNoise(_targetWeight * fatigue, _noiseLevel);

      case 'releasing':
        final releaseDuration = ticksPerSecond * (0.2 + _random.nextDouble() * 0.2);
        final releaseProgress = min(1.0, _phaseTime / releaseDuration);
        final releaseWeight = _targetWeight * (1 - _easeInQuad(releaseProgress));

        if (releaseProgress >= 1) {
          _phase = 'rest';
          _phaseTime = 0;
        }
        return _addNoise(releaseWeight, _noiseLevel);

      default:
        return 0;
    }
  }

  double _generateHold() {
    final ticksPerSecond = _sampleRate;
    _phaseTime++;

    if (_phase == 'rest') {
      if (_phaseTime > ticksPerSecond * 2) {
        _phase = 'loading';
        _phaseTime = 0;
        _targetWeight = 20000;
      }
      return _addNoise(0, _noiseLevel);
    } else if (_phase == 'loading') {
      final loadDuration = ticksPerSecond * 0.5;
      final progress = min(1.0, _phaseTime / loadDuration);
      if (progress >= 1) {
        _phase = 'holding';
      }
      return _addNoise(_targetWeight * _easeOutQuad(progress), _noiseLevel);
    } else {
      final fatigue = 1 - (_phaseTime / (ticksPerSecond * 60)) * 0.15;
      return _addNoise(_targetWeight * max(0.7, fatigue), _noiseLevel);
    }
  }

  double _generateRamp() {
    final ticksPerSecond = _sampleRate;
    final cycleLength = ticksPerSecond * 10;
    _phaseTime++;

    final cyclePosition = (_phaseTime % (cycleLength * 2)) / cycleLength;
    double weight;

    if (cyclePosition < 1) {
      weight = 30000 * cyclePosition;
    } else {
      weight = 30000 * (2 - cyclePosition);
    }

    return _addNoise(weight, _noiseLevel);
  }

  double _addNoise(double value, double amplitude) {
    // Box-Muller transform for gaussian noise
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    if (u1 == 0) return value; // Avoid log(0)
    final gaussian = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return value + gaussian * amplitude * 0.5;
  }

  double _easeOutQuad(double t) => 1 - (1 - t) * (1 - t);
  double _easeInQuad(double t) => t * t;

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
