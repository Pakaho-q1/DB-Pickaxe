import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/media_type_helper.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/detected_media.dart';
import '../widgets/media_preview_dialog.dart';

class MobileMediaTile extends ConsumerWidget {
  final DetectedMedia media;
  final VoidCallback? onDownload;

  const MobileMediaTile({
    super.key,
    required this.media,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:icon, :color) = MediaTypeHelper.propsFor(media.mediaType);
    final isVideo = media.mediaType == MediaType.video || media.mediaType == MediaType.stream;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Thumbnail Preview Box with Play Overlay & Quality Tag
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => MediaPreviewDialog(media: media),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: AppTheme.darkBackground,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: media.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Center(child: Icon(icon, color: color, size: 24)),
                      )
                    else
                      Center(child: Icon(icon, color: color, size: 24)),
                    if (isVideo)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    if (media.resolution != null && media.resolution!.isNotEmpty)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            media.resolution!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Metadata Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        media.extension.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      Formatters.formatBytes(media.sizeBytes),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. One-Tap Quick Download Button
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppTheme.accentCyan, size: 24),
            tooltip: 'Download',
            onPressed: () {
              if (onDownload != null) {
                onDownload!();
              } else {
                ref.read(downloadQueueProvider.notifier).addMediaToQueue(media);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading ${media.filename}'),
                    backgroundColor: AppTheme.accentCyan,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
