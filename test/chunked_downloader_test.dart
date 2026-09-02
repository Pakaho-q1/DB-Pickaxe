import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
import 'package:db_pickaxe/core/storage/cache_paths.dart';
import 'package:db_pickaxe/features/downloader/domain/models/download_task.dart';
import 'package:db_pickaxe/features/downloader/services/chunked_downloader_service.dart';
import 'package:db_pickaxe/features/settings/domain/models/app_settings.dart';
import 'package:db_pickaxe/features/settings/domain/models/app_shortcuts.dart';
import 'package:db_pickaxe/features/sniffer/domain/models/media_filter.dart';
import 'package:db_pickaxe/features/sniffer/presentation/providers/sniffer_provider.dart';

void main() {
  group('Modern Download Engine & Multi-Threading Unit Tests', () {
    test('AppSettings handles multi-threaded download configuration and clamp correctly', () {
      const defaultSettings = AppSettings();
      expect(defaultSettings.threadsPerDownload, equals(4));
      expect(defaultSettings.enableChunkedDownload, isTrue);
      expect(defaultSettings.minChunkSizeMB, equals(2));
      expect(defaultSettings.startupBehavior, equals(AppStartupBehavior.restoreAll));
      expect(defaultSettings.shortcuts.closeTab, equals('Ctrl+W'));

      expect(defaultSettings.snifferHubStyle, equals(SnifferHubStyle.glassCapsule));
      expect(defaultSettings.snifferHubPosition, equals(SnifferHubPosition.bottomRight));

      final updated = defaultSettings.copyWith(
        threadsPerDownload: 8,
        enableChunkedDownload: true,
        startupBehavior: AppStartupBehavior.newTab,
        shortcuts: const AppShortcuts(closeTab: 'Alt+W'),
        snifferHubStyle: SnifferHubStyle.miniFab,
        snifferHubPosition: SnifferHubPosition.topLeft,
      );
      expect(updated.threadsPerDownload, equals(8));
      expect(updated.startupBehavior, equals(AppStartupBehavior.newTab));
      expect(updated.shortcuts.closeTab, equals('Alt+W'));
      expect(updated.snifferHubStyle, equals(SnifferHubStyle.miniFab));
      expect(updated.snifferHubPosition, equals(SnifferHubPosition.topLeft));

      final map = updated.toMap();
      expect(map['threadsPerDownload'], equals(8));
      expect(map['enableChunkedDownload'], isTrue);
      expect(map['startupBehavior'], equals('newTab'));
      expect(map['snifferHubStyle'], equals('miniFab'));
      expect(map['snifferHubPosition'], equals('topLeft'));

      final restored = AppSettings.fromMap(map);
      expect(restored.threadsPerDownload, equals(8));
      expect(restored.enableChunkedDownload, isTrue);
      expect(restored.startupBehavior, equals(AppStartupBehavior.newTab));
      expect(restored.shortcuts.closeTab, equals('Alt+W'));
      expect(restored.snifferHubStyle, equals(SnifferHubStyle.miniFab));
      expect(restored.snifferHubPosition, equals(SnifferHubPosition.topLeft));

      // Verify thread clamping [1, 16]
      final overLimit = AppSettings.fromMap({'threadsPerDownload': 99});
      expect(overLimit.threadsPerDownload, equals(16));

      final underLimit = AppSettings.fromMap({'threadsPerDownload': 0});
      expect(underLimit.threadsPerDownload, equals(1));
    });

    test('AppShortcuts serialization and copyWith works correctly', () {
      const shortcuts = AppShortcuts();
      expect(shortcuts.closeTab, equals('Ctrl+W'));
      expect(shortcuts.newTab, equals('Ctrl+T'));
      expect(shortcuts.closeOtherTabs, equals('Ctrl+Shift+W'));
      expect(shortcuts.detectMedia, equals('Ctrl+R'));
      expect(shortcuts.toggleMediaDeck, equals('Ctrl+B'));
      expect(shortcuts.focusUrlBar, equals('Ctrl+L'));
      expect(shortcuts.downloadHoverMedia, equals('Shift+D'));

      final custom = shortcuts.copyWith(
        closeTab: 'Ctrl+Q',
        detectMedia: 'F5',
      );
      expect(custom.closeTab, equals('Ctrl+Q'));
      expect(custom.detectMedia, equals('F5'));

      final map = custom.toMap();
      final restored = AppShortcuts.fromMap(map);
      expect(restored.closeTab, equals('Ctrl+Q'));
      expect(restored.detectMedia, equals('F5'));
    });

    test('MediaFilter serialization persists filter state properly', () {
      const filter = MediaFilter(
        typeFilter: MediaType.video,
        searchQuery: 'movie',
        minSizeMB: 5.0,
        sortBy: MediaSortField.size,
        sortOrder: SortOrder.descending,
        density: GridDensity.compact,
      );

      final map = filter.toMap();
      expect(map['typeFilter'], equals('video'));
      expect(map['searchQuery'], equals('movie'));
      expect(map['minSizeMB'], equals(5.0));
      expect(map['sortBy'], equals('size'));
      expect(map['density'], equals('compact'));

      final restored = MediaFilter.fromMap(map);
      expect(restored.typeFilter, equals(MediaType.video));
      expect(restored.searchQuery, equals('movie'));
      expect(restored.minSizeMB, equals(5.0));
      expect(restored.sortBy, equals(MediaSortField.size));
      expect(restored.sortOrder, equals(SortOrder.descending));
      expect(restored.density, equals(GridDensity.compact));
    });

    test('DownloadTask serialization retains isResumable and chunkCount', () {
      final task = DownloadTask(
        id: 'task-123',
        url: 'https://example.com/video.mp4',
        pageUrl: 'https://example.com',
        filename: 'video.mp4',
        savedPath: 'C:\\Downloads\\video.mp4',
        mediaType: MediaType.video,
        createdAt: DateTime.now(),
        isResumable: true,
        chunkCount: 8,
      );

      final map = task.toMap();
      expect(map['isResumable'], isTrue);
      expect(map['chunkCount'], equals(8));

      final restored = DownloadTask.fromMap(map);
      expect(restored.isResumable, isTrue);
      expect(restored.chunkCount, equals(8));
      expect(restored.filename, equals('video.mp4'));
    });

    test('ChunkProgress correctly computes byte offsets and status', () {
      final chunk = ChunkProgress(
        index: 0,
        startByte: 0,
        endByte: 1048575, // 1 MB
        downloadedBytes: 524288,
      );

      expect(chunk.totalChunkBytes, equals(1048576));
      expect(chunk.isCompleted, isFalse);

      final map = chunk.toMap();
      final restored = ChunkProgress.fromMap(map);
      expect(restored.index, equals(0));
      expect(restored.startByte, equals(0));
      expect(restored.endByte, equals(1048575));
      expect(restored.downloadedBytes, equals(524288));
    });

    test('CachePaths provides valid bin directory for portable binaries', () {
      final binDir = CachePaths.binDir;
      expect(binDir.path, contains('.pickaxe-cache\\bin'));
    });

    test('Temp folder cleanup deletes isolated task directory properly', () async {
      final taskId = 'test_cleanup_task';
      final taskTempDir = Directory('${CachePaths.tempDir.path}\\task_$taskId');
      if (!await taskTempDir.exists()) {
        await taskTempDir.create(recursive: true);
      }
      expect(await taskTempDir.exists(), isTrue);

      await ChunkedDownloaderService.deleteTaskTempFolder(taskId);
      expect(await taskTempDir.exists(), isFalse);
    });

    test('Sniffer filename generation never produces double extensions like .mp4.mp4', () {
      final sniffer = SnifferNotifier();
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://example.com/FxGOw5GC_720p.mp4',
        pageUrl: 'https://example.com',
        title: 'FxGOw5GC_720p.mp4',
      );

      final item = sniffer.state['tab-1']!.first;
      expect(item.filename, equals('FxGOw5GC_720p.mp4'));
      expect(item.filename.contains('.mp4.mp4'), isFalse);
    });
  });
}
