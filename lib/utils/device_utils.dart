// lib/utils/device_utils.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class DeviceUtils {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  
  static String get platformName {
    if (kIsWeb) return 'Web';
    return Platform.operatingSystem;
  }
}