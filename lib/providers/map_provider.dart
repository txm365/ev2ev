// lib/providers/map_provider.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/energy_listing.dart';

class MapProvider with ChangeNotifier {
  LatLng? _currentPosition;
  LatLng? _selectedPoint;
  List<LatLng> _routePoints = [];
  double? _selectedDistance;
  String? _routeType;
  bool _isNavigating = false;
  bool _isAcceptedRoute = false; // true = came from an accepted request → show Navigate
  String? _destinationName;

  // ── Seller listings cache ─────────────────────────────────────────────────
  List<EnergyListing> _sellerListings = [];
  DateTime? _listingsCachedAt;

  /// How long before the cache is considered stale and re-fetched
  static const Duration _cacheTtl = Duration(minutes: 5);

  List<EnergyListing> get sellerListings => _sellerListings;

  /// True if cache is empty or older than [_cacheTtl]
  bool get listingsCacheStale {
    if (_sellerListings.isEmpty) return true;
    if (_listingsCachedAt == null) return true;
    return DateTime.now().difference(_listingsCachedAt!) > _cacheTtl;
  }

  /// Called by map_page when it gets fresh listings from MarketplaceProvider.
  /// Only updates cache if the data is actually different (different IDs) or
  /// the cache is stale — avoids unnecessary rebuilds.
  void updateSellerListings(List<EnergyListing> listings) {
    // Check if IDs have changed — if not, no need to notify
    final newIds = listings.map((l) => l.id).toSet();
    final oldIds = _sellerListings.map((l) => l.id).toSet();
    final changed = newIds.length != oldIds.length || !newIds.containsAll(oldIds);

    if (changed || listingsCacheStale) {
      _sellerListings = List.unmodifiable(listings);
      _listingsCachedAt = DateTime.now();
      notifyListeners();
    }
  }

  /// Force-clear the cache (e.g. on logout or manual refresh)
  void clearListingsCache() {
    _sellerListings = [];
    _listingsCachedAt = null;
    notifyListeners();
  }

  // ── Position & routing ────────────────────────────────────────────────────
  LatLng? get currentPosition => _currentPosition;
  LatLng? get selectedPoint => _selectedPoint;
  List<LatLng> get routePoints => _routePoints;
  double? get selectedDistance => _selectedDistance;
  String? get routeType => _routeType;
  bool get isNavigating => _isNavigating;
  bool get isAcceptedRoute => _isAcceptedRoute;
  String? get destinationName => _destinationName;

  void updatePosition(LatLng position) {
    _currentPosition = position;
    notifyListeners();
  }

  double calculateEnergyRequired(double efficiency) {
    if (_selectedDistance == null) return 0;
    return _selectedDistance! / efficiency;
  }

  void setRoute(LatLng end, List<LatLng> points, double distance,
      {String? type}) {
    _selectedPoint = end;
    _routePoints = points;
    _selectedDistance = distance;
    _routeType = type;
    _isNavigating = type != null;
    notifyListeners();
  }

  /// Called from marketplace_screen when user taps "View on Map".
  /// Set [isAcceptedRoute] to true when energy has already been approved —
  /// the map will show Navigate instead of Request Energy on the route card.
  void setRouteFromCoordinates({
    required LatLng start,
    required LatLng end,
    String? destinationName,
    bool isAcceptedRoute = false,
  }) {
    _currentPosition = start;
    _selectedPoint = end;
    _destinationName = destinationName;
    _routePoints = [];
    _selectedDistance = null;
    _isNavigating = true;
    _isAcceptedRoute = isAcceptedRoute;
    notifyListeners();
  }

  void clearRoute() {
    _selectedPoint = null;
    _routePoints = [];
    _selectedDistance = null;
    _routeType = null;
    _isNavigating = false;
    _isAcceptedRoute = false;
    _destinationName = null;
    notifyListeners();
  }

  void updateRoutePoints(List<LatLng> newPoints) {
    _routePoints = newPoints;
    notifyListeners();
  }
}