import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../../core/network/hls_downloader_service.dart';
import '../../../../core/storage/cache_paths.dart';
import '../../../../core/storage/hive_service.dart';
import '../../settings/domain/models/app_settings.dart';
import '../domain/models/download_task.dart';
import 'chunked_downloader_service.dart';
import 'ffmpeg_stream_service.dart';
import 'image_converter_service.dart';

class DownloadQueueManager {
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _activeTaskIds = {};
  bool _isProcessing = false;

  final void Function(DownloadTask task) onTaskUpdated;

  DownloadQueueManager({required this.onTaskUpdated});

  Future<void> processQueue(List<DownloadTask> tasks, AppSettings settings) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final maxConcurrent = settings.maxConcurrentDownloads.clamp(1, 10);

      // Check available slots
      final availableSlots = maxConcurrent - _activeTaskIds.length;
      if (availableSlots <= 0) return;

      final pendingTasks = tasks.where((t) => t.status == DownloadStatus.pending).take(availableSlots).toList();

      for (final task in pendingTasks) {
        _activeTaskIds.add(task.id);
        _startDownload(task, settings);
        if (settings.interTaskDelayMs > 0) {
          await Future.delayed(Duration(milliseconds: settings.interTaskDelayMs));
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _startDownload(DownloadTask task, AppSettings settings) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    // Resolve target directory
    String destDir = settings.defaultDownloadPath;
    if (destDir.isEmpty) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        destDir = downloadsDir?.path ?? Directory.current.path;
      } catch (_) {
        destDir = Directory.current.path;
      }
    }

    if (settings.autoCategorizeFolders) {
      String subFolder;
      switch (task.mediaType) {
        case MediaType.image:
          subFolder = 'Images';
          break;
        case MediaType.video:
          subFolder = 'Videos';
          break;
        case MediaType.stream:
          subFolder = 'Streams';
          break;
        case MediaType.audio:
          subFolder = 'Audio';
          break;
        default:
          subFolder = 'Other';
      }
      destDir = '$destDir\\$subFolder';
    }

    if (task.subFolder != null && task.subFolder!.isNotEmpty) {
      destDir = '$destDir\\${task.subFolder}';
    }

