// lib/providers/bluetooth_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothProvider with ChangeNotifier {
  // Device data storage
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
  bool _isConnecting = false; // true while connection is being established
  DateTime? _lastDisconnectedTime;
  bool _userRequestedDisconnect = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  // Auto-connection
  final bool _autoConnectionEnabled = true;
  Timer? _autoReconnectTimer;
  int _reconnectionAttempts = 0;
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
  bool get isConnecting => _isConnecting;
  bool get isDataStreaming => _isDataStreaming;
  DateTime? get lastDisconnectedTime => _lastDisconnectedTime;
  bool get autoConnectionEnabled => _autoConnectionEnabled;
  String get vehicleName => deviceData['brand'] != ''
      ? '${deviceData['brand']} ${deviceData['model']}'
      : 'No Vehicle Connected';

  // ─────────────────────────────────────────────────────────────────────────
  // INIT / MONITORING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _loadLastConnectedDevice();

    if (await FlutterBluePlus.isSupported) {
      _adapterStateSubscription =
          FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on && _autoConnectionEnabled) {
          _scheduleAutoReconnect();
        }
      });
    }

    _startDataStreamingMonitor();
  }

  void _startDataStreamingMonitor() {
    _dataStreamingTimer?.cancel();
    _dataStreamingTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_lastDataUpdate != null) {
        final timeSinceLastUpdate =
            DateTime.now().difference(_lastDataUpdate!);
        final wasStreaming = _isDataStreaming;
        _isDataStreaming = timeSinceLastUpdate.inSeconds < 5;

        if (wasStreaming != _isDataStreaming) {
          notifyListeners();
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERSISTENCE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_connected_device_id');
      final deviceName = prefs.getString('last_connected_device_name');

      if (deviceId != null && deviceName != null) {
        debugPrint('Loaded last connected device: $deviceName ($deviceId)');
      }
    } catch (e) {
      debugPrint('Failed to load last connected device: $e');
    }
  }

  Future<void> _saveLastConnectedDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_connected_device_id', device.remoteId.toString());
      await prefs.setString(
          'last_connected_device_name', device.platformName);
      debugPrint('Saved last connected device: ${device.platformName}');
    } catch (e) {
      debugPrint('Failed to save last connected device: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCANNING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    try {
      _errorMessage = null;
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth not supported on this device');
      }

      await _requestPermissions();

      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      _devices.clear();
      _isScanning = true;
      notifyListeners();

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _devices = results
            .map((r) => r.device)
            .where((device) => device.platformName.isNotEmpty)
            .toList();

        // Deduplicate by remote ID
        final unique = <String, BluetoothDevice>{};
        for (var d in _devices) {
          unique[d.remoteId.toString()] = d;
        }
        _devices = unique.values.toList();
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      Future.delayed(const Duration(seconds: 15), () {
        if (_isScanning) stopScan();
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
        throw Exception('Bluetooth permissions required');
      }
      if (statuses[Permission.locationWhenInUse]!.isDenied) {
        throw Exception('Location permission required for Bluetooth scanning');
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

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECTION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> connect(BluetoothDevice device) async {
    try {
      _errorMessage = null;
      _userRequestedDisconnect = false;
      _reconnectionAttempts = 0;
      _isConnecting = true;
      _autoReconnectTimer?.cancel();

      _connectedDevice = device;
      _lastConnectedDevice = device;

      await _saveLastConnectedDevice(device);
      await _setupConnection(device);

      debugPrint('Successfully connected to ${device.platformName}');
    } catch (e) {
      _errorMessage = 'Connection failed: ${e.toString()}';
      _isConnecting = false;
      _cleanupConnection();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _setupConnection(BluetoothDevice device) async {
    // Bail if this device is already fully connected
    if (_isConnected && _connectedDevice?.remoteId == device.remoteId) {
      debugPrint('⚠️ _setupConnection: already connected to ${device.platformName}, skipping');
      _isConnecting = false;
      return;
    }
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

    await device.connect(
        autoConnect: false, timeout: const Duration(seconds: 15));

    try {
      await device.requestMtu(512);
    } catch (e) {
      debugPrint('MTU request failed: $e');
    }

    _services = await device.discoverServices();

    // Subscribe to notifiable characteristics
    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          try {
            await characteristic.setNotifyValue(true);

            _dataSubscriptions[characteristic.uuid.toString()] =
                characteristic.onValueReceived.listen((value) {
              // Defer processing off the BLE platform callback thread.
              // Calling notifyListeners() synchronously on a BLE callback
              // can cause native crashes if Flutter is mid-frame.
              Future.microtask(() {
                try {
                  // ── Intercept known raw-byte GATT characteristics ───────
                  final uuidShort = characteristic.uuid
                      .toString()
                      .substring(4, 8)
                      .toLowerCase();

                  if (_handleRawGattCharacteristic(uuidShort, value)) return;

                  // ── Everything else: treat as UTF-8 / JSON ──────────────
                  // allowMalformed: true prevents FormatException on bad bytes
                  final stringData =
                      utf8.decode(value, allowMalformed: true);
                  _receivedData = stringData;
                  updateDeviceData(stringData);
                } catch (e) {
                  debugPrint('BLE data processing error: $e');
                }
              });
            });
          } catch (e) {
            debugPrint(
                'Failed to setup notification for ${characteristic.uuid}: $e');
          }
        }
      }
    }

    _isConnected = true;
    _isConnecting = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RAW GATT CHARACTERISTIC HANDLER  ← THE PATCH
  // ─────────────────────────────────────────────────────────────────────────

  /// Handles standard GATT characteristics that send raw bytes, not JSON.
  /// Returns true if handled (caller should skip JSON decode),
  /// false if caller should proceed with UTF-8 / JSON decode.
  bool _handleRawGattCharacteristic(String uuidShort, List<int> value) {
    if (value.isEmpty) return true;
    if (uuidShort.length < 4) return false; // malformed UUID short code

    switch (uuidShort) {
      case '2a19': // Battery Level — single byte 0-100
        final level = value[0].toDouble().clamp(0.0, 100.0);
        deviceData['bl'] = level;
        _lastDataUpdate = DateTime.now();
        _isDataStreaming = true;
        notifyListeners();
        debugPrint('🔋 Battery Level (2A19): ${level.toStringAsFixed(0)}%');
        return true;

      case '2a37': // Heart Rate Measurement — not EV data, suppress
        return true;

      case '2a05': // Service Changed — indication only, no payload
        return true;

      case '2a63': // Cycling Power Measurement — raw binary, suppress
        return true;

      default:
        return false; // unknown — caller tries UTF-8 / JSON
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA PARSING
  // ─────────────────────────────────────────────────────────────────────────

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
      _tryParseSimpleData(jsonData);
    }
  }

  void _tryParseSimpleData(String data) {
    try {
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
                deviceData['bl'] =
                    double.tryParse(value) ?? deviceData['bl'];
                break;
              case 'voltage':
              case 'v':
                deviceData['v'] =
                    double.tryParse(value) ?? deviceData['v'];
                break;
              case 'current':
              case 'i':
                deviceData['I'] =
                    double.tryParse(value) ?? deviceData['I'];
                break;
              case 'power':
              case 'p':
                deviceData['P'] =
                    double.tryParse(value) ?? deviceData['P'];
                break;
              case 'temperature':
              case 'temp':
              case 't':
                deviceData['T'] =
                    double.tryParse(value) ?? deviceData['T'];
                break;
              case 'range':
                deviceData['range'] =
                    double.tryParse(value) ?? deviceData['range'];
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

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECTION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _userRequestedDisconnect = true;
    _lastDisconnectedTime = DateTime.now();
    _autoReconnectTimer?.cancel();
    _dataStreamingTimer?.cancel();
    _dataStreamingTimer = null;
    _reconnectionAttempts = 0;

    debugPrint('🔵 User requested disconnect...');

    try {
      // ── Step 1: Cancel all data subscriptions first ──────────────────────
      for (var subscription in _dataSubscriptions.values) {
        await subscription.cancel();
      }
      _dataSubscriptions.clear();

      // ── Step 2: Disable all notify characteristics ────────────────────────
      // This tells the ESP32 to stop sending notifications before we drop
      // the connection — gives the hardware a clean shutdown signal.
      if (_connectedDevice != null && _services.isNotEmpty) {
        for (var service in _services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.notify) {
              try {
                await characteristic.setNotifyValue(false);
                debugPrint(
                    '🔕 Disabled notify: ${characteristic.uuid}');
              } catch (e) {
                debugPrint(
                    '⚠️ Could not disable notify ${characteristic.uuid}: $e');
              }
            }
          }
        }
      }

      // ── Step 3: Stop any active scan ──────────────────────────────────────
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        _isScanning = false;
      }

      // ── Step 4: Disconnect the primary device and wait for confirmation ───
      // Keep _connectionSubscription alive here so the BLE stack can
      // propagate the disconnected state event to the ESP32 radio layer.
      // Cancelling it before disconnect() leaves the ESP32 thinking it's
      // still connected — it stops advertising and won't show in scans.
      if (_connectedDevice != null && _connectedDevice!.isConnected) {
        debugPrint(
            '🔵 Disconnecting from ${_connectedDevice!.platformName}...');
        await _connectedDevice!.disconnect();

        // Wait for the disconnected state to propagate (up to 3 seconds)
        int waited = 0;
        while (_connectedDevice != null &&
            _connectedDevice!.isConnected &&
            waited < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          waited++;
        }
        debugPrint(
            '🔵 Device disconnected after ${waited * 100}ms');
      }

      // ── Step 5: Safety net — disconnect any other lingering BLE devices ───
      // Catches edge cases where flutter_blue_plus tracks devices separately
      // from our _connectedDevice reference.
      for (final device in FlutterBluePlus.connectedDevices) {
        try {
          if (device.isConnected) {
            debugPrint(
                '🔵 Safety disconnect: ${device.platformName}');
            await device.disconnect();
            await Future.delayed(const Duration(milliseconds: 300));
          }
        } catch (e) {
          debugPrint('⚠️ Safety disconnect error: $e');
        }
      }

      // ── Step 6: Now safe to cancel the connection listener ────────────────
      _connectionSubscription?.cancel();
      _connectionSubscription = null;

    } catch (e) {
      debugPrint('❌ Error during disconnect: $e');
    } finally {
      _cleanupConnection();
      debugPrint('✅ Disconnect complete — device should now be visible in scans');
    }
  }

  Future<void> forceDisconnect() async {
    debugPrint('Force disconnect initiated...');

    _userRequestedDisconnect = true;
    _lastDisconnectedTime = DateTime.now();
    _autoReconnectTimer?.cancel();
    _reconnectionAttempts = 0;

    try {
      _dataStreamingTimer?.cancel();
      _autoReconnectTimer?.cancel();

      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        _isScanning = false;
      }

      for (var device in FlutterBluePlus.connectedDevices) {
        try {
          if (device.isConnected) {
            debugPrint(
                'Force disconnecting device: ${device.platformName}');
            await device.disconnect();
          }
        } catch (e) {
          debugPrint(
              'Error force disconnecting ${device.platformName}: $e');
        }
      }

      await Future.delayed(const Duration(milliseconds: 1000));
    } catch (e) {
      debugPrint('Error during force disconnect: $e');
    } finally {
      _cleanupConnection();
      debugPrint('Force disconnect complete');
    }
  }

  void _cleanupConnection() {
    debugPrint('Cleaning up connection state...');

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    for (var subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();

    // Cancel the streaming timer so it cannot flip _isDataStreaming
    // back to true after disconnect using a stale _lastDataUpdate timestamp.
    _dataStreamingTimer?.cancel();
    _dataStreamingTimer = null;
    _lastDataUpdate = null; // clear timestamp so timer cannot reactivate streaming

    _connectedDevice = null;
    _services.clear();
    _isConnected = false;
    _isConnecting = false;
    _isDataStreaming = false;
    _receivedData = '';

    deviceData = {
      'profile': '', 'brand': '', 'model': '',
      'bl': 0.0, 'v': 0.0, 'I': 0.0, 'T': 0.0, 'P': 0.0, 'range': 0.0
    };

    debugPrint('Connection cleanup complete');
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTO-RECONNECT
  // ─────────────────────────────────────────────────────────────────────────

  void _scheduleAutoReconnect() {
    if (!_autoConnectionEnabled ||
        _userRequestedDisconnect ||
        _isConnected ||
        _isConnecting) {
      return;
    }

    _autoReconnectTimer?.cancel();

    // Exponential backoff: 10s → 20s → 40s → 60s (cap) — keeps trying
    // indefinitely so coming back into range always triggers reconnection,
    // regardless of how long the device was out of range.
    final backoffSeconds = (_reconnectInterval.inSeconds *
            (1 << _reconnectionAttempts.clamp(0, 3)))
        .clamp(10, 60);
    final interval = Duration(seconds: backoffSeconds);

    debugPrint('⏱️ Scheduling reconnect in ${backoffSeconds}s '
        '(attempt ${_reconnectionAttempts + 1})');

    _autoReconnectTimer = Timer(interval, () {
      attemptAutoReconnect();
    });
  }

  Future<void> attemptAutoReconnect() async {
    if (_userRequestedDisconnect ||
        _isConnected ||
        _isConnecting ||
        !_autoConnectionEnabled) {
      return;
    }

    if (_lastConnectedDevice == null) {
      await startAutomaticScan();
      return;
    }

    try {
      _reconnectionAttempts++;
      debugPrint('Auto-reconnect attempt $_reconnectionAttempts to ${_lastConnectedDevice!.platformName}');

      await _lastConnectedDevice!.connect(
          autoConnect: false, timeout: const Duration(seconds: 10));

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
      debugPrint('Auto-reconnect attempt $_reconnectionAttempts failed: $e');
      // Keep scheduling — device may be temporarily out of range.
      // Exponential backoff in _scheduleAutoReconnect prevents flooding.
      _scheduleAutoReconnect();
    }
  }

  Future<void> startAutomaticScan() async {
    try {
      await startScan();
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
        final isDeviceFound = _devices
            .any((d) => d.remoteId.toString() == lastDeviceId);

        if (isDeviceFound && _autoConnectionEnabled) {
          final previousDevice = _devices.firstWhere(
              (d) => d.remoteId.toString() == lastDeviceId);
          debugPrint(
              'Found previously connected device, attempting auto-connection...');
          await connect(previousDevice);
        }
      }
    } catch (e) {
      debugPrint('Error checking for previous device: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────


  void clearError() {
    _errorMessage = null;
    notifyListeners();
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