// lib/screens/bluetooth_scan_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_provider.dart' as bt;

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  bool _hasAutoConnected = false;
  bool _showConnectionProgress = false;
  String _connectionStatus = '';

  // ── Safe setState — no-ops if the widget has already been disposed ─────────
  // Every async method below must use this instead of calling setState directly.
  // Without this guard, any setState after an await gap on a popped page throws:
  //   "setState() called after dispose()"
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutomaticProcess();
    });
  }

  // ── Auto-scan + connect flow ───────────────────────────────────────────────

  Future<void> _startAutomaticProcess() async {
    if (!mounted) return;
    final provider = Provider.of<bt.BluetoothProvider>(context, listen: false);

    _safeSetState(() {
      _connectionStatus = 'Initializing Bluetooth...';
      _showConnectionProgress = true;
    });

    try {
      _safeSetState(() => _connectionStatus = 'Scanning for devices...');
      await provider.startScan();

      // Give devices 3 s to appear in scan results
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      await _attemptAutoConnection(provider);
    } catch (e) {
      _safeSetState(() {
        _connectionStatus = 'Error: ${e.toString()}';
        _showConnectionProgress = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-scan failed: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _attemptAutoConnection(bt.BluetoothProvider provider) async {
    if (!mounted || _hasAutoConnected) return;

    final lastConnectedDevice = provider.lastConnectedDevice;
    final availableDevices = provider.devices;

    if (lastConnectedDevice != null && availableDevices.isNotEmpty) {
      BluetoothDevice? previousDevice;
      try {
        previousDevice = availableDevices.firstWhere(
          (d) => d.remoteId == lastConnectedDevice.remoteId,
        );
      } catch (_) {
        previousDevice = null;
      }

      if (previousDevice != null) {
        _safeSetState(() => _connectionStatus =
            'Connecting to ${previousDevice?.platformName ?? "device"}...');

        try {
          await provider.connect(previousDevice);
          if (!mounted) return;

          if (provider.isConnected) {
            _hasAutoConnected = true;
            _safeSetState(() => _connectionStatus = 'Connected successfully!');
            await _waitForDataStreaming(provider);
          }
        } catch (e) {
          _safeSetState(() =>
              _connectionStatus = 'Auto-connection failed: ${e.toString()}');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    if (!mounted) return;

    if (!_hasAutoConnected) {
      _safeSetState(() {
        _showConnectionProgress = false;
        _connectionStatus = '';
      });
    }
  }

  Future<void> _waitForDataStreaming(bt.BluetoothProvider provider) async {
    const maxAttempts = 10; // 10 × 500 ms = 5 s max wait
    for (var i = 0; i < maxAttempts; i++) {
      if (!mounted || !provider.isConnected) return;

      final data = provider.deviceData;
      final hasData = (data['brand']?.toString() ?? '').isNotEmpty ||
          (data['v'] as double? ?? 0.0) > 0 ||
          (data['bl'] as double? ?? 0.0) > 0;

      if (hasData) {
        _safeSetState(() => _connectionStatus = 'Data streaming started!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Connected but no data yet — still show dashboard
    if (!mounted) return;
    _safeSetState(() => _connectionStatus = 'Connected — waiting for data...');
    await Future.delayed(const Duration(seconds: 2));
    _safeSetState(() => _showConnectionProgress = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          Consumer<bt.BluetoothProvider>(
            builder: (context, provider, _) {
              if (provider.isScanning) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                onPressed: provider.startScan,
                icon: const Icon(Icons.refresh),
                tooltip: 'Rescan',
              );
            },
          ),
        ],
      ),
      body: Consumer<bt.BluetoothProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              if (_showConnectionProgress || provider.isConnected)
                _buildStatusCard(provider),
              if (provider.errorMessage != null)
                _buildErrorCard(provider),
              if (provider.connectedDevice != null && !_showConnectionProgress)
                _ConnectedView(provider: provider),
              if (provider.connectedDevice == null || _showConnectionProgress)
                Expanded(child: _ScanView(provider: provider)),
            ],
          );
        },
      ),
    );
  }

  // ── Status / error cards ───────────────────────────────────────────────────

  Widget _buildStatusCard(bt.BluetoothProvider provider) {
    final isConnected = provider.isConnected;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.blue.shade50,
        border: Border.all(
          color: isConnected ? Colors.green : Colors.blue,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_showConnectionProgress) ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
          ] else ...[
            Icon(
              isConnected ? Icons.check_circle : Icons.bluetooth_searching,
              color: isConnected ? Colors.green : Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectionStatus.isEmpty
                      ? (isConnected ? 'Connected' : 'Scanning...')
                      : _connectionStatus,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
                if (provider.connectedDevice != null)
                  Text(
                    provider.connectedDevice!.platformName,
                    style: TextStyle(
                      fontSize: 14,
                      color: isConnected ? Colors.green.shade600 : Colors.blue.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (isConnected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dashboard'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: provider.disconnect,
                  icon: const Icon(Icons.close),
                  tooltip: 'Disconnect',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bt.BluetoothProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connected device view ──────────────────────────────────────────────────────

class _ConnectedView extends StatelessWidget {
  final bt.BluetoothProvider provider;
  const _ConnectedView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Connected to:',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(
                        provider.connectedDevice!.platformName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 1, child: _ServiceList(services: provider.services)),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _DataView(
                      data: provider.receivedData,
                      deviceData: provider.deviceData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Service list ───────────────────────────────────────────────────────────────

class _ServiceList extends StatelessWidget {
  final List<BluetoothService> services;
  const _ServiceList({required this.services});

  String _getProperties(BluetoothCharacteristic c) {
    final props = <String>[];
    if (c.properties.read) props.add('Read');
    if (c.properties.write) props.add('Write');
    if (c.properties.notify) props.add('Notify');
    return props.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: services.length,
              itemBuilder: (context, index) => Card(
                child: ExpansionTile(
                  title: Text('Service ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    services[index].uuid.toString().substring(0, 8),
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: services[index]
                      .characteristics
                      .map((c) => ListTile(
                            dense: true,
                            title: const Text('Characteristic',
                                style: TextStyle(fontSize: 14)),
                            subtitle: Text(_getProperties(c)),
                            trailing: c.properties.notify
                                ? const Icon(Icons.notifications_active,
                                    color: Colors.green, size: 16)
                                : null,
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data view ──────────────────────────────────────────────────────────────────

class _DataView extends StatelessWidget {
  final String data;
  final Map<String, dynamic> deviceData;
  const _DataView({required this.data, required this.deviceData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Device Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (deviceData['brand']?.toString().isNotEmpty == true)
                    _row('Vehicle',
                        '${deviceData['brand']} ${deviceData['model']}'),
                  _row('Voltage', '${deviceData['v']?.toStringAsFixed(1) ?? '0.0'} V'),
                  _row('Current', '${deviceData['I']?.toStringAsFixed(1) ?? '0.0'} A'),
                  _row('Power', '${deviceData['P']?.toStringAsFixed(1) ?? '0.0'} W'),
                  _row('Battery', '${deviceData['bl']?.toStringAsFixed(1) ?? '0.0'}%'),
                  _row('Temperature', '${deviceData['T']?.toStringAsFixed(1) ?? '0.0'}°C'),
                  const Divider(height: 24),
                  const Text('Raw data:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(data, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
            ),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}

// ── Scan view ──────────────────────────────────────────────────────────────────

class _ScanView extends StatelessWidget {
  final bt.BluetoothProvider provider;
  const _ScanView({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching,
                size: 64,
                color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              provider.isScanning
                  ? 'Searching for devices...'
                  : 'No devices found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              provider.isScanning
                  ? 'Make sure your device is discoverable'
                  : 'Tap the refresh icon to scan again',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.devices.length,
      itemBuilder: (context, index) {
        final device = provider.devices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.bluetooth, color: Colors.blue),
            title: Text(device.platformName.isEmpty
                ? 'Unknown Device'
                : device.platformName),
            subtitle: Text(device.remoteId.toString()),
            trailing: ElevatedButton(
              onPressed: () => provider.connect(device),
              child: const Text('Connect'),
            ),
          ),
        );
      },
    );
  }
}