import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../downloader/presentation/providers/download_queue_provider.dart';
import '../../domain/models/media_filter.dart';
import '../providers/sniffer_provider.dart';
import 'mobile_media_tile.dart';

class MobileSnifferBottomSheet extends ConsumerWidget {
  const MobileSnifferBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMedia = ref.watch(activeTabMediaProvider);
    final displayList = ref.watch(filteredMediaProvider);
    final filter = ref.watch(snifferFilterProvider);
    final filterNotifier = ref.read(snifferFilterProvider.notifier);

    // Counts for dropdown
    final videoCount = allMedia.where((m) => m.mediaType == MediaType.video || m.mediaType == MediaType.stream).length;
    final imageCount = allMedia.where((m) => m.mediaType == MediaType.image).length;
    final audioCount = allMedia.where((m) => m.mediaType == MediaType.audio).length;
    final otherCount = allMedia.where((m) => m.mediaType == MediaType.document || m.mediaType == MediaType.other).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkBackground,
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
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top Title & Batch Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hardware_rounded, color: AppTheme.accentCyan, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Detected Media (${displayList.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (displayList.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16, color: AppTheme.accentCyan),
                        label: const Text('Download All', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          for (final m in displayList) {
                            ref.read(downloadQueueProvider.notifier).addMediaToQueue(m);
                          }
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${displayList.length} items to download queue'),
                              backgroundColor: AppTheme.accentCyan,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Dropdown Filters & Sorters (Space-Saving)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    // Media Type Dropdown
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MediaType?>(
                            value: filter.typeFilter,
                            isExpanded: true,
                            dropdownColor: AppTheme.darkSurface,
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextPrimary),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('All Media (${allMedia.length})'),
                              ),
                              DropdownMenuItem(
                                value: MediaType.video,
                                child: Text('🎬 Videos ($videoCount)'),
                              ),
                              DropdownMenuItem(
                                value: MediaType.image,
                                child: Text('🖼️ Images ($imageCount)'),
                              ),
                              DropdownMenuItem(
                                value: MediaType.audio,
                                child: Text('🎵 Audio ($audioCount)'),
                              ),
                              DropdownMenuItem(
                                value: MediaType.document,
                                child: Text('📄 Others ($otherCount)'),
                              ),
                            ],
                            onChanged: (val) {
                              filterNotifier.state = filter.copyWith(
                                typeFilter: val,
                                clearTypeFilter: val == null,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Option Dropdown
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MediaSortField>(
                            value: filter.sortBy,
                            isExpanded: true,
                            dropdownColor: AppTheme.darkSurface,
                            style: const TextStyle(fontSize: 12, color: AppTheme.accentCyan),
                            items: const [
                              DropdownMenuItem(
                                value: MediaSortField.pageOrder,
                                child: Text('Order: Default'),
                              ),
                              DropdownMenuItem(
                                value: MediaSortField.size,
                                child: Text('Sort: File Size'),
                              ),
                              DropdownMenuItem(
                                value: MediaSortField.detectedAt,
                                child: Text('Sort: Time'),
                              ),
                              DropdownMenuItem(
                                value: MediaSortField.filename,
                                child: Text('Sort: Name'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                filterNotifier.state = filter.copyWith(sortBy: val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 12, color: AppTheme.darkBorder),

              // Media List View
              Expanded(
                child: displayList.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar_rounded, size: 48, color: AppTheme.darkTextSecondary),
                            SizedBox(height: 12),
                            Text(
                              'No matching media detected',
                              style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Play videos or scroll page to detect media streams',
                              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final media = displayList[index];
                          return MobileMediaTile(media: media);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
