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
import '../providers/bluetooth_provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  MapPageState createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final PolylinePoints _polylinePoints = PolylinePoints();
  late final MapController _mapController;
  late final MapProvider _mapProvider;
  late final BluetoothProvider _bluetoothProvider;
  bool _isRouting = false;
  bool _mapReady = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapProvider = context.read<MapProvider>();
    _bluetoothProvider = context.read<BluetoothProvider>();
    _initializePosition();
    
    // Listen for route changes from external sources (e.g., marketplace)
    _mapProvider.addListener(_handleRouteUpdate);
  }

  @override
  void dispose() {
    _mapProvider.removeListener(_handleRouteUpdate);
    _mapController.dispose();
    super.dispose();
  }

  void _handleRouteUpdate() {
    if (_mapProvider.selectedPoint != null && 
        _mapProvider.routePoints.isEmpty && 
        _mapProvider.currentPosition != null) {
      // Route was set from external source, calculate the actual route
      _calculateRoute(
        _mapProvider.currentPosition!,
        _mapProvider.selectedPoint!,
      );
    }
  }

  Future<void> _initializePosition() async {
    try {
      // Check and request location permissions
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

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null && mounted) {
        _mapProvider.updatePosition(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        );
        if (_mapReady) {
          _mapController.move(_mapProvider.currentPosition!, 15);
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

  Future<Map<String, dynamic>> _getOSRMRoute(LatLng start, LatLng end) async {
    try {
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=polyline'
      ));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Failed to load route: $e');
    }
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    if (_isRouting) return;
    
    setState(() => _isRouting = true);
    
    try {
      final routeData = await _getOSRMRoute(start, end);
      final route = routeData['routes'][0];
      final points = _polylinePoints.decodePolyline(route['geometry']);

      if (mounted) {
        _mapProvider.updateRoutePoints(
          points.map((p) => LatLng(p.latitude, p.longitude)).toList()
        );
        _mapProvider.updateRouteDistance(route['distance'] / 1000);
        
        // Center map to show the route
        _centerMapOnRoute(start, end);
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

  void _centerMapOnRoute(LatLng start, LatLng end) {
    final bounds = LatLngBounds(start, end);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
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

    await _calculateRoute(currentPos, latLng);
  }

  void _handleEnergyTradeAction(String type) async {
    if (_mapProvider.selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first')));
      return;
    }

    final energy = _mapProvider.calculateEnergyRequired(6);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm $type Energy Trade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Distance: ${_mapProvider.selectedDistance!.toStringAsFixed(2)} km'),
            Text('Estimated Energy: ${energy.toStringAsFixed(2)} kWh'),
            if (_bluetoothProvider.isConnected) ...[
              const SizedBox(height: 8),
              Text('Current SOC: ${_bluetoothProvider.deviceData['bl']?.toStringAsFixed(0) ?? '0'}%'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _mapProvider.setRoute(
                _mapProvider.selectedPoint!,
                _mapProvider.routePoints,
                _mapProvider.selectedDistance!,
                type: type
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$type energy trade route started')));
            },
            child: Text(type),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializePosition,
          ),
          if (_mapProvider.selectedPoint != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _mapProvider.clearRoute();
                if (_mapProvider.currentPosition != null) {
                  _mapController.move(_mapProvider.currentPosition!, 15);
                }
              },
            ),
        ],
      ),
      body: Consumer<MapProvider>(
        builder: (context, mapProvider, _) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapProvider.currentPosition ?? const LatLng(-26.2041, 28.0473), // Johannesburg
                  initialZoom: 15.0,
                  onTap: _handleMapTap,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    if (mapProvider.currentPosition != null) {
                      _mapController.move(mapProvider.currentPosition!, 15);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ev_dashboard',
                  ),
                  MarkerLayer(
                    markers: [
                      if (mapProvider.currentPosition != null)
                        Marker(
                          point: mapProvider.currentPosition!,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(Icons.my_location, 
                                  color: Colors.blue, size: 40),
                            ],
                          ),
                        ),
                      if (mapProvider.selectedPoint != null)
                        Marker(
                          point: mapProvider.selectedPoint!,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              if (mapProvider.destinationName != null)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    mapProvider.destinationName!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const Icon(Icons.location_pin, 
                                  color: Colors.red, size: 40),
                            ],
                          ),
                        ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (mapProvider.routePoints.isNotEmpty)
                        Polyline(
                          points: mapProvider.routePoints,
                          color: Colors.blue,
                          strokeWidth: 4.0,
                        ),
                    ],
                  ),
                ],
              ),
              
              // Loading indicator
              if (!_mapReady || _isRouting)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              
              // Distance and route info
              if (mapProvider.selectedDistance != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildRouteInfo(mapProvider),
                ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildRouteInfo(MapProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.destinationName != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To: ${provider.destinationName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Distance:', 
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('${provider.selectedDistance!.toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Est. Energy:', 
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('${provider.calculateEnergyRequired(6).toStringAsFixed(2)} kWh',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ],
            ),
            if (provider.routeType == 'energy_trade') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.navigation),
                  label: const Text('Start Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation feature coming soon!')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}