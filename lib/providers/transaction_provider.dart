import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TransactionProvider with ChangeNotifier {
  LatLng? _currentPosition;
  LatLng? _selectedPoint;
  List<LatLng> _routePoints = [];
  double? _selectedDistance;
  String? _transactionType;
  bool _isNavigating = false;

  LatLng? get currentPosition => _currentPosition;
  LatLng? get selectedPoint => _selectedPoint;
  List<LatLng> get routePoints => _routePoints;
  double? get selectedDistance => _selectedDistance;
  String? get transactionType => _transactionType;
  bool get isNavigating => _isNavigating;

  void updatePosition(LatLng position) {
    _currentPosition = position;
    notifyListeners();
  }

  double calculateEnergyRequired(double efficiency) {
    if (_selectedDistance == null) return 0;
    return _selectedDistance! / efficiency; // kWh
  }

  void setRoute(LatLng end, List<LatLng> points, double distance, {String? type}) {
    _selectedPoint = end;
    _routePoints = points;
    _selectedDistance = distance;
    _transactionType = type;
    _isNavigating = type != null;
    notifyListeners();
  }

  void clearRoute() {
    _selectedPoint = null;
    _routePoints = [];
    _selectedDistance = null;
    _transactionType = null;
    _isNavigating = false;
    notifyListeners();
  }

  void updateRoutePoints(List<LatLng> newPoints) {
    _routePoints = newPoints;
    notifyListeners();
  }
}