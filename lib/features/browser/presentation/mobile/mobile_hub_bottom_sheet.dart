import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_launcher_helper.dart';
import '../../../../core/utils/formatters.dart';
import '../../../downloader/domain/models/download_task.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/presentation/providers/sniffer_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/history_provider.dart';
import '../providers/browser_tabs_provider.dart';

enum MobileHubView {
  rootGrid,
  downloads,
  bookmarks,
  history,
  settings,
}

class MobileHubBottomSheet extends ConsumerStatefulWidget {
  final Function(String url) onNavigateUrl;
  final MobileHubView initialView;

  const MobileHubBottomSheet({
    super.key,
    required this.onNavigateUrl,
    this.initialView = MobileHubView.rootGrid,
  });

  @override
  ConsumerState<MobileHubBottomSheet> createState() => _MobileHubBottomSheetState();
}

class _MobileHubBottomSheetState extends ConsumerState<MobileHubBottomSheet> {
  late MobileHubView _currentView;

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _currentView == MobileHubView.rootGrid ? 0.48 : 0.85,
      minChildSize: 0.30,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Navigation Header
              _buildHeader(),
              const Divider(height: 1, color: AppTheme.darkBorder),

              // Content Area based on current view
              Expanded(
                child: _buildCurrentContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final isRoot = _currentView == MobileHubView.rootGrid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      child: Column(
        children: [
          // Drag handle pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              if (!isRoot)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.accentCyan),
                  onPressed: () => setState(() => _currentView = MobileHubView.rootGrid),
                )
              else
                const SizedBox(width: 8),
              Text(
                _getHeaderTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppTheme.darkTextSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_currentView) {
      case MobileHubView.rootGrid:
        return 'Menu Hub';
      case MobileHubView.downloads:
        return 'Download Manager';
      case MobileHubView.bookmarks:
        return 'Bookmarks';
      case MobileHubView.history:
        return 'Browsing History';
      case MobileHubView.settings:
        return 'Settings';
    }
  }

  Widget _buildCurrentContent(ScrollController scrollController) {
    switch (_currentView) {
      case MobileHubView.rootGrid:
        return _buildRootGridView(scrollController);
      case MobileHubView.downloads:
        return _buildDownloadsView(scrollController);
      case MobileHubView.bookmarks:
        return _buildBookmarksView(scrollController);
      case MobileHubView.history:
        return _buildHistoryView(scrollController);
      case MobileHubView.settings:
        return _buildFullSettingsView(scrollController);
    }
  }

  // ==========================================
  // LEVEL 0: ROOT GRID MENU
  // ==========================================
  Widget _buildRootGridView(ScrollController scrollController) {
    final bookmarksCount = ref.watch(bookmarksProvider).length;
    final historyCount = ref.watch(historyProvider).length;

    return GridView.count(
      controller: scrollController,
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildGridCard(
          icon: Icons.tune_rounded,
          iconColor: AppTheme.accentCyan,
          title: 'Settings',
          subtitle: 'Engine, DNS, Filters',
          onTap: () => setState(() => _currentView = MobileHubView.settings),
        ),
        _buildGridCard(
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
          title: 'Bookmarks',
          subtitle: '$bookmarksCount saved pages',
          onTap: () => setState(() => _currentView = MobileHubView.bookmarks),
        ),
        _buildGridCard(
          icon: Icons.history_rounded,
          iconColor: Colors.purpleAccent,
          title: 'History',
          subtitle: '$historyCount visited pages',
          onTap: () => setState(() => _currentView = MobileHubView.history),
        ),
        _buildGridCard(
          icon: Icons.download_rounded,
          iconColor: Colors.greenAccent,
          title: 'Downloads',
          subtitle: 'Tasks & queue manager',
          onTap: () => setState(() => _currentView = MobileHubView.downloads),
        ),
        _buildGridCard(
          icon: Icons.cleaning_services_rounded,
          iconColor: Colors.orangeAccent,
          title: 'Clear Cache',
          subtitle: 'Cookies & temp data',
          onTap: () => _confirmClearCacheDialog(),
        ),
        _buildGridCard(
          icon: Icons.info_outline_rounded,
          iconColor: AppTheme.darkTextSecondary,
          title: 'About',
          subtitle: 'DB-Pickaxe v${AppConstants.appVersion}',
          onTap: () => _showAboutDialog(),
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================================
  // LEVEL 1: DOWNLOADS SUB-VIEW (Side Under Screen)
  // ==========================================
  Widget _buildDownloadsView(ScrollController scrollController) {
    final tasks = ref.watch(downloadQueueProvider);
    final queueNotifier = ref.read(downloadQueueProvider.notifier);

    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done_rounded, size: 48, color: AppTheme.darkTextSecondary),
            SizedBox(height: 12),
            Text(
              'No Downloads Yet',
              style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Tap the pickaxe ⛏️ bubble to detect and download media',
              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${tasks.length} total tasks', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppTheme.accentCyan),
                label: const Text('Clear Completed', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12)),
                onPressed: () => queueNotifier.clearCompleted(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: tasks.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildDownloadTaskCard(task, queueNotifier);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadTaskCard(DownloadTask task, DownloadQueueNotifier queueNotifier) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isCompleted = task.status == DownloadStatus.completed;
    final isPaused = task.status == DownloadStatus.paused;
    final isFailed = task.status == DownloadStatus.failed;

    return Card(
      color: AppTheme.darkBackground,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDownloading ? AppTheme.accentCyan.withValues(alpha: 0.4) : AppTheme.darkBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : isDownloading
                          ? Icons.downloading_rounded
                          : isPaused
                              ? Icons.pause_circle_rounded
                              : Icons.error_outline_rounded,
                  color: isCompleted
                      ? Colors.greenAccent
                      : isDownloading
                          ? AppTheme.accentCyan
                          : isPaused
                              ? Colors.amber
                              : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCompleted)
                  IconButton(
                    icon: const Icon(Icons.folder_open_rounded, size: 20, color: AppTheme.accentCyan),
                    tooltip: 'Open File',
                    onPressed: () => FileLauncherHelper.openFileOrLocation(task.savedPath),
                  )
                else if (isDownloading)
                  IconButton(
                    icon: const Icon(Icons.pause_rounded, size: 20, color: Colors.amber),
                    tooltip: 'Pause',
                    onPressed: () => queueNotifier.pauseTask(task.id),
                  )
                else if (isPaused || isFailed)
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.greenAccent),
                    tooltip: 'Resume',
                    onPressed: () => queueNotifier.resumeTask(task.id),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.darkTextSecondary),
                  tooltip: 'Cancel & Delete',
                  onPressed: () => queueNotifier.removeTask(task.id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: isCompleted ? 1.0 : (task.progress > 0 ? task.progress : null),
                backgroundColor: Colors.white10,
                color: isCompleted
                    ? Colors.greenAccent
                    : isFailed
                        ? Colors.redAccent
                        : isPaused
                            ? Colors.amber
                            : AppTheme.accentCyan,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCompleted
                      ? '${Formatters.formatBytes(task.totalBytes)} • Completed'
                      : '${Formatters.formatBytes(task.downloadedBytes)} / ${Formatters.formatBytes(task.totalBytes)}',
                  style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11),
                ),
                if (isDownloading)
                  Text(
                    '${Formatters.formatSpeed(task.speedBytesPerSec)} • ${(task.progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                  )
                else if (isFailed)
                  Text(
                    task.errorMessage ?? 'Failed',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LEVEL 1: BOOKMARKS VIEW
  // ==========================================
  Widget _buildBookmarksView(ScrollController scrollController) {
    final bookmarks = ref.watch(bookmarksProvider);

    if (bookmarks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline_rounded, size: 48, color: AppTheme.darkTextSecondary),
            SizedBox(height: 12),
            Text(
              'No Bookmarks Yet',
              style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Tap the star icon ⭐ in the top bar to bookmark pages',
              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: bookmarks.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final b = bookmarks[index];
        return Dismissible(
          key: ValueKey(b.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red.withValues(alpha: 0.8),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) {
            ref.read(bookmarksProvider.notifier).removeBookmark(b.id);
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.12),
              child: const Icon(Icons.bookmark_rounded, color: AppTheme.accentCyan, size: 18),
            ),
            title: Text(
              b.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              b.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.darkTextSecondary),
              onPressed: () => ref.read(bookmarksProvider.notifier).removeBookmark(b.id),
            ),
            onTap: () {
              Navigator.of(context).pop();
              widget.onNavigateUrl(b.url);
            },
          ),
        );
      },
    );
  }

