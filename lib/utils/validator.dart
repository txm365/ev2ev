// lib/utils/validators.dart
class Validators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  static String? validateEnergyAmount(String? amount) {
    if (amount == null || amount.isEmpty) {
      return 'Energy amount is required';
    }
    
    final energy = double.tryParse(amount);
    if (energy == null || energy <= 0) {
      return 'Please enter a valid energy amount';
    }
    
    if (energy > 100) {
      return 'Energy amount seems too high';
    }
    
    return null;
  }

  static String? validatePrice(String? price) {
    if (price == null || price.isEmpty) {
      return 'Price is required';
    }
    
    final priceValue = double.tryParse(price);
    if (priceValue == null || priceValue <= 0) {
      return 'Please enter a valid price';
    }
    
    if (priceValue > 20) {
      return 'Price seems unusually high';
    }
    
    return null;
  }

  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }
    
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }
}