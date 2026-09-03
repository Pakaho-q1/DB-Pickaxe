import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../../core/policy/platform_capabilities.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/presentation/providers/sniffer_provider.dart';
import '../../domain/models/browser_tab.dart';
import '../../services/unified_browser_bridge.dart';

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

    // On Mobile: pure BrowserTab without Windows WebView2
    if (PlatformCapabilities.isMobile) {
      final newTab = BrowserTab(
        id: tabId,
        url: url,
        title: 'New Tab',
        isLoading: false,
      );
      state = [...state, newTab];
      ref.read(activeTabIdProvider.notifier).state = tabId;
      _persistSession();
      return;
    }

    // On Desktop (Windows): Initialize WebviewController
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
      await controller.setUserAgent(PlatformCapabilities.defaultUserAgent);
      await controller.setBackgroundColor(const Color(0xFF0F172A));
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);

      // Store subscriptions for Windows WebView
      _tabSubscriptions[tabId] = [
        // 1. PostMessage from Injected JS -> Unified SSOT Bridge
        controller.webMessage.listen((message) {
          UnifiedBrowserBridge.handleWebMessage(
            ref: ref,
            tabId: tabId,
            rawMessage: message,
          );
        }),

        // 2. URL changes -> Unified SSOT Bridge
        controller.url.listen((currentUrl) {
          if (currentUrl.isNotEmpty) {
            UnifiedBrowserBridge.onPageLoadStarted(
              ref: ref,
              tabId: tabId,
              url: currentUrl,
            );
          }
        }),

        // 3. Title updates -> Unified SSOT Bridge
        controller.title.listen((title) {
          final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
          UnifiedBrowserBridge.onPageLoadFinished(
            ref: ref,
            tabId: tabId,
            url: tab.url,
            title: title.trim(),
          );
        }),

        // 4. Loading state updates
        controller.loadingState.listen((stateEnum) async {
          final isLoading = stateEnum == LoadingState.loading;
          final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));

          if (isLoading) {
            UnifiedBrowserBridge.onPageLoadStarted(
              ref: ref,
              tabId: tabId,
              url: tab.url,
            );
          } else if (stateEnum == LoadingState.navigationCompleted) {
            final isAuto = ref.read(isAutoDetectEnabledProvider);
            if (isAuto) {
              final settings = HiveService.getSettings();
              final script = UnifiedBrowserBridge.getInjectedSnifferScript(
                enableAutoScroll: settings.enableAutoScroll,
                enableAutoVideoTrigger: settings.enableAutoVideoTrigger,
              );
              await controller.executeScript(script);
            }

            // Auto-sync page cookies to Cookie Vault
            try {
              final cookieRaw = await controller.executeScript('document.cookie');
              if (cookieRaw != null && cookieRaw is String && cookieRaw.isNotEmpty) {
                await CookieManagerService.syncCookiesFromPage(tab.url, cookieRaw);
              }
            } catch (_) {}

            UnifiedBrowserBridge.onPageLoadFinished(
              ref: ref,
              tabId: tabId,
              url: tab.url,
              title: tab.title,
            );
          }
        }),

        controller.onLoadError.listen((error) {
          _updateTab(tabId, isLoading: false);
        }),
      ];

      await controller.loadUrl(url);

      // Safety timeout
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

  void updateTabInfo(
    String tabId, {
    String? url,
    String? title,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
    double? progress,
  }) {
    _updateTab(
      tabId,
      url: url,
      title: title,
      isLoading: isLoading,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      progress: progress,
    );
    _persistSession();
  }

  void _updateTab(
    String tabId, {
    String? title,
    String? url,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
    double? progress,
  }) {
    state = [
      for (final tab in state)
        if (tab.id == tabId)
          tab.copyWith(
            title: title,
            url: url,
            isLoading: isLoading,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            progress: progress,
          )
        else
          tab,
    ];
  }

  void selectTab(String tabId) {
    if (state.any((t) => t.id == tabId)) {
      ref.read(activeTabIdProvider.notifier).state = tabId;
      _persistSession();
    }
  }

  Future<void> navigateTo(String tabId, String targetUrl) async {
    var finalUrl = targetUrl.trim();
    if (finalUrl.isEmpty) return;

    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = 'https://$finalUrl';
      } else {
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
      }
    }

    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    _updateTab(tabId, url: finalUrl, isLoading: true);
    _persistSession();

    if (tab.controller != null) {
      await tab.controller?.loadUrl(finalUrl);
    }
  }

  Future<void> goBack(String tabId) async {
    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    if (tab.controller != null && tab.canGoBack) {
      await tab.controller?.goBack();
    }
  }

  Future<void> goForward(String tabId) async {
    final tab = state.firstWhere((t) => t.id == tabId, orElse: () => BrowserTab(id: tabId));
    if (tab.controller != null && tab.canGoForward) {
      await tab.controller?.goForward();
    }
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

  Future<void> rescanActiveTab() async {
    final activeTabId = ref.read(activeTabIdProvider);
    if (activeTabId.isEmpty) return;
    final tab = state.firstWhere((t) => t.id == activeTabId, orElse: () => BrowserTab(id: activeTabId));
    final settings = HiveService.getSettings();
    final script = UnifiedBrowserBridge.getInjectedSnifferScript(
      enableAutoScroll: settings.enableAutoScroll,
      enableAutoVideoTrigger: settings.enableAutoVideoTrigger,
    );
    if (tab.controller != null) {
      await tab.controller?.executeScript(script);
    }
  }
}
