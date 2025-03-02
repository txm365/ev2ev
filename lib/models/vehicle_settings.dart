import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleSettings with ChangeNotifier {
  String _name = '';
  String _model = '';
  String _type = '';

  String get name => _name;
  String get model => _model;
  String get type => _type;

  VehicleSettings() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('vehicle_name') ?? '';
    _model = prefs.getString('vehicle_model') ?? '';
    _type = prefs.getString('vehicle_type') ?? 'car';
    notifyListeners();
  }

  Future<void> saveSettings({
    required String name,
    required String model,
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicle_name', name);
    await prefs.setString('vehicle_model', model);
    await prefs.setString('vehicle_type', type);
    
    _name = name;
    _model = model;
    _type = type;
    notifyListeners();
  }
}