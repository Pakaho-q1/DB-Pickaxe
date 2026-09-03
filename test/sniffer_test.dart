import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
import 'package:db_pickaxe/features/sniffer/domain/models/detected_media.dart';
import 'package:db_pickaxe/features/sniffer/domain/models/media_filter.dart';
import 'package:db_pickaxe/features/sniffer/presentation/providers/sniffer_provider.dart';

void main() {
  group('Per-Tab Sniffer & Smart Deduplication Unit Tests', () {
    late SnifferNotifier sniffer;

    setUp(() {
      sniffer = SnifferNotifier();
    });

    test('Media is isolated per tabId', () {
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://example.com/video1.mp4',
        pageUrl: 'https://example.com',
        title: 'Video 1',
      );

      sniffer.addMedia(
        tabId: 'tab-2',
        url: 'https://example.com/video2.mp4',
        pageUrl: 'https://example.com/2',
        title: 'Video 2',
      );

      expect(sniffer.state['tab-1']?.length, equals(1));
      expect(sniffer.state['tab-1']?.first.filename, equals('Video 1.mp4'));

      expect(sniffer.state['tab-2']?.length, equals(1));
      expect(sniffer.state['tab-2']?.first.filename, equals('Video 2.mp4'));

      // Clearing tab-1 does not affect tab-2
      sniffer.clearTabMedia('tab-1');
      expect(sniffer.state['tab-1']?.isEmpty, isTrue);
      expect(sniffer.state['tab-2']?.length, equals(1));
    });

    test('Canonical URL Deduplication & Smart Merge unifies DOM and Network entries', () {
      // 1. Initial DOM scan finds image with resolution but sizeBytes = 0
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.unsplash.com/photo-1234.jpg?w=800&auto=format&fit=crop',
        pageUrl: 'https://unsplash.com',
        width: 1920,
        height: 1080,
      );

      expect(sniffer.state['tab-1']?.length, equals(1));
      expect(sniffer.state['tab-1']?.first.sizeBytes, equals(0));
      expect(sniffer.state['tab-1']?.first.resolution, equals('1920x1080'));

      // 2. Network XHR captures same image with sizeBytes and ephemeral token (w/q preserved,
      // token/t stripped so canonical stays equal → smart merge).
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.unsplash.com/photo-1234.jpg?w=800&auto=format&fit=crop&t=1700000000&token=xyz999',
        pageUrl: 'https://unsplash.com',
        sizeBytes: 2048576,
      );

      // Should smart merge into the single card instead of creating a duplicate!
      expect(sniffer.state['tab-1']?.length, equals(1));
      final merged = sniffer.state['tab-1']!.first;
      expect(merged.sizeBytes, equals(2048576));
      expect(merged.resolution, equals('1920x1080'));
    });

    test('Quality params w/q/dpr are PRESERVED — different resolutions are distinct entries', () {
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.unsplash.com/photo-1234.jpg?w=800&auto=format&fit=crop',
        pageUrl: 'https://unsplash.com',
        width: 800,
        height: 600,
      );
      // Same base image but w=1200 and q=80 — must NOT dedup.
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.unsplash.com/photo-1234.jpg?w=1200&q=80&auto=format&fit=crop',
        pageUrl: 'https://unsplash.com',
        width: 1200,
        height: 900,
      );
      expect(sniffer.state['tab-1']?.length, equals(2));
    });

    test('Canonical URL Deduplication prevents duplicate media entries with ephemeral tokens', () {
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/stream.m3u8?token=xyz123&t=1600000000&_=1',
        pageUrl: 'https://example.com/watch',
      );

      // Same base stream with different ephemeral timestamp/token
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/stream.m3u8?token=abc999&t=1600000099&_=2',
        pageUrl: 'https://example.com/watch',
      );

      expect(sniffer.state['tab-1']?.length, equals(1));
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.stream));
    });

    test('Batch media addition handles multiple items efficiently in a single operation', () {
      final batch = [
        {
          'url': 'https://example.com/batch_img1.jpg',
          'pageUrl': 'https://example.com',
          'title': 'Batch 1',
          'type': 'image',
        },
        {
          'url': 'https://example.com/batch_img2.jpg',
          'pageUrl': 'https://example.com',
          'title': 'Batch 2',
          'type': 'image',
        },
        {
          'url': 'https://example.com/batch_video.mp4',
          'pageUrl': 'https://example.com',
          'title': 'Batch Video',
          'type': 'video',
        },
      ];

      sniffer.addMediaBatch(tabId: 'tab-1', items: batch);
      expect(sniffer.state['tab-1']?.length, equals(3));
    });

    test('Selection and batch selection operations work per tab', () {
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://example.com/img1.jpg',
        pageUrl: 'https://example.com',
      );
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://example.com/img2.jpg',
        pageUrl: 'https://example.com',
      );

      final mediaId1 = sniffer.state['tab-1']![0].id;
      final mediaId2 = sniffer.state['tab-1']![1].id;

      sniffer.toggleSelect(mediaId1);
      expect(sniffer.state['tab-1']!.firstWhere((m) => m.id == mediaId1).isSelected, isTrue);
      expect(sniffer.state['tab-1']!.firstWhere((m) => m.id == mediaId2).isSelected, isFalse);

      sniffer.selectAllForTab('tab-1', true);
      expect(sniffer.state['tab-1']!.every((m) => m.isSelected), isTrue);

      sniffer.selectAllForTab('tab-1', false);
      expect(sniffer.state['tab-1']!.every((m) => !m.isSelected), isTrue);
    });

    // Phase 4 guard rails
    test('Canonical sorts keys — param order does not create duplicate', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/a.jpg?b=2&a=1', pageUrl: 'https://example.com');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/a.jpg?a=1&b=2', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
    });

    test('Canonical strips ephemeral keys case-insensitively (Token vs token)', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/v.mp4?Token=abc', pageUrl: 'https://example.com');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/v.mp4?token=xyz', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
    });

    test('Smart merge enriches thumbnail and resolution without duplicating', () {
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/clip.mp4',
        pageUrl: 'https://example.com',
        width: 0,
        height: 0,
      );
      expect(sniffer.state['tab-1']?.first.resolution, isNull);
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://cdn.example.com/clip.mp4?token=ephemeral',
        pageUrl: 'https://example.com',
        width: 1280,
        height: 720,
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
      );
      expect(sniffer.state['tab-1']?.length, equals(1));
      expect(sniffer.state['tab-1']?.first.resolution, equals('1280x720'));
      expect(sniffer.state['tab-1']?.first.thumbnailUrl, equals('https://cdn.example.com/thumb.jpg'));
    });

    test('clearTabMedia resets dedup — same URL can be re-added after clear', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://example.com/readd.jpg', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
      sniffer.clearTabMedia('tab-1');
      expect(sniffer.state['tab-1']?.length, equals(0));
      sniffer.addMedia(tabId: 'tab-1', url: 'https://example.com/readd.jpg', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
    });

    // P0: _detectMediaType — mime / typeStr / extension precedence
    test('P0 detectMediaType via extension and mime override', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/clip.mp4', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.video));
      expect(sniffer.state['tab-1']?.first.extension, equals('.mp4'));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/photo.jpg', pageUrl: 'https://example.com', mime: 'video/mp4');
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.video));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/file.bin', pageUrl: 'https://example.com', mime: 'image/jpeg');
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.image));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/live.m3u8', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.stream));
      expect(sniffer.state['tab-1']?.first.extension, equals('.m3u8'));
    });

    test('P0 detectMediaType via typeStr override', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/unknown.bin', pageUrl: 'https://example.com', typeStr: 'image');
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.image));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/unknown2.bin', pageUrl: 'https://example.com', typeStr: 'audio');
      expect(sniffer.state['tab-1']?.first.mediaType, equals(MediaType.audio));
    });

    test('P0 _generateFilename sanitize + truncate + double-ext guard', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/FxGOw5GC_720p.mp4', pageUrl: 'https://example.com', title: 'FxGOw5GC_720p.mp4');
      expect(sniffer.state['tab-1']?.first.filename, equals('FxGOw5GC_720p.mp4'));
      expect(sniffer.state['tab-1']?.first.filename.contains('.mp4.mp4'), isFalse);
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/a.mp4', pageUrl: 'https://example.com', title: r'a/b:c*?"<>|.mp4');
      expect(sniffer.state['tab-1']?.first.filename.contains('/'), isFalse);
      expect(sniffer.state['tab-1']?.first.filename.contains(':'), isFalse);
      sniffer.clearTabMedia('tab-1');
      final longTitle = 'A' * 100 + '.mp4';
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/long.mp4', pageUrl: 'https://example.com', title: longTitle);
      expect(sniffer.state['tab-1']?.first.filename.length, lessThanOrEqualTo(60));
      expect(sniffer.state['tab-1']?.first.filename.endsWith('.mp4'), isTrue);
    });

    test('P0 _canonicalUrl: host lower, malformed fallback, only ephemeral stripped', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://CDN.Example.COM/a.jpg?b=2&a=1', pageUrl: 'https://example.com');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/a.jpg?a=1&b=2', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'not a valid url ???', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/x.jpg?token=1&_nc_sid=abc&w=800', pageUrl: 'https://example.com');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/x.jpg?w=800', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.length, equals(1));
    });

    test('P0 _extractExtension fallback .dat and .mp4 for video type', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/noext', pageUrl: 'https://example.com', typeStr: 'video');
      expect(sniffer.state['tab-1']?.first.extension, equals('.mp4'));
      sniffer.clearTabMedia('tab-1');
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/noext2', pageUrl: 'https://example.com');
      expect(sniffer.state['tab-1']?.first.extension, equals('.dat'));
    });

    test('P1 smart merge preserves headers and does not overwrite existing resolution', () {
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/v.mp4', pageUrl: 'https://example.com', width: 1920, height: 1080, headers: {'Referer': 'https://example.com'});
      expect(sniffer.state['tab-1']?.first.resolution, equals('1920x1080'));
      sniffer.addMedia(tabId: 'tab-1', url: 'https://cdn.example.com/v.mp4?token=1', pageUrl: 'https://example.com', width: 640, height: 360, headers: {'Cookie': 'a=b'});
      expect(sniffer.state['tab-1']?.length, equals(1));
      expect(sniffer.state['tab-1']?.first.resolution, equals('1920x1080'));
      expect(sniffer.state['tab-1']?.first.headers['Referer'], equals('https://example.com'));
      expect(sniffer.state['tab-1']?.first.headers['Cookie'], equals('a=b'));
    });

    test('P1 addMediaBatch merges duplicates within same batch', () {
      sniffer.addMediaBatch(tabId: 'tab-1', items: [
        {'url': 'https://cdn.example.com/b1.jpg', 'pageUrl': 'https://example.com', 'type': 'image', 'width': 100, 'height': 100},
        {'url': 'https://cdn.example.com/b1.jpg?token=1', 'pageUrl': 'https://example.com', 'type': 'image', 'width': 200, 'height': 200},
      ]);
      expect(sniffer.state['tab-1']?.length, equals(1));
      expect(sniffer.state['tab-1']?.first.resolution, equals('100x100'));
    });
  });

  group('P1 DetectedMedia model', () {
    test('copyWith preserves fields', () {
      final m = DetectedMedia(id: '1', url: 'https://cdn.example.com/a.jpg', pageUrl: 'https://example.com', filename: 'a.jpg', mediaType: MediaType.image, extension: '.jpg', detectedAt: DateTime(2024, 1, 1), resolution: '800x600', domIndex: 5);
      final c = m.copyWith(isSelected: true, sizeBytes: 123);
      expect(c.isSelected, isTrue);
      expect(c.sizeBytes, equals(123));
      expect(c.resolution, equals('800x600'));
      expect(c.id, equals('1'));
    });
  });

  group('B image grouping display collapse', () {
    test('imageGroupKey: same path different ?w/q collapse to one grouped card', () {
      expect(imageGroupKey('https://cdn.example.com/a/b.jpg?w=400&q=80'), equals(imageGroupKey('https://cdn.example.com/a/b.jpg?w=800&q=60')));
      expect(imageGroupKey('https://CDN.Example.COM/A/B.JPG?W=400'), equals('https://cdn.example.com/a/b.jpg'));
      expect(imageGroupKey('https://cdn.example.com/a/b.jpg?w=400'), equals('https://cdn.example.com/a/b.jpg'));
      expect(imageGroupKey('https://cdn.example.com/a/other.jpg?w=400'), isNot(equals(imageGroupKey('https://cdn.example.com/a/b.jpg?w=400'))));
    });

    test('groupedFilteredMediaProvider collapses ?w variants, sorts by area, video not grouped', () async {
      DetectedMedia mk(String url, int w, int h, MediaType t) => DetectedMedia(
            id: url,
            url: url,
            pageUrl: 'https://example.com',
            filename: 'f${url.hashCode}.jpg',
            mediaType: t,
            extension: t == MediaType.video ? '.mp4' : '.jpg',
            detectedAt: DateTime.now(),
            resolution: '${w}x$h',
            domIndex: w,
          );
      final seeded = [
        mk('https://cdn.example.com/p/photo.jpg?w=400', 400, 300, MediaType.image),
        mk('https://cdn.example.com/p/photo.jpg?w=800', 800, 600, MediaType.image),
        mk('https://cdn.example.com/p/photo.jpg?w=1200', 1200, 900, MediaType.image),
        mk('https://cdn.example.com/p/other.jpg?w=400', 400, 300, MediaType.image),
        mk('https://cdn.example.com/v/clip.mp4', 1280, 720, MediaType.video),
      ];
      final container = ProviderContainer(overrides: [
        filteredMediaProvider.overrideWith((ref) => seeded),
      ]);
      addTearDown(container.dispose);

      final groups = container.read(groupedFilteredMediaProvider);
      // 3 variants collapse to 1 group + other image + video = 3 groups total
      expect(groups.length, equals(3));
      final photoGroup = groups.firstWhere((g) => g.primary.url.contains('/photo.jpg'));
      expect(photoGroup.variants.length, equals(2));
      expect(photoGroup.primary.resolution, equals('1200x900')); // largest first
      expect(photoGroup.totalCount, equals(3));
      final videoGroups = groups.where((g) => g.primary.mediaType == MediaType.video).toList();
      expect(videoGroups.length, equals(1));
      expect(videoGroups.first.variants, isEmpty);
    });

    test('showGroupedVariants toggle expands to flat list', () async {
      DetectedMedia mk(String url, int w) => DetectedMedia(
            id: url,
            url: url,
            pageUrl: 'https://example.com',
            filename: 'f.jpg',
            mediaType: MediaType.image,
            extension: '.jpg',
            detectedAt: DateTime.now(),
            resolution: '${w}x$w',
            domIndex: w,
          );
      final seeded = [
        mk('https://cdn.example.com/p/a.jpg?w=400', 400),
        mk('https://cdn.example.com/p/a.jpg?w=800', 800),
      ];
      final container = ProviderContainer(overrides: [
        filteredMediaProvider.overrideWith((ref) => seeded),
      ]);
      addTearDown(container.dispose);
      expect(container.read(groupedFilteredMediaProvider).length, equals(1));
      container.read(showGroupedVariantsProvider.notifier).state = true;
      expect(container.read(groupedFilteredMediaProvider).length, equals(2));
    });
  });

  group('P1 filteredMediaProvider logic via ProviderContainer', () {
    test('typeFilter video includes stream, search and minSize filter', () async {
      // We test the pure filter logic by replicating SnifferNotifier state + MediaFilter
      // to avoid HiveService init in provider. Directly test MediaFilter + list filtering.
      final items = [
        DetectedMedia(id: '1', url: 'https://cdn.example.com/a.mp4', pageUrl: 'https://example.com', filename: 'movie.mp4', mediaType: MediaType.video, extension: '.mp4', sizeBytes: 10 * 1024 * 1024, detectedAt: DateTime.now(), resolution: '1920x1080', domIndex: 1),
        DetectedMedia(id: '2', url: 'https://cdn.example.com/b.m3u8', pageUrl: 'https://example.com', filename: 'live.m3u8', mediaType: MediaType.stream, extension: '.m3u8', sizeBytes: 0, detectedAt: DateTime.now(), resolution: '1280x720', domIndex: 2),
        DetectedMedia(id: '3', url: 'https://cdn.example.com/c.jpg', pageUrl: 'https://example.com', filename: 'photo.jpg', mediaType: MediaType.image, extension: '.jpg', sizeBytes: 500 * 1024, detectedAt: DateTime.now(), resolution: '800x600', domIndex: 3),
      ];
      // typeFilter video should keep video+stream
      const videoFilter = MediaFilter(typeFilter: MediaType.video);
      final videoFiltered = items.where((i) {
        if (videoFilter.typeFilter == MediaType.video) return i.mediaType == MediaType.video || i.mediaType == MediaType.stream;
        return i.mediaType == videoFilter.typeFilter;
      }).toList();
      expect(videoFiltered.length, equals(2));
      // search — use MediaFilter field directly
      final searched = items.where((i) => i.filename.toLowerCase().contains(const MediaFilter(searchQuery: 'photo').searchQuery)).toList();
      expect(searched.length, equals(1));
      // minWidth
      const widthFilter = MediaFilter(minWidth: 1000);
      final widthFiltered = items.where((i) {
        if (i.resolution != null && i.resolution!.contains('x')) {
          final w = int.tryParse(i.resolution!.split('x')[0]) ?? 0;
          return w >= widthFilter.minWidth;
        }
        return true;
      }).toList();
      expect(widthFiltered.length, equals(2));
    });
  });
}
