import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/storage/cache_paths.dart';

class FfmpegInstallerService {
  // Reliable direct download link for portable Windows 64-bit FFmpeg binary
  static const String ffmpegDownloadUrl =
      'https://github.com/GyanD/codexffmpeg/releases/download/7.1/ffmpeg-7.1-essentials_build.zip';

  /// Resolves the usable FFmpeg executable path:
  /// 1. `.pickaxe-cache/bin/ffmpeg.exe`
  /// 2. System PATH `ffmpeg.exe` / `ffmpeg`
  static Future<String?> getFfmpegExecutablePath() async {
    // 1. Check local portable cache bin
    final localBin = File('${CachePaths.binDir.path}\\ffmpeg.exe');
    if (await localBin.exists()) {
      try {
        final res = await Process.run(localBin.path, ['-version']);
        if (res.exitCode == 0) return localBin.path;
      } catch (_) {}
    }

    // 2. Check System PATH
    try {
      final res = await Process.run('ffmpeg', ['-version']);
      if (res.exitCode == 0) return 'ffmpeg';
    } catch (_) {}

    return null;
  }

  /// Check if any usable FFmpeg is available
  static Future<bool> isFfmpegInstalled() async {
    final path = await getFfmpegExecutablePath();
    return path != null;
  }

  /// Download and set up portable FFmpeg into `.pickaxe-cache/bin/ffmpeg.exe`
  static Future<bool> downloadAndInstallPortableFfmpeg({
    required void Function(double progress, String statusMessage) onProgress,
    CancelToken? cancelToken,
  }) async {
    final binDir = CachePaths.binDir;
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final targetExe = File('${binDir.path}\\ffmpeg.exe');
    final zipFile = File('${CachePaths.tempDir.path}\\ffmpeg_download.zip');

    try {
      onProgress(0.05, 'Starting portable FFmpeg download...');

      final dio = Dio();
      await dio.download(
        ffmpegDownloadUrl,
        zipFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = (received / total) * 0.8;
            final mb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
            onProgress(p, 'Downloading FFmpeg ($mb MB / $totalMb MB)...');
          } else {
            onProgress(0.4, 'Downloading FFmpeg binary...');
          }
        },
      );

      onProgress(0.85, 'Extracting ffmpeg.exe to cache directory...');

      // Extract only ffmpeg.exe using Windows built-in PowerShell System.IO.Compression
      final zipPath = zipFile.path.replaceAll("'", "''");
      final destPath = binDir.path.replaceAll("'", "''");
      final extractCommand =
          "\$tempZip = '$zipPath'; \$dest = '$destPath'; Add-Type -AssemblyName System.IO.Compression.FileSystem; \$zip = [System.IO.Compression.ZipFile]::OpenRead(\$tempZip); foreach(\$entry in \$zip.Entries) { if(\$entry.Name -eq 'ffmpeg.exe') { [System.IO.Compression.ZipFileExtensions]::ExtractToFile(\$entry, \"\$dest\\ffmpeg.exe\", \$true); } }; \$zip.Dispose();";

      final process = await Process.run('powershell', ['-Command', extractCommand]);

      if (await targetExe.exists()) {
        onProgress(1.0, 'FFmpeg installation complete!');
        try {
          await zipFile.delete();
        } catch (_) {}
        return true;
      } else {
        throw Exception('Extraction failed: ${process.stderr}');
      }
    } catch (e) {
      onProgress(0.0, 'Installation error: $e');
      return false;
    }
  }
}