  // ==========================================
  // LEVEL 1: HISTORY VIEW
  // ==========================================
  Widget _buildHistoryView(ScrollController scrollController) {
    final history = ref.watch(historyProvider);

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: AppTheme.darkTextSecondary),
            SizedBox(height: 12),
            Text(
              'No Browsing History',
              style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${history.length} visited pages', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.redAccent),
                label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                onPressed: () => ref.read(historyProvider.notifier).clearAll(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final h = history[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  child: const Icon(Icons.language_rounded, color: AppTheme.darkTextSecondary, size: 18),
                ),
                title: Text(
                  h.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  DateFormat('MMM d, HH:mm').format(h.visitedAt),
                  style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onNavigateUrl(h.url);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // LEVEL 1: FULL MOBILE SETTINGS VIEW
  // (Preserves all desktop settings categories!)
  // ==========================================
  Widget _buildFullSettingsView(ScrollController scrollController) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isAutoDetect = ref.watch(isAutoDetectEnabledProvider);
    final keepMedia = ref.watch(keepMediaAcrossPagesProvider);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Downloader Acceleration Engine
        _buildSectionHeader('🚀 Download Acceleration Engine'),
        Card(
          color: AppTheme.darkBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Multi-Thread Chunks', style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('${settings.threadsPerDownload} Threads', style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: settings.threadsPerDownload.toDouble(),
                  min: 1,
                  max: 32,
                  divisions: 31,
                  activeColor: AppTheme.accentCyan,
                  onChanged: (val) {
                    settingsNotifier.updateSettings(
                      settings.copyWith(threadsPerDownload: val.round()),
                    );
                  },
                ),
                const Divider(height: 16, color: AppTheme.darkBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Max Concurrent Downloads', style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13)),
                    Text('${settings.maxConcurrentDownloads} Tasks', style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: settings.maxConcurrentDownloads.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: AppTheme.accentCyan,
                  onChanged: (val) {
                    settingsNotifier.updateSettings(
                      settings.copyWith(maxConcurrentDownloads: val.round()),
                    );
                  },
                ),
                const Divider(height: 16, color: AppTheme.darkBorder),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Create Subfolders by Website', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                  value: settings.autoCreateSubfolders,
                  activeThumbColor: AppTheme.accentCyan,
                  onChanged: (val) => settingsNotifier.updateSettings(settings.copyWith(autoCreateSubfolders: val)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Media Sniffer & Pro Detection Engine
        _buildSectionHeader('🔍 Media Sniffer & Pro Detection Engine'),
        Card(
          color: AppTheme.darkBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Real-Time Media Auto-Detect', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Continuously detects media as pages load', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: isAutoDetect,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => ref.read(isAutoDetectEnabledProvider.notifier).state = val,
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              SwitchListTile(
                title: const Text('Keep Media Across Navigations', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Preserves sniffed media history when navigating to new URLs', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: keepMedia,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => ref.read(keepMediaAcrossPagesProvider.notifier).state = val,
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              SwitchListTile(
                title: const Text('Auto-Scroll Lazy Load', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Auto-scrolls pages to trigger image and video loading', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: settings.enableAutoScroll,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => settingsNotifier.updateSettings(settings.copyWith(enableAutoScroll: val)),
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              SwitchListTile(
                title: const Text('Auto-Trigger Video Preloads', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Triggers silent micro-playback to extract hidden stream manifests', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: settings.enableAutoVideoTrigger,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => settingsNotifier.updateSettings(settings.copyWith(enableAutoVideoTrigger: val)),
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              SwitchListTile(
                title: const Text('Auto-Grab Subtitles (.srt / .vtt)', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Fetches subtitle tracks for streaming videos automatically', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: settings.autoGrabSubtitles,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => settingsNotifier.updateSettings(settings.copyWith(autoGrabSubtitles: val)),
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              SwitchListTile(
                title: const Text('Embed Cover Art & Metadata', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Embeds video poster and tags into downloaded files', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: settings.embedMetadataAndCoverArt,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => settingsNotifier.updateSettings(settings.copyWith(embedMetadataAndCoverArt: val)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Security, DNS & Privacy
        _buildSectionHeader('🛡️ Anti-Censorship & Privacy'),
        Card(
          color: AppTheme.darkBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Secure DNS Provider (DoH)', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                    DropdownButton<String>(
                      value: settings.selectedDnsPreset.isNotEmpty ? settings.selectedDnsPreset : 'Cloudflare (1.1.1.1)',
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12),
                      underline: const SizedBox.shrink(),
                      items: DnsPreset.presets.map((preset) {
                        return DropdownMenuItem<String>(
                          value: preset.name,
                          child: Text(preset.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          settingsNotifier.updateSettings(settings.copyWith(selectedDnsPreset: val));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              SwitchListTile(
                title: const Text('Built-in Ad & Tracker Blocker', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                subtitle: const Text('Blocks ad telemetry and annoying redirect banners', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                value: settings.enableAdBlocker,
                activeThumbColor: AppTheme.accentCyan,
                onChanged: (val) => settingsNotifier.updateSettings(settings.copyWith(enableAdBlocker: val)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Startup & Session Behavior
        _buildSectionHeader('🌐 Startup & Session'),
        Card(
          color: AppTheme.darkBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Startup Behavior', style: TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary)),
                DropdownButton<AppStartupBehavior>(
                  value: settings.startupBehavior,
                  dropdownColor: AppTheme.darkSurface,
                  style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: AppStartupBehavior.newTab, child: Text('Open New Tab')),
                    DropdownMenuItem(value: AppStartupBehavior.lastTab, child: Text('Restore Last Tab')),
                    DropdownMenuItem(value: AppStartupBehavior.restoreAll, child: Text('Restore All Tabs')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      settingsNotifier.updateSettings(settings.copyWith(startupBehavior: val));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Clear Cache & Data', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: const Text('This will clear browsing history and temporary cookies.', style: TextStyle(color: AppTheme.darkTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearAll();
              HiveService.cookiesBox.clear();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache & Cookies cleared'),
                  backgroundColor: AppTheme.accentCyan,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: AppTheme.accentCyan),
            const SizedBox(width: 8),
            Text(AppConstants.appName, style: const TextStyle(color: AppTheme.darkTextPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: ${AppConstants.appVersion}', style: const TextStyle(color: AppTheme.darkTextSecondary)),
            const SizedBox(height: 8),
            const Text('A cross-platform powerhouse browser with built-in media sniffer, chunked downloader, and DoH anti-censorship proxy.', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppTheme.accentCyan)),
          ),
        ],
      ),
    );
  }
}
