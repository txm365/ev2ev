import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

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

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothService> get services => _services;
  String get receivedData => _receivedData;
  bool get isScanning => _isScanning;
  List<BluetoothDevice> get devices => _devices;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _isConnected;
  DateTime? get lastDisconnectedTime => _lastDisconnectedTime;
  String get vehicleName => deviceData['brand'] != '' 
      ? '${deviceData['brand']} ${deviceData['model']}' 
      : 'No Vehicle Connected';

  Future<void> initialize() async {
    if (await FlutterBluePlus.isSupported) {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          attemptAutoReconnect();
        }
      });
    }
  }

  Future<void> attemptAutoReconnect() async {
    if (_userRequestedDisconnect || _lastConnectedDevice == null) return;
    
    try {
      debugPrint('Attempting auto-reconnect to ${_lastConnectedDevice!.platformName}');
      await _lastConnectedDevice!.connect(autoConnect: false);
      
      if (_lastConnectedDevice!.isConnected) {
        try {
          await _lastConnectedDevice!.requestMtu(512);
        } catch (e) {
          debugPrint('MTU request failed: $e');
        }
        await connect(_lastConnectedDevice!);
      }
    } catch (e) {
      debugPrint('Auto-reconnect failed: $e');
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      _connectedDevice = device;
      _lastConnectedDevice = device;
      _userRequestedDisconnect = false;
      
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        _isConnected = state == BluetoothConnectionState.connected;
        if (!_isConnected) {
          _lastDisconnectedTime = DateTime.now();
          _cleanupConnection();
          if (!_userRequestedDisconnect) {
            attemptAutoReconnect();
          }
        }
        notifyListeners();
      });

      await device.connect(autoConnect: false);
      
      try {
        await device.requestMtu(512);
      } catch (e) {
        debugPrint('MTU request failed: $e');
      }

      _services = await device.discoverServices();

      for (var service in _services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _dataSubscriptions[characteristic.uuid.toString()] =
                characteristic.onValueReceived.listen((value) {
              final stringData = utf8.decode(value);
              updateDeviceData(stringData);
            });
          }
        }
      }
      
      _isConnected = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Connection failed: ${e.toString()}';
      _cleanupConnection();
      notifyListeners();
      rethrow;
    }
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing BLE data: $e');
    }
  }

  Future<void> disconnect() async {
    _userRequestedDisconnect = true;
    _lastDisconnectedTime = DateTime.now();
    await _connectedDevice?.disconnect();
    _cleanupConnection();
  }

  void _cleanupConnection() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDevice = null;
    _services.clear();
    _isConnected = false;
    for (var subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();
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
        _devices = results.map((r) => r.device).toList();
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency
      );
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

  Future<Position?> getCurrentPosition() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        return await Geolocator.getCurrentPosition();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  void dispose() {
    disconnect();
    stopScan();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }
}