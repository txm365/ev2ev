// lib/screens/map_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/map_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/energy_listing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show mainScreenKey;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  MapPageState createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final PolylinePoints _polylinePoints = PolylinePoints();
  late final MapController _mapController;
  late final MapProvider _mapProvider;
  bool _isRouting = false;
  bool _mapReady = false;
  Position? _currentPosition;
  EnergyListing? _activeRouteListing;
  double _zoomLevel = 10.5;
  double? _externalRouteDestLat;
  double? _externalRouteDestLng;
  bool _isExternalRoute = false;

  // ── Map-local seller state (independent of marketplace filters) ────────────
  List<EnergyListing> _mapSellers = [];
  bool _isLoadingSellers = false;
  double _lastFetchedRadiusKm = 0;
  Timer? _zoomDebounce;

  // ── Vehicle type filter ───────────────────────────────────────────────────
  String _selectedVehicleType = 'All';
  static const List<String> _vehicleTypes = [
    'All', 'Electric Car', 'Electric Van', 'Electric Truck',
    'Electric Bus', 'Electric Motorcycle', 'Charging Station',
  ];

  // ── Last known position (persisted) ─────────────────────────────────────
  static const _prefLat = 'map_last_lat';
  static const _prefLng = 'map_last_lng';
  LatLng _lastSavedPosition = const LatLng(-26.2041, 28.0473); // Johannesburg fallback

  /// Converts zoom level → visible radius in km.
  /// zoom 5 ≈ 1000 km  |  zoom 7 ≈ 250 km  |  zoom 10.5 ≈ 50 km  |  zoom 14 ≈ 5 km
  double _zoomToRadiusKm(double zoom) {
    // Each zoom step halves the visible area (exponential scale)
    return (1000.0 * math.pow(2.0, 5.0 - zoom)).clamp(1.0, 1000.0);
  }

  /// Human-readable radius label shown on the zoom slider
  String _radiusLabel(double zoom) {
    final km = _zoomToRadiusKm(zoom);
    if (km >= 1000) return '1000 km';
    if (km >= 100) return '${km.toStringAsFixed(0)} km';
    if (km >= 10) return '${km.toStringAsFixed(0)} km';
    return '${km.toStringAsFixed(1)} km';
  }

  /// Debounce zoom changes so we don't hit the DB on every pixel of slider drag
  void _onZoomChanged(double newZoom) {
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 600), () {
      final radiusKm = _zoomToRadiusKm(newZoom);
      // Only refetch if radius changed by more than 20%
      if ((_lastFetchedRadiusKm - radiusKm).abs() > _lastFetchedRadiusKm * 0.2) {
        _fetchSellersForRadius(radiusKm);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapProvider = context.read<MapProvider>();
    _loadLastPosition(); // restore saved position before map opens
    _initializePosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSellersForRadius(50);
    });
  }

  Future<void> _loadLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_prefLat);
    final lng = prefs.getDouble(_prefLng);
    if (lat != null && lng != null && mounted) {
      setState(() => _lastSavedPosition = LatLng(lat, lng));
    }
  }

  Future<void> _saveLastPosition(LatLng pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefLat, pos.latitude);
    await prefs.setDouble(_prefLng, pos.longitude);
  }

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP-LOCAL SELLER FETCH (bypasses marketplace filters)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _fetchSellersForRadius(double radiusKm) async {
    if (_isLoadingSellers) return;
    // Normalize: _currentPosition is Position (geolocator), provider uses LatLng
    final LatLng? pos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _mapProvider.currentPosition;
    if (pos == null) {
      // Position not ready yet — will retry after _initializePosition completes
      return;
    }

    if (mounted) setState(() => _isLoadingSellers = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? '';

      // Try the RPC first (same one marketplace uses)
      List<dynamic>? rows;
      try {
        rows = await client.rpc('get_nearby_listings', params: {
          'user_lat': pos.latitude,
          'user_lng': pos.longitude,
          'radius_km': radiusKm,
          'current_user_id': userId,
        }) as List<dynamic>;
      } catch (_) {
        // RPC failed — plain fallback
        rows = await client
            .from('energy_listings')
            .select('*')
            .eq('status', 'available')
            .neq('seller_id', userId);
      }

      final List<dynamic> rowList = rows;
      final listings = rowList.map<EnergyListing>((row) {
        // Equirectangular distance — accurate enough for <200 km
        if (row['distance'] == null) {
          final sLat = (row['location_lat'] as num).toDouble();
          final sLng = (row['location_lng'] as num).toDouble();
          const kmPerDeg = 111.32;
          final dlat = (sLat - pos.latitude) * kmPerDeg;
          // cos(lat) approximation valid for -90..90
          final cosLat = 1.0 - (pos.latitude.abs() / 90.0) * 0.40;
          final dlng = (sLng - pos.longitude) * kmPerDeg * cosLat;
          final dist2 = dlat * dlat + dlng * dlng;
          row['distance'] = dist2 <= 0 ? 0.0 : (dlat.abs() + dlng.abs()) / 1.414;
        }
        row['seller_name'] = row['seller_name'] ?? 'Energy Provider';
        return EnergyListing.fromJson(row);
      }).where((l) {
        final d = l.distance;
        return d == null || d <= radiusKm;
      }).toList();

      listings.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

      _lastFetchedRadiusKm = radiusKm;
      debugPrint('🗺️ Map fetched ${listings.length} sellers within ${radiusKm.toStringAsFixed(0)} km');

      if (mounted) setState(() => _mapSellers = listings);
    } catch (e) {
      debugPrint('🗺️ Map seller fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSellers = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initializePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions are denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null && mounted) {
        final pos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        _mapProvider.updatePosition(pos);
        _saveLastPosition(pos);          // persist for next session
        setState(() => _lastSavedPosition = pos);
        if (_mapReady) {
          _mapController.move(pos, _zoomLevel);
        }
        // Now that we have position, do initial seller fetch
        _fetchSellersForRadius(50);
      }
    } catch (e) {
      _showLocationError('Error getting location: $e');
    }
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROUTING
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _getOSRMRoute(LatLng start, LatLng end) async {
    final response = await http.get(Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=polyline',
    ));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) async {
    if (!mounted || _isRouting || !_mapReady) return;

    final currentPos = _mapProvider.currentPosition;
    if (currentPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
      return;
    }

    setState(() => _isRouting = true);
    try {
      final routeData = await _getOSRMRoute(currentPos, latLng);
      final route = routeData['routes'][0];
      final points = _polylinePoints.decodePolyline(route['geometry']);
      if (mounted) {
        _mapProvider.setRoute(
          latLng,
          points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          route['distance'] / 1000,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Routing failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  /// Called by marketplace "View on Map" — routes to arbitrary coordinates.
  Future<void> routeToCoordinates(double lat, double lng) async {
    final currentPos = _mapProvider.currentPosition;
    if (currentPos == null) return;
    final dest = LatLng(lat, lng);
    setState(() => _isRouting = true);
    try {
      final routeData = await _getOSRMRoute(currentPos, dest);
      final route = routeData['routes'][0];
      final points = _polylinePoints.decodePolyline(route['geometry']);
      if (mounted) {
        _mapProvider.setRoute(
          dest,
          points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          route['distance'] / 1000,
        );
        _mapController.move(dest, 13);
        // Store destination so Navigate button knows where to go
        setState(() {
          _zoomLevel = 13;
          _externalRouteDestLat = lat;
          _externalRouteDestLng = lng;
          _isExternalRoute = true;
          _activeRouteListing = null; // no seller card needed
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Routing failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  Future<void> _routeToSeller(EnergyListing listing) async {
    final currentPos = _mapProvider.currentPosition;
    if (currentPos == null) return;

    final sellerPos = LatLng(listing.locationLat, listing.locationLng);
    setState(() => _isRouting = true);
    try {
      final routeData = await _getOSRMRoute(currentPos, sellerPos);
      final route = routeData['routes'][0];
      final points = _polylinePoints.decodePolyline(route['geometry']);
      if (mounted) {
        _mapProvider.setRoute(
          sellerPos,
          points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          route['distance'] / 1000,
        );
        _mapController.move(sellerPos, 13);
        setState(() => _activeRouteListing = listing); // track active seller
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Routing failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELLER MARKER — vehicle-type icon + price tag
  // ─────────────────────────────────────────────────────────────────────────
  IconData _vehicleIcon(String vehicleType) {
    final v = vehicleType.toLowerCase();
    if (v.contains('bus')) return Icons.directions_bus;
    if (v.contains('truck')) return Icons.local_shipping;
    if (v.contains('van')) return Icons.airport_shuttle;
    if (v.contains('motorcycle') || v.contains('scooter') || v.contains('bike')) {
      return Icons.electric_moped;
    }
    if (v.contains('station') || v.contains('charging')) return Icons.ev_station;
    return Icons.electric_car;
  }

  Color _vehicleColor(String vehicleType) {
    final v = vehicleType.toLowerCase();
    if (v.contains('bus')) return const Color(0xFF7B1FA2);
    if (v.contains('truck')) return const Color(0xFFE65100);
    if (v.contains('van')) return const Color(0xFF0277BD);
    if (v.contains('motorcycle') || v.contains('scooter') || v.contains('bike')) {
      return const Color(0xFF00897B);
    }
    if (v.contains('station') || v.contains('charging')) return const Color(0xFFAD1457);
    return const Color(0xFF2E7D32);
  }

  Widget _buildSellerMarker(EnergyListing listing) {
    final color = _vehicleColor(listing.vehicleType);
    final icon = _vehicleIcon(listing.vehicleType);

    return GestureDetector(
      onTap: () => _showSellerBottomSheet(listing),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Pin circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          // Price tag floating above
          Positioned(
            top: -14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'R${listing.pricePerKwh.toStringAsFixed(1)}',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELLER BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showSellerBottomSheet(EnergyListing listing) {
    final color = _vehicleColor(listing.vehicleType);
    final icon = _vehicleIcon(listing.vehicleType);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        // bottom padding accounts for the phone's system navbar height
        padding: EdgeInsets.fromLTRB(
          20, 12, 20,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.sellerName ?? 'Energy Seller',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        listing.vehicleType,
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: listing.status == 'available'
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: listing.status == 'available'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Text(
                    listing.status == 'available' ? 'Available' : 'Paused',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: listing.status == 'available'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _statTile(
                    'Price',
                    'R${listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                    Icons.attach_money,
                    color),
                const SizedBox(width: 12),
                _statTile(
                    'Available',
                    '${listing.availableEnergy.toStringAsFixed(1)} kWh',
                    Icons.battery_charging_full,
                    color),
                const SizedBox(width: 12),
                _statTile(
                    'Distance',
                    listing.distance != null
                        ? '${listing.distance!.toStringAsFixed(1)} km'
                        : 'N/A',
                    Icons.near_me,
                    color),
              ],
            ),

            if (listing.connectorType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.electrical_services,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    'Connector: ${listing.connectorType}',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ],

            if (listing.description != null &&
                listing.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                listing.description!,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ],

            const SizedBox(height: 20),

            // Full-width View Route button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _routeToSeller(listing);
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────────────────
  // MY LOCATION MARKER — pulsing blue dot
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMyLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.15),
            border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3), width: 1),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4), blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROUTE INFO CARD
  // ─────────────────────────────────────────────────────────────────────────
  // EV efficiency assumption: 6 km/kWh (adjustable)
  static const double _evEfficiencyKmPerKwh = 6.0;

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATOR APP LAUNCHER
  // ─────────────────────────────────────────────────────────────────────────
  void _launchNavigator(double lat, double lng, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Navigate with...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.blue),
              title: const Text('Google Maps'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.teal),
              title: const Text('Waze'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  // Waze not installed — open Play Store
                  final fallback = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                  if (await canLaunchUrl(fallback)) {
                    await launchUrl(fallback,
                        mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.orange),
              title: const Text('Default Maps App'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(MapProvider provider) {
    final distance = provider.selectedDistance!;
    final energyKwh = distance / _evEfficiencyKmPerKwh;
    final cs = Theme.of(context).colorScheme;
    final seller = _activeRouteListing;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top row: stats + clear ────────────────────────────────
              Row(
                children: [
                  // Distance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Distance',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                        Row(
                          children: [
                            Icon(Icons.route, size: 16, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${distance.toStringAsFixed(2)} km',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Vertical divider
                  Container(
                    width: 1,
                    height: 36,
                    color: cs.onSurface.withValues(alpha: 0.12),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),

                  // Energy estimate
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Est. Energy Needed',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.bolt,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${energyKwh.toStringAsFixed(2)} kWh',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          'at ${_evEfficiencyKmPerKwh.toStringAsFixed(0)} km/kWh',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),

                  // Clear button
                  IconButton(
                    onPressed: () {
                      provider.clearRoute();
                      setState(() {
                        _activeRouteListing = null;
                        _isExternalRoute = false;
                        _externalRouteDestLat = null;
                        _externalRouteDestLng = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear route',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              // ── External route Navigate button (from marketplace) ──────
              if (_isExternalRoute &&
                  _externalRouteDestLat != null &&
                  _externalRouteDestLng != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchNavigator(
                      _externalRouteDestLat!,
                      _externalRouteDestLng!,
                      'Energy Seller',
                    ),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              ],

              // ── Seller context (if route was to a seller marker) ──────────
              if (seller != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Seller name + price pill
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                _vehicleColor(seller.vehicleType),
                            child: Icon(
                              _vehicleIcon(seller.vehicleType),
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  seller.sellerName ?? 'Energy Seller',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'R${seller.pricePerKwh.toStringAsFixed(2)}/kWh'
                                  ' · ${seller.availableEnergy.toStringAsFixed(1)} kWh avail.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Request Energy button
                    ElevatedButton.icon(
                      onPressed: () {
                        mainScreenKey.currentState?.navigateToTab(1);
                      },
                      icon: const Icon(Icons.bolt, size: 16),
                      label: const Text('Request Energy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _vehicleColor(seller.vehicleType),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Navigation'),
        actions: [
          // Refresh sellers directly from DB
          if (_isLoadingSellers)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh sellers',
              onPressed: () => _fetchSellersForRadius(
                  _zoomToRadiusKm(_zoomLevel)),
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializePosition,
          ),
        ],
      ),
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, _) {
          // Apply vehicle type filter
          final sellers = _selectedVehicleType == 'All'
              ? _mapSellers
              : _mapSellers.where((s) =>
                  s.vehicleType.toLowerCase()
                      .contains(_selectedVehicleType.toLowerCase())).toList();

          // Auto-plot route when marketplace triggers "View on Map"
          if (mapProvider.isNavigating &&
              mapProvider.selectedPoint != null &&
              mapProvider.routePoints.isEmpty &&
              !_isRouting &&
              _mapReady) {
            final dest = mapProvider.selectedPoint!;
            final isAccepted = mapProvider.isAcceptedRoute;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (isAccepted) setState(() => _isExternalRoute = true);
                routeToCoordinates(dest.latitude, dest.longitude);
              }
            });
          }

          return Stack(
            children: [
              // ── Map ────────────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapProvider.currentPosition ??
                      _lastSavedPosition,
                  initialZoom: 10.5, // zoom level to show ~50 km radius
                  onTap: _handleMapTap,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    if (mapProvider.currentPosition != null) {
                      _mapController.move(
                          mapProvider.currentPosition!, 10.5);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ev_dashboard',
                    // Silently swallow tile load failures (network timeout,
                    // cancelled connection etc.) — show blank tile instead
                    errorTileCallback: (tile, error, stackTrace) {
                      // suppress — avoids flooding logs on slow networks
                    },
                  ),
                  PolylineLayer(
                    polylines: [
                      if (mapProvider.routePoints.isNotEmpty)
                        Polyline(
                          points: mapProvider.routePoints,
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 4.0,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // My location
                      if (mapProvider.currentPosition != null)
                        Marker(
                          point: mapProvider.currentPosition!,
                          width: 50,
                          height: 50,
                          child: _buildMyLocationMarker(),
                        ),
                      // Selected tap point
                      if (mapProvider.selectedPoint != null)
                        Marker(
                          point: mapProvider.selectedPoint!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      // Seller markers
                      ...sellers
                          .where(
                              (s) => s.locationLat != 0 && s.locationLng != 0)
                          .map(
                            (listing) => Marker(
                              point: LatLng(
                                  listing.locationLat, listing.locationLng),
                              width: 52,
                              height: 66,
                              child: _buildSellerMarker(listing),
                            ),
                          ),
                    ],
                  ),
                ],
              ),

              // ── Loading overlay ─────────────────────────────────────────
              if (!_mapReady || _isRouting)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),

              // seller count badge removed

              // ── No sellers hint ─────────────────────────────────────────
              if (sellers.isEmpty && !_isLoadingSellers)
                Positioned(
                  top: 62,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_off,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(
                          'No energy sellers found nearby',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom: route info card (raised above navbar) ─────────
              Positioned(
                bottom: 72,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mapProvider.selectedDistance != null)
                      _buildRouteInfo(mapProvider),
                  ],
                ),
              ),

              // ── Right side: vertical zoom slider with radius label ──────
              Positioned(
                right: 12,
                top: 0,
                bottom: 80,
                child: Center(
                  child: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Radius label
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _radiusLabel(_zoomLevel),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Zoom in
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            final nz = (_zoomLevel + 1).clamp(5.0, 18.0);
                            setState(() => _zoomLevel = nz);
                            _mapController.move(
                              mapProvider.currentPosition ?? _lastSavedPosition,
                              nz,
                            );
                            _onZoomChanged(nz);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                        ),
                        // Vertical slider
                        SizedBox(
                          height: 150,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                                activeTrackColor:
                                    Theme.of(context).colorScheme.primary,
                                inactiveTrackColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.2),
                                thumbColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              child: Slider(
                                value: _zoomLevel,
                                min: 5.0,
                                max: 18.0,
                                onChanged: (val) {
                                  setState(() => _zoomLevel = val);
                                  _mapController.move(
                                    mapProvider.currentPosition ?? _lastSavedPosition,
                                    val,
                                  );
                                  _onZoomChanged(val);
                                },
                              ),
                            ),
                          ),
                        ),
                        // Zoom out
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () {
                            final nz = (_zoomLevel - 1).clamp(5.0, 18.0);
                            setState(() => _zoomLevel = nz);
                            _mapController.move(
                              mapProvider.currentPosition ?? _lastSavedPosition,
                              nz,
                            );
                            _onZoomChanged(nz);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Top: vehicle type filter chips ─────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                right: 72, // leave room for zoom slider
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _vehicleTypes.map((type) {
                      final selected = _selectedVehicleType == type;
                      final cs = Theme.of(context).colorScheme;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            type == 'All' ? '⚡ All' :
                            type == 'Charging Station' ? '🔌 Station' :
                            type == 'Electric Car' ? '🚗 Car' :
                            type == 'Electric Bus' ? '🚌 Bus' :
                            type == 'Electric Truck' ? '🚛 Truck' :
                            type == 'Electric Van' ? '🚐 Van' :
                            type == 'Electric Motorcycle' ? '🛵 Moto' : type,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected
                                  ? cs.onPrimary
                                  : cs.onSurface,
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedVehicleType = type),
                          backgroundColor:
                              cs.surface.withValues(alpha: 0.92),
                          selectedColor: cs.primary,
                          checkmarkColor: cs.onPrimary,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}