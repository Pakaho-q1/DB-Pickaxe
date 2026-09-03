import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/network/local_doh_proxy_service.dart';
import 'core/storage/hive_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/permission_helper.dart';
import 'features/main/presentation/screens/adaptive_main_screen.dart';
import 'platform/windows/windows_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Local Database
  await HiveService.init();

  // 2. Initialize Embedded Secure DoH Proxy (Bypasses ISP DNS Censorship)
  try {
    await LocalDohProxyService.start();
  } catch (_) {}

  // 3. Initialize Desktop Window & WebView2 (Windows only)
  if (Platform.isWindows) {
    await WindowsInitializer.init();
  }

  // 4. Request Standard Android Permissions (Storage, Media, Notification)
  if (Platform.isAndroid) {
    await PermissionHelper.requestInitialPermissions();
  }

  runApp(const ProviderScope(child: DBPickaxeApp()));
}

class DBPickaxeApp extends StatelessWidget {
  const DBPickaxeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AdaptiveMainScreen(),
    );
  }
}
