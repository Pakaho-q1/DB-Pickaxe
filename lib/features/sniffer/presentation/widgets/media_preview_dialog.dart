import 'dart:convert';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/media_type_helper.dart';
import '../../../browser/presentation/providers/browser_tabs_provider.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/detected_media.dart';
import 'media_preview_player.dart';

Uint8List _previewBase64Decode(String src) => base64Decode(src);

class MediaPreviewDialog extends ConsumerStatefulWidget {
  final DetectedMedia media;

  const MediaPreviewDialog({super.key, required this.media});

  @override
  ConsumerState<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends ConsumerState<MediaPreviewDialog> {
  late bool _showLivePlayer;
  double _trimStart = 0;
  double _trimEnd = 60;
  bool _enableTrim = false;

  @override
  void initState() {
    super.initState();
    // Default to Live Player for video, stream, and audio
    _showLivePlayer = widget.media.mediaType == MediaType.video ||
        widget.media.mediaType == MediaType.stream ||
        widget.media.mediaType == MediaType.audio;
  }

  bool _isHttpScheme(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Map<String, String> _previewHeaders(String imageUrl) {
    final h = <String, String>{};
    if (widget.media.pageUrl.isNotEmpty) h['Referer'] = widget.media.pageUrl;
    final cookie = CookieManagerService.getCookieHeaderForUrl(imageUrl);
    if (cookie != null && cookie.isNotEmpty) h['Cookie'] = cookie;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final (:icon, :color) = MediaTypeHelper.propsFor(media.mediaType);
    final typeIcon = icon;
    final typeColor = color;
    final isPlayable = media.mediaType == MediaType.video ||
        media.mediaType == MediaType.stream ||
        media.mediaType == MediaType.audio;

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 760,
        height: 620,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    media.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ),
                if (isPlayable) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(
                          label: 'Live Player',
                          icon: Icons.play_circle_outline,
                          isActive: _showLivePlayer,
                          onTap: () => setState(() => _showLivePlayer = true),
                        ),
                        _buildModeButton(
                          label: 'Thumbnail',
                          icon: Icons.image_outlined,
                          isActive: !_showLivePlayer,
                          onTap: () => setState(() => _showLivePlayer = false),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            // Main Media Preview Viewport
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: _buildMainPreview(typeIcon, typeColor),
              ),
            ),
            const SizedBox(height: 12),
            // URL Info Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 16, color: AppTheme.darkTextSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      media.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    tooltip: 'Copy URL',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: media.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Video Time-Range Trimmer Section
            if (isPlayable) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.content_cut, size: 14, color: AppTheme.accentAmber),
                            const SizedBox(width: 6),
                            const Text(
                              'Time-Range Trimmer',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _enableTrim,
                              activeThumbColor: AppTheme.accentAmber,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) => setState(() => _enableTrim = val),
                            ),
                          ],
                        ),
                        if (_enableTrim)
                          Text(
                            '${Formatters.formatSeconds(_trimStart.toInt())} - ${Formatters.formatSeconds(_trimEnd.toInt())}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                          ),
                      ],
                    ),
                    if (_enableTrim) ...[
                      RangeSlider(
                        values: RangeValues(_trimStart, _trimEnd),
                        min: 0,
                        max: 600, // Up to 10 mins
                        divisions: 120,
                        activeColor: AppTheme.accentAmber,
                        labels: RangeLabels(
                          Formatters.formatSeconds(_trimStart.toInt()),
                          Formatters.formatSeconds(_trimEnd.toInt()),
                        ),
                        onChanged: (vals) {
                          setState(() {
                            _trimStart = vals.start;
                            _trimEnd = vals.end;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Bottom Action Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: const Text('Open in Tab', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    ref.read(browserTabsProvider.notifier).createTab(url: media.url);
                    Navigator.of(context).pop();
                  },
                ),
                Row(
                  children: [
                    if (isPlayable) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.music_note, size: 15),
                        label: const Text('Extract Audio (.mp3)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          ref.read(downloadQueueProvider.notifier).addAudioOnlyToQueue(media);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Audio Queued: ${media.filename} (.mp3)')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_enableTrim) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentAmber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.content_cut, size: 15),
                        label: Text(
                          'Trim & Download (${Formatters.formatSeconds((_trimEnd - _trimStart).toInt())})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          ref.read(downloadQueueProvider.notifier).addTrimmedVideoToQueue(
                                media,
                                startTime: _trimStart,
                                endTime: _trimEnd,
                              );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Trimmed Clip Queued: ${media.filename}')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download Full', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ref.read(downloadQueueProvider.notifier).addMediaToQueue(media);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to download queue: ${media.filename}')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isActive ? Colors.white : AppTheme.darkTextSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPreview(IconData icon, Color color) {
    final media = widget.media;

    // Image preview: Zoomable InteractiveViewer
    if (media.mediaType == MediaType.image) {
      if (media.url.startsWith('data:image')) {
        final commaIdx = media.url.indexOf(',');
        if (commaIdx == -1) return _buildFallbackInfo(icon, color);
        final b64 = media.url.substring(commaIdx + 1);
        if (b64.length > 800 * 1024) return _buildFallbackInfo(icon, color);
        return InteractiveViewer(
          maxScale: 4.0,
          child: Center(
            child: FutureBuilder<Uint8List>(
              future: compute(_previewBase64Decode, b64),
              builder: (context, snap) {
                if (snap.hasData) {
                  return Image.memory(snap.data!, fit: BoxFit.contain);
                }
                if (snap.hasError) return _buildFallbackInfo(icon, color);
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
      if (_isHttpScheme(media.url)) {
        return InteractiveViewer(
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: media.url,
              httpHeaders: _previewHeaders(media.url),
              fit: BoxFit.contain,
              placeholder: (context, _) => const Center(
                child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorBuilder: (context, _, stackTrace) => _buildFallbackInfo(icon, color),
              fadeInDuration: const Duration(milliseconds: 150),
            ),
          ),
        );
      }
      return _buildFallbackInfo(icon, color);
    }

    // Video / Stream / Audio: Live Interactive Player View
    if (_showLivePlayer) {
      return MediaPreviewPlayer(key: ValueKey('player_${media.id}'), media: media);
    }

    // Fallback or Thumbnail Mode
    final thumb = media.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      if (thumb.startsWith('data:image')) {
        final commaIdx = thumb.indexOf(',');
        if (commaIdx == -1) return _buildFallbackInfo(icon, color);
        final b64 = thumb.substring(commaIdx + 1);
        if (b64.length > 800 * 1024) return _buildFallbackInfo(icon, color);
        return FutureBuilder<Uint8List>(
          future: compute(_previewBase64Decode, b64),
          builder: (context, snap) {
            if (snap.hasData) {
              return Center(
                child: Image.memory(snap.data!, fit: BoxFit.contain),
              );
            }
            if (snap.hasError) return _buildFallbackInfo(icon, color);
            return const Center(
              child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      }
      if (_isHttpScheme(thumb)) {
        return Center(
          child: CachedNetworkImage(
            imageUrl: thumb,
            httpHeaders: _previewHeaders(thumb),
            fit: BoxFit.contain,
            placeholder: (context, _) => const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorBuilder: (context, _, stackTrace) => _buildFallbackInfo(icon, color),
            fadeInDuration: const Duration(milliseconds: 150),
          ),
        );
      }
    }

    return _buildFallbackInfo(icon, color);
  }

  Widget _buildFallbackInfo(IconData icon, Color color) {
    final media = widget.media;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            media.mediaType == MediaType.stream
                ? 'HLS Video Stream (.m3u8)'
                : media.mediaType == MediaType.audio
                    ? 'Audio Track (.${media.extension.replaceAll('.', '')})'
                    : 'Video Resource (.${media.extension.replaceAll('.', '')})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
          ),
          const SizedBox(height: 8),
          if (media.resolution != null)
            Text(
              'Resolution: ${media.resolution}',
              style: const TextStyle(color: AppTheme.accentCyan, fontSize: 13),
            ),
          const SizedBox(height: 4),
          Text(
            media.sizeBytes > 0 ? 'Size: ${Formatters.formatBytes(media.sizeBytes)}' : 'Streaming / Media Link',
            style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
