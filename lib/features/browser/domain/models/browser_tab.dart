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
    this.url = 'https://www.google.com',
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.progress = 0.0,
    this.controller,
  });

  String get displayTitle {
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty &&
        cleanTitle != 'about:blank' &&
        cleanTitle != 'New Tab' &&
        cleanTitle != 'Web Page') {
      return cleanTitle;
    }

    if (url.isNotEmpty && url != 'about:blank') {
      try {
        final uri = Uri.parse(url);
        String host = uri.host.toLowerCase();
        host = host.replaceFirst(RegExp(r'^www\.'), '');
        if (host.isNotEmpty) {
          final parts = host.split('.');
          if (parts.isNotEmpty) {
            final name = parts[0];
            if (name.isNotEmpty) {
              return name[0].toUpperCase() + (name.length > 1 ? name.substring(1) : '');
            }
          }
          return host;
        }
      } catch (_) {}
    }

    return 'Google';
  }

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
