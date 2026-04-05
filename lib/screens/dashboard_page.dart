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
            });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'User';
          _loadingProfile = false;
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

  // ── helpers ────────────────────────────────────────────────────────────────
  Color _batteryColor(double level) {
    if (level < 20) return Colors.red;
    if (level < 50) return Colors.orange;
    return const Color(0xFF2E7D32);
  }

  Color _tempColor(double temp) {
    if (temp < 15) return Colors.blue;
    if (temp < 30) return const Color(0xFF2E7D32);
    if (temp < 40) return Colors.orange;
    return Colors.red;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GREETING HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final isConnected = _bluetoothProvider?.isConnected ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${ _greeting()},',
                  style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              Consumer<ThemeProvider>(
                builder: (_, theme, __) => IconButton(
                  icon: Icon(
                    theme.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  onPressed: theme.toggleTheme,
                ),
              ),
            ],
          ),

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
                  if (!_loadingProfile) const SizedBox(width: 10),
                  _loadingProfile
                      ? const SizedBox(
                          width: 100,
                          child: LinearProgressIndicator())
                      : Text(
                          _userName ?? 'User',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                ],
              ),

              // BT connect / disconnect
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_initializingBluetooth)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      size: 22,
                      color: isConnected
                          ? Colors.green
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                  TextButton(
                    onPressed: _initializingBluetooth
                        ? null
                        : () async {
                            if (isConnected) {
                              await _bluetoothProvider?.disconnect();
                            } else {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      const BluetoothScanPage()));
                            }
                          },
                    child: Text(
                      _initializingBluetooth
                          ? 'Loading...'
                          : isConnected
                              ? 'Disconnect'
                              : 'Connect',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_bluetoothProvider?.lastDisconnectedTime != null &&
              !isConnected)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Last connected: ${DateFormat('h:mm a').format(_bluetoothProvider!.lastDisconnectedTime!)}',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECTED EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDisconnectedState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Connect prompt card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 4,
                  color: cs.onSurface.withValues(alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bluetooth_searching,
                            size: 36, color: cs.primary),
                      ),
                      const SizedBox(height: 16),
                      const Text('No Device Connected',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Connect your EV via Bluetooth to see live battery, '
                        'power and temperature data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.55),
                            height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BluetoothScanPage())),
                          icon: const Icon(Icons.bluetooth_rounded, size: 18),
                          label: const Text('Scan for Devices',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tips row — two small cards
          Row(
            children: [
              Expanded(
                child: _tipCard(
                  icon: Icons.battery_charging_full,
                  color: const Color(0xFF2E7D32),
                  title: 'Sell Energy',
                  body: 'List your battery on the marketplace when parked.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tipCard(
                  icon: Icons.map_outlined,
                  color: Colors.blue,
                  title: 'Find Sellers',
                  body: 'Browse the map to find nearby energy sellers.',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _tipCard(
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.purple,
                  title: 'POL Wallet',
                  body: 'Pay and receive energy payments via Polygon.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tipCard(
                  icon: Icons.shield_outlined,
                  color: Colors.teal,
                  title: 'Escrow Safe',
                  body: 'Smart contract holds funds until delivery.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    height: 1.4)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECTED STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConnectedDashboard(Map<String, dynamic> data) {
    final cs = Theme.of(context).colorScheme;
    final isCharging = (data['I']?.toDouble() ?? 0.0) < 0;
    final battery = data['bl']?.toDouble() ?? 0.0;
    final voltage = data['v']?.toDouble() ?? 0.0;
    final current = (data['I']?.toDouble() ?? 0.0).abs();
    final power = data['P']?.toDouble() ?? 0.0;
    final temp = data['T']?.toDouble() ?? 0.0;
    final range = data['range']?.toDouble() ?? 0.0;
    final hasVehicle = (data['brand']?.toString() ?? '').isNotEmpty;
    final battColor = _batteryColor(battery);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Single unified card ────────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // Accent bar — battery colour
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      battColor,
                      battColor.withValues(alpha: 0.35),
                    ]),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Vehicle header ─────────────────────────────────
                      if (hasVehicle) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                data['profile'] == 'Electric Car'
                                    ? Icons.directions_car
                                    : Icons.electric_moped,
                                color: cs.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data['brand'] ?? ''} ${data['model'] ?? ''}'.trim(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    data['profile'] ?? 'Electric Vehicle',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            ),
                            // Live badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('Live',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Separator
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Divider(
                              height: 1,
                              color: cs.outline.withValues(alpha: 0.12)),
                        ),
                      ],

                      // ── SOC + Range ────────────────────────────────────
                      Row(
                        children: [
                          // SOC
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('State of Charge',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withValues(alpha: 0.5))),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${battery.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 44,
                                            fontWeight: FontWeight.bold,
                                            color: battColor,
                                            height: 1)),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 6, left: 2),
                                      child: Text('%',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: battColor)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 52,
                              color: cs.outline.withValues(alpha: 0.12)),
                          // Range
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Est. Range',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.5))),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${range.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 44,
                                              fontWeight: FontWeight.bold,
                                              height: 1)),
                                      const Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 6, left: 2),
                                        child: Text('km',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Battery bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: battery / 100,
                          minHeight: 8,
                          backgroundColor: cs.outline.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(battColor),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Charging pill + timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCharging
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isCharging
                                      ? Colors.green.withValues(alpha: 0.35)
                                      : Colors.orange.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    isCharging
                                        ? Icons.bolt_rounded
                                        : Icons.power_outlined,
                                    size: 13,
                                    color: isCharging
                                        ? Colors.green
                                        : Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  isCharging ? 'Charging' : 'Discharging',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isCharging
                                          ? Colors.green
                                          : Colors.orange),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm:ss').format(DateTime.now()),
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.3)),
                          ),
                        ],
                      ),

                      // ── Separator ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(
                            height: 1,
                            color: cs.outline.withValues(alpha: 0.12)),
                      ),

                      // ── 4 metrics inline ───────────────────────────────
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            _inlineMetric(
                              icon: Icons.bolt,
                              iconColor: Colors.amber[700]!,
                              value: voltage.toStringAsFixed(1),
                              unit: 'V',
                              label: 'Voltage',
                              cs: cs,
                            ),
                            _metricVDivider(cs),
                            _inlineMetric(
                              icon: Icons.electric_bolt,
                              iconColor: Colors.blue,
                              value: current.toStringAsFixed(1),
                              unit: 'A',
                              label: 'Current',
                              cs: cs,
                            ),
                            _metricVDivider(cs),
                            _inlineMetric(
                              icon: Icons.power,
                              iconColor: isCharging
                                  ? const Color(0xFF2E7D32)
                                  : Colors.orange,
                              value: power.abs().toStringAsFixed(1),
                              unit: 'W',
                              label: 'Power',
                              cs: cs,
                            ),
                            _metricVDivider(cs),
                            _inlineMetric(
                              icon: Icons.thermostat,
                              iconColor: _tempColor(temp),
                              value: temp.toStringAsFixed(1),
                              unit: '°C',
                              label: 'Temp',
                              cs: cs,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Power flow card (kept separate — it earns its space) ───────
          _buildPowerFlowCard(voltage, current, power, isCharging, cs),
        ],
      ),
    );
  }

  Widget _inlineMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
    required ColorScheme cs,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }

  Widget _metricVDivider(ColorScheme cs) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: cs.onSurface.withValues(alpha: 0.08),
      );

  // ── Power flow visualisation ───────────────────────────────────────────────
  Widget _buildPowerFlowCard(double voltage, double current,
      double power, bool isCharging, ColorScheme cs) {
    final flowColor =
        isCharging ? const Color(0xFF2E7D32) : Colors.orange;

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.electric_bolt,
                    size: 16, color: flowColor),
                const SizedBox(width: 6),
                Text('Power Flow',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Source
                _flowNode(
                  icon: isCharging
                      ? Icons.ev_station
                      : Icons.battery_full,
                  label: isCharging ? 'Charger' : 'Battery',
                  color: flowColor,
                  cs: cs,
                ),

                // Animated flow arrow
                Expanded(
                  child: Column(
                    children: [
                      // Power value above arrow
                      Text(
                        '${power.abs().toStringAsFixed(0)} W',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: flowColor),
                      ),
                      const SizedBox(height: 4),
                      // Arrow
                      Row(
                        children: List.generate(
                          5,
                          (i) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 1),
                              height: 3,
                              decoration: BoxDecoration(
                                color: flowColor.withValues(
                                    alpha: (i + 1) / 5),
                                borderRadius:
                                    BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${voltage.toStringAsFixed(1)}V · ${current.toStringAsFixed(1)}A',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface
                                .withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),

                // Destination
                _flowNode(
                  icon: isCharging
                      ? Icons.battery_charging_full
                      : Icons.electric_car,
                  label: isCharging ? 'Battery' : 'Motor',
                  color: flowColor,
                  cs: cs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowNode({
    required IconData icon,
    required String label,
    required Color color,
    required ColorScheme cs,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.55))),
      ],
    );
  }



  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        _bluetoothProvider = bluetoothProvider;

        final Map<String, dynamic> data =
            bluetoothProvider.deviceData.isEmpty
                ? {
                    'profile': '', 'brand': '', 'model': '',
                    'bl': 0.0, 'v': 0.0, 'I': 0.0, 'T': 0.0,
                    'P': 0.0, 'range': 0.0,
                  }
                : bluetoothProvider.deviceData;
        final isConnected = bluetoothProvider.isConnected;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              await _fetchUserProfile();
              if (isConnected) {
                try {
                  await bluetoothProvider.attemptAutoReconnect();
                } catch (e) {
                  debugPrint('Refresh error: $e');
                }
              }
            },
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    if (isConnected)
                      _buildConnectedDashboard(data)
                    else
                      _buildDisconnectedState(),
                    const SizedBox(height: 28),
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