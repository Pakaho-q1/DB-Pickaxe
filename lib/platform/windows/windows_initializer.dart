import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/storage/cache_paths.dart';

class WindowsInitializer {
  static Future<void> init() async {
    if (Platform.isWindows) {
      // 1. Initialize WebView2 with dedicated UserDataPath inside .pickaxe-cache/webview
      try {
        await WebviewController.initializeEnvironment(
          userDataPath: CachePaths.webviewDir.path,
        );
      } catch (_) {}

      // 2. Initialize Window Manager for desktop window frame
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1380, 850),
        minimumSize: Size(960, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'DB-Pickaxe - Browser & Media Sniffer',
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }
}
