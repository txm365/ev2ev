// lib/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryGreenDark = Color(0xFF388E3C);
  static const Color primaryGreenLight = Color(0xFF81C784);
  
  // Secondary Colors
  static const Color secondaryBlue = Color(0xFF2196F3);
  static const Color secondaryBlueDark = Color(0xFF1976D2);
  static const Color secondaryBlueLight = Color(0xFF64B5F6);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF1976D2);
  
  // Neutral Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF212121);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;
  
  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderFocused = primaryGreen;
  static const Color borderError = error;
  
  // Energy Status Colors
  static const Color energyAvailable = success;
  static const Color energyPaused = warning;
  static const Color energyInactive = Color(0xFF9E9E9E);
  
  // Request Status Colors
  static const Color requestPending = warning;
  static const Color requestAccepted = success;
  static const Color requestRejected = error;
  static const Color requestCancelled = Color(0xFF9E9E9E);
}