import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/domain/models/detected_media.dart';
import '../../../sniffer/presentation/providers/sniffer_provider.dart';
import '../../../sniffer/services/js_sniffer_scripts.dart';
import '../../domain/models/browser_tab.dart';
import 'history_provider.dart';

final activeTabIdProvider = StateProvider<String>((ref) => '');

class AutoDetectNotifier extends StateNotifier<bool> {
  AutoDetectNotifier() : super(HiveService.getIsAutoDetect());

  @override
  set state(bool value) {
    super.state = value;
    HiveService.saveIsAutoDetect(value);
  }
}

// Auto-Detect Toggle: When true, continuously detects media. When false, only detects on demand. (Persisted)
final isAutoDetectEnabledProvider = StateNotifierProvider<AutoDetectNotifier, bool>((ref) {
  return AutoDetectNotifier();
});

final browserTabsProvider = StateNotifierProvider<BrowserTabsNotifier, List<BrowserTab>>((ref) {
  return BrowserTabsNotifier(ref);
});

class BrowserTabsNotifier extends StateNotifier<List<BrowserTab>> {
  final Ref ref;
  bool _isInitialTabCreated = false;

  /// Tracks all active stream subscriptions per tab ID so they can be
  /// cancelled when the tab is closed, preventing memory and listener leaks.
  final Map<String, List<StreamSubscription<dynamic>>> _tabSubscriptions = {};

  BrowserTabsNotifier(this.ref) : super([]) {
    if (!_isInitialTabCreated) {
      _isInitialTabCreated = true;
      Future.microtask(() => _initSession());
    }
  }

  Future<void> _initSession() async {
    final settings = ref.read(settingsProvider);
    final savedTabs = HiveService.getSessionTabs();
    final lastActiveId = HiveService.getLastActiveTabId();

    switch (settings.startupBehavior) {
      case AppStartupBehavior.newTab:
        await createTab(url: AppConstants.defaultHomePage);
        break;

      case AppStartupBehavior.lastTab:
        if (savedTabs.isNotEmpty) {
          final lastTabMap = savedTabs.firstWhere(
            (t) => t['id'] == lastActiveId,
            orElse: () => savedTabs.last,
          );
          final url = lastTabMap['url'] as String? ?? AppConstants.defaultHomePage;
          await createTab(url: url.isNotEmpty ? url : AppConstants.defaultHomePage);
        } else {
          await createTab(url: AppConstants.defaultHomePage);
        }
        break;

      case AppStartupBehavior.restoreAll:
        if (savedTabs.isNotEmpty) {
          for (final tabMap in savedTabs) {
            final url = tabMap['url'] as String? ?? AppConstants.defaultHomePage;
            await createTab(url: url.isNotEmpty ? url : AppConstants.defaultHomePage);
          }
        } else {
          await createTab(url: AppConstants.defaultHomePage);
        }
        break;

      case AppStartupBehavior.newTabPlusRestore:
        if (savedTabs.isNotEmpty) {
          for (final tabMap in savedTabs) {
            final url = tabMap['url'] as String? ?? AppConstants.defaultHomePage;
            await createTab(url: url.isNotEmpty ? url : AppConstants.defaultHomePage);
          }
        }
        await createTab(url: AppConstants.defaultHomePage);
        break;
    }
  }

  void _persistSession() {
    final activeId = ref.read(activeTabIdProvider);
    final tabMaps = state.map((tab) => {
          'id': tab.id,
          'url': tab.url,
          'title': tab.title,
        }).toList();
    HiveService.saveSessionTabs(tabMaps, activeId);
  }

