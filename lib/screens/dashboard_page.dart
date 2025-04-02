import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../models/vehicle_settings.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late AnimationController _batteryController;
  late AnimationController _tempController;
  late AnimationController _chargeController;
  BluetoothProvider? _bluetoothProvider;
  String _currentProfile = 'car'; // Default fallback value

  @override
  void initState() {
    super.initState();
    _batteryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _tempController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.5,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (_bluetoothProvider != newProvider) {
      _bluetoothProvider?.removeListener(_updateOnNewData);
      newProvider.addListener(_updateOnNewData);
      _bluetoothProvider = newProvider;
      _updateOnNewData(); // Initialize with current values
    }
  }

  @override
  void dispose() {
    _bluetoothProvider?.removeListener(_updateOnNewData);
    _batteryController.dispose();
    _tempController.dispose();
    _chargeController.dispose();
    _bluetoothProvider = null;
    super.dispose();
  }

  void _updateOnNewData() {
    if (!mounted) return;
    try {
      final bluetoothData = _bluetoothProvider?.deviceData ?? {
        'bl': 75.0, 'v': 48.2, 'I': 2.5, 'T': 32.0, 'P': 0.0, 'range': 0.0, 'profile': 'car'
      };
      
      // Update profile from BLE data
      if (bluetoothData.containsKey('profile')) {
        final profile = bluetoothData['profile'].toString().toLowerCase();
        if (profile.contains('car')) {
          _currentProfile = 'car';
        } else if (profile.contains('bike')) {
          _currentProfile = 'ebike';
        } else if (profile.contains('scooter')) {
          _currentProfile = 'scooter';
        } else if (profile.contains('charger') || profile.contains('station')) {
          _currentProfile = 'charger';
        }
      }

      _batteryController.animateTo(bluetoothData['bl'] / 100);
      _tempController.animateTo(bluetoothData['T'] / 100);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error updating dashboard: $e');
    }
  }

  Widget _buildVehicleIcon(String profile) {
    final IconData icon;
    switch (profile) {
      case 'car':
        icon = Icons.directions_car;
        break;
      case 'ebike':
        icon = Icons.electric_bike;
        break;
      case 'scooter':
        icon = Icons.electric_scooter;
        break;
      case 'charger':
        icon = Icons.ev_station;
        break;
      default:
        icon = Icons.electric_car;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 150,
        color: _getIconColor(profile),
      ),
    );
  }

  Color _getIconColor(String profile) {
    switch (profile) {
      case 'car':
        return Colors.blue;
      case 'ebike':
        return Colors.green;
      case 'scooter':
        return Colors.orange;
      case 'charger':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildBatteryGauge(double level, bool isCharging) {
    return AnimatedBuilder(
      animation: _batteryController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(150, 150),
          painter: BatteryGaugePainter(
            value: _batteryController.value,
            isCharging: isCharging,
          ),
        );
      },
    );
  }

  Widget _buildTempGauge(double temp) {
    return AnimatedBuilder(
      animation: _tempController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(150, 150),
          painter: TempGaugePainter(_tempController.value),
        );
      },
    );
  }

  Widget _buildDataTile(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(value, 
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothData = _bluetoothProvider?.deviceData ?? {
      'bl': 75.0, 'v': 48.2, 'I': 2.5, 'T': 32.0, 'P': 0.0, 'range': 0.0, 'profile': 'car'
    };
    final isCharging = bluetoothData['I'] < 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(bluetoothData['profile']?.toString() ?? 'Vehicle Dashboard'),
        actions: [
          AnimatedBuilder(
            animation: _chargeController,
            builder: (context, child) {
              return Icon(
                Icons.bolt,
                color: isCharging 
                  ? Colors.amber.withOpacity(_chargeController.value)
                  : Colors.grey,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildVehicleIcon(_currentProfile),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    _buildBatteryGauge(bluetoothData['bl'], isCharging),
                    const SizedBox(height: 8),
                    Text('${bluetoothData['bl'].toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 24)),
                  ],
                ),
                Column(
                  children: [
                    _buildTempGauge(bluetoothData['T']),
                    const SizedBox(height: 8),
                    Text('${bluetoothData['T'].toStringAsFixed(1)}°C',
                      style: const TextStyle(fontSize: 24)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              padding: const EdgeInsets.all(16),
              children: [
                _buildDataTile('Voltage', '${bluetoothData['v'].toStringAsFixed(1)} V', Icons.bolt),
                _buildDataTile('Current', '${bluetoothData['I'].toStringAsFixed(1)} A', Icons.electric_bolt),
                _buildDataTile('Power', '${bluetoothData['P'].toStringAsFixed(1)} W', Icons.power),
                _buildDataTile('Range', '${bluetoothData['range'].toStringAsFixed(1)} km', Icons.speed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BatteryGaugePainter extends CustomPainter {
  final double value;
  final bool isCharging;

  const BatteryGaugePainter({required this.value, required this.isCharging});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;
    final paint = Paint()
      ..color = const Color.fromRGBO(128, 128, 128, 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    canvas.drawCircle(center, radius - 6, paint);

    final sweepAngle = 2 * pi * value;
    paint
      ..shader = LinearGradient(
        colors: [
          isCharging ? Colors.amber : Colors.red,
          isCharging ? Colors.lightGreen : Colors.green,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -pi/2,
      sweepAngle,
      false,
      paint,
    );

    final icon = isCharging ? Icons.bolt : Icons.battery_full;
    TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: icon.fontFamily,
          color: isCharging ? Colors.amber : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()
     ..paint(canvas, Offset(center.dx - 20, center.dy - 20));
  }

  @override
  bool shouldRepaint(covariant BatteryGaugePainter oldDelegate) =>
      value != oldDelegate.value || isCharging != oldDelegate.isCharging;
}

class TempGaugePainter extends CustomPainter {
  final double value;

  const TempGaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    const colors = [Colors.blue, Colors.green, Colors.orange, Colors.red];
    const stops = [0.0, 0.3, 0.6, 1.0];
    paint.shader = const SweepGradient(
      colors: colors,
      stops: stops,
      startAngle: -pi/2,
      endAngle: 3 * pi/2,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -pi/2,
      pi,
      false,
      paint,
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;
    final angle = -pi/2 + pi * value;
    final needleEnd = Offset(
      center.dx + radius * 0.8 * cos(angle),
      center.dy + radius * 0.8 * sin(angle),
    );
    canvas.drawLine(center, needleEnd, needlePaint);

    TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.thermostat.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: Icons.thermostat.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()
     ..paint(canvas, Offset(center.dx - 20, center.dy - 20));
  }

  @override
  bool shouldRepaint(covariant TempGaugePainter oldDelegate) => 
      value != oldDelegate.value;
}