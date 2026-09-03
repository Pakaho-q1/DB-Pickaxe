import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Centralized Single Source of Truth for Platform Capabilities, Policies & Features.
class PlatformCapabilities {
  /// Whether running on Android or iOS
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Whether running on Windows, macOS, or Linux
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Whether window docking, split-views, and custom window frames are supported
  static bool get supportsDesktopWindowControls => isDesktop;

  /// Whether physical keyboard shortcuts are relevant for the UI
  static bool get supportsKeyboardShortcuts => isDesktop;

  /// Returns the optimal User-Agent string for the current platform
  static String get defaultUserAgent => isMobile ? AppConstants.mobileUserAgent : AppConstants.defaultUserAgent;
}
