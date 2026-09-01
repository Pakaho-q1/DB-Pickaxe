import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/browser_tabs_provider.dart';
import '../providers/history_provider.dart';

class HistoryDialog extends ConsumerWidget {
  const HistoryDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final activeTabId = ref.watch(activeTabIdProvider);

    return Dialog(
      child: Container(
        width: 550,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: AppTheme.accentCyan, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Browsing History',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (history.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep, size: 16, color: AppTheme.accentRose),
                        label: const Text('Clear All', style: TextStyle(color: AppTheme.accentRose, fontSize: 12)),
                        onPressed: () {
                          ref.read(historyProvider.notifier).clearAll();
                        },
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
            Expanded(
              child: history.isEmpty
                  ? const Center(
                      child: Text(
                        'No browsing history recorded.',
                        style: TextStyle(color: AppTheme.darkTextSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.public, size: 18, color: AppTheme.darkTextSecondary),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary),
                          ),
                          subtitle: Text(
                            item.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                          ),
                          trailing: Text(
                            Formatters.formatDateTime(item.visitedAt),
                            style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                          ),
                          onTap: () {
                            ref.read(browserTabsProvider.notifier).navigateTo(activeTabId, item.url);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
