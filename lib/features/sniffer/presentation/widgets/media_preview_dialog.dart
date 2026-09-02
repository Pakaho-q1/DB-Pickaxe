import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/media_type_helper.dart';
import '../../../browser/presentation/providers/browser_tabs_provider.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/detected_media.dart';

class MediaPreviewDialog extends ConsumerWidget {
  final DetectedMedia media;

  const MediaPreviewDialog({super.key, required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:icon, :color) = MediaTypeHelper.propsFor(media.mediaType);
    final typeIcon = icon;
    final typeColor = color;

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        height: 580,
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                  ),
                ),
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
            const SizedBox(height: 12),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildMainPreview(IconData icon, Color color) {
    if (media.mediaType == MediaType.image) {
      return InteractiveViewer(
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            media.url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildFallbackInfo(icon, color),
          ),
        ),
      );
    }

    if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty) {
      if (media.thumbnailUrl!.startsWith('data:image')) {
        try {
          final base64Str = media.thumbnailUrl!.split(',').last;
          final bytes = base64Decode(base64Str);
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(bytes, fit: BoxFit.contain),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
                ),
              ],
            ),
          );
        } catch (_) {}
      } else {
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.network(media.thumbnailUrl!, fit: BoxFit.contain),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
              ),
            ],
          ),
        );
      }
    }

    return _buildFallbackInfo(icon, color);
  }

  Widget _buildFallbackInfo(IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            media.mediaType == MediaType.stream ? 'HLS Video Stream (.m3u8)' : 'Video / Media Resource',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
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
