import '../../../../core/constants/app_constants.dart';

enum MediaSortField {
  pageOrder, // Top-to-bottom order on page (DOM Order)
  detectedAt, // Time detected
  size, // File size
  filename, // File name
  type, // Media type
}

enum SortOrder {
  ascending,
  descending,
}

enum GridDensity {
  compact, // 3-4 cols
  normal, // 2-3 cols
  large, // 1-2 cols
}

class MediaFilter {
  final MediaType? typeFilter;
  final String searchQuery;
  final double minSizeMB; // 0 = no filter
  final double maxSizeMB; // 0 = no filter
  final int minWidth; // 0 = no filter
  final int minHeight; // 0 = no filter
  final MediaSortField sortBy;
  final SortOrder sortOrder;
  final GridDensity density;

  const MediaFilter({
    this.typeFilter,
    this.searchQuery = '',
    this.minSizeMB = 0,
    this.maxSizeMB = 0,
    this.minWidth = 0,
    this.minHeight = 0,
    this.sortBy = MediaSortField.pageOrder,
    this.sortOrder = SortOrder.ascending,
    this.density = GridDensity.normal,
  });

  MediaFilter copyWith({
    MediaType? typeFilter,
    bool clearTypeFilter = false,
    String? searchQuery,
    double? minSizeMB,
    double? maxSizeMB,
    int? minWidth,
    int? minHeight,
    MediaSortField? sortBy,
    SortOrder? sortOrder,
    GridDensity? density,
  }) {
    return MediaFilter(
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      minSizeMB: minSizeMB ?? this.minSizeMB,
      maxSizeMB: maxSizeMB ?? this.maxSizeMB,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      density: density ?? this.density,
    );
  }

  Map<String, dynamic> toMap() => {
        'typeFilter': typeFilter?.name,
        'searchQuery': searchQuery,
        'minSizeMB': minSizeMB,
        'maxSizeMB': maxSizeMB,
        'minWidth': minWidth,
        'minHeight': minHeight,
        'sortBy': sortBy.name,
        'sortOrder': sortOrder.name,
        'density': density.name,
      };

  factory MediaFilter.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const MediaFilter();

    final typeStr = map['typeFilter'] as String?;
    final sortByStr = map['sortBy'] as String?;
    final sortOrderStr = map['sortOrder'] as String?;
    final densityStr = map['density'] as String?;

    return MediaFilter(
      typeFilter: typeStr != null
          ? MediaType.values.firstWhere(
              (e) => e.name == typeStr,
              orElse: () => MediaType.video,
            )
          : null,
      searchQuery: map['searchQuery'] as String? ?? '',
      minSizeMB: (map['minSizeMB'] as num?)?.toDouble() ?? 0,
      maxSizeMB: (map['maxSizeMB'] as num?)?.toDouble() ?? 0,
      minWidth: map['minWidth'] as int? ?? 0,
      minHeight: map['minHeight'] as int? ?? 0,
      sortBy: MediaSortField.values.firstWhere(
        (e) => e.name == sortByStr,
        orElse: () => MediaSortField.pageOrder,
      ),
      sortOrder: SortOrder.values.firstWhere(
        (e) => e.name == sortOrderStr,
        orElse: () => SortOrder.ascending,
      ),
      density: GridDensity.values.firstWhere(
        (e) => e.name == densityStr,
        orElse: () => GridDensity.normal,
      ),
    );
  }
}
