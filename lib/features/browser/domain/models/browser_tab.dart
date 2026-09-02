import 'package:webview_windows/webview_windows.dart';

class BrowserTab {
  final String id;
  final String title;
  final String url;
  final bool isLoading;
  final bool canGoBack;
  final bool canGoForward;
  final double progress;
  final WebviewController? controller;

  const BrowserTab({
    required this.id,
    this.title = '',
    this.url = '',
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.progress = 0.0,
    this.controller,
  });

  /// Returns page title if available, otherwise returns dynamic fallback "Browser $index".
  String getTitle(int index) {
    final clean = title.trim();
    if (clean.isNotEmpty &&
        clean != 'about:blank' &&
        clean != 'New Tab' &&
        clean != 'Web Page') {
      return clean;
    }
    return 'Browser $index';
  }

  String get displayTitle => getTitle(1);

  BrowserTab copyWith({
    String? title,
    String? url,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
    double? progress,
    WebviewController? controller,
  }) {
    return BrowserTab(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      isLoading: isLoading ?? this.isLoading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      progress: progress ?? this.progress,
      controller: controller ?? this.controller,
    );
  }
}

