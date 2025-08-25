// lib/providers/marketplace_provider.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/energy_listing.dart';
import '../models/energy_request.dart';
import '../models/energy_transaction.dart';

class MarketplaceProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // State management
  List<EnergyListing> _nearbyListings = [];
  List<EnergyRequest> _myRequests = [];
  List<EnergyRequest> _receivedRequests = [];
  List<EnergyTransaction> _myTransactions = [];
  EnergyListing? _myActiveListing;
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;

  // Search and filter state
  String _searchQuery = '';
  String _selectedVehicleType = 'all';
  double _maxDistance = 10.0;
  double _maxPrice = 5.0;
  bool _showAvailableOnly = true;

  // Getters
  List<EnergyListing> get nearbyListings => _getFilteredListings();
  List<EnergyRequest> get myRequests => _myRequests;
  List<EnergyRequest> get receivedRequests => _receivedRequests;
  List<EnergyTransaction> get myTransactions => _myTransactions;
  EnergyListing? get myActiveListing => _myActiveListing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;
  String get searchQuery => _searchQuery;
  String get selectedVehicleType => _selectedVehicleType;
  double get maxDistance => _maxDistance;
  double get maxPrice => _maxPrice;
  bool get showAvailableOnly => _showAvailableOnly;
  
  String? get currentUserId => _supabase.auth.currentUser?.id;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // ============================================================================
  // LISTING MANAGEMENT ACTIONS (SELLER FUNCTIONALITY)
  // ============================================================================

  /// Create a new energy listing and publish to Supabase database
  Future<bool> createEnergyListing({
    required double pricePerKwh,
    required double availableEnergy,
    required double minEnergySale,
    required double maxEnergySale,
    required String vehicleType,
    required String connectorType,
    DateTime? availabilityEnd,
    String? description,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      // Get current location
      final position = await getCurrentLocation();
      if (position == null) {
        _setError('Unable to get current location');
        return false;
      }

      // Check if user already has an active listing
      final existingListing = await _supabase
          .from('energy_listings')
          .select()
          .eq('seller_id', userId)
          .or('status.eq.available,status.eq.paused')
          .maybeSingle();

      if (existingListing != null) {
        _setError('You already have an active listing. Delete or edit your current listing first.');
        return false;
      }

      // Create the listing data
      final now = DateTime.now();
      final listingData = {
        'seller_id': userId,
        'price_per_kwh': pricePerKwh,
        'available_energy': availableEnergy,
        'min_energy_sale': minEnergySale,
        'max_energy_sale': maxEnergySale,
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'location_address': 'Current Location', // Can be enhanced with reverse geocoding
        'vehicle_type': vehicleType,
        'connector_type': connectorType,
        'availability_start': now.toIso8601String(),
        'availability_end': availabilityEnd?.toIso8601String(),
        'status': 'available',
        'description': description,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Insert into database
      final response = await _supabase
          .from('energy_listings')
          .insert(listingData)
          .select()
          .single();

      // Create EnergyListing object and update state
      _myActiveListing = EnergyListing.fromJson(response);
      
      // Start listening for requests
      _listenForReceivedRequests();
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Energy listing created successfully: ${_myActiveListing!.id}');
      return true;

    } catch (e) {
      debugPrint('❌ Error creating listing: $e');
      _setError('Failed to create listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing energy listing
  Future<bool> updateEnergyListing({
    required String listingId,
    double? pricePerKwh,
    double? availableEnergy,
    double? minEnergySale,
    double? maxEnergySale,
    String? vehicleType,
    String? connectorType,
    DateTime? availabilityEnd,
    String? description,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      // Build update data - only include non-null values
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (pricePerKwh != null) updateData['price_per_kwh'] = pricePerKwh;
      if (availableEnergy != null) updateData['available_energy'] = availableEnergy;
      if (minEnergySale != null) updateData['min_energy_sale'] = minEnergySale;
      if (maxEnergySale != null) updateData['max_energy_sale'] = maxEnergySale;
      if (vehicleType != null) updateData['vehicle_type'] = vehicleType;
      if (connectorType != null) updateData['connector_type'] = connectorType;
      if (availabilityEnd != null) updateData['availability_end'] = availabilityEnd.toIso8601String();
      if (description != null) updateData['description'] = description;

      // Update in database with security check
      final response = await _supabase
          .from('energy_listings')
          .update(updateData)
          .eq('id', listingId)
          .eq('seller_id', userId) // Security: ensure user owns the listing
          .select()
          .single();

      // Update local state
      _myActiveListing = EnergyListing.fromJson(response);
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Energy listing updated successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Error updating listing: $e');
      _setError('Failed to update listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update listing status (pause/resume/available)
  Future<bool> updateListingStatus(String status) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null || _myActiveListing == null) {
        _setError('No active listing found');
        return false;
      }

      // Validate status
      if (!['available', 'paused', 'inactive'].contains(status)) {
        _setError('Invalid status. Must be: available, paused, or inactive');
        return false;
      }

      final response = await _supabase
          .from('energy_listings')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _myActiveListing!.id)
          .eq('seller_id', userId)
          .select()
          .single();

      // Update local state
      _myActiveListing = EnergyListing.fromJson(response);
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Listing status updated to: $status');
      return true;

    } catch (e) {
      debugPrint('❌ Error updating listing status: $e');
      _setError('Failed to update listing status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete the user's active listing
  Future<bool> deleteMyListing() async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null || _myActiveListing == null) {
        _setError('No active listing found');
        return false;
      }

      // Check if there are any pending requests
      final pendingRequests = await _supabase
          .from('energy_requests')
          .select('id')
          .eq('listing_id', _myActiveListing!.id)
          .eq('status', 'pending');

      if (pendingRequests.isNotEmpty) {
        _setError('Cannot delete listing with pending requests. Please respond to all requests first.');
        return false;
      }

      // Delete the listing
      await _supabase
          .from('energy_listings')
          .delete()
          .eq('id', _myActiveListing!.id)
          .eq('seller_id', userId);

      // Clear local state
      _myActiveListing = null;
      _receivedRequests.clear();
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Listing deleted successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Error deleting listing: $e');
      _setError('Failed to delete listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Respond to a buyer's energy request
  Future<bool> respondToRequest(String requestId, String status) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      // Validate status
      if (!['accepted', 'rejected'].contains(status)) {
        _setError('Invalid response status. Must be: accepted or rejected');
        return false;
      }

      // Update request status
      await _supabase
          .from('energy_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // If accepted, create a transaction record
      if (status == 'accepted') {
        final request = _receivedRequests.firstWhere((r) => r.id == requestId);
        
        await _supabase
            .from('energy_transactions')
            .insert({
              'request_id': requestId,
              'seller_id': userId,
              'buyer_id': request.buyerId,
              'status': 'pending',
              'payment_status': 'pending',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
      }

      // Refresh received requests
      await _loadReceivedRequests();
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Request $status successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Error responding to request: $e');
      _setError('Failed to respond to request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // BUYER FUNCTIONALITY - PULLING LISTINGS FROM DATABASE
  // ============================================================================

  /// Get nearby energy listings with geospatial queries
  Future<void> getNearbyListings({double radiusKm = 15.0}) async {
    try {
      _setLoading(true);
      _setError(null);

      debugPrint('🔍 Getting nearby listings...');
      
      final position = _currentPosition ?? await getCurrentLocation();
      if (position == null) {
        _setError('Could not get current location');
        debugPrint('❌ No location available');
        return;
      }

      debugPrint('📍 Current location: ${position.latitude}, ${position.longitude}');

      // Try to use the optimized RPC function first
      try {
        debugPrint('🔄 Trying RPC function get_nearby_listings...');
        final response = await _supabase
            .rpc('get_nearby_listings', params: {
              'user_lat': position.latitude,
              'user_lng': position.longitude,
              'radius_km': radiusKm,
              'current_user_id': currentUserId ?? '',
            });

        if (response != null && response is List) {
          debugPrint('✅ RPC response received: ${response.length} listings');
          _nearbyListings = (response as List).map((listing) {
            listing['seller_name'] = listing['seller_name'] ?? 'Energy Provider';
            return EnergyListing.fromJson(listing);
          }).toList();
        } else {
          throw Exception('RPC function not available, using fallback');
        }
      } catch (e) {
        // Fallback to basic SQL query
        debugPrint('⚠️ RPC failed, using fallback query: $e');
        final fallbackResponse = await _supabase
            .from('energy_listings')
            .select('*')
            .eq('status', 'available')
            .neq('seller_id', currentUserId ?? '');

        debugPrint('📊 Fallback query returned: ${fallbackResponse.length} total listings');

        _nearbyListings = (fallbackResponse as List).map((listing) {
          final sellerLat = listing['location_lat'] as double;
          final sellerLng = listing['location_lng'] as double;
          final distance = _calculateDistance(
            position.latitude, position.longitude,
            sellerLat, sellerLng,
          );
          
          debugPrint('📏 Listing ${listing['id']} distance: ${distance.toStringAsFixed(2)} km');
          
          // Add computed fields
          listing['distance'] = distance;
          listing['seller_name'] = 'Energy Provider';
          
          return EnergyListing.fromJson(listing);
        }).where((listing) => 
          listing.distance != null && listing.distance! <= radiusKm
        ).toList();

        // Sort by distance
        _nearbyListings.sort((a, b) => 
          (a.distance ?? 0).compareTo(b.distance ?? 0));
      }

      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Final result: ${_nearbyListings.length} nearby listings within ${radiusKm}km');
      for (var listing in _nearbyListings) {
        debugPrint('  - ${listing.sellerName}: ${listing.distance?.toStringAsFixed(2)}km, R${listing.pricePerKwh}/kWh, ${listing.availableEnergy}kWh');
      }

    } catch (e) {
      debugPrint('❌ Error getting nearby listings: $e');
      _setError('Failed to load nearby listings: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create test listings for debugging (temporary method)
  Future<void> createTestListings() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return;

      // Create a few test listings around the current location
      final testListings = [
        {
          'seller_id': 'test-seller-1',
          'price_per_kwh': 2.50,
          'available_energy': 15.5,
          'min_energy_sale': 5.0,
          'max_energy_sale': 15.0,
          'location_lat': position.latitude + 0.01, // ~1km away
          'location_lng': position.longitude + 0.01,
          'location_address': 'Test Location 1',
          'vehicle_type': 'Electric Car',
          'connector_type': 'Type 2',
          'availability_start': DateTime.now().toIso8601String(),
          'status': 'available',
          'description': 'Test listing for debugging',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'seller_id': 'test-seller-2', 
          'price_per_kwh': 3.00,
          'available_energy': 25.0,
          'min_energy_sale': 10.0,
          'max_energy_sale': 25.0,
          'location_lat': position.latitude - 0.01,
          'location_lng': position.longitude - 0.01,
          'location_address': 'Test Location 2',
          'vehicle_type': 'Electric Van',
          'connector_type': 'CCS',
          'availability_start': DateTime.now().toIso8601String(),
          'status': 'available',
          'description': 'Another test listing',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }
      ];

      for (var testListing in testListings) {
        await _supabase
            .from('energy_listings')
            .insert(testListing);
      }

      debugPrint('✅ Created ${testListings.length} test listings');
      await getNearbyListings();
      
    } catch (e) {
      debugPrint('❌ Error creating test listings: $e');
    }
  }

  // HELPER METHODS AND UTILITIES
  // ============================================================================

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Load received requests for seller
  Future<void> _loadReceivedRequests() async {
    try {
      if (_myActiveListing == null) return;

      final response = await _supabase
          .from('energy_requests')
          .select('*')
          .eq('listing_id', _myActiveListing!.id)
          .order('created_at', ascending: false);

      _receivedRequests = (response as List).map((request) {
        request['buyer_name'] = 'Buyer';
        return EnergyRequest.fromJson(request);
      }).toList();

      notifyListeners();

    } catch (e) {
      debugPrint('❌ Error loading received requests: $e');
    }
  }

  /// Listen for new requests in real-time
  void _listenForReceivedRequests() {
    if (_myActiveListing == null) return;

    _supabase
        .from('energy_requests')
        .stream(primaryKey: ['id'])
        .eq('listing_id', _myActiveListing!.id)
        .listen((data) {
          _loadReceivedRequests();
        });
  }

  /// Get current location with permissions
  Future<Position?> getCurrentLocation() async {
    try {
      _setLoading(true);
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('Location permissions are permanently denied');
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _setError(null);
      return _currentPosition;
    } catch (e) {
      _setError('Error getting location: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // FILTERING AND STATE MANAGEMENT
  // ============================================================================

  List<EnergyListing> _getFilteredListings() {
    var filtered = List<EnergyListing>.from(_nearbyListings);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((listing) {
        final query = _searchQuery.toLowerCase();
        return listing.sellerName?.toLowerCase().contains(query) == true ||
               listing.description?.toLowerCase().contains(query) == true ||
               listing.vehicleType.toLowerCase().contains(query) ||
               listing.connectorType.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedVehicleType != 'all') {
      filtered = filtered.where((listing) => 
        listing.vehicleType.toLowerCase() == _selectedVehicleType.toLowerCase()
      ).toList();
    }

    filtered = filtered.where((listing) => 
      listing.distance == null || listing.distance! <= _maxDistance
    ).toList();

    filtered = filtered.where((listing) => 
      listing.pricePerKwh <= _maxPrice
    ).toList();

    if (_showAvailableOnly) {
      filtered = filtered.where((listing) => 
        listing.status == 'available'
      ).toList();
    }

    return filtered;
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateVehicleTypeFilter(String vehicleType) {
    _selectedVehicleType = vehicleType;
    notifyListeners();
  }

  void updateDistanceFilter(double distance) {
    _maxDistance = distance;
    notifyListeners();
  }

  void updatePriceFilter(double price) {
    _maxPrice = price;
    notifyListeners();
  }

  void updateAvailabilityFilter(bool showAvailableOnly) {
    _showAvailableOnly = showAvailableOnly;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedVehicleType = 'all';
    _maxDistance = 10.0;
    _maxPrice = 5.0;
    _showAvailableOnly = true;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    await getCurrentLocation();
    await getNearbyListings();
    await _loadMyActiveListing();
    if (_myActiveListing != null) {
      await _loadReceivedRequests();
    }
  }

  /// Load user's active listing
  Future<void> _loadMyActiveListing() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final response = await _supabase
          .from('energy_listings')
          .select()
          .eq('seller_id', userId)
          .or('status.eq.available,status.eq.paused')
          .maybeSingle();

      if (response != null) {
        _myActiveListing = EnergyListing.fromJson(response);
        await _loadReceivedRequests();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading active listing: $e');
    }
  }

  /// Initialize provider
  Future<void> initialize() async {
    try {
      await getCurrentLocation();
      await _loadMyActiveListing();
      await getNearbyListings();
      if (_myActiveListing != null) {
        _listenForReceivedRequests();
      }
    } catch (e) {
      debugPrint('Marketplace initialization error: $e');
    }
  }

  /// Create an energy request (buyer functionality)
  Future<bool> createEnergyRequest({
    required String listingId,
    required double requestedEnergy,
    required double offeredPricePerKwh,
    String? message,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      // Get current location
      final position = await getCurrentLocation();
      if (position == null) {
        _setError('Unable to get current location');
        return false;
      }

      // Create the request data
      final requestData = {
        'buyer_id': userId,
        'listing_id': listingId,
        'requested_energy': requestedEnergy,
        'offered_price_per_kwh': offeredPricePerKwh,
        'buyer_location_lat': position.latitude,
        'buyer_location_lng': position.longitude,
        'message': message,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert into database
      await _supabase
          .from('energy_requests')
          .insert(requestData);

      // Refresh user's requests
      await getMyRequests();
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Energy request created successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Error creating energy request: $e');
      _setError('Failed to create energy request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel an energy request (buyer functionality)
  Future<bool> cancelRequest(String requestId) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      // Update request status to cancelled
      await _supabase
          .from('energy_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('buyer_id', userId); // Security: ensure user owns the request

      // Refresh user's requests
      await getMyRequests();
      
      _setError(null);
      notifyListeners();
      
      debugPrint('✅ Energy request cancelled successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Error cancelling energy request: $e');
      _setError('Failed to cancel energy request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Implementation methods for completeness
  Future<void> getMyRequests() async {
    // Implementation for loading user's requests
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final response = await _supabase
          .from('energy_requests')
          .select('*')
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      _myRequests = (response as List).map((request) {
        request['seller_name'] = 'Seller';
        return EnergyRequest.fromJson(request);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading my requests: $e');
    }
  }

  Future<void> getMyTransactions() async {
    // Implementation for loading user's transactions
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final response = await _supabase
          .from('energy_transactions')
          .select('*')
          .or('seller_id.eq.$userId,buyer_id.eq.$userId')
          .order('created_at', ascending: false);

      _myTransactions = (response as List).map((transaction) => 
        EnergyTransaction.fromJson(transaction)
      ).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading my transactions: $e');
    }
  }

  Future<bool> completeTransaction(String transactionId, double energyTransferred) async {
    // Implementation for completing transactions
    try {
      await _supabase
          .from('energy_transactions')
          .update({
            'energy_transferred': energyTransferred,
            'status': 'completed',
            'end_time': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId);
      
      await getMyTransactions();
      return true;
    } catch (e) {
      debugPrint('Error completing transaction: $e');
      return false;
    }
  }
}