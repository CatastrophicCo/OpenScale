import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final ConnectionState connectionState;
  final String deviceName;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ConnectionStatusWidget({
    super.key,
    required this.connectionState,
    required this.deviceName,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connectionState == ConnectionState.connected
                        ? (deviceName.isNotEmpty ? deviceName : 'OpenScale')
                        : 'No Device',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Connect/Disconnect button
            if (connectionState == ConnectionState.disconnected)
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.bluetooth),
                label: const Text('Connect'),
              )
            else if (connectionState == ConnectionState.connected)
              OutlinedButton(
                onPressed: onDisconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Disconnect'),
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (connectionState) {
      case ConnectionState.disconnected:
        return Colors.red;
      case ConnectionState.scanning:
        return Colors.orange;
      case ConnectionState.connecting:
        return Colors.yellow;
      case ConnectionState.connected:
        return Colors.green;
    }
  }

  String _getStatusText() {
    switch (connectionState) {
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.scanning:
        return 'Scanning...';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.connected:
        return 'Connected';
    }
  }
}
