import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/media_filter.dart';
import '../providers/sniffer_provider.dart';

class MediaFilterBar extends ConsumerStatefulWidget {
  const MediaFilterBar({super.key});

  @override
  ConsumerState<MediaFilterBar> createState() => _MediaFilterBarState();
}

class _MediaFilterBarState extends ConsumerState<MediaFilterBar> {
  bool _isAdvancedExpanded = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(snifferFilterProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatSizeRangeLabel(double minMB, double maxMB) {
    if (minMB <= 0 && maxMB <= 0) return 'All Sizes (No limit)';
    if (minMB > 0 && maxMB <= 0) return '>= ${minMB.toStringAsFixed(1)} MB';
    if (minMB <= 0 && maxMB > 0) return '<= ${maxMB.toStringAsFixed(1)} MB';
    return '${minMB.toStringAsFixed(1)} MB - ${maxMB.toStringAsFixed(1)} MB';
  }

  String _formatDimensionLabel(int minPx, int maxPx) {
    if (minPx <= 0 && maxPx <= 0) return 'Any (No limit)';
    if (minPx > 0 && maxPx <= 0) return '>= $minPx px';
    if (minPx <= 0 && maxPx > 0) return '<= $maxPx px';
    return '$minPx px - $maxPx px';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(snifferFilterProvider);
    final activeTabMedia = ref.watch(activeTabMediaProvider);

    final videoCount = activeTabMedia
        .where((m) => m.mediaType == MediaType.video || m.mediaType == MediaType.stream)
        .length;
    final imageCount = activeTabMedia
        .where((m) => m.mediaType == MediaType.image)
        .length;
    final audioCount = activeTabMedia
        .where((m) => m.mediaType == MediaType.audio)
        .length;

    final activeFilters = filter.activeFilterCount;
    final isVideoMode = filter.typeFilter == MediaType.video;
    final isImageMode = filter.typeFilter == MediaType.image;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Search, Filter Toggle, Sort & Density
          Row(
            children: [
              // Search Field
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12, color: AppTheme.darkTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search filename / url...',
                      hintStyle: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                      prefixIcon: const Icon(Icons.search, size: 14, color: AppTheme.darkTextSecondary),
                      prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      suffixIcon: filter.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 12, color: AppTheme.darkTextSecondary),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(snifferFilterProvider.notifier).state = filter.copyWith(searchQuery: '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.primaryLight),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(snifferFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Advanced Filter Drawer Toggle Button with Active Count Badge
              InkWell(
                onTap: () {
                  setState(() {
                    _isAdvancedExpanded = !_isAdvancedExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _isAdvancedExpanded || activeFilters > 0
                        ? AppTheme.primaryColor.withValues(alpha: 0.20)
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: activeFilters > 0 ? AppTheme.accentCyan : AppTheme.darkBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 14,
                        color: activeFilters > 0 ? AppTheme.accentCyan : AppTheme.darkTextSecondary,
                      ),
                      if (activeFilters > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$activeFilters',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Sort dropdown
              PopupMenuButton<MediaSortField>(
                tooltip: 'Sort by',
                color: AppTheme.darkSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 14, color: AppTheme.darkTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _sortLabel(filter.sortBy),
                        style: const TextStyle(fontSize: 10, color: AppTheme.darkTextPrimary),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.darkTextSecondary),
                    ],
                  ),
                ),
                onSelected: (sortField) {
                  ref.read(snifferFilterProvider.notifier).state = filter.copyWith(sortBy: sortField);
                },
                itemBuilder: (context) => [
                  _buildSortItem(MediaSortField.pageOrder, 'Page Order'),
                  _buildSortItem(MediaSortField.size, 'File Size'),
                  _buildSortItem(MediaSortField.detectedAt, 'Time Detected'),
                  _buildSortItem(MediaSortField.filename, 'File Name'),
                  _buildSortItem(MediaSortField.type, 'Media Type'),
                ],
              ),
              const SizedBox(width: 4),
              // Sort Direction Toggle (Asc / Desc)
              InkWell(
                onTap: () {
                  ref.read(snifferFilterProvider.notifier).state = filter.copyWith(
                    sortOrder: filter.sortOrder == SortOrder.ascending
                        ? SortOrder.descending
                        : SortOrder.ascending,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 30,
                  width: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Center(
                    child: Icon(
                      filter.sortOrder == SortOrder.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 13,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Grid Density Switcher
              _buildDensityIcon(GridDensity.compact, Icons.grid_view, 'Compact'),
              _buildDensityIcon(GridDensity.normal, Icons.view_comfy, 'Normal'),
              _buildDensityIcon(GridDensity.large, Icons.rectangle_outlined, 'Large'),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All (${activeTabMedia.length})',
                  icon: Icons.apps,
                  isSelected: filter.typeFilter == null,
                  onSelected: () {
                    ref.read(snifferFilterProvider.notifier).state = filter.copyWith(clearTypeFilter: true);
                  },
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  label: 'Videos ($videoCount)',
                  icon: Icons.movie,
                  isSelected: filter.typeFilter == MediaType.video,
                  onSelected: () {
                    ref.read(snifferFilterProvider.notifier).state = filter.copyWith(typeFilter: MediaType.video);
                  },
                ),
                const SizedBox(width: 4),
                _buildFilterChip(
                  label: 'Images ($imageCount)',
                  icon: Icons.image,
                  isSelected: filter.typeFilter == MediaType.image,
                  onSelected: () {
                    ref.read(snifferFilterProvider.notifier).state = filter.copyWith(typeFilter: MediaType.image);
                  },
                ),
                if (audioCount > 0) ...[
                  const SizedBox(width: 4),
                  _buildFilterChip(
                    label: 'Audio ($audioCount)',
                    icon: Icons.audiotrack,
                    isSelected: filter.typeFilter == MediaType.audio,
                    onSelected: () {
                      ref.read(snifferFilterProvider.notifier).state = filter.copyWith(typeFilter: MediaType.audio);
                    },
                  ),
                ],
              ],
            ),
          ),
          // Collapsible Advanced Filters Drawer
          if (_isAdvancedExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. File Size RangeSlider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVideoMode ? 'Video File Size Range:' : (isImageMode ? 'Image File Size Range:' : 'File Size Range:'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary),
                      ),
                      Text(
                        _formatSizeRangeLabel(filter.minSizeMB, filter.maxSizeMB),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      filter.minSizeMB.clamp(0.0, 100.0),
                      (filter.maxSizeMB == 0 ? 100.0 : filter.maxSizeMB).clamp(0.0, 100.0),
                    ),
                    min: 0,
                    max: 100,
                    divisions: 50,
                    activeColor: AppTheme.accentCyan,
                    inactiveColor: AppTheme.darkBorder,
                    labels: RangeLabels(
                      '${filter.minSizeMB.toStringAsFixed(0)} MB',
                      filter.maxSizeMB == 0 ? 'Max' : '${filter.maxSizeMB.toStringAsFixed(0)} MB',
                    ),
                    onChanged: (RangeValues values) {
                      final min = values.start;
                      final max = values.end >= 100.0 ? 0.0 : values.end;
                      ref.read(snifferFilterProvider.notifier).state = filter.copyWith(
                        minSizeMB: min,
                        maxSizeMB: max,
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // 2. Width RangeSlider (0 to 4000 px)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVideoMode ? 'Video Width (px):' : (isImageMode ? 'Image Width (px):' : 'Width (px):'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary),
                      ),
                      Text(
                        _formatDimensionLabel(filter.minWidth, filter.maxWidth),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      filter.minWidth.toDouble().clamp(0.0, 4000.0),
                      (filter.maxWidth == 0 ? 4000.0 : filter.maxWidth.toDouble()).clamp(0.0, 4000.0),
                    ),
                    min: 0,
                    max: 4000,
                    divisions: 40,
                    activeColor: AppTheme.primaryLight,
                    inactiveColor: AppTheme.darkBorder,
                    labels: RangeLabels(
                      '${filter.minWidth} px',
                      filter.maxWidth == 0 ? 'Max' : '${filter.maxWidth} px',
                    ),
                    onChanged: (RangeValues values) {
                      final min = values.start.toInt();
                      final max = values.end >= 4000.0 ? 0 : values.end.toInt();
                      ref.read(snifferFilterProvider.notifier).state = filter.copyWith(
                        minWidth: min,
                        maxWidth: max,
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // 3. Height RangeSlider (0 to 4000 px)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVideoMode ? 'Video Height (px):' : (isImageMode ? 'Image Height (px):' : 'Height (px):'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary),
                      ),
                      Text(
                        _formatDimensionLabel(filter.minHeight, filter.maxHeight),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      filter.minHeight.toDouble().clamp(0.0, 4000.0),
                      (filter.maxHeight == 0 ? 4000.0 : filter.maxHeight.toDouble()).clamp(0.0, 4000.0),
                    ),
                    min: 0,
                    max: 4000,
                    divisions: 40,
                    activeColor: AppTheme.accentAmber,
                    inactiveColor: AppTheme.darkBorder,
                    labels: RangeLabels(
                      '${filter.minHeight} px',
                      filter.maxHeight == 0 ? 'Max' : '${filter.maxHeight} px',
                    ),
                    onChanged: (RangeValues values) {
                      final min = values.start.toInt();
                      final max = values.end >= 4000.0 ? 0 : values.end.toInt();
                      ref.read(snifferFilterProvider.notifier).state = filter.copyWith(
                        minHeight: min,
                        maxHeight: max,
                      );
                    },
                  ),
                  const SizedBox(height: 6),

                  // 4. Quality Presets
                  const Text(
                    'Quick Presets:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip(QualityPreset.all, 'All', filter.qualityPreset),
                        const SizedBox(width: 4),
                        _buildPresetChip(QualityPreset.uhd4k, '4K UHD (2160p+)', filter.qualityPreset),
                        const SizedBox(width: 4),
                        _buildPresetChip(QualityPreset.fhd1080p, 'FHD (1080p)', filter.qualityPreset),
                        const SizedBox(width: 4),
                        _buildPresetChip(QualityPreset.hd720p, 'HD (720p)', filter.qualityPreset),
                        const SizedBox(width: 4),
                        _buildPresetChip(QualityPreset.sd, 'SD (<720p)', filter.qualityPreset),
                      ],
                    ),
                  ),

                  // Reset All Filters Button
                  if (activeFilters > 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.refresh, size: 12, color: AppTheme.accentRose),
                        label: const Text(
                          'Reset All Filters',
                          style: TextStyle(fontSize: 10, color: AppTheme.accentRose),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(snifferFilterProvider.notifier).state = const MediaFilter();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(QualityPreset preset, String label, QualityPreset current) {
    final isSelected = current == preset;
    return GestureDetector(
      onTap: () {
        ref.read(snifferFilterProvider.notifier).state =
            ref.read(snifferFilterProvider).copyWith(qualityPreset: preset);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : AppTheme.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<MediaSortField> _buildSortItem(MediaSortField field, String label) {
    return PopupMenuItem<MediaSortField>(
      value: field,
      height: 32,
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary)),
    );
  }

  String _sortLabel(MediaSortField field) {
    switch (field) {
      case MediaSortField.pageOrder:
        return 'Order';
      case MediaSortField.size:
        return 'Size';
      case MediaSortField.detectedAt:
        return 'Time';
      case MediaSortField.filename:
        return 'Name';
      case MediaSortField.type:
        return 'Type';
    }
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : AppTheme.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDensityIcon(GridDensity density, IconData icon, String tooltip) {
    final current = ref.watch(snifferFilterProvider).density;
    final isSelected = current == density;

    return InkWell(
      onTap: () {
        ref.read(snifferFilterProvider.notifier).state =
            ref.read(snifferFilterProvider).copyWith(density: density);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? AppTheme.accentCyan : AppTheme.darkTextSecondary,
        ),
      ),
    );
  }
}
