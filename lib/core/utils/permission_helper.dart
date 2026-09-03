import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Comprehensive helper managing Android runtime permissions
class PermissionHelper {
  /// Prompts all essential runtime permissions for storage, media, and background notifications
  static Future<void> requestInitialPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      // 1. Notification Permission (Android 13+ / API 33+)
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }

      // 2. Granular Media Permissions (Android 13+ / API 33+)
      final mediaPhotos = await Permission.photos.status;
      final mediaVideos = await Permission.videos.status;
      final mediaAudio = await Permission.audio.status;

      if (!mediaPhotos.isGranted || !mediaVideos.isGranted || !mediaAudio.isGranted) {
        await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
      }

      // 3. Legacy Storage Permission (Android 12 and below / API <= 32)
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        await Permission.storage.request();
      }
    } catch (_) {}
  }

  /// Verifies if storage / media write permission is granted before beginning download
  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final storage = await Permission.storage.status;
      if (storage.isGranted) return true;

      final videos = await Permission.videos.status;
      final photos = await Permission.photos.status;
      if (videos.isGranted || photos.isGranted) return true;

      final result = await [
        Permission.storage,
        Permission.videos,
        Permission.photos,
      ].request();

      return result.values.any((s) => s.isGranted);
    } catch (_) {
      return true;
    }
  }
}
