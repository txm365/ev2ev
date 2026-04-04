import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_provider.dart' as bt;

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({Key? key}) : super(key: key);

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  bool _hasAutoConnected = false;
  bool _showConnectionProgress = false;
  String _connectionStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutomaticProcess();
    });
  }

  Future<void> _startAutomaticProcess() async {
    final provider = Provider.of<bt.BluetoothProvider>(context, listen: false);
    
    setState(() {
      _connectionStatus = 'Initializing Bluetooth...';
      _showConnectionProgress = true;
    });
    
    try {
      // Start scanning automatically
      setState(() => _connectionStatus = 'Scanning for devices...');
      await provider.startScan();
      
      // Wait a bit for devices to be discovered
      await Future.delayed(const Duration(seconds: 3));
      
      // Check if previously connected device is available
      await _attemptAutoConnection(provider);
      
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: ${e.toString()}';
        _showConnectionProgress = false;
      });
      
      // Show error and fallback to manual mode
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
    if (_hasAutoConnected) return;
    
    // Check if there's a previously connected device that's now available
    final lastConnectedDevice = provider.lastConnectedDevice;
    final availableDevices = provider.devices;
    
    if (lastConnectedDevice != null && availableDevices.isNotEmpty) {
      // Look for the previously connected device in scan results
      BluetoothDevice? previousDevice;
      try {
        previousDevice = availableDevices.firstWhere(
          (device) => device.remoteId == lastConnectedDevice.remoteId,
        );
      } catch (e) {
        // Device not found in current scan
        previousDevice = null;
      }
      
      // If we find the previous device, try to connect automatically
      if (previousDevice != null) {
        setState(() => _connectionStatus = 'Connecting to ${previousDevice?.platformName ?? "device"}...');
        
        try {
          await provider.connect(previousDevice);
          
          if (provider.isConnected) {
            _hasAutoConnected = true;
            setState(() => _connectionStatus = 'Connected successfully!');
            
            // Wait for data streaming to start (check for 2 seconds)
            await _waitForDataStreaming(provider);
          }
        } catch (e) {
          setState(() => _connectionStatus = 'Auto-connection failed: ${e.toString()}');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    // If no auto-connection happened, show available devices
    if (!_hasAutoConnected) {
      setState(() {
        _showConnectionProgress = false;
        _connectionStatus = '';
      });
    }
  }

  Future<void> _waitForDataStreaming(bt.BluetoothProvider provider) async {
    int attempts = 0;
    const maxAttempts = 10; // Wait up to 10 seconds
    
    while (attempts < maxAttempts && provider.isConnected) {
      // Check if we're receiving data (check if any device data has been updated)
      if (provider.deviceData['brand'] != '' || 
          provider.deviceData['v'] > 0 ||
          provider.deviceData['bl'] > 0) {
        
        // Data is streaming, navigate back to dashboard
        setState(() => _connectionStatus = 'Data streaming started!');
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pop(); // Go back to previous screen
          // The main screen should automatically show dashboard (index 0)
        }
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    
    // If we reach here, data isn't streaming yet but device is connected
    setState(() => _connectionStatus = 'Connected - waiting for data...');
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _showConnectionProgress = false);
  }

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
                  padding: EdgeInsets.all(16.0),
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
              // Connection Status Card
              if (_showConnectionProgress || provider.isConnected)
                _buildStatusCard(provider),
              
              // Error Message
              if (provider.errorMessage != null)
                _buildErrorCard(provider),
              
              // Connected Device View
              if (provider.connectedDevice != null && !_showConnectionProgress)
                _ConnectedView(provider: provider),
              
              // Available Devices List
              if (provider.connectedDevice == null || _showConnectionProgress)
                Expanded(child: _ScanView(provider: provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(bt.BluetoothProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.isConnected ? Colors.green.shade50 : Colors.blue.shade50,
        border: Border.all(
          color: provider.isConnected ? Colors.green : Colors.blue,
          width: 1,
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
              provider.isConnected ? Icons.check_circle : Icons.bluetooth_searching,
              color: provider.isConnected ? Colors.green : Colors.blue,
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
                    ? (provider.isConnected ? 'Connected' : 'Scanning...')
                    : _connectionStatus,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: provider.isConnected ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
                if (provider.isConnected && provider.connectedDevice != null)
                  Text(
                    provider.connectedDevice!.platformName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bt.BluetoothProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: provider.clearError,
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class _ScanView extends StatelessWidget {
  final bt.BluetoothProvider provider;

  const _ScanView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scan Control
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.isScanning ? provider.stopScan : provider.startScan,
              icon: Icon(provider.isScanning ? Icons.stop : Icons.search),
              label: Text(provider.isScanning ? 'Stop Scanning' : 'Start Scan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        
        // Devices List
        Expanded(
          child: provider.devices.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.devices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = provider.devices[index];
                    final isLastConnected = provider.lastConnectedDevice?.remoteId == device.remoteId;
                    
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isLastConnected 
                          ? const BorderSide(color: Colors.blue, width: 2)
                          : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Stack(
                          children: [
                            const Icon(Icons.bluetooth, size: 32),
                            if (isLastConnected)
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(
                                  Icons.history,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          device.platformName.isNotEmpty 
                            ? device.platformName 
                            : 'Unknown Device',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.remoteId.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (isLastConnected)
                              const Text(
                                'Previously connected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => provider.connect(device),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLastConnected ? Colors.blue : null,
                            foregroundColor: isLastConnected ? Colors.white : null,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Connect'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            provider.isScanning 
              ? 'Searching for devices...' 
              : 'No devices found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isScanning
              ? 'Make sure your device is discoverable'
              : 'Tap "Start Scan" to search for devices',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedView extends StatelessWidget {
  final bt.BluetoothProvider provider;

  const _ConnectedView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          // Connected Device Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green, width: 1),
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
                      const Text(
                        'Connected to:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        provider.connectedDevice!.platformName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
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
          ),
          
          // Services and Data View
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _ServiceList(services: provider.services),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _DataView(data: provider.receivedData, deviceData: provider.deviceData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<BluetoothService> services;

  const _ServiceList({required this.services});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: services.length,
              itemBuilder: (context, index) => Card(
                child: ExpansionTile(
                  title: Text(
                    'Service ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    services[index].uuid.toString().substring(0, 8),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  children: services[index].characteristics
                      .map((c) => ListTile(
                            dense: true,
                            title: const Text(
                              'Characteristic',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: _getProperties(c),
                            trailing: _getNotificationIcon(c),
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

  Widget _getProperties(BluetoothCharacteristic c) {
    List<String> props = [];
    if (c.properties.read) props.add('Read');
    if (c.properties.write) props.add('Write');
    if (c.properties.notify) props.add('Notify');
    return Text(
      props.join(', '),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _getNotificationIcon(BluetoothCharacteristic c) {
    return c.properties.notify
        ? const Icon(Icons.notifications_active, size: 16, color: Colors.green)
        : const Icon(Icons.notifications_off, size: 16, color: Colors.grey);
  }
}

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
          Row(
            children: [
              const Text(
                'Live Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (deviceData['brand'] != '' || deviceData['v'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Streaming',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Device Information
          if (deviceData['brand'] != '' || deviceData['model'] != '')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Info',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Brand: ${deviceData['brand'] ?? 'N/A'}'),
                    Text('Model: ${deviceData['model'] ?? 'N/A'}'),
                    Text('Profile: ${deviceData['profile'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Real-time Metrics
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Real-time Metrics',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          _buildMetricCard('SOC', '${deviceData['bl']?.toStringAsFixed(1) ?? '0'}%', Colors.blue),
                          _buildMetricCard('Voltage', '${deviceData['v']?.toStringAsFixed(1) ?? '0'}V', Colors.orange),
                          _buildMetricCard('Current', '${deviceData['I']?.toStringAsFixed(1) ?? '0'}A', Colors.green),
                          _buildMetricCard('Power', '${deviceData['P']?.toStringAsFixed(1) ?? '0'}W', Colors.purple),
                          _buildMetricCard('Temp', '${deviceData['T']?.toStringAsFixed(1) ?? '0'}°C', Colors.red),
                          _buildMetricCard('Range', '${deviceData['range']?.toStringAsFixed(0) ?? '0'}km', Colors.teal),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Raw Data (if available)
          if (data.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Raw Data',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color..withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color..withValues(alpha:0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}