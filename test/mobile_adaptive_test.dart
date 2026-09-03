import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:db_pickaxe/core/constants/app_constants.dart';
import 'package:db_pickaxe/core/utils/platform_helper.dart';
import 'package:db_pickaxe/features/browser/domain/models/browser_tab.dart';
import 'package:db_pickaxe/features/browser/presentation/mobile/mobile_bottom_bar.dart';
import 'package:db_pickaxe/features/browser/presentation/providers/browser_tabs_provider.dart';
import 'package:db_pickaxe/features/sniffer/domain/models/detected_media.dart';
import 'package:db_pickaxe/features/sniffer/presentation/mobile/mobile_media_tile.dart';

class MockBrowserTabsNotifier extends StateNotifier<List<BrowserTab>> implements BrowserTabsNotifier {
  @override
  final Ref ref;

  MockBrowserTabsNotifier(this.ref, List<BrowserTab> initialTabs) : super(initialTabs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Mobile Adaptive Architecture Unit Tests', () {
    test('PlatformHelper returns valid desktop/mobile booleans', () {
      expect(PlatformHelper.isMobile, isA<bool>());
      expect(PlatformHelper.isDesktop, isA<bool>());
    });

    testWidgets('MobileBottomBar renders 5 navigation buttons & tab count badge', (tester) async {
      bool tabsOpened = false;
      bool settingsOpened = false;

      final mockTabs = [
        const BrowserTab(
          id: 'tab-1',
          url: 'https://flutter.dev',
          title: 'Flutter Dev',
          isLoading: false,
          canGoBack: true,
          canGoForward: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserTabsProvider.overrideWith((ref) => MockBrowserTabsNotifier(ref, mockTabs)),
            activeTabIdProvider.overrideWith((ref) => 'tab-1'),
          ],
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MobileBottomBar(
                onOpenTabs: () => tabsOpened = true,
                onOpenSettings: () => settingsOpened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify buttons exist
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Verify tab count badge is '1'
      expect(find.text('1'), findsOneWidget);

      // Tap tab switcher
      await tester.tap(find.byKey(const Key('mobile_tab_switcher_btn')));
      expect(tabsOpened, isTrue);

      // Tap menu button
      await tester.tap(find.byIcon(Icons.menu_rounded));
      expect(settingsOpened, isTrue);
    });

    testWidgets('MobileMediaTile displays metadata and quick action buttons', (tester) async {
      final media = DetectedMedia(
        id: 'media-1',
        tabId: 'tab-1',
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        pageUrl: 'https://sample.com',
        filename: 'BigBuckBunny',
        mediaType: MediaType.video,
        extension: '.mp4',
        resolution: '1080p',
        sizeBytes: 158000000,
        detectedAt: DateTime.now(),
      );

      bool downloadTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MobileMediaTile(
                media: media,
                onDownload: () => downloadTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify filename, resolution, and extension tags render
      expect(find.text('BigBuckBunny'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('.MP4'), findsOneWidget);

      // Tap download button
      await tester.tap(find.byIcon(Icons.download_rounded));
      expect(downloadTapped, isTrue);
    });
  });
}
