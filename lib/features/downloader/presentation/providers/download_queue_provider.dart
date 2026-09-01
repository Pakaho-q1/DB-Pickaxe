import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/domain/models/detected_media.dart';
import '../../domain/models/download_task.dart';
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

  Future<void> addMediaToQueue(DetectedMedia media) async {
    // Anti-duplicate check
    final isDuplicate = state.any((t) => t.url == media.url && t.status == DownloadStatus.completed);
    if (isDuplicate) {
      // already downloaded
      return;
    }

    final task = DownloadTask(
      id: const Uuid().v4(),
      url: media.url,
      pageUrl: media.pageUrl,
      filename: media.filename,
      savedPath: '',
      mediaType: media.mediaType,
      headers: media.headers,
      createdAt: DateTime.now(),
      totalBytes: media.sizeBytes,
    );

    await HiveService.saveDownloadTask(task);
    state = [task, ...state];

    final settings = ref.read(settingsProvider);
    _queueManager.processQueue(state, settings);
  }

  Future<void> addBatchMediaToQueue(List<DetectedMedia> mediaList) async {
    final tasksToAdd = <DownloadTask>[];
    for (final media in mediaList) {
      final task = DownloadTask(
        id: const Uuid().v4(),
        url: media.url,
        pageUrl: media.pageUrl,
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
    final settings = ref.read(settingsProvider);
    _queueManager.processQueue(state, settings);
  }

  void cancelTask(String taskId) {
    _queueManager.cancelTask(taskId);
    state = state.map((t) {
      if (t.id == taskId) {
        return t.copyWith(status: DownloadStatus.cancelled);
      }
      return t;
    }).toList();
  }

  Future<void> retryTask(String taskId) async {
    final taskIndex = state.indexWhere((t) => t.id == taskId);
    if (taskIndex >= 0) {
      final task = state[taskIndex].copyWith(
        status: DownloadStatus.pending,
        retryCount: 0,
        errorMessage: null,
      );
      await HiveService.saveDownloadTask(task);
      state = state.map((t) => t.id == taskId ? task : t).toList();

      final settings = ref.read(settingsProvider);
      _queueManager.processQueue(state, settings);
    }
  }

  Future<void> removeTask(String taskId) async {
    _queueManager.cancelTask(taskId);
    await HiveService.deleteDownloadTask(taskId);
    state = state.where((t) => t.id != taskId).toList();
  }

  Future<void> clearCompleted() async {
    final completed = state.where((t) => t.status == DownloadStatus.completed).toList();
    for (var task in completed) {
      await HiveService.deleteDownloadTask(task.id);
    }
    state = state.where((t) => t.status != DownloadStatus.completed).toList();
  }
}
