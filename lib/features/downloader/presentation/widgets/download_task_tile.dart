import 'dart:io';
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

  void _openFileLocation(String filePath) {
    if (filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        Process.run('explorer.exe', ['/select,', filePath]);
      } else if (file.parent.existsSync()) {
        Process.run('explorer.exe', [file.parent.path]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color statusColor;
    String statusBadgeText;
    IconData statusIcon;

    switch (task.status) {
      case DownloadStatus.downloading:
        statusColor = AppTheme.accentCyan;
        statusBadgeText = '${(task.progress * 100).toStringAsFixed(0)}%';
        statusIcon = Icons.downloading;
        break;
      case DownloadStatus.completed:
        statusColor = AppTheme.accentGreen;
        statusBadgeText = 'COMPLETED';
        statusIcon = Icons.check_circle_outline;
        break;
      case DownloadStatus.failed:
        statusColor = AppTheme.accentRose;
        statusBadgeText = 'FAILED';
        statusIcon = Icons.error_outline;
        break;
      case DownloadStatus.converting:
        statusColor = AppTheme.accentAmber;
        statusBadgeText = 'CONVERTING';
        statusIcon = Icons.transform;
        break;
      case DownloadStatus.paused:
        statusColor = AppTheme.accentAmber;
        statusBadgeText = 'PAUSED';
        statusIcon = Icons.pause_circle_outline;
        break;
      case DownloadStatus.cancelled:
        statusColor = AppTheme.darkTextSecondary;
        statusBadgeText = 'CANCELLED';
        statusIcon = Icons.cancel_outlined;
        break;
      case DownloadStatus.pending:
        statusColor = AppTheme.primaryLight;
        statusBadgeText = 'QUEUED';
        statusIcon = Icons.hourglass_top;
        break;
    }

    final dateToDisplay = task.completedAt ?? task.createdAt;
    final dateStr = Formatters.formatDateTimeFriendly(dateToDisplay);

    final isStreaming = task.mediaType == MediaType.stream;
    final isVideo = task.mediaType == MediaType.video || isStreaming;
    final isImage = task.mediaType == MediaType.image;
    final isAudio = task.mediaType == MediaType.audio;

    final mediaIcon = isVideo
        ? (isStreaming ? Icons.live_tv_rounded : Icons.movie_outlined)
        : isImage
            ? Icons.image_outlined
            : isAudio
                ? Icons.audiotrack_outlined
                : Icons.insert_drive_file_outlined;

    final isDownloading = task.status == DownloadStatus.downloading;
    final isConverting = task.status == DownloadStatus.converting;
    final isCompleted = task.status == DownloadStatus.completed;
    final isFailedOrCancelled = task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.cancelled ||
        task.status == DownloadStatus.paused;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDownloading
              ? AppTheme.primaryLight.withValues(alpha: 0.35)
              : AppTheme.darkBorder,
          width: isDownloading ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Media Icon + Clean Filename + Badges + Action Buttons
          Row(
            children: [
              Icon(
                mediaIcon,
                size: 15,
                color: isDownloading ? AppTheme.accentCyan : AppTheme.darkTextSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  task.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Thread count badge
              if (task.chunkCount > 1 && !isCompleted)
                Container(
                  margin: const EdgeInsets.only(right: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 9, color: AppTheme.accentCyan),
                      const SizedBox(width: 1),
                      Text(
                        '${task.chunkCount}T',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                      ),
                    ],
                  ),
                ),
              // Unified Single Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 9, color: statusColor),
                    const SizedBox(width: 3),
                    Text(
                      statusBadgeText,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Actions
              if (isDownloading)
                InkWell(
                  onTap: () => ref.read(downloadQueueProvider.notifier).cancelTask(task.id),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.pause_circle_outline, size: 15, color: AppTheme.accentAmber),
                  ),
                )
              else if (isFailedOrCancelled)
                InkWell(
                  onTap: () => ref.read(downloadQueueProvider.notifier).retryTask(task.id),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.replay_outlined, size: 15, color: AppTheme.accentCyan),
                  ),
                )
              else if (isCompleted) ...[
                InkWell(
                  onTap: () => _openFileLocation(task.savedPath),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.folder_open_outlined, size: 15, color: AppTheme.darkTextSecondary),
                  ),
                ),
              ],
              InkWell(
                onTap: () => ref.read(downloadQueueProvider.notifier).removeTask(task.id),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 14, color: AppTheme.darkTextSecondary),
                ),
              ),
            ],
          ),
          // Slim Progress bar (Only when downloading or converting)
          if (isDownloading || isConverting) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: isConverting ? null : (task.totalBytes > 0 ? task.progress : null),
                backgroundColor: AppTheme.darkSurface,
                color: statusColor,
                minHeight: 3,
              ),
            ),
          ],
          const SizedBox(height: 4),
          // Row 2: Metadata Footer (Date/Time on Left + Speed/Size on Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date & Time + Resumable/Error Tag
              Row(
                children: [
                  const Icon(Icons.schedule, size: 11, color: AppTheme.darkTextSecondary),
                  const SizedBox(width: 3),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                  ),
                  if (task.errorMessage != null && task.status == DownloadStatus.failed) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ${task.errorMessage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.accentRose),
                    ),
                  ] else if (task.isResumable && task.status == DownloadStatus.cancelled) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '• Resumable',
                      style: TextStyle(fontSize: 9, color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              // Download Speed & File Size Info
              Row(
                children: [
                  if (isDownloading && task.speedBytesPerSec > 0) ...[
                    Text(
                      '⚡ ${Formatters.formatSpeed(task.speedBytesPerSec)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentCyan),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    task.totalBytes > 0
                        ? (isCompleted
                            ? Formatters.formatBytes(task.totalBytes)
                            : '${Formatters.formatBytes(task.downloadedBytes)} / ${Formatters.formatBytes(task.totalBytes)}')
                        : Formatters.formatBytes(task.downloadedBytes),
                    style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
