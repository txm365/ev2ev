// lib/services/auth_service.dart
//
// Wraps local_auth v2 to gate sensitive operations behind device biometric or PIN.
// Compatible with Dart SDK ^3.7 / local_auth ^2.3.0.
//
// Usage:
//   final ok = await AuthService.instance.authenticate('Confirm payment');
//   if (!ok) return;
//
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  // ── Capability checks ──────────────────────────────────────────────────────

  Future<bool> get isAvailable async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Prompts the user to authenticate using biometric or device PIN/pattern.
  /// Returns true if authenticated, false if cancelled or failed.
  Future<bool> authenticate(String reason) async {
    try {
      final available = await isAvailable;
      if (!available) return true; // no lock screen — device itself unsecured

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,       // allow PIN/pattern fallback
          stickyAuth: true,           // keep prompt open if user switches apps
          sensitiveTransaction: true, // Android shows financial warning
        ),
      );
    } on PlatformException catch (e) {
      // Device has no biometric/PIN enrolled — allow through
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}