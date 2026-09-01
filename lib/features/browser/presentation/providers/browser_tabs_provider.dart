import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../../sniffer/domain/models/detected_media.dart';
import '../../../sniffer/presentation/providers/sniffer_provider.dart';
import '../../../sniffer/services/js_sniffer_scripts.dart';
import '../../domain/models/browser_tab.dart';
import 'history_provider.dart';

final activeTabIdProvider = StateProvider<String>((ref) => '');

// Auto-Detect Toggle: When true, continuously detects media. When false, only detects on demand.
final isAutoDetectEnabledProvider = StateProvider<bool>((ref) => true);

final browserTabsProvider = StateNotifierProvider<BrowserTabsNotifier, List<BrowserTab>>((ref) {
  return BrowserTabsNotifier(ref);
});

class BrowserTabsNotifier extends StateNotifier<List<BrowserTab>> {
  final Ref ref;
  bool _isInitialTabCreated = false;

  BrowserTabsNotifier(this.ref) : super([]) {
    if (!_isInitialTabCreated) {
      _isInitialTabCreated = true;
      // Initialize initial tab smoothly
      Future.microtask(() => createTab(url: AppConstants.defaultHomePage));
    }
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

    try {
      await controller.initialize();
      await controller.setUserAgent(AppConstants.defaultUserAgent);
      await controller.setBackgroundColor(const Color(0xFF0F172A));

      // Prevent popup ads from opening separate external windows
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);

      // Listen to postMessage from Injected JS
      controller.webMessage.listen((message) {
        _handleWebMessage(message, tabId);
      });

      // Listen to URL updates
      controller.url.listen((currentUrl) {
        if (currentUrl.isNotEmpty) {
          _updateTab(tabId, url: currentUrl);
        }
      });

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
      });

      // Listen to Loading state
      controller.loadingState.listen((stateEnum) async {
        final isLoading = stateEnum == LoadingState.loading;
        _updateTab(tabId, isLoading: isLoading);

        if (stateEnum == LoadingState.navigationCompleted) {
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
      });

      // Listen to Error state
      controller.onLoadError.listen((error) {
        _updateTab(tabId, isLoading: false);
      });

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

        // If user clicked the floating "Download Video" IDM button
        if (action == 'DIRECT_DOWNLOAD') {
          final media = DetectedMedia(
            id: const Uuid().v4(),
            url: url,
            pageUrl: pageUrl,
            filename: title != null && title.isNotEmpty ? '$title.mp4' : 'downloaded_video.mp4',
            mediaType: MediaType.video,
            extension: '.mp4',
            detectedAt: DateTime.now(),
            thumbnailUrl: thumbnailUrl,
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
  }

  Future<void> rescanActiveTab() async {
    final activeId = ref.read(activeTabIdProvider);
    final activeTab = state.firstWhere((t) => t.id == activeId, orElse: () => const BrowserTab(id: ''));
    if (activeTab.controller != null) {
      await activeTab.controller!.executeScript(JsSnifferScripts.snifferPayload);
      await activeTab.controller!.executeScript('if (window.__dbPickaxeRescan) window.__dbPickaxeRescan();');
    }
  }

  Future<void> navigateTo(String tabId, String urlString) async {
    String formattedUrl = urlString.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      if (formattedUrl.contains('.') && !formattedUrl.contains(' ')) {
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
    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    tab.controller?.dispose();

    final remaining = state.where((t) => t.id != tabId).toList();
    state = remaining;

    if (ref.read(activeTabIdProvider) == tabId) {
      if (remaining.isNotEmpty) {
        ref.read(activeTabIdProvider.notifier).state = remaining.last.id;
      } else {
        await createTab();
      }
    }
  }
}
