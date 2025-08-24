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
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
          route['distance'] / 1000
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
                  onMapReady: () => setState(() => _mapReady = true),
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
                          child: const Icon(Icons.location_pin, 
                              color: Colors.blue, size: 40),
                        ),
                      if (mapProvider.selectedPoint != null)
                        Marker(
                          point: mapProvider.selectedPoint!,
                          child: const Icon(Icons.location_pin, 
                              color: Colors.red, size: 40),
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
              
              // Energy trade action buttons
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton('Buy Energy', Icons.shopping_cart, Colors.green)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton('Sell Energy', Icons.electric_bolt, Colors.blue)
                    ),
                  ],
                ),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Route Distance:', 
                  style: Theme.of(context).textTheme.titleMedium),
                Text('${provider.selectedDistance!.toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 18)),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.directions),
              label: const Text('Navigate'),
              onPressed: () {
                // TODO: Implement navigation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigation feature coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () => _handleEnergyTradeAction(text.split(' ')[0]), // Extract 'Buy' or 'Sell'
    );
  }
}