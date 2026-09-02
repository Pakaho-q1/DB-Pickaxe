import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_constants.dart';
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
      final downloadsDir = await getDownloadsDirectory();
      destDir = downloadsDir?.path ?? Directory.current.path;
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

    final targetDir = Directory(destDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Adjust target extension if stream (.m3u8 -> .mp4)
    var finalFilename = task.filename;
    if (task.mediaType == MediaType.stream && !finalFilename.toLowerCase().endsWith('.mp4')) {
      finalFilename = '${finalFilename.replaceAll(RegExp(r'\.m3u8', caseSensitive: false), '')}.mp4';
    }

    final fullFilePath = '$destDir\\$finalFilename';

    var currentTask = task.copyWith(
      status: DownloadStatus.downloading,
      savedPath: fullFilePath,
      filename: finalFilename,
      errorMessage: null,
    );
    onTaskUpdated(currentTask);
    await HiveService.saveDownloadTask(currentTask);

    try {
      if (task.mediaType == MediaType.stream || task.url.toLowerCase().contains('.m3u8')) {
        // Handle HLS / M3U8 via FFmpeg
        await FfmpegStreamService.downloadHlsStream(
          taskId: task.id,
          m3u8Url: task.url,
          outputPath: fullFilePath,
          refererUrl: task.pageUrl,
          customHeaders: task.headers,
          onProgress: (progress, speed, msg) {
            currentTask = currentTask.copyWith(
              speedBytesPerSec: speed,
              errorMessage: msg,
            );
            onTaskUpdated(currentTask);
          },
        );
      } else {
        // Multi-Threaded / Resumable Chunked Download
        await ChunkedDownloaderService.download(
          taskId: task.id,
          url: task.url,
          destinationPath: fullFilePath,
          settings: settings,
          refererUrl: task.pageUrl,
          customHeaders: task.headers,
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

        // Post-processing: Image Format Conversion
        if (task.mediaType == MediaType.image && settings.targetImageFormat != ImageTargetFormat.original) {
          currentTask = currentTask.copyWith(status: DownloadStatus.converting);
          onTaskUpdated(currentTask);

          final convertedFile = await ImageConverterService.convertImage(
            inputFile: File(fullFilePath),
            targetFormat: settings.targetImageFormat,
          );

          currentTask = currentTask.copyWith(
            savedPath: convertedFile.path,
            filename: convertedFile.path.split('\\').last,
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
        // Handle Smart Retry
        if (currentTask.retryCount < settings.maxRetries) {
          final nextRetry = currentTask.retryCount + 1;
          currentTask = currentTask.copyWith(
            status: DownloadStatus.pending,
            retryCount: nextRetry,
            errorMessage: 'Retrying ($nextRetry/${settings.maxRetries})...',
          );
          await Future.delayed(Duration(seconds: settings.retryDelaySeconds));
        } else {
          currentTask = currentTask.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString(),
            speedBytesPerSec: 0,
          );
        }
      }
      onTaskUpdated(currentTask);
      await HiveService.saveDownloadTask(currentTask);
    } finally {
      _activeTaskIds.remove(task.id);
      _cancelTokens.remove(task.id);
      FfmpegStreamService.cancel(task.id);
      ChunkedDownloaderService.cancel(task.id);
      // Trigger next pending tasks in queue
      processQueue(HiveService.getDownloadTasks(), settings);
    }
  }

  void cancelTask(String taskId) {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel();
      _cancelTokens.remove(taskId);
    }
    FfmpegStreamService.cancel(taskId);
    ChunkedDownloaderService.cancel(taskId);
    _activeTaskIds.remove(taskId);
  }
}
