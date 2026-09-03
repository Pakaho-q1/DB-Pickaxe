import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
import 'package:db_pickaxe/core/network/ad_blocker_service.dart';
import 'package:db_pickaxe/core/network/hls_downloader_service.dart';
import 'package:db_pickaxe/core/storage/hive_service.dart';
import 'package:db_pickaxe/core/utils/filename_template_service.dart';
import 'package:db_pickaxe/features/downloader/domain/models/download_task.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('powerhouse_test_');
    Hive.init(tempDir.path);
    HiveService.settingsBox = await Hive.openBox(HiveService.settingsBoxName);
    HiveService.downloadsBox = await Hive.openBox(HiveService.downloadsBoxName);
  });

  tearDown(() async {
    if (HiveService.downloadsBox.isOpen) {
      await HiveService.downloadsBox.close();
    }
    if (HiveService.settingsBox.isOpen) {
      await HiveService.settingsBox.close();
    }
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Feature 1: Multi-Threaded HLS / M3U8 Playlist Parser', () {
    test('Correctly parses master/variant M3U8 and extracts segments with base URL resolution', () {
      const sampleM3u8 = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:9.009,
segment_0.ts
#EXTINF:9.009,
segment_1.ts
#EXTINF:4.500,
https://cdn.example.com/live/segment_2.ts
#EXT-X-ENDLIST''';

      final segments = HlsDownloaderService.parseM3u8Playlist(
        sampleM3u8,
        'https://cdn.example.com/vod/playlist.m3u8',
      );

      expect(segments.length, equals(3));
      expect(segments[0].url, equals('https://cdn.example.com/vod/segment_0.ts'));
      expect(segments[0].duration, closeTo(9.009, 0.001));
      expect(segments[1].url, equals('https://cdn.example.com/vod/segment_1.ts'));
      expect(segments[2].url, equals('https://cdn.example.com/live/segment_2.ts'));
    });
  });

  group('Feature 2: Auto-Pair Video + Audio (DASH Stream Muxing)', () {
    test('DownloadTask serialization preserves audioUrl for DASH muxing', () {
      final task = DownloadTask(
        id: 'dash-task-1',
        url: 'https://v.redd.it/123/DASH_1080.mp4',
        audioUrl: 'https://v.redd.it/123/DASH_AUDIO_128.mp4',
        pageUrl: 'https://reddit.com/r/videos/123',
        filename: 'reddit_video.mp4',
        savedPath: 'C:\\Downloads\\reddit_video.mp4',
        mediaType: MediaType.video,
        createdAt: DateTime.now(),
      );

      final map = task.toMap();
      expect(map['audioUrl'], equals('https://v.redd.it/123/DASH_AUDIO_128.mp4'));

      final restored = DownloadTask.fromMap(map);
      expect(restored.audioUrl, equals('https://v.redd.it/123/DASH_AUDIO_128.mp4'));
    });
  });

  group('Feature 3: Refresh Expired Download Link', () {
    test('DownloadTask isExpired and copyWith updates URL and resets status to pending', () {
      final expiredTask = DownloadTask(
        id: 'task-exp-1',
        url: 'https://expired-cdn.com/file.zip?token=old123',
        pageUrl: 'https://example.com/download/1',
        filename: 'large_file.zip',
        savedPath: 'C:\\Downloads\\large_file.zip',
        mediaType: MediaType.other,
        status: DownloadStatus.expired,
        totalBytes: 1000000000,
        downloadedBytes: 450000000, // 45% downloaded
        createdAt: DateTime.now(),
      );

      expect(expiredTask.isExpired, isTrue);

      final refreshedTask = expiredTask.copyWith(
        url: 'https://expired-cdn.com/file.zip?token=fresh_token_456',
        status: DownloadStatus.pending,
        errorMessage: null,
      );

      expect(refreshedTask.isExpired, isFalse);
      expect(refreshedTask.url, contains('fresh_token_456'));
      expect(refreshedTask.downloadedBytes, equals(450000000)); // Byte progress kept!
      expect(refreshedTask.status, equals(DownloadStatus.pending));
    });
  });

  group('Feature 4: Smart Filename Templating & Subfolder Auto-Organize', () {
    test('FilenameTemplateService renders placeholders correctly', () {
      final rendered = FilenameTemplateService.render(
        template: '{title} - {resolution}.{ext}',
        title: 'Genshin Artwork 2026',
        originalFilename: 'img_12345.png',
        resolution: '1920x1080',
        extension: '.png',
      );

      expect(rendered, equals('Genshin Artwork 2026 - 1920x1080.png'));
    });

    test('FilenameTemplateService generates clean subfolders for batch organizing', () {
      final sub = FilenameTemplateService.generateSubfolder(
        domain: 'gelbooru.com',
        pageTitle: 'Awesome Character Set #12',
        autoCreateSubfolders: true,
      );

      expect(sub, equals('gelbooru.com/Awesome Character Set #12'));
    });
  });

  group('Feature 5: Built-in EasyList AdBlocker & Popup Blocker', () {
    test('AdBlockerService identifies known ad networks and tracking URLs', () {
      expect(AdBlockerService.isAdUrl('https://googleads.g.doubleclick.net/pagead/ads?client=ca-pub'), isTrue);
      expect(AdBlockerService.isAdUrl('https://syndication.exoclick.com/splash.php?cat=12'), isTrue);
      expect(AdBlockerService.isAdUrl('https://popads.net/serve/popunder.js'), isTrue);
      expect(AdBlockerService.isAdUrl('https://images.unsplash.com/photo-12345'), isFalse);
      expect(AdBlockerService.isAdUrl('https://gelbooru.com/index.php?page=post'), isFalse);
    });
  });
}
