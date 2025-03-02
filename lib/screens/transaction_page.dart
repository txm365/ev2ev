import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
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
    if (_transactionProvider.currentPosition == null) {
      final position = await _bluetoothProvider.getCurrentPosition();
      if (position != null && mounted) {
        _transactionProvider.updatePosition(
          LatLng(position.latitude, position.longitude)
        );
        if (_mapReady) { // Only move if map is ready
          _mapController.move(_transactionProvider.currentPosition!, 15);
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getOSRMRoute(LatLng start, LatLng end) async {
    final response = await http.get(Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=polyline'
    ));

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load route');
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) async {
    if (!mounted || _isRouting || !_mapReady) return;

    setState(() => _isRouting = true);
    
    try {
      final routeData = await _getOSRMRoute(
        _transactionProvider.currentPosition!, 
        latLng
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, _) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: transactionProvider.currentPosition ?? const LatLng(0, 0),
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
              if (!_mapReady)
                const Center(child: CircularProgressIndicator()),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(child: _buildActionButton('Buy', Icons.shopping_cart, Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildActionButton('Sell', Icons.electric_bolt, Colors.blue)),
                  ],
                ),
              ),
              if (transactionProvider.selectedDistance != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildDistanceInfo(transactionProvider),
                ),
              if (_isRouting)
                const Center(child: CircularProgressIndicator()),
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
              onPressed: () {},
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
      onPressed: () {},
    );
  }
}