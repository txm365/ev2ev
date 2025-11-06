// lib/providers/map_route_provider.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapRouteProvider extends ChangeNotifier {
  LatLng? _buyerLocation;
  LatLng? _sellerLocation;
  String? _sellerName;
  String? _buyerName;
  bool _hasActiveRoute = false;

  LatLng? get buyerLocation => _buyerLocation;
  LatLng? get sellerLocation => _sellerLocation;
  String? get sellerName => _sellerName;
  String? get buyerName => _buyerName;
  bool get hasActiveRoute => _hasActiveRoute;

  void setRoute({
    required double buyerLat,
    required double buyerLng,
    required double sellerLat,
    required double sellerLng,
    String? sellerName,
    String? buyerName,
  }) {
    _buyerLocation = LatLng(buyerLat, buyerLng);
    _sellerLocation = LatLng(sellerLat, sellerLng);
    _sellerName = sellerName;
    _buyerName = buyerName;
    _hasActiveRoute = true;
    notifyListeners();
  }

  void clearRoute() {
    _buyerLocation = null;
    _sellerLocation = null;
    _sellerName = null;
    _buyerName = null;
    _hasActiveRoute = false;
    notifyListeners();
  }
}