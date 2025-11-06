// lib/providers/map_provider.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapProvider with ChangeNotifier {
  LatLng? _currentPosition;
  LatLng? _selectedPoint;
  List<LatLng> _routePoints = [];
  double? _selectedDistance;
  String? _routeType;
  bool _isNavigating = false;
  String? _destinationName;

  LatLng? get currentPosition => _currentPosition;
  LatLng? get selectedPoint => _selectedPoint;
  List<LatLng> get routePoints => _routePoints;
  double? get selectedDistance => _selectedDistance;
  String? get routeType => _routeType;
  bool get isNavigating => _isNavigating;
  String? get destinationName => _destinationName;

  void updatePosition(LatLng position) {
    _currentPosition = position;
    notifyListeners();
  }

  double calculateEnergyRequired(double efficiency) {
    if (_selectedDistance == null) return 0;
    return _selectedDistance! / efficiency; // kWh
  }

  void setRoute(LatLng end, List<LatLng> points, double distance, {String? type, String? name}) {
    _selectedPoint = end;
    _routePoints = points;
    _selectedDistance = distance;
    _routeType = type;
    _isNavigating = type != null;
    _destinationName = name;
    notifyListeners();
  }

  /// Set route from external coordinates (e.g., from accepted energy request)
  void setRouteFromCoordinates({
    required LatLng start,
    required LatLng end,
    String? destinationName,
  }) {
    _currentPosition = start;
    _selectedPoint = end;
    _destinationName = destinationName;
    // Route points will be calculated by the map page
    _routePoints = [];
    _selectedDistance = null;
    _routeType = 'energy_trade';
    _isNavigating = false;
    notifyListeners();
  }

  void clearRoute() {
    _selectedPoint = null;
    _routePoints = [];
    _selectedDistance = null;
    _routeType = null;
    _isNavigating = false;
    _destinationName = null;
    notifyListeners();
  }

  void updateRoutePoints(List<LatLng> newPoints) {
    _routePoints = newPoints;
    notifyListeners();
  }

  void updateRouteDistance(double distance) {
    _selectedDistance = distance;
    notifyListeners();
  }
}