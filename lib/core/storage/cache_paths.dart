import 'dart:io';

/// Provides resolved [Directory] references for the application's cache folders.
///
/// Getters are **pure** — they return a [Directory] without creating it.
/// Call [ensureDirectoriesExist] once at startup to create all required folders.
class CachePaths {
  static const String rootFolderName = '.pickaxe-cache';

  static Directory get rootDir {
    final currentPath = Directory.current.path;
    return Directory('$currentPath\\$rootFolderName');
  }

  static Directory get databaseDir => Directory('${rootDir.path}\\database');
  static Directory get webviewDir  => Directory('${rootDir.path}\\webview');
  static Directory get tempDir     => Directory('${rootDir.path}\\temp');
  static Directory get binDir      => Directory('${rootDir.path}\\bin');

  /// Creates all cache directories if they do not already exist.
  /// Call this **once** during app startup (before accessing any cache path).
  static void ensureDirectoriesExist() {
    for (final dir in [rootDir, databaseDir, webviewDir, tempDir, binDir]) {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }
  }
}

