import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
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
      body: Consumer<OpenScaleBluetoothService>(
        builder: (context, bluetooth, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection status
                ConnectionStatusWidget(
                  connectionState: bluetooth.connectionState,
                  deviceName: bluetooth.deviceName,
                  onConnect: () => _showDeviceList(context, bluetooth),
                  onDisconnect: bluetooth.disconnect,
                ),
                const SizedBox(height: 24),

                // Weight display
                WeightDisplayWidget(
                  currentWeight: bluetooth.currentWeight,
                  peakWeight: bluetooth.peakWeight,
                  unit: bluetooth.unit,
                  onTare: bluetooth.connectionState == ConnectionState.connected
                      ? bluetooth.tare
                      : null,
                  onResetPeak: bluetooth.resetPeak,
                  onUnitChange: bluetooth.setUnit,
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
                              onPressed: bluetooth.clearHistory,
                              tooltip: 'Clear history',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ForceChartWidget(
                            weightHistory: bluetooth.weightHistory,
                            unit: bluetooth.unit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeviceList(BuildContext context, OpenScaleBluetoothService bluetooth) {
    bluetooth.startScanning();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) {
        return Consumer<OpenScaleBluetoothService>(
          builder: (context, bt, _) {
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
                      if (bt.connectionState == ConnectionState.scanning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: bt.startScanning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (bt.discoveredDevices.isEmpty)
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
                      itemCount: bt.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final result = bt.discoveredDevices[index];
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
                            bt.connect(device);
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      bt.stopScanning();
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
