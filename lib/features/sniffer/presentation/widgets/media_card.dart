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
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/detected_media.dart';
import '../providers/sniffer_provider.dart';
import 'media_preview_dialog.dart';

// Top-level for compute() isolate
Uint8List _base64DecodeIsolate(String src) => base64Decode(src);

class MediaCard extends ConsumerWidget {
  final DetectedMedia media;
  final int variantCount;

  const MediaCard({
    super.key,
    required this.media,
    this.variantCount = 0,
  });

  String _formatResolutionBadge(String res) {
    if (res.contains('3840') || res.contains('2160')) return '4K $res';
    if (res.contains('2560') || res.contains('1440')) return '2K $res';
    if (res.contains('1920') || res.contains('1080')) return 'FHD $res';
    if (res.contains('1280') || res.contains('720')) return 'HD $res';
    return res;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:icon, :color) = MediaTypeHelper.propsFor(media.mediaType);
    final badgeColor = color;
    final typeIcon = icon;

    return InkWell(
      onTap: () {
        ref.read(snifferProvider.notifier).toggleSelect(media.id);
      },
      borderRadius: BorderRadius.circular(8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: media.isSelected ? AppTheme.primaryLight : AppTheme.darkBorder,
            width: media.isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Container(
          color: media.isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : AppTheme.darkCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail area
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => MediaPreviewDialog(media: media),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThumbnailView(typeIcon, badgeColor),
                      // Top Left Badge: Format & Variant Count (+N)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                media.extension.toUpperCase().replaceAll('.', ''),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (variantCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCyan,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '(+$variantCount)',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Top Right: Checkbox
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Checkbox(
                          value: media.isSelected,
                          activeColor: AppTheme.primaryLight,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (_) {
                            ref.read(snifferProvider.notifier).toggleSelect(media.id);
                          },
                        ),
                      ),
                      // Bottom Right Resolution Badge
                      if (media.resolution != null && media.resolution!.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.80),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              _formatResolutionBadge(media.resolution!),
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      // Video Play Indicator Overlay
                      if (media.mediaType == MediaType.video || media.mediaType == MediaType.stream)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Compact Info & Action strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          media.sizeBytes > 0
                              ? Formatters.formatBytes(media.sizeBytes)
                              : (media.mediaType == MediaType.stream
                                  ? 'Stream'
                                  : (media.resolution != null ? media.resolution! : 'Probing...')),
                          style: const TextStyle(fontSize: 9, color: AppTheme.darkTextSecondary),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: media.url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('URL copied'), duration: Duration(seconds: 1)),
                                );
                              },
                              child: const Icon(Icons.copy, size: 13, color: AppTheme.darkTextSecondary),
                            ),
                            const SizedBox(width: 6),
                            if (media.mediaType == MediaType.video || media.mediaType == MediaType.stream) ...[
                              Tooltip(
                                message: 'Extract Audio Only (.mp3)',
                                child: InkWell(
                                  onTap: () {
                                  ref.read(downloadQueueProvider.notifier).addAudioOnlyToQueue(media);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Audio Queued: ${media.filename} (.mp3)'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                  child: const Icon(Icons.music_note, size: 14, color: AppTheme.accentCyan),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            InkWell(
                              onTap: () {
                                ref.read(downloadQueueProvider.notifier).addMediaToQueue(media);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Queued: ${media.filename}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: const Icon(Icons.download, size: 14, color: AppTheme.primaryLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRenderableScheme(String url) {
    if (url.startsWith('data:image')) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Map<String, String> _thumbHeaders(String imageUrl) {
    final headers = <String, String>{};
    if (media.pageUrl.isNotEmpty) headers['Referer'] = media.pageUrl;
    final cookie = CookieManagerService.getCookieHeaderForUrl(imageUrl);
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  Widget _buildCachedThumb(String url, IconData fallbackIcon, Color fallbackColor) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: _thumbHeaders(url),
      memCacheWidth: 320,
      memCacheHeight: 320,
      filterQuality: FilterQuality.low,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(
        color: AppTheme.darkBackground,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorBuilder: (context, _, stackTrace) => _buildFallback(fallbackIcon, fallbackColor),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  Widget _buildDataThumb(String dataUri, IconData fallbackIcon, Color fallbackColor) {
    final commaIdx = dataUri.indexOf(',');
    if (commaIdx == -1) return _buildFallback(fallbackIcon, fallbackColor);
    final base64Str = dataUri.substring(commaIdx + 1);
    if (base64Str.length > 350 * 1024) {
      return _buildFallback(fallbackIcon, fallbackColor);
    }
    return FutureBuilder<Uint8List>(
      future: compute(_base64DecodeIsolate, base64Str),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            cacheWidth: 320,
            cacheHeight: 320,
            filterQuality: FilterQuality.low,
            fit: BoxFit.cover,
            errorBuilder: (context, _, stackTrace) => _buildFallback(fallbackIcon, fallbackColor),
          );
        }
        if (snap.hasError) return _buildFallback(fallbackIcon, fallbackColor);
        return Container(
          color: AppTheme.darkBackground,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnailView(IconData fallbackIcon, Color fallbackColor) {
    final thumb = media.thumbnailUrl;

    if (thumb != null && thumb.isNotEmpty) {
      if (thumb.startsWith('data:image')) {
        return _buildDataThumb(thumb, fallbackIcon, fallbackColor);
      }
      if (!_isRenderableScheme(thumb)) {
        return _buildFallback(fallbackIcon, fallbackColor);
      }
      return _buildCachedThumb(thumb, fallbackIcon, fallbackColor);
    }

    if (media.mediaType == MediaType.image) {
      if (media.url.startsWith('data:image')) {
        return _buildDataThumb(media.url, fallbackIcon, fallbackColor);
      }
      if (!_isRenderableScheme(media.url)) {
        return _buildFallback(fallbackIcon, fallbackColor);
      }
      return _buildCachedThumb(media.url, fallbackIcon, fallbackColor);
    }

    return _buildFallback(fallbackIcon, fallbackColor);
  }

  Widget _buildFallback(IconData icon, Color color) {
    return Container(
      color: AppTheme.darkBackground,
      child: Center(
        child: Icon(icon, size: 30, color: color),
      ),
    );
  }
}
