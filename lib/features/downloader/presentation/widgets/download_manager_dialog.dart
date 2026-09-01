import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/download_queue_provider.dart';
import 'download_task_tile.dart';

class DownloadManagerDialog extends ConsumerWidget {
  const DownloadManagerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadQueueProvider);
    final activeCount = tasks.where((t) => t.status == DownloadStatus.downloading).length;
    final completedCount = tasks.where((t) => t.status == DownloadStatus.completed).length;

    return Dialog(
      child: Container(
        width: 650,
        height: 550,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.download_for_offline_rounded, color: AppTheme.primaryLight, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Download Manager',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Text(
                        'Active: $activeCount | Completed: $completedCount',
                        style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (completedCount > 0)
                      TextButton.icon(
                        icon: const Icon(Icons.cleaning_services_rounded, size: 14, color: AppTheme.darkTextSecondary),
                        label: const Text('Clear Completed', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11)),
                        onPressed: () => ref.read(downloadQueueProvider.notifier).clearCompleted(),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            // Tasks List
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      child: Text(
                        'No download tasks in queue.',
                        style: TextStyle(color: AppTheme.darkTextSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return DownloadTaskTile(task: tasks[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
