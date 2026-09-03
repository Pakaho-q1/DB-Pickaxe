import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/policy/platform_capabilities.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/presentation/mobile/mobile_floating_sniffer_bubble.dart';
import '../../domain/models/browser_tab.dart';
import '../../services/unified_browser_bridge.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/browser_tabs_provider.dart';
import 'mobile_bottom_bar.dart';
import 'mobile_hub_bottom_sheet.dart';
import 'mobile_tab_switcher_sheet.dart';

class MobileBrowserScreen extends ConsumerStatefulWidget {
  const MobileBrowserScreen({super.key});

  @override
  ConsumerState<MobileBrowserScreen> createState() => _MobileBrowserScreenState();
}

class _MobileBrowserScreenState extends ConsumerState<MobileBrowserScreen> {
  final _urlTextController = TextEditingController();
  final _focusNode = FocusNode();
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  InAppWebViewController? _webViewController;
  String _currentLoadedUrl = '';
  String _lastRenderedTabId = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlTextController.dispose();
    _focusNode.dispose();
    _progressNotifier.dispose();
    _isLoadingNotifier.dispose();
    super.dispose();
  }

  void _submitUrl() {
    final raw = _urlTextController.text.trim();
    if (raw.isNotEmpty) {
      var target = raw;
      if (!target.startsWith('http://') && !target.startsWith('https://')) {
        if (target.contains('.') && !target.contains(' ')) {
          target = 'https://$target';
        } else {
          target = 'https://www.google.com/search?q=${Uri.encodeComponent(target)}';
        }
      }
      _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
    }
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  void _toggleBookmark() {
    final currentUrl = _currentLoadedUrl.isNotEmpty ? _currentLoadedUrl : _urlTextController.text.trim();
    if (currentUrl.isEmpty) return;

    final bookmarks = ref.read(bookmarksProvider);
    final existing = bookmarks.where((b) => b.url.toLowerCase() == currentUrl.toLowerCase()).firstOrNull;

    if (existing != null) {
      ref.read(bookmarksProvider.notifier).removeBookmark(existing.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bookmark removed'),
          duration: Duration(seconds: 1),
          backgroundColor: AppTheme.darkSurface,
        ),
      );
    } else {
      ref.read(bookmarksProvider.notifier).addBookmark(
        title: _urlTextController.text.isNotEmpty ? _urlTextController.text : currentUrl,
        url: currentUrl,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⭐ Added to Bookmarks'),
          duration: Duration(seconds: 1),
          backgroundColor: AppTheme.accentCyan,
        ),
      );
    }
  }

  void _injectSnifferScript() {
    final settings = ref.read(settingsProvider);
    final script = UnifiedBrowserBridge.getInjectedSnifferScript(
      enableAutoScroll: settings.enableAutoScroll,
      enableAutoVideoTrigger: settings.enableAutoVideoTrigger,
    );
    _webViewController?.evaluateJavascript(source: script);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(browserTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);
    final activeTab = tabs.firstWhere(
      (t) => t.id == activeTabId,
      orElse: () => tabs.isNotEmpty ? tabs.first : const BrowserTab(id: ''),
    );

    // Synchronize address bar input on tab switch
    if (activeTab.id != _lastRenderedTabId) {
      _lastRenderedTabId = activeTab.id;
      _currentLoadedUrl = activeTab.url;
      _urlTextController.text = activeTab.url;
    }

    final bookmarks = ref.watch(bookmarksProvider);
    final isCurrentBookmarked = _currentLoadedUrl.isNotEmpty &&
        bookmarks.any((b) => b.url.toLowerCase() == _currentLoadedUrl.toLowerCase());

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Modern Address Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: AppTheme.darkSurface,
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppTheme.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _urlTextController,
                              focusNode: _focusNode,
                              style: const TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Search or enter URL...',
                                hintStyle: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              onEditingComplete: _submitUrl,
                              onSubmitted: (_) => _submitUrl(),
                            ),
                          ),
                          if (_urlTextController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppTheme.darkTextSecondary),
                              onPressed: () {
                                _urlTextController.clear();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // ⭐ Bookmark Star Button
                  IconButton(
                    icon: Icon(
                      isCurrentBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 22,
                      color: isCurrentBookmarked ? Colors.amber : AppTheme.darkTextSecondary,
                    ),
                    tooltip: 'Bookmark',
                    onPressed: _toggleBookmark,
                  ),
                  // Reload / Stop Button
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingNotifier,
                    builder: (context, isLoading, _) {
                      return IconButton(
                        icon: Icon(
                          isLoading ? Icons.close : Icons.refresh,
                          size: 20,
                          color: AppTheme.darkTextPrimary,
                        ),
                        onPressed: () {
                          if (isLoading) {
                            _webViewController?.stopLoading();
                          } else {
                            _webViewController?.reload();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            // High-Performance Progress Indicator
            ValueListenableBuilder<bool>(
              valueListenable: _isLoadingNotifier,
              builder: (context, isLoading, _) {
                if (!isLoading) return const SizedBox.shrink();
                return ValueListenableBuilder<double>(
                  valueListenable: _progressNotifier,
                  builder: (context, progress, _) {
                    return LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: Colors.transparent,
                      color: AppTheme.accentCyan,
                      minHeight: 2.5,
                    );
                  },
                );
              },
            ),
            // 2. Mobile InAppWebView Viewport Area (Keyed by activeTab.id for 100% SSOT)
            Expanded(
              child: Stack(
                children: [
                  if (activeTab.id.isNotEmpty)
                    InAppWebView(
                      key: ValueKey(activeTab.id),
                      initialUrlRequest: URLRequest(
                        url: WebUri(activeTab.url.isNotEmpty ? activeTab.url : AppConstants.defaultHomePage),
                      ),
                      initialSettings: InAppWebViewSettings(
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        cacheEnabled: true,
                        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                        userAgent: PlatformCapabilities.defaultUserAgent,
                        preferredContentMode: UserPreferredContentMode.MOBILE,
                        supportZoom: true,
                        builtInZoomControls: true,
                        displayZoomControls: false,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'SnifferChannel',
                          callback: (args) {
                            if (args.isNotEmpty) {
                              UnifiedBrowserBridge.handleWebMessage(
                                ref: ref,
                                tabId: activeTab.id,
                                rawMessage: args[0],
                              );
                            }
                          },
                        );
                      },
                      onLoadStart: (controller, url) {
                        _isLoadingNotifier.value = true;
                        if (url != null) {
                          _currentLoadedUrl = url.toString();
                          if (!_focusNode.hasFocus) {
                            _urlTextController.text = _currentLoadedUrl;
                          }
                          UnifiedBrowserBridge.onPageLoadStarted(
                            ref: ref,
                            tabId: activeTab.id,
                            url: _currentLoadedUrl,
                          );
                        }
                        _injectSnifferScript();
                      },
                      onLoadStop: (controller, url) async {
                        _isLoadingNotifier.value = false;
                        if (url != null) {
                          _currentLoadedUrl = url.toString();
                          if (!_focusNode.hasFocus) {
                            _urlTextController.text = _currentLoadedUrl;
                          }
                          final title = await controller.getTitle();
                          final canBack = await controller.canGoBack();
                          final canFwd = await controller.canGoForward();

                          UnifiedBrowserBridge.onPageLoadFinished(
                            ref: ref,
                            tabId: activeTab.id,
                            url: _currentLoadedUrl,
                            title: title,
                            canGoBack: canBack,
                            canGoForward: canFwd,
                          );
                        }
                        _injectSnifferScript();
                      },
                      onProgressChanged: (controller, progress) {
                        _progressNotifier.value = progress / 100.0;
                        _isLoadingNotifier.value = progress < 100;
                      },
                    ),
                  // Floating Sniffer Bubble (1DM Style)
                  const MobileFloatingSnifferBubble(),
                ],
              ),
            ),
            // 3. Mobile Bottom Action Bar
            MobileBottomBar(
              onGoBack: () => _webViewController?.goBack(),
              onGoForward: () => _webViewController?.goForward(),
              onGoHome: () => _webViewController?.loadUrl(
                urlRequest: URLRequest(url: WebUri(AppConstants.defaultHomePage)),
              ),
              onOpenTabs: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const MobileTabSwitcherSheet(),
                );
              },
              onOpenSettings: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MobileHubBottomSheet(
                    onNavigateUrl: (url) {
                      _urlTextController.text = url;
                      _submitUrl();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
