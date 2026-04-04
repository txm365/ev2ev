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

  // ── State ─────────────────────────────────────────────────────────────────
  List<EnergyListing> _nearbyListings = [];
  List<EnergyRequest> _myRequests = [];
  List<EnergyRequest> _receivedRequests = [];
  List<EnergyTransaction> _myTransactions = [];
  EnergyListing? _myActiveListing;
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;

  // ── Search / filter state ─────────────────────────────────────────────────
  String _searchQuery = '';
  String _selectedVehicleType = 'all';
  double _maxDistance = 10.0;
  double _maxPrice = 5.0;
  bool _showAvailableOnly = true;

  // ── Init guard — prevents double-init when widgets rebuild ────────────────
  bool _initialized = false;

  // ── Listing cache ─────────────────────────────────────────────────────────
  // Prevents re-fetching if the data is still fresh (within _cacheTtl).
  DateTime? _listingsCachedAt;
  static const Duration _cacheTtl = Duration(minutes: 5);
  bool get _cacheIsStale =>
      _listingsCachedAt == null ||
      DateTime.now().difference(_listingsCachedAt!) > _cacheTtl;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<EnergyListing> get nearbyListings => _getFilteredListings();

  /// Unfiltered list — used by the map to show ALL sellers regardless of
  /// the user's marketplace search/filter settings.
  List<EnergyListing> get allListingsUnfiltered =>
      List.unmodifiable(_nearbyListings);

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
  // LISTING MANAGEMENT — SELLER FUNCTIONALITY
  // ============================================================================

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

      final position = await getCurrentLocation();
      if (position == null) {
        _setError('Unable to get current location');
        return false;
      }

      final existingListing = await _supabase
          .from('energy_listings')
          .select()
          .eq('seller_id', userId)
          .or('status.eq.available,status.eq.paused')
          .maybeSingle();

      if (existingListing != null) {
        _setError(
            'You already have an active listing. Delete or edit your current listing first.');
        return false;
      }

      final now = DateTime.now();
      final listingData = {
        'seller_id': userId,
        'price_per_kwh': pricePerKwh,
        'available_energy': availableEnergy,
        'min_energy_sale': minEnergySale,
        'max_energy_sale': maxEnergySale,
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'location_address': 'Current Location',
        'vehicle_type': vehicleType,
        'connector_type': connectorType,
        'availability_start': now.toIso8601String(),
        'availability_end': availabilityEnd?.toIso8601String(),
        'status': 'available',
        'description': description,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('energy_listings')
          .insert(listingData)
          .select()
          .single();

      _myActiveListing = EnergyListing.fromJson(response);
      _listenForReceivedRequests();

      _setError(null);
      notifyListeners();

      debugPrint('✅ Energy listing created: ${_myActiveListing!.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating listing: $e');
      _setError('Failed to create listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

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

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (pricePerKwh != null) updateData['price_per_kwh'] = pricePerKwh;
      if (availableEnergy != null) updateData['available_energy'] = availableEnergy;
      if (minEnergySale != null) updateData['min_energy_sale'] = minEnergySale;
      if (maxEnergySale != null) updateData['max_energy_sale'] = maxEnergySale;
      if (vehicleType != null) updateData['vehicle_type'] = vehicleType;
      if (connectorType != null) updateData['connector_type'] = connectorType;
      if (availabilityEnd != null) {
        updateData['availability_end'] = availabilityEnd.toIso8601String();
      }
      if (description != null) updateData['description'] = description;

      final response = await _supabase
          .from('energy_listings')
          .update(updateData)
          .eq('id', listingId)
          .eq('seller_id', userId)
          .select()
          .single();

      _myActiveListing = EnergyListing.fromJson(response);
      _setError(null);
      notifyListeners();

      debugPrint('✅ Energy listing updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating listing: $e');
      _setError('Failed to update listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateListingStatus(String status) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null || _myActiveListing == null) {
        _setError('No active listing found');
        return false;
      }

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

  Future<bool> deleteMyListing() async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null || _myActiveListing == null) {
        _setError('No active listing found');
        return false;
      }

      final pendingRequests = await _supabase
          .from('energy_requests')
          .select('id')
          .eq('listing_id', _myActiveListing!.id)
          .eq('status', 'pending');

      if (pendingRequests.isNotEmpty) {
        _setError(
            'Cannot delete listing with pending requests. Please respond to all requests first.');
        return false;
      }

      await _supabase
          .from('energy_listings')
          .delete()
          .eq('id', _myActiveListing!.id)
          .eq('seller_id', userId);

      _myActiveListing = null;
      _receivedRequests.clear();
      _setError(null);
      notifyListeners();

      debugPrint('✅ Listing deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting listing: $e');
      _setError('Failed to delete listing: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> respondToRequest(String requestId, String status) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      if (!['accepted', 'rejected'].contains(status)) {
        _setError('Invalid response status. Must be: accepted or rejected');
        return false;
      }

      await _supabase
          .from('energy_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      if (status == 'accepted') {
        final request =
            _receivedRequests.firstWhere((r) => r.id == requestId);
        await _supabase.from('energy_transactions').insert({
          'request_id': requestId,
          'seller_id': userId,
          'buyer_id': request.buyerId,
          'seller_location_lat': _myActiveListing?.locationLat,
          'seller_location_lng': _myActiveListing?.locationLng,
          'buyer_location_lat': request.buyerLocationLat,
          'buyer_location_lng': request.buyerLocationLng,
          'status': 'pending',
          'payment_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

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
  // BUYER FUNCTIONALITY — NEARBY LISTINGS WITH CACHE
  // ============================================================================

  /// Fetch nearby energy listings.
  ///
  /// Set [forceRefresh] = true to bypass the 5-minute cache and always hit
  /// the database. Used by the map refresh button and [refreshAll].
  Future<void> getNearbyListings({
    double radiusKm = 15.0,
    bool forceRefresh = false,
  }) async {
    // ── Cache guard ──────────────────────────────────────────────────────────
    if (!forceRefresh && !_cacheIsStale && _nearbyListings.isNotEmpty) {
      debugPrint(
          '📦 Using cached listings (${_nearbyListings.length} items, '
          '${DateTime.now().difference(_listingsCachedAt!).inSeconds}s old)');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      debugPrint(
          '🔍 Fetching listings (cache ${_cacheIsStale ? "stale" : "empty"})...');

      final position = _currentPosition ?? await getCurrentLocation();
      if (position == null) {
        _setError('Could not get current location');
        debugPrint('❌ No location available');
        return;
      }

      debugPrint(
          '📍 Location: ${position.latitude}, ${position.longitude}');

      // Try optimised RPC first
      try {
        debugPrint('🔄 Trying RPC get_nearby_listings...');
        final response = await _supabase.rpc('get_nearby_listings', params: {
          'user_lat': position.latitude,
          'user_lng': position.longitude,
          'radius_km': radiusKm,
          'current_user_id': currentUserId ?? '',
        });

        if (response != null && response is List) {
          debugPrint('✅ RPC returned ${response.length} listings');
          _nearbyListings = response.map<EnergyListing>((listing) {
            listing['seller_name'] =
                listing['seller_name'] ?? 'Energy Provider';
            return EnergyListing.fromJson(listing);
          }).toList();
        } else {
          throw Exception('RPC unavailable, falling back');
        }
      } catch (e) {
        // ── Fallback: plain SQL query ────────────────────────────────────────
        debugPrint('⚠️ RPC failed, using fallback: $e');
        final fallbackResponse = await _supabase
            .from('energy_listings')
            .select('*')
            .eq('status', 'available')
            .neq('seller_id', currentUserId ?? '');

        debugPrint(
            '📊 Fallback returned ${fallbackResponse.length} listings');

        _nearbyListings = fallbackResponse.map<EnergyListing>((listing) {
          final sellerLat = listing['location_lat'] as double;
          final sellerLng = listing['location_lng'] as double;
          final distance = _calculateDistance(
            position.latitude,
            position.longitude,
            sellerLat,
            sellerLng,
          );
          listing['distance'] = distance;
          listing['seller_name'] = 'Energy Provider';
          return EnergyListing.fromJson(listing);
        }).where((l) => l.distance != null && l.distance! <= radiusKm).toList();

        _nearbyListings.sort(
            (a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      }

      // ── Stamp the cache ──────────────────────────────────────────────────
      _listingsCachedAt = DateTime.now();

      _setError(null);
      notifyListeners();

      debugPrint(
          '✅ ${_nearbyListings.length} listings within ${radiusKm}km');
      for (var l in _nearbyListings) {
        debugPrint(
            '  - ${l.sellerName}: ${l.distance?.toStringAsFixed(1)}km, '
            'R${l.pricePerKwh}/kWh, ${l.availableEnergy}kWh');
      }
    } catch (e) {
      debugPrint('❌ Error getting listings: $e');
      _setError('Failed to load nearby listings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // ENERGY REQUESTS — BUYER FUNCTIONALITY
  // ============================================================================

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
        debugPrint('❌ User not authenticated');
        return false;
      }

      if (listingId.isEmpty) {
        _setError('Invalid listing ID');
        debugPrint('❌ Empty listing ID');
        return false;
      }

      debugPrint('🔄 Creating energy request...');
      debugPrint('   Listing: $listingId | User: $userId');
      debugPrint('   Energy: $requestedEnergy kWh | Price: R$offeredPricePerKwh');

      final position = await getCurrentLocation();
      if (position == null) {
        _setError(
            'Unable to get current location. Please enable location services.');
        debugPrint('❌ Could not get location');
        return false;
      }

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

      final response = await _supabase
          .from('energy_requests')
          .insert(requestData)
          .select()
          .single();

      debugPrint('✅ Request created: ${response['id']}');

      await getMyRequests();
      _setError(null);
      notifyListeners();

      return true;
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase error: ${e.message} (${e.code})');
      String userMessage = 'Failed to create energy request: ';
      if (e.code == '23505') {
        userMessage +=
            'You already have a pending request for this listing.';
      } else if (e.code == '23503') {
        userMessage += 'The listing is no longer available.';
      } else if (e.code == '23502') {
        userMessage += 'Missing required information. Please try again.';
      } else {
        userMessage += e.message;
      }
      _setError(userMessage);
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error creating request: $e');
      _setError('Failed to create energy request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = currentUserId;
      if (userId == null) {
        _setError('User not authenticated');
        return false;
      }

      await _supabase
          .from('energy_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('buyer_id', userId);

      await getMyRequests();
      _setError(null);
      notifyListeners();

      debugPrint('✅ Request cancelled');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling request: $e');
      _setError('Failed to cancel energy request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // FETCHING DATA — NO auth.users ACCESS
  // ============================================================================

  /// Buyer's own requests with seller names and locations.
  Future<void> getMyRequests() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('⚠️ Cannot get requests: not authenticated');
        return;
      }

      debugPrint('🔍 Loading user requests...');

      // Step 1: requests only
      final requestsResponse = await _supabase
          .from('energy_requests')
          .select('*')
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      if (requestsResponse.isEmpty) {
        _myRequests = [];
        notifyListeners();
        return;
      }

      debugPrint('✅ Step 1: ${requestsResponse.length} requests');

      // Step 2: fetch listings for location / seller id
      final listingIds = requestsResponse
          .map((r) => r['listing_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, dynamic> listingsMap = {};
      if (listingIds.isNotEmpty) {
        try {
          final listingsResponse = await _supabase
              .from('energy_listings')
              .select('id, seller_id, location_lat, location_lng')
              .inFilter('id', listingIds);
          for (var l in listingsResponse) {
            listingsMap[l['id']] = l;
          }
          debugPrint('✅ Step 2: ${listingsResponse.length} listings');
        } catch (e) {
          debugPrint('⚠️ Could not fetch listings: $e');
        }
      }

      // Step 3: seller profiles
      final sellerIds = listingsMap.values
          .map((l) => l['seller_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> sellerNames = {};
      if (sellerIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('user_profiles')
              .select('user_id, first_name, last_name')
              .inFilter('user_id', sellerIds);
          for (var p in profiles) {
            final uid = p['user_id'];
            final name =
                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            sellerNames[uid] = name.isNotEmpty ? name : 'Seller';
          }
          debugPrint('✅ Step 3: ${profiles.length} seller profiles');
        } catch (e) {
          debugPrint('⚠️ Could not fetch seller names: $e');
        }
      }

      // Step 4: combine
      _myRequests = requestsResponse.map<EnergyRequest>((request) {
        String sellerName = 'Seller';
        double? sellerLat;
        double? sellerLng;

        try {
          final lid = request['listing_id'];
          if (lid != null && listingsMap.containsKey(lid)) {
            final listing = listingsMap[lid];
            final lat = listing['location_lat'];
            final lng = listing['location_lng'];
            sellerLat = (lat is num) ? lat.toDouble() : null;
            sellerLng = (lng is num) ? lng.toDouble() : null;

            final sid = listing['seller_id'];
            if (sid != null && sellerNames.containsKey(sid)) {
              sellerName = sellerNames[sid]!;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error processing request ${request['id']}: $e');
        }

        request['seller_name'] = sellerName;
        request['seller_location_lat'] = sellerLat;
        request['seller_location_lng'] = sellerLng;
        return EnergyRequest.fromJson(request);
      }).toList();

      debugPrint('✅ ${_myRequests.length} requests loaded');
      notifyListeners();
    } catch (e, st) {
      debugPrint('❌ Error loading requests: $e\n$st');
      _setError('Failed to load your requests: $e');
      _myRequests = [];
      notifyListeners();
    }
  }

  Future<void> getMyTransactions() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      debugPrint('🔍 Loading transactions...');

      final response = await _supabase
          .from('energy_transactions')
          .select('*')
          .or('seller_id.eq.$userId,buyer_id.eq.$userId')
          .order('created_at', ascending: false);

      final allUserIds = <String>{};
      for (var t in response) {
        if (t['seller_id'] != null) allUserIds.add(t['seller_id']);
        if (t['buyer_id'] != null) allUserIds.add(t['buyer_id']);
      }

      Map<String, String> userNames = {};
      if (allUserIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('user_profiles')
              .select('user_id, first_name, last_name')
              .inFilter('user_id', allUserIds.toList());
          for (var p in profiles) {
            final uid = p['user_id'];
            final name =
                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            userNames[uid] = name.isNotEmpty ? name : 'User';
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch user names: $e');
        }
      }

      _myTransactions = response.map<EnergyTransaction>((t) {
        String sellerName = 'Seller';
        String buyerName = 'Buyer';
        try {
          if (t['seller_id'] != null && userNames.containsKey(t['seller_id'])) {
            sellerName = userNames[t['seller_id']]!;
          }
        } catch (_) {}
        try {
          if (t['buyer_id'] != null && userNames.containsKey(t['buyer_id'])) {
            buyerName = userNames[t['buyer_id']]!;
          }
        } catch (_) {}
        t['seller_name'] = sellerName;
        t['buyer_name'] = buyerName;
        return EnergyTransaction.fromJson(t);
      }).toList();

      debugPrint('✅ ${_myTransactions.length} transactions loaded');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');
    }
  }

  Future<bool> completeTransaction(
      String transactionId, double energyTransferred) async {
    try {
      await _supabase.from('energy_transactions').update({
        'energy_transferred': energyTransferred,
        'status': 'completed',
        'end_time': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);
      await getMyTransactions();
      return true;
    } catch (e) {
      debugPrint('Error completing transaction: $e');
      return false;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * (math.pi / 180);

  Future<void> _loadReceivedRequests() async {
    try {
      if (_myActiveListing == null) return;

      debugPrint('🔍 Loading received requests...');

      final response = await _supabase
          .from('energy_requests')
          .select('*')
          .eq('listing_id', _myActiveListing!.id)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        _receivedRequests = [];
        notifyListeners();
        return;
      }

      debugPrint('✅ Step 1: ${response.length} received requests');

      final buyerIds = response
          .map((r) => r['buyer_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> buyerNames = {};
      if (buyerIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('user_profiles')
              .select('user_id, first_name, last_name')
              .inFilter('user_id', buyerIds);
          for (var p in profiles) {
            final uid = p['user_id'];
            final name =
                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            buyerNames[uid] = name.isNotEmpty ? name : 'Buyer';
          }
          debugPrint('✅ Step 2: ${profiles.length} buyer profiles');
        } catch (e) {
          debugPrint('⚠️ Could not fetch buyer names: $e');
        }
      }

      _receivedRequests = response.map<EnergyRequest>((request) {
        String buyerName = 'Buyer';
        try {
          final bid = request['buyer_id'];
          if (bid != null && buyerNames.containsKey(bid)) {
            buyerName = buyerNames[bid]!;
          }
        } catch (e) {
          debugPrint('⚠️ Error processing request ${request['id']}: $e');
        }
        request['buyer_name'] = buyerName;
        return EnergyRequest.fromJson(request);
      }).toList();

      debugPrint('✅ ${_receivedRequests.length} received requests loaded');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading received requests: $e');
      _receivedRequests = [];
      notifyListeners();
    }
  }

  void _listenForReceivedRequests() {
    if (_myActiveListing == null) return;
    _supabase
        .from('energy_requests')
        .stream(primaryKey: ['id'])
        .eq('listing_id', _myActiveListing!.id)
        .listen((_) => _loadReceivedRequests());
  }

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
      filtered = filtered.where((l) {
        final q = _searchQuery.toLowerCase();
        return l.sellerName?.toLowerCase().contains(q) == true ||
            l.description?.toLowerCase().contains(q) == true ||
            l.vehicleType.toLowerCase().contains(q) ||
            l.connectorType.toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedVehicleType != 'all') {
      filtered = filtered
          .where((l) =>
              l.vehicleType.toLowerCase() ==
              _selectedVehicleType.toLowerCase())
          .toList();
    }

    filtered = filtered
        .where((l) => l.distance == null || l.distance! <= _maxDistance)
        .toList();

    filtered =
        filtered.where((l) => l.pricePerKwh <= _maxPrice).toList();

    if (_showAvailableOnly) {
      filtered =
          filtered.where((l) => l.status == 'available').toList();
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

  /// Refresh everything — always bypasses the listing cache.
  Future<void> refreshAll() async {
    await getCurrentLocation();
    await getNearbyListings(forceRefresh: true); // always hits DB on manual refresh
    await getMyRequests();
    await _loadMyActiveListing();
    if (_myActiveListing != null) {
      await _loadReceivedRequests();
    }
  }

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

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚡ MarketplaceProvider already initialized — skipping');
      return;
    }
    _initialized = true;
    try {
      debugPrint('🚀 Initializing MarketplaceProvider...');
      await getCurrentLocation();
      await _loadMyActiveListing();
      await getNearbyListings();
      await getMyRequests();
      if (_myActiveListing != null) {
        _listenForReceivedRequests();
      }
      debugPrint(
          '✅ MarketplaceProvider ready — requests: ${_myRequests.length}');
    } catch (e) {
      debugPrint('Marketplace init error: $e');
    }
  }
}