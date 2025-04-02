import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/transaction_provider.dart';
import 'models/vehicle_settings.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => VehicleSettings()),
      ],
      child: Builder(
        builder: (context) {
          final bluetoothProvider = context.read<BluetoothProvider>();
          return MaterialApp(
            title: 'EV Dashboard',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              useMaterial3: true,
            ),
            home: bluetoothProvider.errorMessage != null
                ? _buildErrorScreen(context, bluetoothProvider)
                : const MainScreen(),
          );
        },
      ),
    ),
  );
}

Widget _buildErrorScreen(BuildContext context, BluetoothProvider provider) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(provider.errorMessage!,
            style: const TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: provider.clearError,
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    ),
  );
}