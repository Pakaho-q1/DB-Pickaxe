import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:db_pickaxe/core/network/cookie_manager_service.dart';
import 'package:db_pickaxe/core/storage/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('db_pickaxe_upgrade_test_');
    Hive.init(tempTestDir.path);
    HiveService.cookiesBox = await Hive.openBox(HiveService.cookiesBoxName);
  });

  tearDown(() async {
    await HiveService.cookiesBox.close();
    await Hive.close();
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('Cookie & Header Auto-Sync Unit Tests', () {
    test('CookieManagerService.syncCookiesFromPage extracts domain and saves to Hive', () async {
      await CookieManagerService.syncCookiesFromPage(
        'https://sub.example.com/watch?v=123',
        'session_id=abc123xyz; auth=token999',
      );

      final cookie = CookieManagerService.getCookieHeaderForUrl('https://sub.example.com/video.mp4');
      expect(cookie, isNotNull);
      expect(cookie, contains('session_id=abc123xyz'));
      expect(cookie, contains('auth=token999'));
    });

    test('CookieManagerService.getHeadersForUrl automatically injects Cookie and Referer', () async {
      await CookieManagerService.syncCookiesFromPage(
        'https://stream.provider.net/embed/456',
        'cf_clearance=cf_token_secret; uid=8888',
      );

      final headers = CookieManagerService.getHeadersForUrl(
        'https://stream.provider.net/media/playlist.m3u8',
        pageUrl: 'https://stream.provider.net/embed/456',
      );

      expect(headers['Referer'], equals('https://stream.provider.net/embed/456'));
      expect(headers['Cookie'], equals('cf_clearance=cf_token_secret; uid=8888'));
    });

    test('CookieManagerService.getHeadersForUrl respects existing custom headers', () async {
      final custom = {'User-Agent': 'CustomBot/1.0', 'Referer': 'https://custom.referer'};
      final headers = CookieManagerService.getHeadersForUrl(
        'https://example.com/asset.jpg',
        pageUrl: 'https://ignored.com',
        customHeaders: custom,
      );

      expect(headers['User-Agent'], equals('CustomBot/1.0'));
      expect(headers['Referer'], equals('https://custom.referer'));
    });
  });
}
