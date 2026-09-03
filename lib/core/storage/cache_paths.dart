import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Provides resolved [Directory] references for the application's cache and database folders.
class CachePaths {
  static const String rootFolderName = '.pickaxe-cache';
  static Directory? _resolvedRoot;

  /// Initializes root path based on platform and ensures all subdirectories exist.
  static Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final docDir = await getApplicationDocumentsDirectory();
      _resolvedRoot = Directory('${docDir.path}/$rootFolderName');
    } else {
      final currentPath = Directory.current.path;
      _resolvedRoot = Directory('$currentPath\\$rootFolderName');
    }
    ensureDirectoriesExist();
  }

  static Directory get rootDir {
    if (_resolvedRoot != null) return _resolvedRoot!;
    if (Platform.isAndroid || Platform.isIOS) {
      return Directory('/data/user/0/com.dbpickaxe.db_pickaxe/app_flutter/$rootFolderName');
    }
    final currentPath = Directory.current.path;
    return Directory('$currentPath\\$rootFolderName');
  }

  static Directory get databaseDir => Directory('${rootDir.path}${Platform.isWindows ? r'\' : '/'}database');
  static Directory get webviewDir  => Directory('${rootDir.path}${Platform.isWindows ? r'\' : '/'}webview');
  static Directory get tempDir     => Directory('${rootDir.path}${Platform.isWindows ? r'\' : '/'}temp');
  static Directory get binDir      => Directory('${rootDir.path}${Platform.isWindows ? r'\' : '/'}bin');

  /// Creates all cache directories if they do not already exist.
  static void ensureDirectoriesExist() {
    for (final dir in [rootDir, databaseDir, webviewDir, tempDir, binDir]) {
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
    }
  }
}
