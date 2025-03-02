import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothProvider with ChangeNotifier {
    Map<String, dynamic> deviceData = {
    'bl': 75.0, 'v': 48.2, 'I': 2.5, 'T': 32.0
  };

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

  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  String _receivedData = '';
  final Map<String, StreamSubscription<List<int>>> _dataSubscriptions = {};
  bool _isScanning = false;
  List<BluetoothDevice> _devices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  String? _errorMessage;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothService> get services => _services;
  String get receivedData => _receivedData;
  bool get isScanning => _isScanning;
  List<BluetoothDevice> get devices => _devices;
  String? get errorMessage => _errorMessage;

  Future<void> connect(BluetoothDevice device) async {
    try {
      _connectedDevice = device;
      await device.connect(autoConnect: false);
      _services = await device.discoverServices();

      for (var service in _services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _dataSubscriptions[characteristic.uuid.toString()] =
                characteristic.onValueReceived.listen(_handleData);
          }
        }
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Connection failed: ${e.toString()}';
      disconnect();
      notifyListeners();
      rethrow;
    }
  }

  void _handleData(List<int> value) {
    _receivedData += utf8.decode(value);
    notifyListeners();
  }

  Future<void> disconnect() async {
    _receivedData = '';
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _services.clear();
    for (var subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();
    _errorMessage = null;
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
    FlutterBluePlus.stopScan();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }
}