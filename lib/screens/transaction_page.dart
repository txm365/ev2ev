// lib/screens/transaction_page.dart
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
import '../providers/transaction_provider.dart';
import '../providers/bluetooth_provider.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  TransactionPageState createState() => TransactionPageState();
}

class TransactionPageState extends State<TransactionPage> {
  final PolylinePoints _polylinePoints = PolylinePoints();
  late final MapController _mapController;
  late final TransactionProvider _transactionProvider;
  late final BluetoothProvider _bluetoothProvider;
  bool _isRouting = false;
  bool _mapReady = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _transactionProvider = context.read<TransactionProvider>();
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
        _transactionProvider.updatePosition(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        );
        if (_mapReady) {
          _mapController.move(_transactionProvider.currentPosition!, 15);
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

    final currentPos = _transactionProvider.currentPosition;
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
        _transactionProvider.setRoute(
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

  void _handleTransactionAction(String type) async {
    if (_transactionProvider.selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first')));
      return;
    }

    final energy = _transactionProvider.calculateEnergyRequired(6);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm $type Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Distance: ${_transactionProvider.selectedDistance!.toStringAsFixed(2)} km'),
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
              _transactionProvider.setRoute(
                _transactionProvider.selectedPoint!,
                _transactionProvider.routePoints,
                _transactionProvider.selectedDistance!,
                type: type
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$type transaction started')));
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
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializePosition,
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, _) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: transactionProvider.currentPosition ?? const LatLng(-26.2041, 28.0473), // Johannesburg
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
                      if (transactionProvider.currentPosition != null)
                        Marker(
                          point: transactionProvider.currentPosition!,
                          child: const Icon(Icons.location_pin, 
                              color: Colors.blue, size: 40),
                        ),
                      if (transactionProvider.selectedPoint != null)
                        Marker(
                          point: transactionProvider.selectedPoint!,
                          child: const Icon(Icons.location_pin, 
                              color: Colors.red, size: 40),
                        ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (transactionProvider.routePoints.isNotEmpty)
                        Polyline(
                          points: transactionProvider.routePoints,
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
              
              // Action buttons
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton('Buy', Icons.shopping_cart, Colors.green)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton('Sell', Icons.electric_bolt, Colors.blue)
                    ),
                  ],
                ),
              ),
              
              // Distance info
              if (transactionProvider.selectedDistance != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildDistanceInfo(transactionProvider),
                ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildDistanceInfo(TransactionProvider provider) {
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
      onPressed: () => _handleTransactionAction(text),
    );
  }
}