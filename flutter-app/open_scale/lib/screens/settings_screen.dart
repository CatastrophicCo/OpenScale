import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../models/weight_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _deviceNameController = TextEditingController();
  final _calibrationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bt = context.read<OpenScaleBluetoothService>();
    _deviceNameController.text = bt.customDeviceName;
    _calibrationController.text = bt.calibrationFactor.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _calibrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Consumer<OpenScaleBluetoothService>(
        builder: (context, bluetooth, _) {
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
                      trailing: _buildConnectionStatus(bluetooth.connectionState),
                    ),
                    if (bluetooth.connectionState == ConnectionState.connected) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Device Name'),
                        subtitle: Text(bluetooth.customDeviceName.isNotEmpty
                            ? bluetooth.customDeviceName
                            : bluetooth.deviceName),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showRenameDialog(context, bluetooth),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Disconnect'),
                        leading: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                        onTap: bluetooth.disconnect,
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
                        value: bluetooth.unit,
                        underline: const SizedBox(),
                        items: WeightUnit.values.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(_unitDisplayName(unit)),
                          );
                        }).toList(),
                        onChanged: (unit) {
                          if (unit != null) {
                            bluetooth.setUnit(unit);
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
                      subtitle: Text('${bluetooth.sampleRate} Hz'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: bluetooth.sampleRate.toDouble(),
                        min: 1,
                        max: 80,
                        divisions: 79,
                        label: '${bluetooth.sampleRate} Hz',
                        onChanged: bluetooth.connectionState == ConnectionState.connected
                            ? (value) => bluetooth.setSampleRate(value.round())
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
                      onTap: bluetooth.connectionState == ConnectionState.connected
                          ? bluetooth.tare
                          : null,
                      enabled: bluetooth.connectionState == ConnectionState.connected,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Calibration Factor'),
                      subtitle: Text(bluetooth.calibrationFactor.toStringAsFixed(1)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: bluetooth.connectionState == ConnectionState.connected
                            ? () => _showCalibrationDialog(context, bluetooth)
                            : null,
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

  Widget _buildConnectionStatus(ConnectionState state) {
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
        color = Colors.green;
        text = 'Connected';
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

  void _showRenameDialog(BuildContext context, OpenScaleBluetoothService bluetooth) {
    _deviceNameController.text = bluetooth.customDeviceName;

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
                  bluetooth.setDeviceName(_deviceNameController.text);
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

  void _showCalibrationDialog(BuildContext context, OpenScaleBluetoothService bluetooth) {
    _calibrationController.text = bluetooth.calibrationFactor.toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Calibration Factor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _calibrationController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Calibration Factor',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the calibration sketch to find the correct value for your load cell.',
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
                final value = double.tryParse(_calibrationController.text);
                if (value != null) {
                  bluetooth.setCalibration(value);
                }
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }
}
