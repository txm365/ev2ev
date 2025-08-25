// lib/constants/app_strings.dart
class AppStrings {
  // General
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String create = 'Create';
  static const String update = 'Update';
  static const String refresh = 'Refresh';
  
  // Authentication
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String signOut = 'Sign Out';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  
  // Marketplace
  static const String marketplace = 'Energy Marketplace';
  static const String buyEnergy = 'Buy Energy';
  static const String sellEnergy = 'Sell Energy';
  static const String myRequests = 'My Requests';
  static const String history = 'History';
  static const String nearbyListings = 'Nearby Listings';
  static const String createListing = 'Create Listing';
  static const String editListing = 'Edit Listing';
  static const String requestEnergy = 'Request Energy';
  static const String energyProvider = 'Energy Provider';
  
  // Listing Details
  static const String pricePerKwh = 'Price per kWh';
  static const String availableEnergy = 'Available Energy';
  static const String minimumSale = 'Minimum Sale';
  static const String maximumSale = 'Maximum Sale';
  static const String vehicleType = 'Vehicle Type';
  static const String connectorType = 'Connector Type';
  static const String availability = 'Availability';
  static const String description = 'Description';
  static const String location = 'Location';
  
  // Status Messages
  static const String available = 'Available';
  static const String paused = 'Paused';
  static const String pending = 'Pending';
  static const String accepted = 'Accepted';
  static const String rejected = 'Rejected';
  static const String cancelled = 'Cancelled';
  static const String completed = 'Completed';
  
  // Error Messages
  static const String errorGeneral = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorLocation = 'Unable to get your location.';
  static const String errorPermission = 'Permission denied.';
  static const String errorAuthentication = 'Authentication failed.';
  static const String errorNotFound = 'Resource not found.';
  static const String errorInvalidInput = 'Invalid input provided.';
  
  // Success Messages
  static const String listingCreated = 'Energy listing created successfully!';
  static const String listingUpdated = 'Listing updated successfully!';
  static const String listingDeleted = 'Listing deleted successfully!';
  static const String requestSent = 'Energy request sent successfully!';
  static const String requestAccepted = 'Request accepted successfully!';
  static const String requestRejected = 'Request rejected successfully!';
}