  Future<void> createTab({String url = AppConstants.defaultHomePage}) async {
    final tabId = const Uuid().v4();
    final controller = WebviewController();

    final newTab = BrowserTab(
      id: tabId,
      url: url,
      title: '',
      controller: controller,
      isLoading: true,
    );

    // Register tab in state
    state = [...state, newTab];
    ref.read(activeTabIdProvider.notifier).state = tabId;
    _persistSession();

    try {
      await controller.initialize();
      await controller.setUserAgent(AppConstants.defaultUserAgent);
      await controller.setBackgroundColor(const Color(0xFF0F172A));

      // Prevent popup ads from opening separate external windows
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);

      // Store all subscriptions so they can be cancelled on tab close.
      _tabSubscriptions[tabId] = [
        // Listen to postMessage from Injected JS
        controller.webMessage.listen((message) {
          _handleWebMessage(message, tabId);
        }),

        // Listen to URL updates
        controller.url.listen((currentUrl) {
          if (currentUrl.isNotEmpty) {
            _updateTab(tabId, url: currentUrl);
          }
        }),

        // Listen to Title updates
        controller.title.listen((title) {
          final cleanTitle = title.trim();
          if (cleanTitle.isNotEmpty) {
            _updateTab(tabId, title: cleanTitle);
            final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
            if (tab.url.isNotEmpty) {
              ref.read(historyProvider.notifier).recordVisit(title: cleanTitle, url: tab.url);
            }
          }
        }),

        // Listen to Loading state
        controller.loadingState.listen((stateEnum) async {
          final isLoading = stateEnum == LoadingState.loading;
          _updateTab(tabId, isLoading: isLoading);

          if (isLoading) {
            final keepMedia = ref.read(keepMediaAcrossPagesProvider);
            if (!keepMedia) {
              ref.read(snifferProvider.notifier).clearTabMedia(tabId);
            }
          } else if (stateEnum == LoadingState.navigationCompleted) {
            final isAuto = ref.read(isAutoDetectEnabledProvider);
            if (isAuto) {
              await controller.executeScript(JsSnifferScripts.snifferPayload);
            }

            // Auto-sync page cookies to Cookie Vault
            try {
              final cookieRaw = await controller.executeScript('document.cookie');
              if (cookieRaw != null && cookieRaw is String && cookieRaw.isNotEmpty) {
                final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
                await CookieManagerService.syncCookiesFromPage(tab.url, cookieRaw);
              }
            } catch (_) {}
          }
        }),

        // Listen to Error state
        controller.onLoadError.listen((error) {
          _updateTab(tabId, isLoading: false);
        }),
      ];

      await controller.loadUrl(url);

      // Safety timer: Never allow tab to remain stuck in isLoading state
      Future.delayed(const Duration(seconds: 5), () {
        final current = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
        if (current.isLoading) {
          _updateTab(tabId, isLoading: false);
        }
      });
    } catch (e) {
      _updateTab(tabId, isLoading: false);
    }
  }

  void _handleWebMessage(dynamic message, String tabId) {
    try {
      final Map<String, dynamic> data = jsonDecode(message.toString());
      final action = data['action'] as String? ?? '';

      // SPA Navigation detected
      if (action == 'PAGE_URL_CHANGED') {
        final keepMedia = ref.read(keepMediaAcrossPagesProvider);
        if (!keepMedia) {
          ref.read(snifferProvider.notifier).clearTabMedia(tabId);
        }
        final newUrl = data['newUrl'] as String? ?? '';
        if (newUrl.isNotEmpty) {
          _updateTab(tabId, url: newUrl);
        }
        return;
      }

      // High-Performance Batched Media Delivery
      if (action == 'MEDIA_BATCH_DETECTED') {
        final rawItems = data['items'] as List<dynamic>? ?? [];
        final items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        ref.read(snifferProvider.notifier).addMediaBatch(
              tabId: tabId,
              items: items,
            );
        return;
      }

      if (action == 'MEDIA_DETECTED' || action == 'DIRECT_DOWNLOAD') {
        final url = data['url'] as String? ?? '';
        final pageUrl = data['pageUrl'] as String? ?? '';
        final type = data['type'] as String? ?? 'other';
        final title = data['title'] as String?;
        final width = data['width'] as int? ?? 0;
        final height = data['height'] as int? ?? 0;
        final mime = data['mime'] as String?;
        final thumbnailUrl = data['thumbnailUrl'] as String?;
        final domIndex = data['domIndex'] as int? ?? 0;

        ref.read(snifferProvider.notifier).addMedia(
              tabId: tabId,
              url: url,
              pageUrl: pageUrl,
              title: title,
              typeStr: type,
              width: width,
              height: height,
              mime: mime,
              thumbnailUrl: thumbnailUrl,
              domIndex: domIndex,
            );

        // If user clicked the floating download button or pressed Shift+D
        if (action == 'DIRECT_DOWNLOAD') {
          final mediaType = type == 'video'
              ? MediaType.video
              : type == 'stream'
                  ? MediaType.stream
                  : type == 'image'
                      ? MediaType.image
                      : type == 'audio'
                          ? MediaType.audio
                          : MediaType.other;

          final ext = mediaType == MediaType.video || mediaType == MediaType.stream
              ? '.mp4'
              : mediaType == MediaType.image
                  ? (url.toLowerCase().contains('.png')
                      ? '.png'
                      : url.toLowerCase().contains('.webp')
                          ? '.webp'
                          : url.toLowerCase().contains('.gif')
                              ? '.gif'
                              : '.jpg')
                  : mediaType == MediaType.audio
                      ? '.mp3'
                      : '.dat';

          var cleanTitle = (title != null && title.trim().isNotEmpty)
              ? title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
              : 'downloaded_${mediaType.name}';

          if (!cleanTitle.toLowerCase().endsWith(ext.toLowerCase())) {
            cleanTitle = '$cleanTitle$ext';
          }

          final media = DetectedMedia(
            id: const Uuid().v4(),
            tabId: tabId,
            url: url,
            pageUrl: pageUrl,
            filename: cleanTitle,
            mediaType: mediaType,
            extension: ext,
            detectedAt: DateTime.now(),
            thumbnailUrl: thumbnailUrl ?? (mediaType == MediaType.image ? url : null),
            resolution: width > 0 && height > 0 ? '${width}x$height' : null,
          );
          ref.read(downloadQueueProvider.notifier).addMediaToQueue(media);
        }
      }
    } catch (_) {}
  }

  void _updateTab(
    String id, {
    String? title,
    String? url,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
    double? progress,
  }) {
    state = state.map((tab) {
      if (tab.id == id) {
        return tab.copyWith(
          title: (title != null && title.trim().isNotEmpty) ? title.trim() : tab.title,
          url: url ?? tab.url,
          isLoading: isLoading ?? tab.isLoading,
          canGoBack: canGoBack ?? tab.canGoBack,
          canGoForward: canGoForward ?? tab.canGoForward,
          progress: progress ?? tab.progress,
        );
      }
      return tab;
    }).toList();
    _persistSession();
  }

  Future<void> rescanActiveTab() async {
    final activeId = ref.read(activeTabIdProvider);
    final activeTab = state.firstWhere((t) => t.id == activeId, orElse: () => const BrowserTab(id: ''));
    if (activeTab.controller != null) {
      ref.read(snifferProvider.notifier).clearTabMedia(activeId);
      await activeTab.controller!.executeScript(JsSnifferScripts.snifferPayload);
      await activeTab.controller!.executeScript('if (window.__dbPickaxeRescan) window.__dbPickaxeRescan();');
    }
  }

  Future<void> navigateTo(String tabId, String urlString) async {
    String formattedUrl = urlString.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      final domainPattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+(/.*)?$');
      if (domainPattern.hasMatch(formattedUrl)) {
        formattedUrl = 'https://$formattedUrl';
      } else {
        formattedUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(formattedUrl)}';
      }
    }

    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    if (tab.controller != null) {
      _updateTab(tabId, url: formattedUrl, isLoading: true);
      await tab.controller!.loadUrl(formattedUrl);
    }
  }

  Future<void> goBack(String tabId) async {
    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    await tab.controller?.goBack();
  }

  Future<void> goForward(String tabId) async {
    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    await tab.controller?.goForward();
  }

  Future<void> reload(String tabId) async {
    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    _updateTab(tabId, isLoading: true);
    await tab.controller?.reload();
  }

  Future<void> closeTab(String tabId) async {
    // Clear sniffer media associated with this tab to free memory
    ref.read(snifferProvider.notifier).clearTabMedia(tabId);

    final subs = _tabSubscriptions.remove(tabId);
    if (subs != null) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }

    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    await tab.controller?.dispose();

    final remaining = state.where((t) => t.id != tabId).toList();
    state = remaining;

    if (ref.read(activeTabIdProvider) == tabId) {
      if (remaining.isNotEmpty) {
        ref.read(activeTabIdProvider.notifier).state = remaining.last.id;
      } else {
        await createTab();
      }
    }
    _persistSession();
  }

  Future<void> closeOtherTabs(String keepTabId) async {
    final tabsToClose = state.where((t) => t.id != keepTabId).toList();
    for (final tab in tabsToClose) {
      ref.read(snifferProvider.notifier).clearTabMedia(tab.id);
      final subs = _tabSubscriptions.remove(tab.id);
      if (subs != null) {
        for (final sub in subs) {
          await sub.cancel();
        }
      }
      await tab.controller?.dispose();
    }

    state = state.where((t) => t.id == keepTabId).toList();
    ref.read(activeTabIdProvider.notifier).state = keepTabId;
    _persistSession();
  }
}
