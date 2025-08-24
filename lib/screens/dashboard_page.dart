import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/bluetooth_provider.dart';
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
    setState(() {
      _initializingBluetooth = true;
    });

    try {
      _bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);
      await _bluetoothProvider?.initialize();
      await _bluetoothProvider?.attemptAutoReconnect();
    } catch (e) {
      debugPrint('Bluetooth initialization error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initializingBluetooth = false;
        });
      }
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
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select('first_name, last_name, email, avatar_url')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          // Combine first and last name, fallback to email username, then 'User'
          final firstName = response['first_name']?.toString().trim() ?? '';
          
          _userName = '$firstName '.trim();
          
          if (_userName!.isEmpty) {
            _userName = response['email']?.toString().split('@').first ?? 'User';
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
    
    final newProvider = Provider.of<BluetoothProvider>(context, listen: false);
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

  Widget _buildUserGreetingWithConnection() {
    final isConnected = _bluetoothProvider?.isConnected ?? false;
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting,',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_avatarUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(_avatarUrl!),
                      onBackgroundImageError: (error, stackTrace) {
                        setState(() {
                          _avatarUrl = null;
                        });
                      },
                    )
                  else if (!_loadingProfile)
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue[800],
                      child: Text(
                        _userName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_avatarUrl != null || !_loadingProfile) const SizedBox(width: 12),
                  _loadingProfile
                      ? const SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName ?? 'User',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            if (_profileError != null) 
                              GestureDetector(
                                onTap: _fetchUserProfile,
                                child: Text(
                                  'Tap to retry',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[600],
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ],
              ),
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
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      size: 28,
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: isConnected ? Colors.red[100] : Colors.blue[100],
                        foregroundColor: isConnected ? Colors.red : Colors.blue,
                      ),
                      onPressed: _initializingBluetooth ? null : () async {
                        if (isConnected) {
                          try {
                            await _bluetoothProvider?.disconnect();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to disconnect: $e')),
                              );
                            }
                          }
                        } else {
                          try {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BluetoothScanPage()),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to open scanner: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        _initializingBluetooth ? 'Loading...' : (isConnected ? 'Disconnect' : 'Connect'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_bluetoothProvider?.lastDisconnectedTime != null && !isConnected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last disconnected: ${DateFormat('h:mm a').format(_bluetoothProvider!.lastDisconnectedTime!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCombinedStatusMetricsCard(Map<String, dynamic> data, bool isConnected) {
    if (!isConnected) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  Icons.bluetooth_searching,
                  size: 48,
                  color: Colors.grey[400],
                ),
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
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCharging = (data['I']?.toDouble() ?? 0.0) < 0;
    final hasVehicleInfo = (data['brand']?.toString() ?? '').isNotEmpty;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
                      color: Colors.blue[800],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['brand'] ?? 'Unknown'} ${data['model'] ?? 'Vehicle'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data['profile'] ?? 'Electric Vehicle',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
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
                            title: Text('${data['brand'] ?? 'Vehicle'} Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Model: ${data['model'] ?? 'N/A'}'),
                                Text('Type: ${data['profile'] ?? 'N/A'}'),
                                const SizedBox(height: 16),
                                const Text('Current Status:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isCharging ? Icons.bolt : Icons.power,
                      color: isCharging ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCharging ? 'CHARGING' : 'DISCHARGING',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCharging ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Last updated ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'State of Charge',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${data['bl']?.toStringAsFixed(0) ?? '0'}%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Est. Drivable Range',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${data['range']?.toStringAsFixed(0) ?? '0'} km',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 40, thickness: 1),
            const Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
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
                  _buildMetricTile('Voltage', '${data['v']?.toStringAsFixed(1) ?? '0.0'} V', Icons.bolt),
                  _buildMetricTile('Current', '${data['I']?.toStringAsFixed(1) ?? '0.0'} A', Icons.electric_bolt),
                  _buildMetricTile('Power', '${data['P']?.toStringAsFixed(1) ?? '0.0'} W', Icons.power),
                  _buildMetricTile('Temperature', '${data['T']?.toStringAsFixed(1) ?? '0.0'}°C', Icons.thermostat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugesCard(double temperature, double batteryLevel, bool isCharging, bool isConnected) {
    if (!isConnected || batteryLevel <= 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: _buildTemperatureSection(temperature),
              ),
              Container(
                width: 1,
                height: 100,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 20),
              ),
              Expanded(
                child: _buildBatterySection(batteryLevel, isCharging),
              ),
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
            color: color,
          ),
        ),
        const Text('Temperature', 
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBatterySection(double level, bool isCharging) {
    final color = _getBatteryColor(level);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBatteryIndicator(level, color, isCharging),
        const SizedBox(height: 8),
        Text(
          '${level.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          isCharging ? 'CHARGING' : 'DISCHARGING',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Text('Battery', 
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryIndicator(double level, Color color, bool isCharging) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: level / 100 * 96,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
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
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[800], size: 28),
      title: Text(value, 
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        _bluetoothProvider = bluetoothProvider;
        
        final bluetoothData = bluetoothProvider.deviceData ?? {
          'profile': '', 'brand': '', 'model': '',
          'bl': 0.0, 'v': 0.0, 'I': 0.0, 'T': 0.0, 'P': 0.0, 'range': 0.0
        };
        final isConnected = bluetoothProvider.isConnected;
        final isCharging = (bluetoothData['I']?.toDouble() ?? 0.0) < 0;

        return Scaffold(
          backgroundColor: Colors.grey[100],
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
                    _buildCombinedStatusMetricsCard(bluetoothData, isConnected),
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