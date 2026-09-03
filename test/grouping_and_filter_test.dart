import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
import 'package:db_pickaxe/core/network/local_doh_proxy_service.dart';
import 'package:db_pickaxe/core/storage/hive_service.dart';
import 'package:db_pickaxe/features/browser/presentation/providers/browser_tabs_provider.dart';
import 'package:db_pickaxe/features/sniffer/domain/models/media_filter.dart';
import 'package:db_pickaxe/features/sniffer/presentation/providers/sniffer_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('grouping_test_');
    Hive.init(tempDir.path);
    HiveService.settingsBox = await Hive.openBox(HiveService.settingsBoxName);
  });

  tearDown(() async {
    await LocalDohProxyService.stop();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Local DoH Proxy Service Tests', () {
    test('LocalDohProxyService starts on loopback port', () async {
      final port = await LocalDohProxyService.start();
      expect(port, greaterThan(0));
      expect(LocalDohProxyService.isRunning, isTrue);
      expect(LocalDohProxyService.port, equals(port));
    });
  });

  group('Universal Media Grouping & (+N) Variant Tests', () {
    test('Videos with same base ID but different resolutions collapse into 1 group with (+N)', () {
      final container = ProviderContainer();
      final sniffer = container.read(snifferProvider.notifier);

      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.pexels.com/video-files/17722627/17722627-sd_360_640_24fps.mp4',
        pageUrl: 'https://pexels.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.pexels.com/video-files/17722627/17722627-hd_720_1280_24fps.mp4',
        pageUrl: 'https://pexels.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.pexels.com/video-files/17722627/17722627-uhd_2160_3840_24fps.mp4',
        pageUrl: 'https://pexels.com',
        thumbnailUrl: 'https://images.pexels.com/videos/17722627/preview.jpg',
      );

      container.read(activeTabIdProvider.notifier).state = 'tab-1';
      final grouped = container.read(groupedFilteredMediaProvider);

      expect(grouped.length, equals(1));
      final g = grouped.first;
      expect(g.variants.length, equals(2));
      expect(g.primary.url, contains('2160_3840'));
      expect(g.primary.thumbnailUrl, equals('https://images.pexels.com/videos/17722627/preview.jpg'));
    });

    test('Thumbnail is inherited by primary even if lower resolution had the thumbnail', () {
      final container = ProviderContainer();
      final sniffer = container.read(snifferProvider.notifier);

      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/video/999/999-uhd_2160_3840.mp4',
        pageUrl: 'https://example.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/video/999/999-hd_720_1280.mp4',
        pageUrl: 'https://example.com',
        thumbnailUrl: 'https://cdn.example.com/thumb_999.jpg',
      );

      container.read(activeTabIdProvider.notifier).state = 'tab-1';
      final grouped = container.read(groupedFilteredMediaProvider);

      expect(grouped.length, equals(1));
      expect(grouped.first.primary.thumbnailUrl, equals('https://cdn.example.com/thumb_999.jpg'));
    });

    test('Resolution is automatically detected from filename patterns', () {
      final container = ProviderContainer();
      final sniffer = container.read(snifferProvider.notifier);

      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/16565095_1440_2560_30fps.mp4',
        pageUrl: 'https://example.com',
      );

      final item = sniffer.state['tab-1']!.first;
      expect(item.resolution, equals('1440x2560'));
    });

    test('Unsplash extensionless image URLs are accurately detected as MediaType.image with .jpg extension', () {
      final container = ProviderContainer();
      final sniffer = container.read(snifferProvider.notifier);

      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop&q=60',
        pageUrl: 'https://unsplash.com',
        title: 'Puppy Photo',
      );

      final item = sniffer.state['tab-1']!.first;
      expect(item.mediaType, equals(MediaType.image));
      expect(item.extension, equals('.jpg'));
      expect(item.filename.endsWith('.jpg'), isTrue);
    });

    test('Junk stream segments (.m4s, chunk.ts) are dropped and ignored', () {
      final container = ProviderContainer();
      final sniffer = container.read(snifferProvider.notifier);

      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://video.twimg.com/ext_tw_video/123/pu/vid/0.m4s',
        pageUrl: 'https://x.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://video.twimg.com/ext_tw_video/123/pu/vid/18446744073709551615.m4s',
        pageUrl: 'https://x.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/live/segment-10.ts',
        pageUrl: 'https://example.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/master.m3u8',
        pageUrl: 'https://example.com',
      );

      final items = sniffer.state['tab-1'] ?? [];
      expect(items.length, equals(1));
      expect(items.first.url, equals('https://cdn.example.com/master.m3u8'));
    });
  });

  group('Production Filter & RangeSlider Tests', () {
    test('Independent Width and Height RangeSliders filter correctly', () {
      final container = ProviderContainer();
      final sniffer = container.read(snifferProvider.notifier);

      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/img_1920x1080.jpg',
        pageUrl: 'https://example.com',
        width: 1920,
        height: 1080,
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/img_1080x1920.jpg',
        pageUrl: 'https://example.com',
        width: 1080,
        height: 1920,
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/img_500x500.jpg',
        pageUrl: 'https://example.com',
        width: 500,
        height: 500,
      );

      container.read(activeTabIdProvider.notifier).state = 'tab-1';

      container.read(snifferFilterProvider.notifier).state = const MediaFilter(
        minWidth: 1900,
        maxHeight: 1200,
      );

      final landscapeList = container.read(filteredMediaProvider);
      expect(landscapeList.length, equals(1));
      expect(landscapeList.first.url, contains('1920x1080'));

      container.read(snifferFilterProvider.notifier).state = const MediaFilter(
        maxWidth: 1200,
        minHeight: 1900,
      );

      final portraitList = container.read(filteredMediaProvider);
      expect(portraitList.length, equals(1));
      expect(portraitList.first.url, contains('1080x1920'));
    });
  });
}
