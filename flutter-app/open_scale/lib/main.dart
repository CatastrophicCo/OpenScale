import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/bluetooth_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OpenScaleApp());
}

class OpenScaleApp extends StatelessWidget {
  const OpenScaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OpenScaleBluetoothService(),
      child: MaterialApp(
        title: 'OpenScale',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          cardTheme: const CardTheme(
            color: Color(0xFF1E293B),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
