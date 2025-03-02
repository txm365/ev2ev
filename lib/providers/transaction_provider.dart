import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TransactionProvider with ChangeNotifier {
  LatLng? _currentPosition;
  LatLng? _selectedPoint;
  List<LatLng> _routePoints = [];
  double? _selectedDistance;

  LatLng? get currentPosition => _currentPosition;
  LatLng? get selectedPoint => _selectedPoint;
  List<LatLng> get routePoints => _routePoints;
  double? get selectedDistance => _selectedDistance;

  void updatePosition(LatLng position) {
    _currentPosition = position;
    notifyListeners();
  }

  void setRoute(LatLng end, List<LatLng> points, double distance) {
    _selectedPoint = end;
    _routePoints = points;
    _selectedDistance = distance;
    notifyListeners();
  }

  void clearRoute() {
    _selectedPoint = null;
    _routePoints = [];
    _selectedDistance = null;
    notifyListeners();
  }
}