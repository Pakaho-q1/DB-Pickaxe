import 'package:webview_windows/webview_windows.dart';
import '../storage/hive_service.dart';

class CookieManagerService {
  /// Save and inject a raw cookie string into the active Webview controller
  static Future<void> injectCookieIntoWebview({
    required WebviewController controller,
    required String domain,
    required String cookieString,
  }) async {
    // 1. Persist to local Hive database
    await HiveService.saveCookieForDomain(domain, cookieString);

    // 2. Inject into WebView document session via JS
    final pairs = cookieString.split(';');
    for (final pair in pairs) {
      final trimmed = pair.trim();
      if (trimmed.isNotEmpty) {
        final js = "document.cookie = '$trimmed; path=/; domain=$domain; max-age=31536000';";
        try {
          await controller.executeScript(js);
        } catch (_) {}
      }
    }
  }

  /// Automatically capture cookies from current web page and save to Hive
  static Future<void> syncCookiesFromPage(String url, String documentCookie) async {
    if (url.isEmpty || documentCookie.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      final domain = uri.host.replaceFirst(RegExp(r'^www\.'), '');
      if (domain.isNotEmpty) {
        await HiveService.saveCookieForDomain(domain, documentCookie);
      }
    } catch (_) {}
  }

  /// Resolve cookie header for any URL to attach into Dio / FFmpeg
  static String? getCookieHeaderForUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return HiveService.getCookiesForDomain(uri.host);
    } catch (_) {
      return null;
    }
  }
}
