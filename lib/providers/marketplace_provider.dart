// lib/providers/marketplace_provider.dart
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

  // Getters
  List<EnergyListing> get nearbyListings => _nearbyListings;
  List<EnergyRequest> get myRequests => _myRequests;
  List<EnergyRequest> get receivedRequests => _receivedRequests;
  List<EnergyTransaction> get myTransactions => _myTransactions;
  EnergyListing? get myActiveListing => _myActiveListing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;
  
  String? get currentUserId => _supabase.auth.currentUser?.id;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Get current location
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

  // Create energy listing (for sellers)
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

      final position = await getCurrentLocation();
      if (position == null) {
        _setError('Could not get current location');
        return false;
      }

      final listingData = {
        'seller_id': currentUserId,
        'price_per_kwh': pricePerKwh,
        'available_energy': availableEnergy,
        'min_energy_sale': minEnergySale,
        'max_energy_sale': maxEnergySale,
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'vehicle_type': vehicleType,
        'connector_type': connectorType,
        'availability_end': availabilityEnd?.toIso8601String(),
        'description': description,
        'status': 'available',
      };

      final response = await _supabase
          .from('energy_listings')
          .insert(listingData)
          .select()
          .single();

      _myActiveListing = EnergyListing.fromJson(response);
      
      // Start listening for requests
      _listenForReceivedRequests();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error creating listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update energy listing status
  Future<bool> updateListingStatus(String status) async {
    try {
      if (_myActiveListing == null) return false;

      await _supabase
          .from('energy_listings')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _myActiveListing!.id);

      _myActiveListing = _myActiveListing!.copyWith(status: status);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error updating listing: $e');
      return false;
    }
  }

  // Delete energy listing
  Future<bool> deleteMyListing() async {
    try {
      if (_myActiveListing == null) return false;

      await _supabase
          .from('energy_listings')
          .delete()
          .eq('id', _myActiveListing!.id);

      _myActiveListing = null;
      _receivedRequests.clear();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error deleting listing: $e');
      return false;
    }
  }

  // Get nearby energy listings (for buyers)
  Future<void> getNearbyListings({double radiusKm = 10.0}) async {
    try {
      _setLoading(true);
      _setError(null);

      final position = await getCurrentLocation();
      if (position == null) {
        _setError('Could not get current location');
        return;
      }

      // Get listings with distance calculation
      final response = await _supabase.rpc('get_nearby_listings', params: {
        'user_lat': position.latitude,
        'user_lng': position.longitude,
        'radius_km': radiusKm,
      });

      _nearbyListings = (response as List)
          .map((listing) => EnergyListing.fromJson(listing))
          .toList();

      // Sort by distance
      _nearbyListings.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      
      notifyListeners();
    } catch (e) {
      _setError('Error fetching nearby listings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create energy request (buyer requests energy from seller)
  Future<bool> createEnergyRequest({
    required String listingId,
    required double requestedEnergy,
    double? offeredPricePerKwh,
    String? message,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final position = await getCurrentLocation();
      if (position == null) {
        _setError('Could not get current location');
        return false;
      }

      final requestData = {
        'buyer_id': currentUserId,
        'listing_id': listingId,
        'requested_energy': requestedEnergy,
        'offered_price_per_kwh': offeredPricePerKwh,
        'buyer_location_lat': position.latitude,
        'buyer_location_lng': position.longitude,
        'message': message,
        'status': 'pending',
      };

      final response = await _supabase
          .from('energy_requests')
          .insert(requestData)
          .select('''
            *,
            energy_listings (*)
          ''')
          .single();

      final newRequest = EnergyRequest.fromJson(response);
      _myRequests.add(newRequest);
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error creating request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Respond to energy request (seller accepts/rejects)
  Future<bool> respondToRequest(String requestId, String status) async {
    try {
      _setLoading(true);

      await _supabase
          .from('energy_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Update local state
      final requestIndex = _receivedRequests.indexWhere((r) => r.id == requestId);
      if (requestIndex != -1) {
        _receivedRequests[requestIndex] = _receivedRequests[requestIndex].copyWith(
          status: status,
        );
      }

      // If accepted, create transaction
      if (status == 'accepted') {
        await _createTransaction(requestId);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error responding to request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Create transaction when request is accepted
  Future<void> _createTransaction(String requestId) async {
    try {
      final request = _receivedRequests.firstWhere((r) => r.id == requestId);
      
      final transactionData = {
        'request_id': requestId,
        'seller_id': currentUserId,
        'buyer_id': request.buyerId,
        'final_price_per_kwh': request.offeredPricePerKwh ?? _myActiveListing!.pricePerKwh,
        'seller_location_lat': _myActiveListing!.locationLat,
        'seller_location_lng': _myActiveListing!.locationLng,
        'buyer_location_lat': request.buyerLocationLat,
        'buyer_location_lng': request.buyerLocationLng,
        'status': 'active',
        'payment_status': 'pending',
      };

      await _supabase
          .from('energy_transactions')
          .insert(transactionData);

    } catch (e) {
      debugPrint('Error creating transaction: $e');
    }
  }

  // Get my requests (as buyer)
  Future<void> getMyRequests() async {
    try {
      _setLoading(true);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return;
      }

      final response = await _supabase
          .from('energy_requests')
          .select('''
            *,
            energy_listings (
              *,
              profiles!energy_listings_seller_id_fkey (first_name, last_name)
            )
          ''')
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      _myRequests = (response as List)
          .map((request) => EnergyRequest.fromJson(request))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Error fetching requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Listen for received requests (as seller)
  void _listenForReceivedRequests() {
    if (_myActiveListing == null) return;

    _supabase
        .from('energy_requests')
        .stream(primaryKey: ['id'])
        .eq('listing_id', _myActiveListing!.id)
        .listen((data) {
          _receivedRequests = data
              .map((request) => EnergyRequest.fromJson(request))
              .toList();
          notifyListeners();
        });
  }

  // Get my transactions
  Future<void> getMyTransactions() async {
    try {
      _setLoading(true);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return;
      }

      // Get transactions where user is seller
      final sellerTransactions = await _supabase
          .from('energy_transactions')
          .select()
          .eq('seller_id', userId);

      // Get transactions where user is buyer
      final buyerTransactions = await _supabase
          .from('energy_transactions')
          .select()
          .eq('buyer_id', userId);

      // Combine and sort by created_at
      final allTransactions = [
        ...sellerTransactions,
        ...buyerTransactions,
      ];

      allTransactions.sort((a, b) => 
          DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

      _myTransactions = allTransactions
          .map((transaction) => EnergyTransaction.fromJson(transaction))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Error fetching transactions: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cancel request (by buyer)
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _supabase
          .from('energy_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      _myRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error cancelling request: $e');
      return false;
    }
  }

  // Complete transaction
  Future<bool> completeTransaction(String transactionId, double energyTransferred) async {
    try {
      final totalAmount = energyTransferred * (_myActiveListing?.pricePerKwh ?? 0);
      
      await _supabase
          .from('energy_transactions')
          .update({
            'energy_transferred': energyTransferred,
            'total_amount': totalAmount,
            'end_time': DateTime.now().toIso8601String(),
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId);

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error completing transaction: $e');
      return false;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}