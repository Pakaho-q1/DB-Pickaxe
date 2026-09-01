import 'dart:io';

class CachePaths {
  static const String rootFolderName = '.pickaxe-cache';

  static Directory get rootDir {
    final currentPath = Directory.current.path;
    final dir = Directory('$currentPath\\$rootFolderName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Directory get databaseDir {
    final dir = Directory('${rootDir.path}\\database');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Directory get webviewDir {
    final dir = Directory('${rootDir.path}\\webview');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Directory get tempDir {
    final dir = Directory('${rootDir.path}\\temp');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }
}
