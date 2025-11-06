import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothProvider with ChangeNotifier {
  // Device data storage with profile information
  Map<String, dynamic> deviceData = {
    'profile': '', 'brand': '', 'model': '',
    'bl': 0.0, 'v': 0.0, 'I': 0.0, 'T': 0.0, 'P': 0.0, 'range': 0.0
  };

  // Connection state
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? _lastConnectedDevice;
  List<BluetoothService> _services = [];
  String _receivedData = '';
  final Map<String, StreamSubscription<List<int>>> _dataSubscriptions = {};
  bool _isScanning = false;
  List<BluetoothDevice> _devices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  String? _errorMessage;
  bool _isConnected = false;
  DateTime? _lastDisconnectedTime;
  bool _userRequestedDisconnect = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  
  // Auto-connection features
  bool _autoConnectionEnabled = true;
  Timer? _autoReconnectTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  static const Duration _reconnectInterval = Duration(seconds: 10);
  
  // Data streaming detection
  bool _isDataStreaming = false;
  Timer? _dataStreamingTimer;
  DateTime? _lastDataUpdate;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothDevice? get lastConnectedDevice => _lastConnectedDevice;
  List<BluetoothService> get services => _services;
  String get receivedData => _receivedData;
  bool get isScanning => _isScanning;
  List<BluetoothDevice> get devices => _devices;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _isConnected;
  bool get isDataStreaming => _isDataStreaming;
  DateTime? get lastDisconnectedTime => _lastDisconnectedTime;
  bool get autoConnectionEnabled => _autoConnectionEnabled;
  String get vehicleName => deviceData['brand'] != '' 
      ? '${deviceData['brand']} ${deviceData['model']}' 
      : 'No Vehicle Connected';

  Future<void> initialize() async {
    await _loadLastConnectedDevice();
    
    if (await FlutterBluePlus.isSupported) {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on && _autoConnectionEnabled) {
          _scheduleAutoReconnect();
        }
      });
    }
    
    _startDataStreamingMonitor();
  }

  void _startDataStreamingMonitor() {
    _dataStreamingTimer?.cancel();
    _dataStreamingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_lastDataUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastDataUpdate!);
        final wasStreaming = _isDataStreaming;
        _isDataStreaming = timeSinceLastUpdate.inSeconds < 5;
        
        if (wasStreaming != _isDataStreaming) {
          notifyListeners();
        }
      }
    });
  }

  Future<void> _loadLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_connected_device_id');
      final deviceName = prefs.getString('last_connected_device_name');
      
      if (deviceId != null && deviceName != null) {
        // Create a reference to the last connected device
        // This will be used for comparison during scanning
        debugPrint('Loaded last connected device: $deviceName ($deviceId)');
      }
    } catch (e) {
      debugPrint('Failed to load last connected device: $e');
    }
  }

  Future<void> _saveLastConnectedDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_connected_device_id', device.remoteId.toString());
      await prefs.setString('last_connected_device_name', device.platformName);
      debugPrint('Saved last connected device: ${device.platformName}');
    } catch (e) {
      debugPrint('Failed to save last connected device: $e');
    }
  }

  void setAutoConnectionEnabled(bool enabled) {
    _autoConnectionEnabled = enabled;
    if (!enabled) {
      _autoReconnectTimer?.cancel();
      _reconnectionAttempts = 0;
    }
    notifyListeners();
  }

  void _scheduleAutoReconnect() {
    if (!_autoConnectionEnabled || _userRequestedDisconnect || _isConnected) return;
    
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer(_reconnectInterval, () {
      if (_reconnectionAttempts < _maxReconnectionAttempts) {
        attemptAutoReconnect();
      } else {
        debugPrint('Max reconnection attempts reached');
        _reconnectionAttempts = 0;
      }
    });
  }

  Future<void> attemptAutoReconnect() async {
    if (_userRequestedDisconnect || _isConnected || !_autoConnectionEnabled) return;
    
    if (_lastConnectedDevice == null) {
      // Try to find a previously connected device by starting a scan
      await startAutomaticScan();
      return;
    }
    
    try {
      _reconnectionAttempts++;
      debugPrint('Auto-reconnection attempt $_reconnectionAttempts to ${_lastConnectedDevice!.platformName}');
      
      await _lastConnectedDevice!.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      
      if (_lastConnectedDevice!.isConnected) {
        try {
          await _lastConnectedDevice!.requestMtu(512);
        } catch (e) {
          debugPrint('MTU request failed: $e');
        }
        
        await _setupConnection(_lastConnectedDevice!);
        _reconnectionAttempts = 0;
        debugPrint('Auto-reconnection successful!');
      }
    } catch (e) {
      debugPrint('Auto-reconnection attempt $_reconnectionAttempts failed: $e');
      if (_reconnectionAttempts < _maxReconnectionAttempts) {
        _scheduleAutoReconnect();
      } else {
        _reconnectionAttempts = 0;
        debugPrint('Auto-reconnection failed after $_maxReconnectionAttempts attempts');
      }
    }
  }

  Future<void> startAutomaticScan() async {
    try {
      await startScan();
      
      // Wait for scan results and check for previously connected device
      await Future.delayed(const Duration(seconds: 5));
      
      await _checkForPreviousDevice();
    } catch (e) {
      debugPrint('Automatic scan failed: $e');
    }
  }

  Future<void> _checkForPreviousDevice() async {
    if (_devices.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDeviceId = prefs.getString('last_connected_device_id');
      
      if (lastDeviceId != null) {
        final previousDevice = _devices.firstWhere(
          (device) => device.remoteId.toString() == lastDeviceId,
          orElse: () => BluetoothDevice.fromId(lastDeviceId), // This will create an invalid device if not found
        );
        
        // Check if the device was actually found in scan results
        final isDeviceFound = _devices.any((device) => device.remoteId.toString() == lastDeviceId);
        
        if (isDeviceFound && _autoConnectionEnabled) {
          debugPrint('Found previously connected device, attempting auto-connection...');
          await connect(previousDevice);
        }
      }
    } catch (e) {
      debugPrint('Error checking for previous device: $e');
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      _errorMessage = null;
      _userRequestedDisconnect = false;
      _reconnectionAttempts = 0;
      
      // Cancel any pending auto-reconnect attempts
      _autoReconnectTimer?.cancel();
      
      _connectedDevice = device;
      _lastConnectedDevice = device;
      
      await _saveLastConnectedDevice(device);
      await _setupConnection(device);
      
      debugPrint('Successfully connected to ${device.platformName}');
    } catch (e) {
      _errorMessage = 'Connection failed: ${e.toString()}';
      _cleanupConnection();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _setupConnection(BluetoothDevice device) async {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      _isConnected = state == BluetoothConnectionState.connected;
      
      if (!_isConnected) {
        _lastDisconnectedTime = DateTime.now();
        _cleanupConnection();
        
        if (!_userRequestedDisconnect && _autoConnectionEnabled) {
          _scheduleAutoReconnect();
        }
      }
      notifyListeners();
    });

    await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    
    try {
      await device.requestMtu(512);
    } catch (e) {
      debugPrint('MTU request failed: $e');
    }

    _services = await device.discoverServices();

    // Setup data subscriptions
    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          try {
            await characteristic.setNotifyValue(true);
            _dataSubscriptions[characteristic.uuid.toString()] =
                characteristic.onValueReceived.listen((value) {
              final stringData = utf8.decode(value);
              _receivedData = stringData;
              updateDeviceData(stringData);
            });
          } catch (e) {
            debugPrint('Failed to setup notification for ${characteristic.uuid}: $e');
          }
        }
      }
    }
    
    _isConnected = true;
    _errorMessage = null;
    notifyListeners();
  }

  void updateDeviceData(String jsonData) {
    try {
      final parsed = jsonDecode(jsonData);
      deviceData = {
        'profile': parsed['profile'] ?? '',
        'brand': parsed['brand'] ?? '',
        'model': parsed['model'] ?? '',
        'v': parsed['V']?.toDouble() ?? 0.0,
        'I': parsed['I']?.toDouble() ?? 0.0,
        'bl': parsed['SOC']?.toDouble() ?? 0.0,
        'T': parsed['T']?.toDouble() ?? 0.0,
        'P': parsed['P']?.toDouble() ?? 0.0,
        'range': parsed['Range']?.toDouble() ?? 0.0,
      };
      
      _lastDataUpdate = DateTime.now();
      _isDataStreaming = true;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing BLE data: $e');
      // Try to parse as simple key-value pairs if JSON parsing fails
      _tryParseSimpleData(jsonData);
    }
  }

  void _tryParseSimpleData(String data) {
    try {
      // If it's not JSON, try to extract basic values
      final lines = data.split('\n');
      for (String line in lines) {
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length == 2) {
            final key = parts[0].trim().toLowerCase();
            final value = parts[1].trim();
            
            switch (key) {
              case 'soc':
              case 'battery':
                deviceData['bl'] = double.tryParse(value) ?? deviceData['bl'];
                break;
              case 'voltage':
              case 'v':
                deviceData['v'] = double.tryParse(value) ?? deviceData['v'];
                break;
              case 'current':
              case 'i':
                deviceData['I'] = double.tryParse(value) ?? deviceData['I'];
                break;
              case 'power':
              case 'p':
                deviceData['P'] = double.tryParse(value) ?? deviceData['P'];
                break;
              case 'temperature':
              case 'temp':
              case 't':
                deviceData['T'] = double.tryParse(value) ?? deviceData['T'];
                break;
              case 'range':
                deviceData['range'] = double.tryParse(value) ?? deviceData['range'];
                break;
            }
          }
        }
      }
      
      _lastDataUpdate = DateTime.now();
      _isDataStreaming = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing simple data: $e');
    }
  }

  // Force disconnect - more aggressive disconnection
  Future<void> forceDisconnect() async {
    debugPrint('Force disconnect initiated...');
    
    _userRequestedDisconnect = true;
    _lastDisconnectedTime = DateTime.now();
    _autoReconnectTimer?.cancel();
    _reconnectionAttempts = 0;
    
    try {
      // Cancel all timers and subscriptions immediately
      _dataStreamingTimer?.cancel();
      _autoReconnectTimer?.cancel();
      
      // Stop scanning if active
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        _isScanning = false;
      }
      
      // Get list of all connected devices and disconnect them
      final connectedDevices = FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        try {
          if (device.isConnected) {
            debugPrint('Force disconnecting device: ${device.platformName}');
            await device.disconnect();
          }
        } catch (e) {
          debugPrint('Error force disconnecting device ${device.platformName}: $e');
        }
      }
      
      // Wait for disconnections to complete
      await Future.delayed(const Duration(milliseconds: 1000));
      
    } catch (e) {
      debugPrint('Error during force disconnect: $e');
    } finally {
      _cleanupConnection();
      debugPrint('Force disconnect complete');
    }
  }

  Future<void> disconnect() async {
    _userRequestedDisconnect = true;
    _lastDisconnectedTime = DateTime.now();
    _autoReconnectTimer?.cancel();
    _reconnectionAttempts = 0;
    
    debugPrint('User requested disconnect - cleaning up connection...');
    
    try {
      // First, cancel all data subscriptions
      for (var subscription in _dataSubscriptions.values) {
        await subscription.cancel();
      }
      _dataSubscriptions.clear();
      
      // Cancel connection state subscription
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      // Stop notifications on all characteristics
      if (_connectedDevice != null && _services.isNotEmpty) {
        for (var service in _services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.notify) {
              try {
                await characteristic.setNotifyValue(false);
                debugPrint('Disabled notifications for ${characteristic.uuid}');
              } catch (e) {
                debugPrint('Error disabling notifications for ${characteristic.uuid}: $e');
              }
            }
          }
        }
      }
      
      // Disconnect from device
      if (_connectedDevice != null && _connectedDevice!.isConnected) {
        debugPrint('Disconnecting from ${_connectedDevice!.platformName}...');
        await _connectedDevice!.disconnect();
        
        // Wait a moment for disconnection to complete
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    } finally {
      // Always clean up state regardless of errors
      _cleanupConnection();
      debugPrint('Disconnect complete - connection cleaned up');
    }
  }

  void _cleanupConnection() {
    debugPrint('Cleaning up connection state...');
    
    // Cancel connection subscription
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    // Cancel all data subscriptions
    for (var subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();
    
    // Clear device references
    _connectedDevice = null;
    _services.clear();
    
    // Reset connection state
    _isConnected = false;
    _isDataStreaming = false;
    
    // Clear received data
    _receivedData = '';
    
    // Reset device data to default values
    deviceData = {
      'profile': '', 'brand': '', 'model': '',
      'bl': 0.0, 'v': 0.0, 'I': 0.0, 'T': 0.0, 'P': 0.0, 'range': 0.0
    };
    
    debugPrint('Connection cleanup complete');
    notifyListeners();
  }

  Future<void> startScan() async {
    try {
      _errorMessage = null;
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception("Bluetooth not supported on this device");
      }

      await _requestPermissions();

      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      _devices.clear();
      _isScanning = true;
      notifyListeners();

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _devices = results.map((r) => r.device).where((device) {
          // Filter out devices with empty names and duplicates
          return device.platformName.isNotEmpty;
        }).toList();
        
        // Remove duplicates based on device ID
        final uniqueDevices = <String, BluetoothDevice>{};
        for (var device in _devices) {
          uniqueDevices[device.remoteId.toString()] = device;
        }
        _devices = uniqueDevices.values.toList();
        
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Stop scanning automatically after timeout
      Future.delayed(const Duration(seconds: 15), () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      _isScanning = false;
      _errorMessage = 'Scan failed: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      if (statuses[Permission.bluetoothScan]!.isDenied ||
          statuses[Permission.bluetoothConnect]!.isDenied) {
        throw Exception("Bluetooth permissions required");
      }

      if (statuses[Permission.locationWhenInUse]!.isDenied) {
        throw Exception("Location permission required for Bluetooth scanning");
      }
    } on Exception catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void stopScan() {
    _isScanning = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    FlutterBluePlus.stopScan();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Method to check if device should auto-route to dashboard
  bool shouldAutoRouteToDashboard() {
    return _isConnected && _isDataStreaming && 
           (deviceData['brand'] != '' || deviceData['v'] > 0 || deviceData['bl'] > 0);
  }

  // Method to reset user disconnect flag (useful when user manually navigates to BLE page)
  void resetUserDisconnectFlag() {
    _userRequestedDisconnect = false;
  }

  Future<Position?> getCurrentPosition() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('Failed to get current position: $e');
        return null;
      }
    }
    return null;
  }

  // Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'isDataStreaming': _isDataStreaming,
      'reconnectionAttempts': _reconnectionAttempts,
      'lastDisconnectedTime': _lastDisconnectedTime,
      'autoConnectionEnabled': _autoConnectionEnabled,
      'connectedDeviceName': _connectedDevice?.platformName ?? 'None',
      'lastDataUpdate': _lastDataUpdate,
    };
  }

  @override
  void dispose() {
    _autoReconnectTimer?.cancel();
    _dataStreamingTimer?.cancel();
    disconnect();
    stopScan();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }
}