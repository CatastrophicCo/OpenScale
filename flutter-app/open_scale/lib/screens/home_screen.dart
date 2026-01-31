import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scale_service.dart';
import '../services/bluetooth_service.dart';
import '../services/emulator_service.dart';
import '../widgets/weight_display.dart';
import '../widgets/force_chart.dart';
import '../widgets/connection_status.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenScale'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<OpenScaleService>(
        builder: (context, scaleService, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection status
                ConnectionStatusWidget(
                  connectionState: scaleService.connectionState,
                  deviceName: scaleService.useEmulator
                      ? '${scaleService.deviceName} (Emulator)'
                      : scaleService.deviceName,
                  onConnect: () => _showDeviceList(context, scaleService),
                  onDisconnect: scaleService.disconnect,
                ),
                const SizedBox(height: 24),

                // Weight display
                WeightDisplayWidget(
                  currentWeight: scaleService.currentWeight,
                  peakWeight: scaleService.peakWeight,
                  unit: scaleService.unit,
                  onTare: scaleService.connectionState == ConnectionState.connected
                      ? scaleService.tare
                      : null,
                  onResetPeak: scaleService.resetPeak,
                  onUnitChange: scaleService.setUnit,
                ),
                const SizedBox(height: 24),

                // Force chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FORCE GRAPH',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear_all, size: 20),
                              onPressed: scaleService.clearHistory,
                              tooltip: 'Clear history',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 280,
                          child: ForceChartWidget(
                            weightHistory: scaleService.weightHistory,
                            unit: scaleService.unit,
                            connectionStartTime: scaleService.connectionStartTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Emulator controls (only show when connected to emulator)
                if (scaleService.useEmulator && scaleService.isConnected) ...[
                  const SizedBox(height: 24),
                  _buildEmulatorControls(context, scaleService),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmulatorControls(BuildContext context, OpenScaleService scaleService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EMULATOR CONTROLS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.orange,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 16),
            // Simulation mode dropdown
            Row(
              children: [
                const Text('Mode: ', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<SimulationMode>(
                    value: scaleService.simulationMode,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF334155),
                    items: const [
                      DropdownMenuItem(
                        value: SimulationMode.noise,
                        child: Text('Idle (Noise Only)'),
                      ),
                      DropdownMenuItem(
                        value: SimulationMode.pulls,
                        child: Text('Climbing Pulls'),
                      ),
                      DropdownMenuItem(
                        value: SimulationMode.hold,
                        child: Text('Sustained Hold'),
                      ),
                      DropdownMenuItem(
                        value: SimulationMode.ramp,
                        child: Text('Ramp Up/Down'),
                      ),
                      DropdownMenuItem(
                        value: SimulationMode.manual,
                        child: Text('Manual Weight'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        scaleService.setSimulationMode(mode);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Manual weight slider (only show in manual mode)
            if (scaleService.simulationMode == SimulationMode.manual) ...[
              Row(
                children: [
                  const Text('Weight: ', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Slider(
                      value: scaleService.manualWeight,
                      min: 0,
                      max: 50000,
                      divisions: 500,
                      label: '${(scaleService.manualWeight / 1000).toStringAsFixed(1)} kg',
                      onChanged: (value) {
                        scaleService.setManualWeight(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${(scaleService.manualWeight / 1000).toStringAsFixed(1)} kg',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            // Noise level slider
            Row(
              children: [
                const Text('Noise: ', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: scaleService.noiseLevel,
                    min: 0,
                    max: 200,
                    divisions: 20,
                    label: '${scaleService.noiseLevel.toStringAsFixed(0)} g',
                    onChanged: (value) {
                      scaleService.setNoiseLevel(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${scaleService.noiseLevel.toStringAsFixed(0)} g',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceList(BuildContext context, OpenScaleService scaleService) {
    scaleService.startScanning();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) {
        return Consumer<OpenScaleService>(
          builder: (context, service, _) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Device',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (service.connectionState == ConnectionState.scanning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: service.startScanning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Emulator option (always available)
                  ListTile(
                    leading: const Icon(Icons.computer, color: Colors.orange),
                    title: const Text('OpenScale-EMU (Emulator)'),
                    subtitle: const Text('Test without hardware'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      service.connectEmulator();
                    },
                  ),
                  const Divider(),

                  // Real devices
                  if (service.discoveredDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Searching for devices...',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Make sure your OpenScale is powered on',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: service.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final result = service.discoveredDevices[index];
                        final device = result.device;
                        return ListTile(
                          leading: const Icon(Icons.monitor_weight, color: Colors.blue),
                          title: Text(device.platformName.isNotEmpty
                              ? device.platformName
                              : 'Unknown Device'),
                          subtitle: Text(device.remoteId.toString()),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            service.connect(device);
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      service.stopScanning();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
