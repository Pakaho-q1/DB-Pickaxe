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
    final allMedia = ref.watch(snifferProvider);
    final filteredMedia = ref.watch(filteredMediaProvider);
    final filter = ref.watch(snifferFilterProvider);
    final isAutoDetect = ref.watch(isAutoDetectEnabledProvider);

    final selectedInFiltered = filteredMedia.where((m) => m.isSelected).toList();
    final allFilteredSelected = filteredMedia.isNotEmpty && selectedInFiltered.length == filteredMedia.length;
    final someFilteredSelected = selectedInFiltered.isNotEmpty && selectedInFiltered.length < filteredMedia.length;

    final videoCount = allMedia.where((m) => m.mediaType == MediaType.video || m.mediaType == MediaType.stream).length;
    final imageCount = allMedia.where((m) => m.mediaType == MediaType.image).length;
    final audioCount = allMedia.where((m) => m.mediaType == MediaType.audio).length;

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
                    const Icon(Icons.radar, color: AppTheme.accentCyan, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Detected Media',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                    const SizedBox(width: 8),
                    // Counter Badges with Material Icons
                    _buildIconBadge(Icons.movie, '$videoCount', AppTheme.accentRose),
                    const SizedBox(width: 4),
                    _buildIconBadge(Icons.image, '$imageCount', AppTheme.accentCyan),
                    if (audioCount > 0) ...[
                      const SizedBox(width: 4),
                      _buildIconBadge(Icons.audiotrack, '$audioCount', AppTheme.primaryLight),
                    ],
                  ],
                ),
                Row(
                  children: [
                    // Auto-detect vs On-demand mode toggle
                    Tooltip(
                      message: isAutoDetect ? 'Mode: Auto-Detect (Continuous)' : 'Mode: Manual / On-Demand',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          ref.read(isAutoDetectEnabledProvider.notifier).state = !isAutoDetect;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAutoDetect ? AppTheme.accentGreen.withValues(alpha: 0.15) : AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isAutoDetect ? AppTheme.accentGreen.withValues(alpha: 0.5) : AppTheme.darkBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAutoDetect ? Icons.flash_on : Icons.touch_app,
                                size: 12,
                                color: isAutoDetect ? AppTheme.accentGreen : AppTheme.darkTextSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isAutoDetect ? 'Auto' : 'Manual',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isAutoDetect ? AppTheme.accentGreen : AppTheme.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Refresh / Rescan Detection Button
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppTheme.accentCyan),
                      tooltip: 'Rescan & Detect Media on This Page',
                      onPressed: () {
                        ref.read(browserTabsProvider.notifier).rescanActiveTab();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deep scanning active web page for media and streams...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    if (allMedia.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppTheme.darkTextSecondary),
                        tooltip: 'Clear Detected List',
                        onPressed: () {
                          ref.read(snifferProvider.notifier).clearAll();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Sniff / Detect Page Action Bar (Shown when in Manual mode)
          if (!isAutoDetect)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.primaryLight),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Manual mode: Click to detect media on this page',
                      style: TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.radar, size: 13),
                    label: const Text('Detect Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ref.read(browserTabsProvider.notifier).rescanActiveTab();
                    },
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
                      ref.read(snifferProvider.notifier).selectVisible(
                            filteredMedia.map((m) => m.id).toList(),
                            val == true,
                          );
                    },
                  ),
                  Text(
                    'Selected (${selectedInFiltered.length}/${filteredMedia.length})',
                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                  ),
                  const Spacer(),
                  if (selectedInFiltered.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.download, size: 13),
                      label: Text('Download (${selectedInFiltered.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ref.read(downloadQueueProvider.notifier).addBatchMediaToQueue(selectedInFiltered);
                        ref.read(snifferProvider.notifier).selectVisible(
                              filteredMedia.map((m) => m.id).toList(),
                              false,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${selectedInFiltered.length} items to download queue'),
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
                          Icon(Icons.travel_explore, size: 40, color: AppTheme.darkBorder),
                          const SizedBox(height: 10),
                          const Text(
                            'No media matches current filter',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkTextSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Play videos or click "Rescan" to capture media streams.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 10),
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
                          crossAxisCount = (constraints.maxWidth / 120).floor().clamp(2, 6);
                          childAspectRatio = 0.85;
                          break;
                        case GridDensity.normal:
                          crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 4);
                          childAspectRatio = 0.95;
                          break;
                        case GridDensity.large:
                          crossAxisCount = (constraints.maxWidth / 240).floor().clamp(1, 2);
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
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
