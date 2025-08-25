
// lib/constants/app_constants.dart
class AppConstants {
  // App Information
  static const String appName = 'EV2EV Energy Trading';
  static const String appVersion = '1.0.0';
  static const String companyName = 'EV2EV Solutions';
  
  // API Configuration
  static const int apiTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;
  
  // Marketplace Configuration
  static const double defaultSearchRadius = 15.0; // kilometers
  static const double maxSearchRadius = 50.0;
  static const double minSearchRadius = 1.0;
  
  // Energy Configuration
  static const double maxEnergyListing = 100.0; // kWh
  static const double minEnergyListing = 1.0;
  static const double maxPricePerKwh = 20.0; // R/kWh
  static const double minPricePerKwh = 0.50;
  
  // Location Configuration
  static const double locationUpdateThreshold = 100.0; // meters
  static const int locationTimeoutSeconds = 10;
  
  // UI Configuration
  static const int debounceDelayMs = 500;
  static const int animationDurationMs = 300;
  static const double defaultBorderRadius = 8.0;
  static const double cardElevation = 2.0;
  
  // Database Configuration
  static const int maxListingsPerUser = 5;
  static const int maxActiveRequests = 10;
  static const int transactionHistoryLimit = 50;
}