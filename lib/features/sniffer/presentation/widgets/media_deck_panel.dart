import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../browser/presentation/providers/browser_tabs_provider.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/media_filter.dart';
import '../providers/sniffer_provider.dart';
import 'media_card.dart';
import 'media_filter_bar.dart';

class MediaDeckPanel extends ConsumerWidget {
  const MediaDeckPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTabId = ref.watch(activeTabIdProvider);
    final activeTabMedia = ref.watch(activeTabMediaProvider);
    final filteredMedia = ref.watch(filteredMediaProvider);
    final filter = ref.watch(snifferFilterProvider);
    final keepMedia = ref.watch(keepMediaAcrossPagesProvider);

    final selectedInFiltered = filteredMedia
        .where((m) => m.isSelected)
        .toList();
    final allFilteredSelected =
        filteredMedia.isNotEmpty &&
        selectedInFiltered.length == filteredMedia.length;
    final someFilteredSelected =
        selectedInFiltered.isNotEmpty &&
        selectedInFiltered.length < filteredMedia.length;

    final videoCount = activeTabMedia
        .where(
          (m) =>
              m.mediaType == MediaType.video || m.mediaType == MediaType.stream,
        )
        .length;
    final imageCount = activeTabMedia
        .where((m) => m.mediaType == MediaType.image)
        .length;
    final audioCount = activeTabMedia
        .where((m) => m.mediaType == MediaType.audio)
        .length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border(left: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.radar,
                      color: AppTheme.accentCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Detected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Counter Badges with Material Icons
                    _buildIconBadge(
                      Icons.movie,
                      '$videoCount',
                      AppTheme.accentRose,
                    ),
                    const SizedBox(width: 4),
                    _buildIconBadge(
                      Icons.image,
                      '$imageCount',
                      AppTheme.accentCyan,
                    ),
                    if (audioCount > 0) ...[
                      const SizedBox(width: 4),
                      _buildIconBadge(
                        Icons.audiotrack,
                        '$audioCount',
                        AppTheme.primaryLight,
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    // Keep Across Pages Toggle (Lock icon)
                    Tooltip(
                      message: keepMedia
                          ? 'Keep Media: ON (Preserves list across page changes)'
                          : 'Auto-Clear: ON (Resets media list when URL changes)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          ref
                                  .read(keepMediaAcrossPagesProvider.notifier)
                                  .state =
                              !keepMedia;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                !keepMedia
                                    ? 'Keep across pages enabled (Accumulate media)'
                                    : 'Auto-clear on page change enabled',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: keepMedia
                                ? AppTheme.accentAmber.withValues(alpha: 0.15)
                                : AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: keepMedia
                                  ? AppTheme.accentAmber.withValues(alpha: 0.5)
                                  : AppTheme.darkBorder,
                            ),
                          ),
                          child: Icon(
                            keepMedia ? Icons.lock : Icons.lock_open_outlined,
                            size: 14,
                            color: keepMedia
                                ? AppTheme.accentAmber
                                : AppTheme.darkTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (activeTabMedia.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                          color: AppTheme.darkTextSecondary,
                        ),
                        tooltip: 'Clear Detected List for Active Tab',
                        onPressed: () {
                          ref
                              .read(snifferProvider.notifier)
                              .clearTabMedia(activeTabId);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Filter Bar
          const MediaFilterBar(),
          // Batch Action Toolbar (Strictly applies to filtered items)
          if (filteredMedia.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: AppTheme.darkSurface.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Checkbox(
                    value: allFilteredSelected,
                    tristate: someFilteredSelected,
                    activeColor: AppTheme.primaryLight,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      ref
                          .read(snifferProvider.notifier)
                          .selectVisible(
                            filteredMedia.map((m) => m.id).toList(),
                            val == true,
                          );
                    },
                  ),
                  Text(
                    'Selected (${selectedInFiltered.length}/${filteredMedia.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (selectedInFiltered.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.download, size: 13),
                      label: Text(
                        'Download (${selectedInFiltered.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(downloadQueueProvider.notifier)
                            .addBatchMediaToQueue(selectedInFiltered);
                        ref
                            .read(snifferProvider.notifier)
                            .selectVisible(
                              filteredMedia.map((m) => m.id).toList(),
                              false,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${selectedInFiltered.length} items to download queue',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          // Resizable Responsive Grid View
          Expanded(
            child: filteredMedia.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.travel_explore,
                            size: 40,
                            color: AppTheme.darkBorder,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No media matches current filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Play videos or click "Rescan" to capture media streams.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.darkTextSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount;
                      double childAspectRatio;

                      switch (filter.density) {
                        case GridDensity.compact:
                          crossAxisCount = (constraints.maxWidth / 120)
                              .floor()
                              .clamp(2, 6);
                          childAspectRatio = 0.85;
                          break;
                        case GridDensity.normal:
                          crossAxisCount = (constraints.maxWidth / 160)
                              .floor()
                              .clamp(2, 4);
                          childAspectRatio = 0.95;
                          break;
                        case GridDensity.large:
                          crossAxisCount = (constraints.maxWidth / 240)
                              .floor()
                              .clamp(1, 2);
                          childAspectRatio = 1.15;
                          break;
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(6),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: filteredMedia.length,
                        itemBuilder: (context, index) {
                          return MediaCard(media: filteredMedia[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            count,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
