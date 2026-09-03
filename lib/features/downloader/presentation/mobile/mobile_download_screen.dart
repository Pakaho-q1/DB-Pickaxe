import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_launcher_helper.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/media_type_helper.dart';
import '../../domain/models/download_task.dart';
import '../providers/download_queue_provider.dart';
import '../widgets/direct_download_dialog.dart';

class MobileDownloadScreen extends ConsumerStatefulWidget {
  const MobileDownloadScreen({super.key});

  @override
  ConsumerState<MobileDownloadScreen> createState() => _MobileDownloadScreenState();
}

class _MobileDownloadScreenState extends ConsumerState<MobileDownloadScreen> {
  DownloadStatus? _statusFilter;

  void _showRefreshLinkDialog(DownloadTask task) {
    final urlController = TextEditingController(text: task.url);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Refresh Expired Link', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a newly generated download URL or session token to resume this file:',
              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'https://...',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
            onPressed: () {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                ref.read(downloadQueueProvider.notifier).refreshTaskUrl(task.id, newUrl);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download link updated. Resuming...')),
                );
              }
            },
            child: const Text('Update & Resume', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(downloadQueueProvider);
    final filteredTasks = _statusFilter == null
        ? allTasks
        : allTasks.where((t) => t.status == _statusFilter).toList();

    final activeTasks = allTasks.where((t) => t.status == DownloadStatus.downloading).toList();
    final totalSpeed = activeTasks.fold<double>(0, (sum, t) => sum + t.speedBytesPerSec);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Download Manager', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (activeTasks.isNotEmpty)
              Text(
                'Speed: ${Formatters.formatSpeed(totalSpeed)} (${activeTasks.length} active)',
                style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link, color: AppTheme.accentCyan),
            tooltip: 'Add Link',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const DirectDownloadDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: AppTheme.darkTextSecondary),
            tooltip: 'Clear Completed',
            onPressed: () => ref.read(downloadQueueProvider.notifier).clearCompleted(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildChip('All (${allTasks.length})', _statusFilter == null, () => setState(() => _statusFilter = null)),
                _buildChip('Downloading (${activeTasks.length})', _statusFilter == DownloadStatus.downloading, () => setState(() => _statusFilter = DownloadStatus.downloading)),
                _buildChip('Completed (${allTasks.where((t) => t.status == DownloadStatus.completed).length})', _statusFilter == DownloadStatus.completed, () => setState(() => _statusFilter = DownloadStatus.completed)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Task List
          Expanded(
            child: filteredTasks.isEmpty
                ? const Center(
                    child: Text('No downloads in this category', style: TextStyle(color: AppTheme.darkTextSecondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      final (:icon, :color) = MediaTypeHelper.propsFor(task.mediaType);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: color, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    task.filename,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.darkTextPrimary,
                                    ),
                                  ),
                                ),
                                _buildStatusBadge(task.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (task.status == DownloadStatus.downloading) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: task.progress,
                                  backgroundColor: AppTheme.darkBorder,
                                  color: AppTheme.accentCyan,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${Formatters.formatBytes(task.downloadedBytes)} / ${Formatters.formatBytes(task.totalBytes)}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                                  ),
                                  Text(
                                    Formatters.formatSpeed(task.speedBytesPerSec),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                                  ),
                                ],
                              ),
                            ],
                            if (task.isExpired) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRose.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer_off_outlined, size: 14, color: AppTheme.accentRose),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Link expired (403/410)',
                                        style: TextStyle(fontSize: 11, color: AppTheme.accentRose),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showRefreshLinkDialog(task),
                                      child: const Text('Refresh Link', style: TextStyle(fontSize: 11, color: AppTheme.accentCyan)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Action controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (task.status == DownloadStatus.completed) ...[
                                  TextButton.icon(
                                    icon: const Icon(Icons.folder_open, size: 16, color: AppTheme.accentCyan),
                                    label: const Text('Open File', style: TextStyle(fontSize: 11, color: AppTheme.accentCyan)),
                                    onPressed: () => FileLauncherHelper.openFileOrLocation(task.savedPath),
                                  ),
                                ],
                                if (task.status == DownloadStatus.downloading) ...[
                                  IconButton(
                                    icon: const Icon(Icons.pause, size: 18, color: AppTheme.accentAmber),
                                    onPressed: () => ref.read(downloadQueueProvider.notifier).pauseTask(task.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: AppTheme.accentRose),
                                    onPressed: () => ref.read(downloadQueueProvider.notifier).cancelTask(task.id),
                                  ),
                                ],
                                if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed) ...[
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, size: 18, color: AppTheme.accentGreen),
                                    onPressed: () => ref.read(downloadQueueProvider.notifier).resumeTask(task.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.accentCyan),
                                    onPressed: () => ref.read(downloadQueueProvider.notifier).retryTask(task.id),
                                  ),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.darkTextSecondary),
                                  onPressed: () => ref.read(downloadQueueProvider.notifier).removeTask(task.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : AppTheme.darkTextPrimary)),
        selected: isSelected,
        selectedColor: AppTheme.accentCyan,
        backgroundColor: AppTheme.darkSurface,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildStatusBadge(DownloadStatus status) {
    Color color;
    switch (status) {
      case DownloadStatus.downloading:
        color = AppTheme.accentCyan;
        break;
      case DownloadStatus.completed:
        color = AppTheme.accentGreen;
        break;
      case DownloadStatus.paused:
        color = AppTheme.accentAmber;
        break;
      case DownloadStatus.failed:
      case DownloadStatus.expired:
        color = AppTheme.accentRose;
        break;
      default:
        color = AppTheme.darkTextSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
