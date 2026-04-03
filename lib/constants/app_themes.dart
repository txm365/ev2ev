// lib/constants/app_themes.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_constants.dart';

class AppThemes {
  // ─── Dark mode surface colours ────────────────────────────────────────────
  static const Color _darkBackground   = Color(0xFF121212);
  static const Color _darkSurface      = Color(0xFF1E1E1E);
  static const Color _darkSurfaceVar   = Color(0xFF2C2C2C);
  static const Color _darkBorder       = Color(0xFF3A3A3A);
  static const Color _darkOnSurface    = Color(0xFFE0E0E0);

  // ─── Light theme ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0FCDEB),
        brightness: Brightness.light,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFC4ECB1),
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardTheme(
        elevation: AppConstants.cardElevation,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppConstants.defaultBorderRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.textOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide:
              const BorderSide(color: AppColors.borderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: AppColors.borderError),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        fillColor: AppColors.surface,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: AppColors.textOnPrimary,
        unselectedLabelColor: AppColors.textOnPrimary,
        indicatorColor: AppColors.textOnPrimary,
      ),
    );
  }

  // ─── Dark theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50),
        brightness: Brightness.dark,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
      ),

      // Scaffold & canvas
      scaffoldBackgroundColor: _darkBackground,
      canvasColor: _darkBackground,

      // Cards
      cardTheme: const CardTheme(
        elevation: AppConstants.cardElevation,
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppConstants.defaultBorderRadius),
          ),
        ),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _darkOnSurface),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreenLight,
          side: const BorderSide(color: AppColors.primaryGreenLight),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGreenLight,
        ),
      ),

      // Inputs — dark fill so no white TextField box
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(
              color: AppColors.primaryGreenLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        filled: true,
        fillColor: _darkSurfaceVar,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        labelStyle: const TextStyle(color: _darkOnSurface),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Tabs
      tabBarTheme: const TabBarTheme(
        labelColor: _darkOnSurface,
        unselectedLabelColor: Color(0xFF9E9E9E),
        indicatorColor: AppColors.primaryGreenLight,
      ),

      // Dividers & outlines
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: AppColors.primaryGreenLight,
        unselectedItemColor: Color(0xFF9E9E9E),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceVar,
        labelStyle: const TextStyle(color: _darkOnSurface),
        side: const BorderSide(color: _darkBorder),
      ),

      // Dialogs
      dialogTheme: const DialogTheme(
        backgroundColor: _darkSurface,
        titleTextStyle: TextStyle(
            color: _darkOnSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: _darkOnSurface),
      ),

      // SnackBar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _darkSurfaceVar,
        contentTextStyle: TextStyle(color: _darkOnSurface),
      ),

      // Icon
      iconTheme: const IconThemeData(color: _darkOnSurface),

      // Text
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(color: _darkOnSurface),
        bodyMedium: TextStyle(color: _darkOnSurface),
        bodySmall:  TextStyle(color: Color(0xFF9E9E9E)),
        titleLarge: TextStyle(color: _darkOnSurface, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: _darkOnSurface),
        titleSmall:  TextStyle(color: _darkOnSurface),
        headlineSmall: TextStyle(color: _darkOnSurface, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: _darkOnSurface, fontWeight: FontWeight.bold),
        labelLarge: TextStyle(color: _darkOnSurface),
        labelMedium: TextStyle(color: Color(0xFF9E9E9E)),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}