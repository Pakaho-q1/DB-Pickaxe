import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/detected_media.dart';
import '../providers/sniffer_provider.dart';
import 'media_preview_dialog.dart';

class MediaCard extends ConsumerWidget {
  final DetectedMedia media;

  const MediaCard({super.key, required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color badgeColor;
    IconData typeIcon;

    switch (media.mediaType) {
      case MediaType.video:
        badgeColor = AppTheme.accentRose;
        typeIcon = Icons.movie;
        break;
      case MediaType.stream:
        badgeColor = AppTheme.accentAmber;
        typeIcon = Icons.live_tv;
        break;
      case MediaType.image:
        badgeColor = AppTheme.accentCyan;
        typeIcon = Icons.image;
        break;
      case MediaType.audio:
        badgeColor = AppTheme.primaryLight;
        typeIcon = Icons.audiotrack;
        break;
      default:
        badgeColor = AppTheme.darkTextSecondary;
        typeIcon = Icons.insert_drive_file;
    }

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
                      // Top Left Badge: Format
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
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
                      // Bottom resolution tag
                      if (media.resolution != null)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              media.resolution!,
                              style: const TextStyle(fontSize: 8, color: Colors.white),
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
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          media.sizeBytes > 0
                              ? Formatters.formatBytes(media.sizeBytes)
                              : (media.resolution != null ? media.resolution! : (media.mediaType == MediaType.stream ? 'Stream' : 'Ready')),
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

  Widget _buildThumbnailView(IconData fallbackIcon, Color fallbackColor) {
    if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty) {
      if (media.thumbnailUrl!.startsWith('data:image')) {
        try {
          final base64Str = media.thumbnailUrl!.split(',').last;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(fallbackIcon, fallbackColor),
          );
        } catch (_) {}
      } else {
        return Image.network(
          media.thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(fallbackIcon, fallbackColor),
        );
      }
    }

    if (media.mediaType == MediaType.image) {
      return Image.network(
        media.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(fallbackIcon, fallbackColor),
      );
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
