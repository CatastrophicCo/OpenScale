import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scale_service.dart';
import '../services/bluetooth_service.dart';
import '../models/weight_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _deviceNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final service = context.read<OpenScaleService>();
    _deviceNameController.text = service.customDeviceName;
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Consumer<OpenScaleService>(
        builder: (context, service, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Connection section
              _buildSectionHeader('Device'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Status'),
                      trailing: _buildConnectionStatus(service.connectionState, service.useEmulator),
                    ),
                    if (service.connectionState == ConnectionState.connected) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Device Name'),
                        subtitle: Text(service.useEmulator
                            ? '${service.deviceName} (Emulator)'
                            : service.customDeviceName.isNotEmpty
                                ? service.customDeviceName
                                : service.deviceName),
                        trailing: service.useEmulator
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showRenameDialog(context, service),
                              ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Disconnect'),
                        leading: Icon(
                          service.useEmulator ? Icons.computer : Icons.bluetooth_disabled,
                          color: Colors.red,
                        ),
                        onTap: service.disconnect,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Display section
              _buildSectionHeader('Display'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Weight Unit'),
                      trailing: DropdownButton<WeightUnit>(
                        value: service.unit,
                        underline: const SizedBox(),
                        items: WeightUnit.values.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(_unitDisplayName(unit)),
                          );
                        }).toList(),
                        onChanged: (unit) {
                          if (unit != null) {
                            service.setUnit(unit);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sampling section
              _buildSectionHeader('Sampling'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Sample Rate'),
                      subtitle: Text('${service.sampleRate} Hz'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: service.sampleRate.toDouble(),
                        min: 1,
                        max: 80,
                        divisions: 79,
                        label: '${service.sampleRate} Hz',
                        onChanged: service.connectionState == ConnectionState.connected
                            ? (value) => service.setSampleRate(value.round())
                            : null,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Higher rates give smoother graphs but use more battery. Recommended: 10-20 Hz.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Calibration section
              _buildSectionHeader('Calibration'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Tare / Zero Scale'),
                      leading: const Icon(Icons.restart_alt),
                      onTap: service.connectionState == ConnectionState.connected
                          ? service.tare
                          : null,
                      enabled: service.connectionState == ConnectionState.connected,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Current Calibration Factor'),
                      subtitle: Text(service.calibrationFactor.toStringAsFixed(2)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: service.connectionState == ConnectionState.connected
                            ? () => _showManualCalibrationDialog(context, service)
                            : null,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Auto Calibration'),
                      subtitle: const Text('Use a known weight'),
                      leading: const Icon(Icons.straighten),
                      onTap: service.connectionState == ConnectionState.connected
                          ? () => _startCalibrationProcess(context, service)
                          : null,
                      enabled: service.connectionState == ConnectionState.connected,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Calibration is saved to the device and persists after disconnect.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // About section
              _buildSectionHeader('About'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('Version'),
                      trailing: Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('GitHub Repository'),
                      leading: const Icon(Icons.code),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {
                        // TODO: Open URL
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(ConnectionState state, bool useEmulator) {
    Color color;
    String text;

    switch (state) {
      case ConnectionState.disconnected:
        color = Colors.red;
        text = 'Disconnected';
        break;
      case ConnectionState.scanning:
        color = Colors.orange;
        text = 'Scanning...';
        break;
      case ConnectionState.connecting:
        color = Colors.yellow;
        text = 'Connecting...';
        break;
      case ConnectionState.connected:
        color = useEmulator ? Colors.orange : Colors.green;
        text = useEmulator ? 'Emulator' : 'Connected';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  String _unitDisplayName(WeightUnit unit) {
    switch (unit) {
      case WeightUnit.grams:
        return 'Grams (g)';
      case WeightUnit.kilograms:
        return 'Kilograms (kg)';
      case WeightUnit.pounds:
        return 'Pounds (lbs)';
    }
  }

  void _showRenameDialog(BuildContext context, OpenScaleService service) {
    _deviceNameController.text = service.customDeviceName;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _deviceNameController,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'OpenScale-XXXX',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restart the device for the new name to appear in Bluetooth scanning.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (_deviceNameController.text.isNotEmpty) {
                  service.setDeviceName(_deviceNameController.text);
                }
                Navigator.pop(context);
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _startCalibrationProcess(BuildContext context, OpenScaleService service) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _CalibrationDialog(service: service);
      },
    );
  }

  void _showManualCalibrationDialog(BuildContext context, OpenScaleService service) {
    final controller = TextEditingController(text: service.calibrationFactor.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Calibration Factor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Calibration Factor',
                  hintText: 'e.g., 420.00',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter a known calibration factor to apply directly to the device.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final factor = double.tryParse(controller.text);
                if (factor != null && factor > 0) {
                  await service.setCalibration(factor);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calibration factor set to ${factor.toStringAsFixed(2)}')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid factor greater than 0')),
                  );
                }
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}

/// Calibration dialog with step-by-step process and custom weight support
class _CalibrationDialog extends StatefulWidget {
  final OpenScaleService service;

  const _CalibrationDialog({required this.service});

  @override
  State<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<_CalibrationDialog> {
  int _step = 0; // 0 = intro, 1 = waiting for weight, 2 = completing, 3 = done
  String? _error;
  double? _newFactor;

  // Custom weight support
  final _weightController = TextEditingController(text: '10');
  String _weightUnit = 'lbs';

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double get _weightInGrams {
    final value = double.tryParse(_weightController.text) ?? 10.0;
    return _weightUnit == 'lbs' ? value * 453.592 : value * 1000;
  }

  Future<void> _startCalibration() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      setState(() {
        _error = 'Please enter a valid weight';
      });
      return;
    }

    setState(() {
      _step = 1;
      _error = null;
    });

    try {
      await widget.service.startCalibration();
    } catch (e) {
      setState(() {
        _error = 'Failed to start calibration: $e';
        _step = 0;
      });
    }
  }

  Future<void> _completeCalibration() async {
    setState(() {
      _step = 2;
      _error = null;
    });

    try {
      _newFactor = await widget.service.completeCalibrationWithWeight(_weightInGrams);
      setState(() {
        _step = 3;
      });
    } catch (e) {
      setState(() {
        _error = 'Calibration failed: $e';
        _step = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Calibration'),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.straighten, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Enter your known weight:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _weightUnit,
                  items: const [
                    DropdownMenuItem(value: 'lbs', child: Text('lbs')),
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _weightUnit = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Remove all weight from the scale before starting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      case 1:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Place exactly ${_weightController.text} $_weightUnit on the scale.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'When the weight is stable, tap Complete.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      case 2:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calibrating...'),
          ],
        );
      case 3:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Calibration Complete!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'New factor: ${_newFactor?.toStringAsFixed(2) ?? "saved"}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  List<Widget> _buildActions() {
    switch (_step) {
      case 0:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _startCalibration,
            child: const Text('Start'),
          ),
        ];
      case 1:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _completeCalibration,
            child: const Text('Complete'),
          ),
        ];
      case 2:
        return [];
      case 3:
        return [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ];
      default:
        return [];
    }
  }
}
