import 'dart:io';
import 'package:open_filex/open_filex.dart';

class FileLauncherHelper {
  /// Opens the downloaded file in the native file explorer or external app
  static Future<void> openFileOrLocation(String filePath) async {
    if (filePath.isEmpty) return;

    try {
      final file = File(filePath);
      if (Platform.isWindows) {
        if (await file.exists()) {
          await Process.run('explorer.exe', ['/select,', filePath]);
        } else if (await file.parent.exists()) {
          await Process.run('explorer.exe', [file.parent.path]);
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (await file.exists()) {
          await OpenFilex.open(filePath);
        }
      } else if (Platform.isMacOS) {
        if (await file.exists()) {
          await Process.run('open', ['-R', filePath]);
        }
      } else if (Platform.isLinux) {
        if (await file.exists()) {
          await Process.run('xdg-open', [file.parent.path]);
        }
      }
    } catch (_) {}
  }
}
