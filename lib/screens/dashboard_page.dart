// lib/screens/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/theme_provider.dart';
import 'bluetooth_scan_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  BluetoothProvider? _bluetoothProvider;
  String? _userName;
  bool _loadingProfile = true;
  String? _avatarUrl;
  String? _profileError;
  bool _initializingBluetooth = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBluetooth();
    });
  }

  Future<void> _initializeBluetooth() async {
    setState(() => _initializingBluetooth = true);
    try {
      _bluetoothProvider =
          Provider.of<BluetoothProvider>(context, listen: false);
      await _bluetoothProvider?.initialize();
      await _bluetoothProvider?.attemptAutoReconnect();
    } catch (e) {
      debugPrint('Bluetooth initialization error: $e');
    } finally {
      if (mounted) setState(() => _initializingBluetooth = false);
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await Supabase.instance.client
          .from('profiles')
          .select('first_name, last_name, email, avatar_url')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          final firstName =
              response['first_name']?.toString().trim() ?? '';
          _userName = firstName.trim();
          if (_userName!.isEmpty) {
            _userName =
                response['email']?.toString().split('@').first ?? 'User';
          }
          _avatarUrl = response['avatar_url']?.toString();
          _loadingProfile = false;
          _profileError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'User';
          _loadingProfile = false;
          _profileError = 'Failed to load profile';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bluetoothProvider == null) return;
    final newProvider =
        Provider.of<BluetoothProvider>(context, listen: false);
    if (_bluetoothProvider != newProvider) {
      _bluetoothProvider?.removeListener(_updateOnNewData);
      newProvider.addListener(_updateOnNewData);
      _bluetoothProvider = newProvider;
    }
  }

  @override
  void dispose() {
    _bluetoothProvider?.removeListener(_updateOnNewData);
    super.dispose();
  }

  void _updateOnNewData() {
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GREETING HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUserGreetingWithConnection() {
    final cs = Theme.of(context).colorScheme;
    final isConnected = _bluetoothProvider?.isConnected ?? false;
    final hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: greeting + dark/light toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(fontSize: 20, color: cs.onSurface.withValues(alpha: 0.6)),
              ),
              Consumer<ThemeProvider>(
                builder: (context, theme, _) => IconButton(
                  tooltip: theme.isDarkMode
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode',
                  icon: Icon(
                    theme.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: cs.onSurface,
                  ),
                  onPressed: theme.toggleTheme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Row 2: avatar + name | BT status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Avatar + name
              Row(
                children: [
                  if (_avatarUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(_avatarUrl!),
                      onBackgroundImageError: (_, __) =>
                          setState(() => _avatarUrl = null),
                    )
                  else if (!_loadingProfile)
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primary,
                      child: Text(
                        _userName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (_avatarUrl != null || !_loadingProfile)
                    const SizedBox(width: 12),
                  _loadingProfile
                      ? const SizedBox(
                          width: 100,
                          child: LinearProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName ?? 'User',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            if (_profileError != null)
                              GestureDetector(
                                onTap: _fetchUserProfile,
                                child: Text(
                                  'Tap to retry',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.error,
                                    decoration:
                                        TextDecoration.underline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ],
              ),

              // BT icon + connect/disconnect
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_initializingBluetooth)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      size: 28,
                      color: isConnected ? Colors.green : cs.onSurface.withValues(alpha: 0.5),
                    ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: _initializingBluetooth
                        ? null
                        : () async {
                            if (isConnected) {
                              await _bluetoothProvider?.disconnect();
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BluetoothScanPage()),
                              );
                            }
                          },
                    child: Text(
                      _initializingBluetooth
                          ? 'Loading...'
                          : (isConnected ? 'Disconnect' : 'Connect'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Last-disconnected hint
          if (_bluetoothProvider?.lastDisconnectedTime != null &&
              !isConnected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last disconnected: ${DateFormat('h:mm a').format(_bluetoothProvider!.lastDisconnectedTime!)}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS + METRICS CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCombinedStatusMetricsCard(
      Map<String, dynamic> data, bool isConnected) {
    final cs = Theme.of(context).colorScheme;

    if (!isConnected) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(Icons.bluetooth_searching,
                    size: 48, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text(
                  'Connect to a device to view data',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Use the Connect button above to scan for nearby devices',
                  style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCharging = (data['I']?.toDouble() ?? 0.0) < 0;
    final hasVehicleInfo =
        (data['brand']?.toString() ?? '').isNotEmpty;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Vehicle info header
            if (hasVehicleInfo)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      data['profile'] == 'Electric Car'
                          ? Icons.directions_car
                          : Icons.electric_scooter,
                      size: 40,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['brand'] ?? 'Unknown'} ${data['model'] ?? 'Vehicle'}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          data['profile'] ?? 'Electric Vehicle',
                          style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                                '${data['brand'] ?? 'Vehicle'} Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Model: ${data['model'] ?? 'N/A'}'),
                                Text(
                                    'Type: ${data['profile'] ?? 'N/A'}'),
                                const SizedBox(height: 16),
                                const Text('Current Status:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text('Voltage: ${data['v'] ?? 0} V'),
                                Text('Current: ${data['I'] ?? 0} A'),
                                Text('Power: ${data['P'] ?? 0} W'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Close'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // Charging/Discharging row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isCharging ? Icons.bolt : Icons.power,
                        color:
                            isCharging ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      isCharging ? 'CHARGING' : 'DISCHARGING',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isCharging ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Last updated ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // SOC + Range
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('State of Charge',
                        style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    Text(
                      '${data['bl']?.toStringAsFixed(0) ?? '0'}%',
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Est. Drivable Range',
                        style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    Text(
                      '${data['range']?.toStringAsFixed(0) ?? '0'} km',
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),

            Divider(height: 40, thickness: 1, color: cs.outline.withValues(alpha: 0.3)),

            Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 120,
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricTile('Voltage',
                      '${data['v']?.toStringAsFixed(1) ?? '0.0'} V',
                      Icons.bolt),
                  _buildMetricTile('Current',
                      '${data['I']?.toStringAsFixed(1) ?? '0.0'} A',
                      Icons.electric_bolt),
                  _buildMetricTile('Power',
                      '${data['P']?.toStringAsFixed(1) ?? '0.0'} W',
                      Icons.power),
                  _buildMetricTile('Temperature',
                      '${data['T']?.toStringAsFixed(1) ?? '0.0'}°C',
                      Icons.thermostat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GAUGES CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGaugesCard(double temperature, double batteryLevel,
      bool isCharging, bool isConnected) {
    if (!isConnected || batteryLevel <= 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                  child: _buildTemperatureSection(temperature)),
              Container(
                width: 1,
                height: 100,
                color: cs.outline.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(vertical: 20),
              ),
              Expanded(
                  child: _buildBatterySection(
                      batteryLevel, isCharging)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureSection(double temperature) {
    final color = _getTemperatureColor(temperature);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.thermostat, size: 100, color: color),
        const SizedBox(height: 8),
        Text('${temperature.toStringAsFixed(1)}°C',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color)),
        Text('Temperature',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 16)),
      ],
    );
  }

  Widget _buildBatterySection(double level, bool isCharging) {
    final color = _getBatteryColor(level);
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBatteryIndicator(level, color, isCharging),
        const SizedBox(height: 8),
        Text('${level.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(isCharging ? 'CHARGING' : 'DISCHARGING',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        Text('Battery',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 16)),
      ],
    );
  }

  Widget _buildBatteryIndicator(
      double level, Color color, bool isCharging) {
    final outlineColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: outlineColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: level / 100 * 96,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(6)),
              ),
            ),
          ),
        ),
        if (isCharging)
          const Icon(Icons.bolt, color: Colors.white, size: 30),
        Positioned(
          right: -10,
          top: 25,
          child: Container(
            width: 8,
            height: 20,
            decoration: BoxDecoration(
              color: outlineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
      String title, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary, size: 28),
      title: Text(value,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold)),
      subtitle: Text(title,
          style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.6))),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 15) return Colors.blue;
    if (temp < 30) return Colors.green;
    if (temp < 40) return Colors.orange;
    return Colors.red;
  }

  Color _getBatteryColor(double level) {
    if (level < 20) return Colors.red;
    if (level < 50) return Colors.orange;
    return Colors.green;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        _bluetoothProvider = bluetoothProvider;

        final Map<String, dynamic> bluetoothData =
            bluetoothProvider.deviceData.isEmpty
                ? {
                    'profile': '', 'brand': '', 'model': '',
                    'bl': 0.0, 'v': 0.0, 'I': 0.0, 'T': 0.0,
                    'P': 0.0, 'range': 0.0,
                  }
                : bluetoothProvider.deviceData;
        final isConnected = bluetoothProvider.isConnected;
        final isCharging =
            (bluetoothData['I']?.toDouble() ?? 0.0) < 0;

        return Scaffold(
          // No hardcoded color — theme scaffoldBackgroundColor handles it
          body: RefreshIndicator(
            onRefresh: () async {
              await _fetchUserProfile();
              if (isConnected) {
                try {
                  await bluetoothProvider.attemptAutoReconnect();
                } catch (e) {
                  debugPrint('Refresh connection error: $e');
                }
              }
            },
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserGreetingWithConnection(),
                    _buildCombinedStatusMetricsCard(
                        bluetoothData, isConnected),
                    _buildGaugesCard(
                      bluetoothData['T']?.toDouble() ?? 0.0,
                      bluetoothData['bl']?.toDouble() ?? 0.0,
                      isCharging,
                      isConnected,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}