import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformHelper {
  /// Returns `true` if running on a mobile platform (Android or iOS)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Returns `true` if running on a desktop platform (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Returns `true` if current screen width is narrow (e.g. mobile phone in portrait or compact window)
  static bool isCompact(BuildContext context) {
    return MediaQuery.of(context).size.width < 720;
  }
}
