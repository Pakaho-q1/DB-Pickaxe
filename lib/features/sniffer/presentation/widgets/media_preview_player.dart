import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/detected_media.dart';

class MediaPreviewPlayer extends StatefulWidget {
  final DetectedMedia media;

  const MediaPreviewPlayer({super.key, required this.media});

  @override
  State<MediaPreviewPlayer> createState() => _MediaPreviewPlayerState();
}

class _MediaPreviewPlayerState extends State<MediaPreviewPlayer> {
  final WebviewController _controller = WebviewController();
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _controller.initialize();
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      // Inject cookies into webview session before loading media
      final cookie = CookieManagerService.getCookieHeaderForUrl(widget.media.url);
      if (cookie != null && cookie.isNotEmpty) {
        try {
          final uri = Uri.parse(widget.media.url);
          await CookieManagerService.injectCookieIntoWebview(
            controller: _controller,
            domain: uri.host,
            cookieString: cookie,
          );
        } catch (_) {}
      }

      final html = _generatePlayerHtml(widget.media);
      await _controller.loadStringContent(html);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _generatePlayerHtml(DetectedMedia media) {
    final rawUrl = media.url;
    final encodedUrl = jsonEncode(rawUrl);
    final isStream = media.mediaType == MediaType.stream || rawUrl.toLowerCase().contains('.m3u8');
    final isAudio = media.mediaType == MediaType.audio;

    if (isAudio) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body {
      background: #0B0F19;
      color: #F8FAFC;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      overflow: hidden;
      user-select: none;
    }
    .player-card {
      background: #1E293B;
      border: 1px solid #334155;
      border-radius: 16px;
      padding: 32px 24px;
      width: 90%;
      max-width: 480px;
      text-align: center;
      box-shadow: 0 10px 25px rgba(0,0,0,0.5);
    }
    .icon-box {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: linear-gradient(135deg, #6366F1, #06B6D4);
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px;
      box-shadow: 0 4px 14px rgba(99,102,241,0.4);
    }
    .icon-box svg { width: 36px; height: 36px; fill: #FFFFFF; }
    .title {
      font-size: 15px;
      font-weight: 600;
      color: #F8FAFC;
      margin-bottom: 8px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .format-badge {
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      color: #06B6D4;
      background: rgba(6,182,212,0.15);
      padding: 3px 10px;
      border-radius: 12px;
      margin-bottom: 24px;
    }
    audio {
      width: 100%;
      outline: none;
      filter: invert(0.88) hue-rotate(180deg);
    }
  </style>
</head>
<body>
  <div class="player-card">
    <div class="icon-box">
      <svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>
    </div>
    <div class="title">${_escapeHtml(media.filename)}</div>
    <div class="format-badge">AUDIO STREAM • ${media.extension.toUpperCase().replaceAll('.', '')}</div>
    <audio controls autoplay src=$encodedUrl></audio>
  </div>
</body>
</html>
''';
    }

    // Video / HLS Stream Player
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  ${media.pageUrl.isNotEmpty ? '<base href="${_escapeHtml(media.pageUrl)}">' : ''}
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0B0F19;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      overflow: hidden;
      font-family: system-ui, sans-serif;
    }
    .video-container {
      position: relative;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #000000;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      outline: none;
    }
    #error-overlay {
      display: none;
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(11,15,25,0.92);
      color: #FDA4AF;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px;
      text-align: center;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="video-container">
    <video id="player" controls autoplay playsinline></video>
    <div id="error-overlay">
      <div style="font-weight: bold; margin-bottom: 6px;">Live playback failed or stream is encrypted (DRM)</div>
      <div id="error-desc" style="color: #94A3B8; font-size: 11px;"></div>
    </div>
  </div>

  <script>
    const mediaUrl = $encodedUrl;
    const isStream = $isStream;
    const video = document.getElementById('player');
    const errOverlay = document.getElementById('error-overlay');
    const errDesc = document.getElementById('error-desc');

    function showError(msg) {
      errDesc.textContent = msg || 'Could not load video source';
      errOverlay.style.display = 'flex';
    }

    if (isStream && window.Hls && Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 90,
        xhrSetup: function(xhr, url) {
          xhr.withCredentials = true;
        }
      });
      hls.loadSource(mediaUrl);
      hls.attachMedia(video);
      hls.on(Hls.Events.MANIFEST_PARSED, function () {
        video.play().catch(function() {});
      });
      hls.on(Hls.Events.ERROR, function (event, data) {
        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              showError('Network stream error (CORS or 403 Forbidden). Try direct download.');
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              hls.recoverMediaError();
              break;
            default:
              showError('Unrecoverable stream error: ' + (data.details || 'DRM protected or encrypted'));
              hls.destroy();
              break;
          }
        }
      });
    } else {
      video.src = mediaUrl;
      video.onerror = function() {
        showError('Direct video playback error (Codec or Access restriction). Try downloading directly.');
      };
      video.play().catch(function() {});
    }
  </script>
</body>
</html>
''';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: AppTheme.darkBackground,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Failed to start media preview player',
                style: TextStyle(color: AppTheme.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: AppTheme.darkBackground,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.accentCyan,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading media preview engine...',
                style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Webview(_controller),
      ),
    );
  }
}
