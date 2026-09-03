import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/network/local_doh_proxy_service.dart';
import '../../core/storage/cache_paths.dart';

class WindowsInitializer {
  /// Set to a non-null error message if WebView2 environment failed to initialize.
  static String? webView2InitError;

  static Future<void> init() async {
    if (Platform.isWindows) {
      final proxyArg = LocalDohProxyService.isRunning
          ? '--proxy-server="127.0.0.1:${LocalDohProxyService.port}" --proxy-bypass-list="<-loopback>" '
          : '';

      // Initialize WebView2 with dedicated UserDataPath inside .pickaxe-cache/webview
      try {
        await WebviewController.initializeEnvironment(
          userDataPath: CachePaths.webviewDir.path,
          additionalArguments:
              '$proxyArg'
              '--disable-web-security '
              '--disable-blink-features=AutomationControlled '
              '--user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.0" '
              '--enable-features=NetworkServiceInProcess '
              '--disable-site-isolation-trials '
              '--ignore-certificate-errors '
              '--allow-running-insecure-content',
        );
      } on PlatformException catch (e) {
        if (e.code == 'environment_already_initialized') {
          // WebView2 environment was already initialized (e.g. hot restart or
          // second process launch sharing the same runtime). This is fine — no action needed.
        } else {
          // A real initialization failure (WebView2 Runtime not installed, etc.)
          // Store the error so the UI layer can show a user-friendly dialog.
          webView2InitError =
              'WebView2 Runtime is not installed or could not be initialized.\n\n'
              'Please install the Microsoft Edge WebView2 Runtime from:\n'
              'https://developer.microsoft.com/en-us/microsoft-edge/webview2/\n\n'
              'Error detail: $e';
        }
      } catch (e) {
        webView2InitError =
            'WebView2 Runtime is not installed or could not be initialized.\n\n'
            'Please install the Microsoft Edge WebView2 Runtime from:\n'
            'https://developer.microsoft.com/en-us/microsoft-edge/webview2/\n\n'
            'Error detail: $e';
      }

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

      // setPreventClose must be called inside waitUntilReadyToShow after the
      // window is fully ready. Calling it before the window is shown can cause
      // spurious onWindowClose events to fire during startup.
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setPreventClose(true);
      });
    }
  }

  /// Call this after [runApp] to display a blocking error dialog if WebView2 is unavailable.
  static void showWebView2ErrorIfNeeded(BuildContext context) {
    final error = webView2InitError;
    if (error == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Browser Engine Unavailable'),
            ],
          ),
          content: Text(error, style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              child: const Text('Close App'),
              onPressed: () => exit(1),
            ),
          ],
        ),
      );
    });
  }
}

