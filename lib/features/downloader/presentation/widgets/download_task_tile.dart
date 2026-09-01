import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/download_task.dart';
import '../providers/download_queue_provider.dart';

class DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color statusColor;
    String statusText;

    switch (task.status) {
      case DownloadStatus.downloading:
        statusColor = AppTheme.accentCyan;
        statusText = 'Downloading (${(task.progress * 100).toStringAsFixed(0)}%) - ${Formatters.formatSpeed(task.speedBytesPerSec)}';
        break;
      case DownloadStatus.completed:
        statusColor = AppTheme.accentGreen;
        statusText = 'Completed';
        break;
      case DownloadStatus.failed:
        statusColor = AppTheme.accentRose;
        statusText = task.errorMessage ?? 'Failed';
        break;
      case DownloadStatus.converting:
        statusColor = AppTheme.accentAmber;
        statusText = 'Converting format...';
        break;
      case DownloadStatus.paused:
        statusColor = AppTheme.accentAmber;
        statusText = 'Paused';
        break;
      case DownloadStatus.cancelled:
        statusColor = AppTheme.darkTextSecondary;
        statusText = 'Cancelled';
        break;
      case DownloadStatus.pending:
        statusColor = AppTheme.primaryLight;
        statusText = 'Queued';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.mediaType == MediaType.video
                    ? Icons.movie_outlined
                    : task.mediaType == MediaType.image
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary),
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  task.status.name.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              const SizedBox(width: 4),
              // Action Buttons
              if (task.status == DownloadStatus.downloading)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.accentRose),
                  tooltip: 'Cancel',
                  onPressed: () => ref.read(downloadQueueProvider.notifier).cancelTask(task.id),
                )
              else if (task.status == DownloadStatus.failed || task.status == DownloadStatus.cancelled)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppTheme.accentCyan),
                  tooltip: 'Retry',
                  onPressed: () => ref.read(downloadQueueProvider.notifier).retryTask(task.id),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.darkTextSecondary),
                tooltip: 'Remove',
                onPressed: () => ref.read(downloadQueueProvider.notifier).removeTask(task.id),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.converting)
            LinearProgressIndicator(
              value: task.status == DownloadStatus.converting ? null : (task.totalBytes > 0 ? task.progress : null),
              backgroundColor: AppTheme.darkSurface,
              color: statusColor,
              minHeight: 4,
            ),
          const SizedBox(height: 6),
          // Details Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
              Text(
                task.totalBytes > 0
                    ? '${Formatters.formatBytes(task.downloadedBytes)} / ${Formatters.formatBytes(task.totalBytes)}'
                    : Formatters.formatBytes(task.downloadedBytes),
                style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
