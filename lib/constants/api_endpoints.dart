// lib/constants/api_endpoints.dart
class ApiEndpoints {
  // Supabase Tables
  static const String energyListings = 'energy_listings';
  static const String energyRequests = 'energy_requests';
  static const String energyTransactions = 'energy_transactions';
  static const String profiles = 'profiles';
  
  // RPC Functions
  static const String getNearbyListings = 'get_nearby_listings';
  static const String getListingStats = 'get_listing_stats';
  
  // External APIs
  static const String osmrRouting = 'https://router.project-osrm.org/route/v1/driving/';
}