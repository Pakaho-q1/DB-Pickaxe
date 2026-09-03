import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/cookie_manager_service.dart';
import '../../downloader/presentation/providers/download_queue_provider.dart';
import '../../sniffer/domain/models/detected_media.dart';
import '../../sniffer/presentation/providers/sniffer_provider.dart';
import '../../sniffer/services/js_sniffer_scripts.dart';
import '../presentation/providers/browser_tabs_provider.dart';
import '../presentation/providers/history_provider.dart';

/// Centralized Single Source of Truth (SSOT) Bridge for all Webview platforms (Windows & Android).
class UnifiedBrowserBridge {
  /// Centralized dispatcher for all incoming messages from injected JavaScript.
  static void handleWebMessage({
    required dynamic ref,
    required String tabId,
    required dynamic rawMessage,
  }) {
    if (tabId.isEmpty || rawMessage == null) return;

    try {
      final Map<String, dynamic> data = rawMessage is Map<String, dynamic>
          ? rawMessage
          : jsonDecode(rawMessage.toString()) as Map<String, dynamic>;

      final action = data['action'] as String? ?? '';

      // 1. High-Performance Batched Media Detection
      if (action == 'MEDIA_BATCH_DETECTED') {
        final rawItems = (data['items'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        if (rawItems.isNotEmpty) {
          ref.read(snifferProvider.notifier).addMediaBatch(
                tabId: tabId,
                items: rawItems,
              );
        }
        return;
      }

      // 2. Cookie Synchronization to Cookie Vault
      if (action == 'COOKIE_SYNC') {
        final pageUrl = data['url'] as String? ?? '';
        final cookies = data['cookies'] as String? ?? '';
        if (pageUrl.isNotEmpty && cookies.isNotEmpty) {
          CookieManagerService.syncCookiesFromPage(pageUrl, cookies);
        }
        return;
      }

      // 3. Single Page App (SPA) URL Change
      if (action == 'PAGE_URL_CHANGED') {
        final keepMedia = ref.read(keepMediaAcrossPagesProvider);
        if (!keepMedia) {
          ref.read(snifferProvider.notifier).clearTabMedia(tabId);
        }
        final newUrl = data['newUrl'] as String? ?? '';
        final cookies = data['cookies'] as String? ?? '';
        if (newUrl.isNotEmpty && cookies.isNotEmpty) {
          CookieManagerService.syncCookiesFromPage(newUrl, cookies);
        }
        if (newUrl.isNotEmpty) {
          ref.read(browserTabsProvider.notifier).updateTabInfo(
                tabId,
                url: newUrl,
              );
        }
        return;
      }

      // 4. Direct One-Click Media Download
      if (action == 'DIRECT_DOWNLOAD') {
        final url = data['url'] as String? ?? '';
        final pageUrl = data['pageUrl'] as String? ?? '';
        final title = data['title'] as String? ?? 'direct_download';
        final ext = title.contains('.') ? '.${title.split('.').last}' : '.mp4';

        if (url.isNotEmpty) {
          final media = DetectedMedia(
            id: '${tabId}_${url.hashCode}',
            tabId: tabId,
            url: url,
            pageUrl: pageUrl,
            filename: title,
            mediaType: MediaType.video,
            extension: ext,
            detectedAt: DateTime.now(),
          );
          ref.read(downloadQueueProvider.notifier).addMediaToQueue(media);
        }
        return;
      }
    } catch (_) {}
  }

  /// Generates the cross-platform JavaScript payload for sniffing media.
  static String getInjectedSnifferScript({
    required bool enableAutoScroll,
    required bool enableAutoVideoTrigger,
  }) {
    return JsSnifferScripts.getSnifferPayload(
      enableAutoScroll: enableAutoScroll,
      enableAutoVideoTrigger: enableAutoVideoTrigger,
    );
  }

  /// Universal hook when a page begins loading.
  static void onPageLoadStarted({
    required dynamic ref,
    required String tabId,
    required String url,
  }) {
    if (tabId.isEmpty) return;

    final keepMedia = ref.read(keepMediaAcrossPagesProvider);
    if (!keepMedia) {
      ref.read(snifferProvider.notifier).clearTabMedia(tabId);
    }

    ref.read(browserTabsProvider.notifier).updateTabInfo(
          tabId,
          url: url,
          isLoading: true,
        );
  }

  /// Universal hook when a page finishes loading.
  static void onPageLoadFinished({
    required dynamic ref,
    required String tabId,
    required String url,
    required String? title,
    bool canGoBack = false,
    bool canGoForward = false,
  }) {
    if (tabId.isEmpty) return;

    ref.read(browserTabsProvider.notifier).updateTabInfo(
          tabId,
          url: url,
          title: title,
          isLoading: false,
          canGoBack: canGoBack,
          canGoForward: canGoForward,
        );

    if (url.isNotEmpty && !url.startsWith('about:') && !url.startsWith('data:')) {
      ref.read(historyProvider.notifier).recordVisit(
            title: title ?? url,
            url: url,
          );
    }
  }
}
