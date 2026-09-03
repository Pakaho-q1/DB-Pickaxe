import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/utils/filename_template_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/domain/models/detected_media.dart';
import '../../domain/models/download_task.dart';
import '../../services/chunked_downloader_service.dart';
import '../../services/download_queue_manager.dart';

final downloadQueueProvider = StateNotifierProvider<DownloadQueueNotifier, List<DownloadTask>>((ref) {
  return DownloadQueueNotifier(ref);
});

class DownloadQueueNotifier extends StateNotifier<List<DownloadTask>> {
  final Ref ref;
  late final DownloadQueueManager _queueManager;

  DownloadQueueNotifier(this.ref) : super(HiveService.getDownloadTasks()) {
    _queueManager = DownloadQueueManager(
      onTaskUpdated: (task) {
        state = state.map((t) => t.id == task.id ? task : t).toList();
      },
    );
  }

  Future<void> refreshTaskUrl(String taskId, String newUrl, {Map<String, String>? headers}) async {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final old = state[idx];
    final updated = old.copyWith(
      url: newUrl,
      headers: headers != null ? {...old.headers, ...headers} : old.headers,
      status: DownloadStatus.pending,
      errorMessage: null,
    );
    state = state.map((t) => t.id == taskId ? updated : t).toList();
    await HiveService.saveDownloadTask(updated);

    final settings = ref.read(settingsProvider);
    _queueManager.processQueue(state, settings);
  }

  Future<void> addMediaToQueue(DetectedMedia media) async {
    final isDuplicate = state.any((t) => t.url == media.url && t.status == DownloadStatus.completed);
    if (isDuplicate) return;

    final settings = ref.read(settingsProvider);
    final subFolder = FilenameTemplateService.generateSubfolder(
      domain: Uri.tryParse(media.pageUrl)?.host,
      pageTitle: media.filename,
      autoCreateSubfolders: settings.autoCreateSubfolders,
    );

    final task = DownloadTask(
      id: const Uuid().v4(),
      url: media.url,
      pageUrl: media.pageUrl,
      subFolder: subFolder,
      filename: media.filename,
      savedPath: '',
      mediaType: media.mediaType,
      headers: media.headers,
      createdAt: DateTime.now(),
      totalBytes: media.sizeBytes,
    );

    await HiveService.saveDownloadTask(task);
    state = [task, ...state];

    _queueManager.processQueue(state, settings);
  }

  /// Extracts Audio Only (.mp3) from video or stream
  Future<void> addAudioOnlyToQueue(DetectedMedia media) async {
    final settings = ref.read(settingsProvider);
    final subFolder = FilenameTemplateService.generateSubfolder(
      domain: Uri.tryParse(media.pageUrl)?.host,
      pageTitle: media.filename,
      autoCreateSubfolders: settings.autoCreateSubfolders,
    );

    String audioFilename = media.filename;
    final dotIdx = audioFilename.lastIndexOf('.');
    if (dotIdx != -1) {
      audioFilename = '.mp3';
    } else {
      audioFilename = '.mp3';
    }

    final task = DownloadTask(
      id: const Uuid().v4(),
      url: media.url,
      pageUrl: media.pageUrl,
      subFolder: subFolder,
      filename: audioFilename,
      savedPath: '',
      mediaType: MediaType.audio,
      isAudioOnly: true,
      headers: media.headers,
      createdAt: DateTime.now(),
      totalBytes: media.sizeBytes,
    );

    await HiveService.saveDownloadTask(task);
    state = [task, ...state];

    _queueManager.processQueue(state, settings);
  }

