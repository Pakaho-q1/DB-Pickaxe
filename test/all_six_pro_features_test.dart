import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
import 'package:db_pickaxe/core/services/pack_archive_service.dart';
import 'package:db_pickaxe/core/storage/hive_service.dart';
import 'package:db_pickaxe/core/utils/formatters.dart';
import 'package:db_pickaxe/features/downloader/domain/models/download_task.dart';
import 'package:db_pickaxe/features/settings/domain/models/app_settings.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('six_features_test_');
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

  group('Pro Feature 1: Audio Only Extraction (.mp3)', () {
    test('DownloadTask model supports isAudioOnly and MediaType.audio', () {
      final task = DownloadTask(
        id: 'aud-task-1',
        url: 'https://cdn.example.com/movie_clip.mp4',
        pageUrl: 'https://example.com/watch/123',
        filename: 'movie_clip.mp3',
        savedPath: 'C:\\Downloads\\movie_clip.mp3',
        mediaType: MediaType.audio,
        isAudioOnly: true,
        createdAt: DateTime.now(),
      );

      final map = task.toMap();
      expect(map['isAudioOnly'], isTrue);
      expect(map['mediaType'], equals(MediaType.audio.name));

      final restored = DownloadTask.fromMap(map);
      expect(restored.isAudioOnly, isTrue);
      expect(restored.filename, equals('movie_clip.mp3'));
      expect(restored.mediaType, equals(MediaType.audio));
    });
  });

  group('Pro Feature 2: Pack Batch to ZIP & CBZ Archives', () {
    test('PackArchiveService creates valid ZIP and CBZ comic archives', () async {
      final file1 = File('${tempDir.path}/page_01.png')..writeAsStringSync('dummy image 1');
      final file2 = File('${tempDir.path}/page_02.png')..writeAsStringSync('dummy image 2');

      final zipOut = '${tempDir.path}/album.zip';
      final cbzOut = '${tempDir.path}/manga.cbz';

      final zipFile = await PackArchiveService.packToZip(files: [file1, file2], outputPath: zipOut);
      expect(await zipFile.exists(), isTrue);
      expect(await zipFile.length(), greaterThan(0));

      final cbzFile = await PackArchiveService.packToCbz(files: [file1, file2], outputPath: cbzOut);
      expect(await cbzFile.exists(), isTrue);
      expect(await cbzFile.length(), greaterThan(0));
    });
  });

  group('Pro Feature 3: Video Time-Range Trimmer', () {
    test('DownloadTask model preserves trimStartTime and trimEndTime', () {
      final task = DownloadTask(
        id: 'trim-task-1',
        url: 'https://cdn.example.com/epic_moment.mp4',
        pageUrl: 'https://example.com/clip',
        filename: 'epic_moment_trim_15s_75s.mp4',
        savedPath: 'C:\\Downloads\\epic_moment_trim_15s_75s.mp4',
        mediaType: MediaType.video,
        trimStartTime: 15.0,
        trimEndTime: 75.0,
        createdAt: DateTime.now(),
      );

      final map = task.toMap();
      expect(map['trimStartTime'], equals(15.0));
      expect(map['trimEndTime'], equals(75.0));

      final restored = DownloadTask.fromMap(map);
      expect(restored.trimStartTime, equals(15.0));
      expect(restored.trimEndTime, equals(75.0));
      expect(restored.filename, contains('_trim_15s_75s.mp4'));
    });
  });

  group('Pro Feature 4 & 5: Subtitles & Metadata in AppSettings', () {
    test('AppSettings preserves autoGrabSubtitles and embedMetadataAndCoverArt', () {
      const settings = AppSettings(
        autoGrabSubtitles: true,
        embedMetadataAndCoverArt: true,
      );

      final map = settings.toMap();
      expect(map['autoGrabSubtitles'], isTrue);
      expect(map['embedMetadataAndCoverArt'], isTrue);

      final restored = AppSettings.fromMap(map);
      expect(restored.autoGrabSubtitles, isTrue);
      expect(restored.embedMetadataAndCoverArt, isTrue);
    });
  });

  group('Pro Feature 6: Formatters Utilities', () {
    test('Formatters.formatSeconds converts seconds into mm:ss and hh:mm:ss', () {
      expect(Formatters.formatSeconds(45), equals('00:45'));
      expect(Formatters.formatSeconds(125), equals('02:05'));
      expect(Formatters.formatSeconds(3665), equals('01:01:05'));
    });
  });
}
