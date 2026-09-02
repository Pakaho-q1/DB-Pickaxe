import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/constants/app_constants.dart';
import 'ffmpeg_installer_service.dart';

class FfmpegStreamService {
  static final Map<String, Process> _runningProcesses = {};

  static Future<bool> isFfmpegAvailable() async {
    return await FfmpegInstallerService.isFfmpegInstalled();
  }

  static Future<void> downloadHlsStream({
    required String taskId,
    required String m3u8Url,
    required String outputPath,
    String? refererUrl,
    Map<String, String>? customHeaders,
    required void Function(double progress, double speedBytesPerSec, String statusMessage) onProgress,
  }) async {
    final ffmpegExe = await FfmpegInstallerService.getFfmpegExecutablePath();
    if (ffmpegExe == null) {
      throw Exception(
        'FFmpeg executable not found. Please install or download Portable FFmpeg in App Settings.',
      );
    }

    // Ensure output file ends with .mp4
    var targetPath = outputPath;
    if (!targetPath.toLowerCase().endsWith('.mp4')) {
      final dotIndex = targetPath.lastIndexOf('.');
      if (dotIndex != -1) {
        targetPath = '${targetPath.substring(0, dotIndex)}.mp4';
      } else {
        targetPath = '$targetPath.mp4';
      }
    }

    // Prepare headers string for FFmpeg
    final headersList = <String>[
      'User-Agent: ${AppConstants.defaultUserAgent}',
      if (refererUrl != null && refererUrl.isNotEmpty) 'Referer: $refererUrl',
    ];
    if (customHeaders != null) {
      customHeaders.forEach((k, v) {
        headersList.add('$k: $v');
      });
    }
    final headersArg = '${headersList.join('\r\n')}\r\n';

    final args = [
      '-y', // Overwrite output files
      '-headers', headersArg,
      '-i', m3u8Url,
      '-c', 'copy', // Direct stream copy (lossless, ultra fast)
      '-bsf:a', 'aac_adtstoasc',
      targetPath,
    ];

    try {
      final process = await Process.start(ffmpegExe, args);
      _runningProcesses[taskId] = process;

      // FFmpeg outputs progress to stderr
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        // Check for DRM encryption warning
        if (line.contains('SAMPLE-AES') || line.contains('DRM') || line.contains('key is invalid')) {
          onProgress(
            0.1,
            0,
            'Warning: Stream appears to have DRM / encryption protection.',
          );
        }

        // Parse time and speed from lines like: size= 5120kB time=00:01:23.45 bitrate= 2500.0kbits/s speed= 5.2x
        if (line.contains('time=') && line.contains('speed=')) {
          final timeMatch = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d+)').firstMatch(line);
          final speedMatch = RegExp(r'speed=\s*([\d\.]+)x').firstMatch(line);

          final timeStr = timeMatch?.group(1) ?? '';
          final speedStr = speedMatch?.group(1) ?? '1.0';
          final speedMultiplier = double.tryParse(speedStr) ?? 1.0;

          // Estimated speed ~ 1.5MB * multiplier
          final estimatedSpeed = speedMultiplier * 1024 * 1024;

          onProgress(
            0.5, // Indeterminate progress for live/stream
            estimatedSpeed,
            'Streaming ($timeStr @ ${speedMultiplier}x)...',
          );
        }
      });

      final exitCode = await process.exitCode;
      _runningProcesses.remove(taskId);

      if (exitCode != 0) {
        throw Exception('FFmpeg exited with error code $exitCode');
      }
    } catch (e) {
      _runningProcesses.remove(taskId);
      rethrow;
    }
  }

  static void cancel(String taskId) {
    if (_runningProcesses.containsKey(taskId)) {
      _runningProcesses[taskId]?.kill();
      _runningProcesses.remove(taskId);
    }
  }

  /// 5-Tier Fallback: Extracts frame 0 from downloaded video file via FFmpeg and caches thumbnail
  static Future<String?> extractVideoThumbnail({
    required String videoPath,
    required String outputThumbnailPath,
  }) async {
    try {
      final ffmpegExe = await FfmpegInstallerService.getFfmpegExecutablePath();
      if (ffmpegExe == null) return null;

      final outputDir = Directory(outputThumbnailPath).parent;
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final args = [
        '-y',
        '-ss', '00:00:01',
        '-i', videoPath,
        '-vframes', '1',
        '-q:v', '2',
        '-vf', 'scale=320:-1',
        outputThumbnailPath,
      ];

      final result = await Process.run(ffmpegExe, args);
      if (result.exitCode == 0 && await File(outputThumbnailPath).exists()) {
        return outputThumbnailPath;
      }
    } catch (_) {}
    return null;
  }
}