  /// Downloads trimmed video time-range (e.g. 00:15 - 01:45)
  Future<void> addTrimmedVideoToQueue(
    DetectedMedia media, {
    required double startTime,
    required double endTime,
  }) async {
    final settings = ref.read(settingsProvider);
    final subFolder = FilenameTemplateService.generateSubfolder(
      domain: Uri.tryParse(media.pageUrl)?.host,
      pageTitle: media.filename,
      autoCreateSubfolders: settings.autoCreateSubfolders,
    );

    final startStr = startTime.toInt().toString();
    final endStr = endTime.toInt().toString();
    String trimmedFilename = media.filename;
    final dotIdx = trimmedFilename.lastIndexOf('.');
    if (dotIdx != -1) {
      trimmedFilename = '${trimmedFilename.substring(0, dotIdx)}_trim_${startStr}s_${endStr}s${trimmedFilename.substring(dotIdx)}';
    } else {
      trimmedFilename = '${trimmedFilename}_trim_${startStr}s_${endStr}s.mp4';
    }

    final task = DownloadTask(
      id: const Uuid().v4(),
      url: media.url,
      pageUrl: media.pageUrl,
      subFolder: subFolder,
      filename: trimmedFilename,
      savedPath: '',
      mediaType: media.mediaType,
      trimStartTime: startTime,
      trimEndTime: endTime,
      headers: media.headers,
      createdAt: DateTime.now(),
      totalBytes: media.sizeBytes,
    );

    await HiveService.saveDownloadTask(task);
    state = [task, ...state];

    _queueManager.processQueue(state, settings);
  }

  Future<void> addBatchMediaToQueue(List<DetectedMedia> mediaList) async {
    final settings = ref.read(settingsProvider);
    final tasksToAdd = <DownloadTask>[];
    for (int i = 0; i < mediaList.length; i++) {
      final media = mediaList[i];
      final subFolder = FilenameTemplateService.generateSubfolder(
        domain: Uri.tryParse(media.pageUrl)?.host,
        pageTitle: media.filename,
        autoCreateSubfolders: settings.autoCreateSubfolders,
      );

      final task = DownloadTask(
        id: const Uuid().v4(),
        url: media.url,
        pageUrl: media.pageUrl,
        subFolder: subFolder,
        filename: media.filename,
        savedPath: '',
        mediaType: media.mediaType,
        headers: media.headers,
        createdAt: DateTime.now(),
        totalBytes: media.sizeBytes,
      );
      tasksToAdd.add(task);
      await HiveService.saveDownloadTask(task);
    }

    state = [...tasksToAdd, ...state];
    _queueManager.processQueue(state, settings);
  }

  void pauseTask(String taskId) {
    _queueManager.pauseTask(taskId);
    state = state.map((t) => t.id == taskId ? t.copyWith(status: DownloadStatus.paused, speedBytesPerSec: 0) : t).toList();
    final task = state.firstWhere((t) => t.id == taskId);
    HiveService.saveDownloadTask(task);
  }

  void resumeTask(String taskId) {
    state = state.map((t) => t.id == taskId ? t.copyWith(status: DownloadStatus.pending) : t).toList();
    final task = state.firstWhere((t) => t.id == taskId);
    HiveService.saveDownloadTask(task);

    final settings = ref.read(settingsProvider);
    _queueManager.processQueue(state, settings);
  }

  void cancelTask(String taskId) {
    _queueManager.cancelTask(taskId);
    state = state.map((t) => t.id == taskId ? t.copyWith(status: DownloadStatus.cancelled, speedBytesPerSec: 0) : t).toList();
    final task = state.firstWhere((t) => t.id == taskId);
    HiveService.saveDownloadTask(task);
  }

  Future<void> retryTask(String taskId) async {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final oldTask = state[idx];
    final updated = oldTask.copyWith(
      status: DownloadStatus.pending,
      errorMessage: null,
      retryCount: oldTask.retryCount + 1,
    );

    state = state.map((t) => t.id == taskId ? updated : t).toList();
    await HiveService.saveDownloadTask(updated);

    final settings = ref.read(settingsProvider);
    _queueManager.processQueue(state, settings);
  }

  Future<void> removeTask(String taskId, {bool deleteFile = false}) async {
    _queueManager.cancelTask(taskId);
    await ChunkedDownloaderService.deleteTaskTempFolder(taskId);

    final task = state.firstWhere((t) => t.id == taskId, orElse: () => state.first);
    if (deleteFile && task.savedPath.isNotEmpty) {
      try {
        final f = File(task.savedPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    state = state.where((t) => t.id != taskId).toList();
    await HiveService.deleteDownloadTask(taskId);
  }

  void clearCompleted() => clearCompletedTasks();

  Future<void> clearCompletedTasks() async {
    final completedIds = state.where((t) => t.status == DownloadStatus.completed).map((t) => t.id).toList();
    state = state.where((t) => t.status != DownloadStatus.completed).toList();
    for (final id in completedIds) {
      await HiveService.deleteDownloadTask(id);
      await ChunkedDownloaderService.deleteTaskTempFolder(id);
    }
  }
}