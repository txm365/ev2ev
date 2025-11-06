// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/energy_listing.dart';
import '../models/energy_request.dart';
import '../models/energy_transaction.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => _client;
  String? get currentUserId => _client.auth.currentUser?.id;

  // Authentication methods
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Energy Listings CRUD
  Future<List<EnergyListing>> getNearbyListings(
    double lat, 
    double lng, 
    double radiusKm
  ) async {
    final response = await _client.rpc('get_nearby_listings', params: {
      'user_lat': lat,
      'user_lng': lng,
      'radius_km': radiusKm,
      'current_user_id': currentUserId ?? '',
    });
    
    return (response as List).map((listing) => EnergyListing.fromJson(listing)).toList();
  }

  Future<EnergyListing> createListing(Map<String, dynamic> listingData) async {
    final response = await _client
        .from('energy_listings')
        .insert(listingData)
        .select()
        .single();
    
    return EnergyListing.fromJson(response);
  }

  Future<EnergyListing> updateListing(String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('energy_listings')
        .update(updates)
        .eq('id', id)
        .eq('seller_id', currentUserId!)
        .select()
        .single();
    
    return EnergyListing.fromJson(response);
  }

  Future<void> deleteListing(String id) async {
    await _client
        .from('energy_listings')
        .delete()
        .eq('id', id)
        .eq('seller_id', currentUserId!);
  }

  // Energy Requests
  Future<EnergyRequest> createRequest(Map<String, dynamic> requestData) async {
    final response = await _client
        .from('energy_requests')
        .insert(requestData)
        .select()
        .single();
    
    return EnergyRequest.fromJson(response);
  }

  Future<List<EnergyRequest>> getMyRequests() async {
    final response = await _client
        .from('energy_requests')
        .select('*')
        .eq('buyer_id', currentUserId!)
        .order('created_at', ascending: false);
    
    return (response as List).map((request) => EnergyRequest.fromJson(request)).toList();
  }

  Future<List<EnergyRequest>> getReceivedRequests(String listingId) async {
    final response = await _client
        .from('energy_requests')
        .select('*')
        .eq('listing_id', listingId)
        .order('created_at', ascending: false);
    
    return (response as List).map((request) => EnergyRequest.fromJson(request)).toList();
  }

  // Energy Transactions
  Future<List<EnergyTransaction>> getMyTransactions() async {
    final response = await _client
        .from('energy_transactions')
        .select('*')
        .or('seller_id.eq.$currentUserId,buyer_id.eq.$currentUserId')
        .order('created_at', ascending: false);
    
    return (response as List).map((transaction) => EnergyTransaction.fromJson(transaction)).toList();
  }
}
