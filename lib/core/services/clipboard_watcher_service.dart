import 'dart:async';
import 'package:flutter/services.dart';

class ClipboardWatcherService {
  static final List<String> capturedLinks = [];
  static bool isWatching = true;
  static Timer? _pollTimer;
  static String _lastClipboardText = '';
  static final StreamController<List<String>> _linksController = StreamController<List<String>>.broadcast();

  static Stream<List<String>> get linksStream => _linksController.stream;

  static void startWatching() {
    isWatching = true;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkClipboard());
  }

  static void stopWatching() {
    isWatching = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static void clearCapturedLinks() {
    capturedLinks.clear();
    _linksController.add(List.unmodifiable(capturedLinks));
  }

  static Future<void> _checkClipboard() async {
    if (!isWatching) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text == _lastClipboardText) return;
      _lastClipboardText = text;

      // Extract URLs from clipboard text
      final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
      final matches = urlRegExp.allMatches(text);

      bool hasNew = false;
      for (final match in matches) {
        final url = match.group(0)?.trim() ?? '';
        if (url.isNotEmpty && !capturedLinks.contains(url)) {
          capturedLinks.insert(0, url);
          hasNew = true;
        }
      }

      if (hasNew) {
        _linksController.add(List.unmodifiable(capturedLinks));
      }
    } catch (_) {}
  }
}
