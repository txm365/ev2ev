// lib/screens/map_page.dart
import 'dart:async';
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
import '../providers/marketplace_provider.dart' as mp;
import '../models/energy_listing.dart';
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
  late final mp.MarketplaceProvider _marketplaceProvider;

  bool _isRouting = false;
  bool _mapReady = false;
  Position? _currentPosition;
  EnergyListing? _activeRouteListing; // seller the current route was plotted to

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapProvider = context.read<MapProvider>();
    _marketplaceProvider = context.read<mp.MarketplaceProvider>();
    _initializePosition();
    // Load sellers when map opens — uses cache if data is fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _marketplaceProvider.getNearbyListings(radiusKm: 100);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
        _mapProvider.updatePosition(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
        if (_mapReady) {
          _mapController.move(_mapProvider.currentPosition!, 9.5);
        }
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
  // LEGEND
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLegend(List<EnergyListing> sellers) {
    final types = sellers.map((s) => s.vehicleType).toSet().toList();
    if (types.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: types.map((t) {
          final color = _vehicleColor(t);
          final icon = _vehicleIcon(t);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                t,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          );
        }).toList(),
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
                      setState(() => _activeRouteListing = null);
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

              // ── Seller context (if route was to a seller) ─────────────
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
          // Refresh sellers — bypasses cache
          Consumer<mp.MarketplaceProvider>(
            builder: (context, marketplaceProvider, _) {
              if (marketplaceProvider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh sellers',
                onPressed: () =>
                    marketplaceProvider.refreshAll(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializePosition,
          ),
        ],
      ),
      body: Consumer2<MapProvider, mp.MarketplaceProvider>(
        builder: (context, mapProvider, marketplaceProvider, _) {
          final sellers = marketplaceProvider.nearbyListings;

          return Stack(
            children: [
              // ── Map ────────────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapProvider.currentPosition ??
                      const LatLng(-26.2041, 28.0473),
                  initialZoom: 9.5, // zoom level to show ~100 km radius
                  onTap: _handleMapTap,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    if (mapProvider.currentPosition != null) {
                      _mapController.move(
                          mapProvider.currentPosition!, 9.5);
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

              // ── Seller count badge (top left) ───────────────────────────
              if (sellers.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.electric_bolt,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${sellers.length} seller${sellers.length == 1 ? '' : 's'} nearby',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── No sellers hint ─────────────────────────────────────────
              if (sellers.isEmpty && !marketplaceProvider.isLoading)
                Positioned(
                  top: 12,
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

              // ── Bottom: legend + route info (raised above navbar) ────────
              Positioned(
                bottom: 72, // clears the phone's bottom navigation bar
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sellers.isNotEmpty) _buildLegend(sellers),
                    if (mapProvider.selectedDistance != null)
                      _buildRouteInfo(mapProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}