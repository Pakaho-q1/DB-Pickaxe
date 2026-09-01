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
  bool _showAdvancedFilters = false;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(snifferFilterProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Search, Sort, Density & Filter Expand Button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter name / URL...',
                      hintStyle: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkTextSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      suffixIcon: filter.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 13),
                              onPressed: () {
                                ref.read(snifferFilterProvider.notifier).state =
                                    filter.copyWith(searchQuery: '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      ref.read(snifferFilterProvider.notifier).state = filter
                          .copyWith(searchQuery: val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Sort dropdown
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MediaSortField>(
                    value: filter.sortBy,
                    dropdownColor: AppTheme.darkSurface,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkTextPrimary,
                    ),
                    icon: const Icon(
                      Icons.sort,
                      size: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: MediaSortField.pageOrder,
                        child: Text('Page Order'),
                      ),
                      DropdownMenuItem(
                        value: MediaSortField.detectedAt,
                        child: Text('Time Detected'),
                      ),
                      DropdownMenuItem(
                        value: MediaSortField.size,
                        child: Text('File Size'),
                      ),
                      DropdownMenuItem(
                        value: MediaSortField.filename,
                        child: Text('File Name'),
                      ),
                      DropdownMenuItem(
                        value: MediaSortField.type,
                        child: Text('Media Type'),
                      ),
                    ],
                    onChanged: (newSort) {
                      if (newSort != null) {
                        ref.read(snifferFilterProvider.notifier).state = filter
                            .copyWith(sortBy: newSort);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Sort Direction Toggle
              SizedBox(
                width: 28,
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    filter.sortOrder == SortOrder.descending
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: AppTheme.primaryLight,
                  ),
                  tooltip: filter.sortOrder == SortOrder.descending
                      ? 'Descending'
                      : 'Ascending',
                  onPressed: () {
                    final nextOrder = filter.sortOrder == SortOrder.descending
                        ? SortOrder.ascending
                        : SortOrder.descending;
                    ref.read(snifferFilterProvider.notifier).state = filter
                        .copyWith(sortOrder: nextOrder);
                  },
                ),
              ),
              const SizedBox(width: 4),
              // Advanced Filter Toggle Button
              SizedBox(
                width: 28,
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.tune,
                    size: 15,
                    color:
                        (filter.minSizeMB > 0 ||
                            filter.minWidth > 0 ||
                            filter.minHeight > 0 ||
                            _showAdvancedFilters)
                        ? AppTheme.accentCyan
                        : AppTheme.darkTextSecondary,
                  ),
                  tooltip: 'Sliders & Dimension Filters',
                  onPressed: () {
                    setState(() {
                      _showAdvancedFilters = !_showAdvancedFilters;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Category Filter Chips: All, Videos, Images, Audios
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  icon: Icons.layers_outlined,
                  isSelected: filter.typeFilter == null,
                  onSelected: () =>
                      ref.read(snifferFilterProvider.notifier).state = filter
                          .copyWith(clearTypeFilter: true),
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'Videos',
                  icon: Icons.movie_outlined,
                  isSelected: filter.typeFilter == MediaType.video,
                  onSelected: () =>
                      ref.read(snifferFilterProvider.notifier).state = filter
                          .copyWith(typeFilter: MediaType.video),
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'Images',
                  icon: Icons.image_outlined,
                  isSelected: filter.typeFilter == MediaType.image,
                  onSelected: () =>
                      ref.read(snifferFilterProvider.notifier).state = filter
                          .copyWith(typeFilter: MediaType.image),
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'Audios',
                  icon: Icons.audiotrack_outlined,
                  isSelected: filter.typeFilter == MediaType.audio,
                  onSelected: () =>
                      ref.read(snifferFilterProvider.notifier).state = filter
                          .copyWith(typeFilter: MediaType.audio),
                ),
                const SizedBox(width: 10),
                // Grid density toggle buttons
                Row(
                  children: [
                    _buildDensityIcon(
                      GridDensity.compact,
                      Icons.grid_view_rounded,
                      'Compact View',
                    ),
                    _buildDensityIcon(
                      GridDensity.normal,
                      Icons.view_module_rounded,
                      'Normal View',
                    ),
                    _buildDensityIcon(
                      GridDensity.large,
                      Icons.view_agenda_rounded,
                      'Large View',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Collapsible Advanced Filter Sliders
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                children: [
                  // Min Size Slider
                  Row(
                    children: [
                      const Text(
                        'Min Size:',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        filter.minSizeMB == 0
                            ? 'No filter'
                            : '>= ${filter.minSizeMB.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: filter.minSizeMB.clamp(0.0, 50.0),
                          min: 0,
                          max: 50,
                          divisions: 50,
                          activeColor: AppTheme.accentCyan,
                          onChanged: (val) {
                            ref.read(snifferFilterProvider.notifier).state =
                                filter.copyWith(minSizeMB: val);
                          },
                        ),
                      ),
                    ],
                  ),
                  // Min Width Slider
                  Row(
                    children: [
                      const Text(
                        'Min Width:',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        filter.minWidth == 0
                            ? 'No filter'
                            : '>= ${filter.minWidth} px',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: filter.minWidth.toDouble().clamp(0.0, 1920.0),
                          min: 0,
                          max: 1920,
                          divisions: 38,
                          activeColor: AppTheme.primaryLight,
                          onChanged: (val) {
                            ref.read(snifferFilterProvider.notifier).state =
                                filter.copyWith(minWidth: val.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                  // Min Height Slider
                  Row(
                    children: [
                      const Text(
                        'Min Height:',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        filter.minHeight == 0
                            ? 'No filter'
                            : '>= ${filter.minHeight} px',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: filter.minHeight.toDouble().clamp(0.0, 1080.0),
                          min: 0,
                          max: 1080,
                          divisions: 21,
                          activeColor: AppTheme.accentAmber,
                          onChanged: (val) {
                            ref.read(snifferFilterProvider.notifier).state =
                                filter.copyWith(minHeight: val.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                  // Reset Filters Button
                  if (filter.minSizeMB > 0 ||
                      filter.minWidth > 0 ||
                      filter.minHeight > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.refresh,
                          size: 12,
                          color: AppTheme.accentRose,
                        ),
                        label: const Text(
                          'Reset Sliders',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.accentRose,
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(snifferFilterProvider.notifier)
                              .state = filter.copyWith(
                            minSizeMB: 0,
                            minWidth: 0,
                            minHeight: 0,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
        ref.read(snifferFilterProvider.notifier).state = ref
            .read(snifferFilterProvider)
            .copyWith(density: density);
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