    final targetDir = Directory(destDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Adjust target extension if stream (.m3u8 -> .mp4) or audio only (.mp3)
    var finalFilename = task.filename;
    if (task.isAudioOnly && !finalFilename.toLowerCase().endsWith('.mp3')) {
      finalFilename = '${finalFilename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.mp3';
    } else if (task.mediaType == MediaType.stream && !finalFilename.toLowerCase().endsWith('.mp4')) {
      finalFilename = '${finalFilename.replaceAll(RegExp(r'\.m3u8', caseSensitive: false), '')}.mp4';
    }

    final fullFilePath = '$destDir\\$finalFilename';

    // Auto-resolve session cookies & headers from CookieManagerService
    final effectiveHeaders = CookieManagerService.getHeadersForUrl(
      task.url,
      pageUrl: task.pageUrl,
      customHeaders: task.headers,
    );

    var currentTask = task.copyWith(
      status: DownloadStatus.downloading,
      savedPath: fullFilePath,
      filename: finalFilename,
      headers: effectiveHeaders,
      errorMessage: null,
    );
    onTaskUpdated(currentTask);
    await HiveService.saveDownloadTask(currentTask);

    try {
      if (task.mediaType == MediaType.stream || task.url.toLowerCase().contains('.m3u8')) {
        if (settings.enableHlsMultiThread) {
          final tempHlsDir = Directory('${CachePaths.tempDir.path}\\hls_${task.id}');
          if (!await tempHlsDir.exists()) await tempHlsDir.create(recursive: true);
          await HlsDownloaderService.downloadHlsSegments(
            m3u8Url: task.url,
            tempDir: tempHlsDir,
            settings: settings,
            cancelToken: cancelToken,
            headers: effectiveHeaders,
            onProgress: (completed, total, progress) {
              currentTask = currentTask.copyWith(
                downloadedBytes: completed,
                totalBytes: total,
                speedBytesPerSec: 0,
                errorMessage: 'Downloading segment $completed / $total (${(progress * 100).toInt()}%)',
              );
              onTaskUpdated(currentTask);
            },
          );

          currentTask = currentTask.copyWith(status: DownloadStatus.converting, errorMessage: 'Muxing MP4...');
          onTaskUpdated(currentTask);

          await HlsDownloaderService.concatenateSegmentsToMp4(
            tempDir: tempHlsDir,
            outputPath: fullFilePath,
          );
          try {
            await tempHlsDir.delete(recursive: true);
          } catch (_) {}
        } else {
          await FfmpegStreamService.downloadHlsStream(
            taskId: task.id,
            m3u8Url: task.url,
            outputPath: fullFilePath,
            refererUrl: task.pageUrl,
            customHeaders: effectiveHeaders,
            onProgress: (progress, speed, msg) {
              currentTask = currentTask.copyWith(
                speedBytesPerSec: speed,
                errorMessage: msg,
              );
              onTaskUpdated(currentTask);
            },
          );
        }
      } else if (task.audioUrl != null && task.audioUrl!.isNotEmpty && settings.autoMergeAudioVideo) {
        // DASH separate Video + Audio Download and Muxing
        final taskTempDir = Directory('${CachePaths.tempDir.path}\\dash_${task.id}');
        if (!await taskTempDir.exists()) await taskTempDir.create(recursive: true);
        final tempVideo = File('${taskTempDir.path}\\video_track.mp4');
        final tempAudio = File('${taskTempDir.path}\\audio_track.m4a');

        await ChunkedDownloaderService.download(
          taskId: '${task.id}_v',
          url: task.url,
          destinationPath: tempVideo.path,
          settings: settings,
          refererUrl: task.pageUrl,
          customHeaders: effectiveHeaders,
          parentCancelToken: cancelToken,
          onProgress: (received, total, speed, isResumable, chunkCount) {
            currentTask = currentTask.copyWith(
              downloadedBytes: (received * 0.8).toInt(),
              totalBytes: total > 0 ? (total * 1.25).toInt() : currentTask.totalBytes,
              speedBytesPerSec: speed,
              errorMessage: 'Downloading video track...',
            );
            onTaskUpdated(currentTask);
          },
        );

        await ChunkedDownloaderService.download(
          taskId: '${task.id}_a',
          url: task.audioUrl!,
          destinationPath: tempAudio.path,
          settings: settings,
          refererUrl: task.pageUrl,
          customHeaders: effectiveHeaders,
          parentCancelToken: cancelToken,
          onProgress: (received, total, speed, isResumable, chunkCount) {
            currentTask = currentTask.copyWith(
              errorMessage: 'Downloading audio track...',
            );
            onTaskUpdated(currentTask);
          },
        );

        currentTask = currentTask.copyWith(status: DownloadStatus.converting, errorMessage: 'Merging Video + Audio...');
        onTaskUpdated(currentTask);

        final ffmpegPath = '${CachePaths.binDir.path}\\ffmpeg.exe';
        if (await File(ffmpegPath).exists()) {
          final res = await Process.run(ffmpegPath, [
            '-y',
            '-i',
            tempVideo.path,
            '-i',
            tempAudio.path,
            '-c:v',
            'copy',
            '-c:a',
            'aac',
            '-map',
            '0:v:0',
            '-map',
            '1:a:0',
            fullFilePath,
          ]);
          if (res.exitCode != 0) {
            await tempVideo.copy(fullFilePath);
          }
        } else {
          await tempVideo.copy(fullFilePath);
        }
        try {
          await taskTempDir.delete(recursive: true);
        } catch (_) {}
      } else {
        await ChunkedDownloaderService.download(
          taskId: task.id,
          url: task.url,
          destinationPath: fullFilePath,
          settings: settings,
          refererUrl: task.pageUrl,
          customHeaders: effectiveHeaders,
          parentCancelToken: cancelToken,
          onProgress: (received, total, speed, isResumable, chunkCount) {
            currentTask = currentTask.copyWith(
              downloadedBytes: received,
              totalBytes: total > 0 ? total : currentTask.totalBytes,
              speedBytesPerSec: speed > 0 ? speed : currentTask.speedBytesPerSec,
              isResumable: isResumable,
              chunkCount: chunkCount,
            );
            onTaskUpdated(currentTask);
          },
        );

        // Audio Extraction from video
        if (task.isAudioOnly) {
          currentTask = currentTask.copyWith(status: DownloadStatus.converting, errorMessage: 'Extracting Audio...');
          onTaskUpdated(currentTask);

          final ffmpegPath = '${CachePaths.binDir.path}\\ffmpeg.exe';
          if (await File(ffmpegPath).exists()) {
            final tempExtracted = '${fullFilePath}_temp.mp3';
            final res = await Process.run(ffmpegPath, [
              '-y',
              '-i', fullFilePath,
              '-vn',
              '-c:a', 'libmp3lame',
              '-q:a', '2',
              tempExtracted,
            ]);
            if (res.exitCode == 0 && await File(tempExtracted).exists()) {
              await File(fullFilePath).delete();
              await File(tempExtracted).rename(fullFilePath);
            }
          }
        }

        // Video Trimming
        if (task.trimStartTime != null && task.trimEndTime != null && task.trimEndTime! > task.trimStartTime!) {
          currentTask = currentTask.copyWith(status: DownloadStatus.converting, errorMessage: 'Trimming Video...');
          onTaskUpdated(currentTask);

          final ffmpegPath = '${CachePaths.binDir.path}\\ffmpeg.exe';
          if (await File(ffmpegPath).exists()) {
            final tempTrimmed = '${fullFilePath}_trimmed.mp4';
            final res = await Process.run(ffmpegPath, [
              '-y',
              '-ss', task.trimStartTime!.toStringAsFixed(2),
              '-to', task.trimEndTime!.toStringAsFixed(2),
              '-i', fullFilePath,
              '-c', 'copy',
              tempTrimmed,
            ]);
            if (res.exitCode == 0 && await File(tempTrimmed).exists()) {
              await File(fullFilePath).delete();
              await File(tempTrimmed).rename(fullFilePath);
            }
          }
        }

        if (task.mediaType == MediaType.image && settings.targetImageFormat != ImageTargetFormat.original) {
          currentTask = currentTask.copyWith(status: DownloadStatus.converting);
          onTaskUpdated(currentTask);

          final convertedFile = await ImageConverterService.convertImage(
            inputFile: File(fullFilePath),
            targetFormat: settings.targetImageFormat,
          );

          currentTask = currentTask.copyWith(
            savedPath: convertedFile.path,
            filename: convertedFile.path.split(Platform.isWindows ? r'\' : '/').last,
          );
        }
      }

      currentTask = currentTask.copyWith(
        status: DownloadStatus.completed,
        completedAt: DateTime.now(),
        speedBytesPerSec: 0,
        errorMessage: null,
      );
      onTaskUpdated(currentTask);
      await HiveService.saveDownloadTask(currentTask);
    } catch (e) {
      if (cancelToken.isCancelled) {
        currentTask = currentTask.copyWith(
          status: DownloadStatus.cancelled,
          speedBytesPerSec: 0,
        );
      } else {
        final errStr = e.toString().toLowerCase();
        final isExpiredToken = errStr.contains('403') ||
            errStr.contains('401') ||
            errStr.contains('410') ||
            errStr.contains('forbidden') ||
            errStr.contains('unauthorized');

        currentTask = currentTask.copyWith(
          status: isExpiredToken ? DownloadStatus.expired : DownloadStatus.failed,
          errorMessage: isExpiredToken
              ? 'Download link expired (403/410). Click Refresh Link to resume.'
              : e.toString(),
          speedBytesPerSec: 0,
        );
      }
      onTaskUpdated(currentTask);
      await HiveService.saveDownloadTask(currentTask);
    } finally {
      _activeTaskIds.remove(task.id);
      _cancelTokens.remove(task.id);
      // Process next available item in queue
      processQueue(HiveService.getDownloadTasks(), settings);
    }
  }

  void cancelTask(String taskId) {
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
    _activeTaskIds.remove(taskId);
    _cancelTokens.remove(taskId);
  }

  void pauseTask(String taskId) {
    cancelTask(taskId);
  }
}
