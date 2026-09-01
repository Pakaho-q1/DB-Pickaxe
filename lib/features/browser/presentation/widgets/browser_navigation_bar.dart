import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../../downloader/presentation/widgets/download_manager_dialog.dart';
import '../../../settings/presentation/widgets/settings_dialog.dart';
import '../../domain/models/browser_tab.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/browser_tabs_provider.dart';
import 'bookmarks_dialog.dart';
import 'cookie_manager_dialog.dart';
import 'history_dialog.dart';

class BrowserNavigationBar extends ConsumerStatefulWidget {
  const BrowserNavigationBar({super.key});

  @override
  ConsumerState<BrowserNavigationBar> createState() => _BrowserNavigationBarState();
}

class _BrowserNavigationBarState extends ConsumerState<BrowserNavigationBar> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(browserTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);
    final activeTab = tabs.firstWhere((t) => t.id == activeTabId, orElse: () => const BrowserTab(id: ''));

    // Update URL controller when active tab URL changes
    if (_urlController.text != activeTab.url && !FocusScope.of(context).hasFocus) {
      _urlController.text = activeTab.url;
    }

    final isBookmarked = ref.watch(bookmarksProvider.notifier).isBookmarked(activeTab.url);
    final downloadTasks = ref.watch(downloadQueueProvider);
    final activeDownloads = downloadTasks.where((t) => t.status == DownloadStatus.downloading).length;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            color: AppTheme.darkTextPrimary,
            tooltip: 'Back',
            onPressed: () => ref.read(browserTabsProvider.notifier).goBack(activeTab.id),
          ),
          // Forward
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 18),
            color: AppTheme.darkTextPrimary,
            tooltip: 'Forward',
            onPressed: () => ref.read(browserTabsProvider.notifier).goForward(activeTab.id),
          ),
          // Refresh
          IconButton(
            icon: Icon(activeTab.isLoading ? Icons.close : Icons.refresh, size: 18),
            color: AppTheme.darkTextPrimary,
            tooltip: 'Reload',
            onPressed: () => ref.read(browserTabsProvider.notifier).reload(activeTab.id),
          ),
          const SizedBox(width: 6),
          // URL Bar
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _urlController,
                style: const TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppTheme.accentGreen),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.star : Icons.star_border,
                      size: 18,
                      color: isBookmarked ? AppTheme.accentAmber : AppTheme.darkTextSecondary,
                    ),
                    tooltip: isBookmarked ? 'Bookmarked' : 'Add Bookmark',
                    onPressed: () {
                      if (activeTab.url.isNotEmpty) {
                        ref.read(bookmarksProvider.notifier).addBookmark(
                              title: activeTab.title,
                              url: activeTab.url,
                            );
                      }
                    },
                  ),
                  hintText: 'Search or enter website URL...',
                  hintStyle: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                onSubmitted: (value) {
                  ref.read(browserTabsProvider.notifier).navigateTo(activeTab.id, value);
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Bookmarks List
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, size: 18, color: AppTheme.darkTextSecondary),
            tooltip: 'Bookmarks',
            onPressed: () {
              showDialog(context: context, builder: (_) => const BookmarksDialog());
            },
          ),
          // History
          IconButton(
            icon: const Icon(Icons.history, size: 18, color: AppTheme.darkTextSecondary),
            tooltip: 'History',
            onPressed: () {
              showDialog(context: context, builder: (_) => const HistoryDialog());
            },
          ),
          // Cookie Vault & Injector
          IconButton(
            icon: const Icon(Icons.cookie_outlined, size: 18, color: AppTheme.accentAmber),
            tooltip: 'Cookie Vault & Injector (ฝังคุกกี้)',
            onPressed: () {
              showDialog(context: context, builder: (_) => const CookieManagerDialog());
            },
          ),
          // Download Manager with Badge
          Badge(
            isLabelVisible: activeDownloads > 0,
            label: Text('$activeDownloads'),
            backgroundColor: AppTheme.primaryLight,
            child: IconButton(
              icon: const Icon(Icons.download_rounded, size: 20, color: AppTheme.darkTextPrimary),
              tooltip: 'Download Manager',
              onPressed: () {
                showDialog(context: context, builder: (_) => const DownloadManagerDialog());
              },
            ),
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18, color: AppTheme.darkTextSecondary),
            tooltip: 'Settings',
            onPressed: () {
              showDialog(context: context, builder: (_) => const SettingsDialog());
            },
          ),
        ],
      ),
    );
  }
}
