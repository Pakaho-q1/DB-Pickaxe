import 'package:flutter_test/flutter_test.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
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

      // 2. Network XHR captures same image with sizeBytes and different sizing query params
      sniffer.addMedia(
        tabId: 'tab-1',
        url: 'https://images.unsplash.com/photo-1234.jpg?q=80&w=1200',
        pageUrl: 'https://unsplash.com',
        sizeBytes: 2048576,
      );

      // Should smart merge into the single card instead of creating a duplicate!
      expect(sniffer.state['tab-1']?.length, equals(1));
      final merged = sniffer.state['tab-1']!.first;
      expect(merged.sizeBytes, equals(2048576));
      expect(merged.resolution, equals('1920x1080'));
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
  });
}
