import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/browser_tabs_provider.dart';

class BookmarksDialog extends ConsumerWidget {
  const BookmarksDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final activeTabId = ref.watch(activeTabIdProvider);

    return Dialog(
      child: Container(
        width: 500,
        height: 450,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bookmarks, color: AppTheme.accentAmber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Bookmarks',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: bookmarks.isEmpty
                  ? const Center(
                      child: Text(
                        'No bookmarks saved yet.',
                        style: TextStyle(color: AppTheme.darkTextSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: bookmarks.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.star, color: AppTheme.accentAmber, size: 18),
                          title: Text(
                            bookmark.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary),
                          ),
                          subtitle: Text(
                            bookmark.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.accentRose),
                            onPressed: () {
                              ref.read(bookmarksProvider.notifier).removeBookmark(bookmark.id);
                            },
                          ),
                          onTap: () {
                            ref.read(browserTabsProvider.notifier).navigateTo(activeTabId, bookmark.url);
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
