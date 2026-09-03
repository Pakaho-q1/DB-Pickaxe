import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../browser/presentation/providers/browser_tabs_provider.dart';
import '../../domain/models/detected_media.dart';
import '../../domain/models/media_filter.dart';

class SnifferFilterNotifier extends StateNotifier<MediaFilter> {
  SnifferFilterNotifier() : super(HiveService.getSnifferFilter());

  @override
  set state(MediaFilter value) {
    super.state = value;
    HiveService.saveSnifferFilter(value);
  }
}

class KeepMediaNotifier extends StateNotifier<bool> {
  KeepMediaNotifier() : super(HiveService.getKeepMediaAcrossPages());

  @override
  set state(bool value) {
    super.state = value;
    HiveService.saveKeepMediaAcrossPages(value);
  }
}

final snifferFilterProvider = StateNotifierProvider<SnifferFilterNotifier, MediaFilter>((ref) {
  return SnifferFilterNotifier();
});

/// Toggle to keep detected media across page navigations (Persisted)
final keepMediaAcrossPagesProvider = StateNotifierProvider<KeepMediaNotifier, bool>((ref) {
  return KeepMediaNotifier();
});

/// Sniffer state mapped per tab ID: `Map<String, List<DetectedMedia>>`
final snifferProvider = StateNotifierProvider<SnifferNotifier, Map<String, List<DetectedMedia>>>((ref) {
  return SnifferNotifier();
});

/// Media items strictly belonging to the currently active browser tab
final activeTabMediaProvider = Provider<List<DetectedMedia>>((ref) {
  final snifferMap = ref.watch(snifferProvider);
  final activeTabId = ref.watch(activeTabIdProvider);
  return snifferMap[activeTabId] ?? const [];
});

/// Filtered & Sorted media items for the active browser tab
final filteredMediaProvider = Provider<List<DetectedMedia>>((ref) {
  final items = ref.watch(activeTabMediaProvider);
  final filter = ref.watch(snifferFilterProvider);

  var list = items.where((item) {
    // 1. Type Filter (Videos includes both direct video and stream m3u8)
    if (filter.typeFilter != null) {
      if (filter.typeFilter == MediaType.video) {
        if (item.mediaType != MediaType.video && item.mediaType != MediaType.stream) {
          return false;
        }
      } else if (item.mediaType != filter.typeFilter) {
        return false;
      }
    }

    // 2. Search Query
    if (filter.searchQuery.isNotEmpty) {
      final q = filter.searchQuery.toLowerCase();
      final matchName = item.filename.toLowerCase().contains(q);
      final matchUrl = item.url.toLowerCase().contains(q);
      if (!matchName && !matchUrl) return false;
    }

    // 3. Min / Max Size Range (MB)
    if (item.sizeBytes > 0) {
      final sizeMB = item.sizeBytes / (1024 * 1024);
      if (filter.minSizeMB > 0 && sizeMB < filter.minSizeMB) return false;
      if (filter.maxSizeMB > 0 && sizeMB > filter.maxSizeMB) return false;
    } else if (filter.minSizeMB > 0 && item.mediaType != MediaType.stream) {
      // If minSize filter is active and item size is still 0 (probe pending), skip
      return false;
    }

    // 4. Width / Height Range Filters (0 = no filter)
    if (filter.minWidth > 0 || filter.maxWidth > 0 || filter.minHeight > 0 || filter.maxHeight > 0) {
      if (item.resolution != null && item.resolution!.contains('x')) {
        final parts = item.resolution!.split('x');
        final w = int.tryParse(parts[0]) ?? 0;
        final h = int.tryParse(parts[1]) ?? 0;
        if (filter.minWidth > 0 && w > 0 && w < filter.minWidth) return false;
        if (filter.maxWidth > 0 && w > 0 && w > filter.maxWidth) return false;
        if (filter.minHeight > 0 && h > 0 && h < filter.minHeight) return false;
        if (filter.maxHeight > 0 && h > 0 && h > filter.maxHeight) return false;
      }
    }

    // 5. Quality Preset filter (UHD 4K, FHD 1080p, HD 720p, SD)
    if (filter.qualityPreset != QualityPreset.all) {
      final area = _groupedMediaArea(item);
      final h = _extractHeight(item);
      switch (filter.qualityPreset) {
        case QualityPreset.uhd4k:
          if (h < 2160 && area < 3840 * 2160) return false;
          break;
        case QualityPreset.fhd1080p:
          if ((h < 1080 && area < 1920 * 1080) || h >= 2160 || area >= 3840 * 2160) return false;
          break;
        case QualityPreset.hd720p:
          if ((h < 720 && area < 1280 * 720) || h >= 1080 || area >= 1920 * 1080) return false;
          break;
        case QualityPreset.sd:
          if (h >= 720 || area >= 1280 * 720) return false;
          break;
        case QualityPreset.all:
          break;
      }
    }

    return true;
  }).toList();

  // Sort
  list.sort((a, b) {
    int comparison = 0;
    switch (filter.sortBy) {
      case MediaSortField.pageOrder:
        comparison = a.domIndex.compareTo(b.domIndex);
        break;
      case MediaSortField.detectedAt:
        comparison = a.detectedAt.compareTo(b.detectedAt);
        break;
      case MediaSortField.size:
        comparison = a.sizeBytes.compareTo(b.sizeBytes);
        break;
      case MediaSortField.filename:
        comparison = a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
        break;
      case MediaSortField.type:
        comparison = a.mediaType.name.compareTo(b.mediaType.name);
        break;
    }
    return filter.sortOrder == SortOrder.descending ? -comparison : comparison;
  });

  return list;
});

int _extractHeight(DetectedMedia m) {
  if (m.resolution != null && m.resolution!.contains('x')) {
    final parts = m.resolution!.split('x');
    final p1 = int.tryParse(parts[0]) ?? 0;
    final p2 = int.tryParse(parts[1]) ?? 0;
    return p1 < p2 ? p1 : p2;
  }
  return 0;
}

/// Identifies and filters out tiny byte-range chunks / partial segments
/// e.g. 0.m4s, 18446744073709551615.m4s, init.m4s, segment-1.ts
bool isJunkStreamSegment(String url) {
  final clean = url.split('?').first.toLowerCase();
  if (clean.endsWith('.m4s') ||
      clean.endsWith('.mp4frag') ||
      clean.endsWith('.cmfv') ||
      clean.endsWith('.cmfa') ||
      clean.endsWith('.init') ||
      clean.endsWith('.m4f')) {
    return true;
  }
  // Numbered ts chunk e.g. seg-1.ts, 12345.ts, chunk_0.ts
  if (clean.endsWith('.ts') && RegExp(r'[-_0-9/](seg|segment|chunk|frag|part|video|audio)?[0-9]+\.ts$').hasMatch(clean)) {
    return true;
  }
  return false;
}

/// Universal group key for media variants:
/// Groups video resolution variants (4K, 1440p, 1080p, 720p, 360p) and image size variants (?w=, ?q=)
/// into a single card per media entity.
String mediaGroupKey(DetectedMedia m) {
  final rawUrl = m.url;
  try {
    final uri = Uri.parse(rawUrl);
    var path = uri.path.toLowerCase();

    // 1. Remove file extension
    final dot = path.lastIndexOf('.');
    if (dot != -1) path = path.substring(0, dot);

    // 2. Strip resolution/quality/density tokens:
    path = path.replaceAll(RegExp(r'[-_](uhd|fhd|hd|sd|4k|2k|qhd|2160p|1440p|1080p|720p|540p|480p|360p|240p|\d+fps)'), '');
    path = path.replaceAll(RegExp(r'[-_]\d+_\d+'), ''); // e.g. _1440_2560
    path = path.replaceAll(RegExp(r'[-_]\d+x\d+'), ''); // e.g. _1440x2560
    path = path.replaceAll(RegExp(r'[-_](large|medium|small|thumb|preview|original|highres|full)'), '');

    return '${m.mediaType.name}:${uri.host}$path';
  } catch (_) {
    return '${m.mediaType.name}:${rawUrl.split('?').first.toLowerCase()}';
  }
}

/// Legacy helper for test compatibility
String imageGroupKey(String rawUrl) {
  try {
    final uri = Uri.parse(rawUrl);
    return '${uri.scheme}://${uri.host}${uri.path}'.toLowerCase();
  } catch (_) {
    return rawUrl.split('?').first.toLowerCase();
  }
}

int _groupedMediaArea(DetectedMedia m) {
  if (m.resolution != null && m.resolution!.contains('x')) {
    final parts = m.resolution!.split('x');
    final w = int.tryParse(parts[0]) ?? 0;
    final h = int.tryParse(parts[1]) ?? 0;
    if (w > 0 && h > 0) return w * h;
  }
  return 0;
}

class GroupedMedia {
  final DetectedMedia primary;
  final List<DetectedMedia> variants;
  const GroupedMedia({required this.primary, this.variants = const []});
  int get totalCount => 1 + variants.length;
  List<DetectedMedia> get all => [primary, ...variants];
}

/// Toggle: false = collapse variants by [mediaGroupKey] (default), true = show all separately.
final showGroupedVariantsProvider = StateProvider<bool>((ref) => false);

final groupedFilteredMediaProvider = Provider<List<GroupedMedia>>((ref) {
  final items = ref.watch(filteredMediaProvider);
  final expandAll = ref.watch(showGroupedVariantsProvider);
  if (expandAll) {
    return items.map((m) => GroupedMedia(primary: m)).toList();
  }
  final Map<String, List<DetectedMedia>> groups = {};
  for (final m in items) {
    final key = mediaGroupKey(m);
    groups.putIfAbsent(key, () => []).add(m);
  }

  final List<GroupedMedia> result = [];
  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.length == 1) {
      result.add(GroupedMedia(primary: list.first));
    } else {
      // Sort: largest resolution first, then largest file size
      list.sort((a, b) {
        final areaA = _groupedMediaArea(a);
        final areaB = _groupedMediaArea(b);
        if (areaB != areaA) return areaB.compareTo(areaA);
        if (b.sizeBytes != a.sizeBytes) return b.sizeBytes.compareTo(a.sizeBytes);
        return a.domIndex.compareTo(b.domIndex);
      });

      // Thumbnail Inheritance: if primary lacks thumbnail, borrow from any variant in group
      String? bestThumb = list.first.thumbnailUrl;
      if (bestThumb == null || bestThumb.isEmpty) {
        for (final item in list) {
          if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
            bestThumb = item.thumbnailUrl;
            break;
          }
        }
      }

      final primaryWithThumb = (bestThumb != null && (list.first.thumbnailUrl == null || list.first.thumbnailUrl!.isEmpty))
          ? list.first.copyWith(thumbnailUrl: bestThumb)
          : list.first;

      result.add(GroupedMedia(
        primary: primaryWithThumb,
        variants: list.sublist(1).map((v) {
          if ((v.thumbnailUrl == null || v.thumbnailUrl!.isEmpty) && bestThumb != null) {
            return v.copyWith(thumbnailUrl: bestThumb);
          }
          return v;
        }).toList(),
      ));
    }
  }

  // Keep page order by primary.domIndex
  result.sort((a, b) => a.primary.domIndex.compareTo(b.primary.domIndex));
  return result;
});

class SnifferNotifier extends StateNotifier<Map<String, List<DetectedMedia>>> {
  SnifferNotifier() : super({});

  final Map<String, Set<String>> _tabDetectedUrls = {};

  /// Canonical URL for dedup: strips ONLY ephemeral/auth params.
  static const _ephemeralKeys = {
    '_',
    'token',
    't',
    'timestamp',
    'sig',
    'signature',
    '_t',
    'auth',
    'expires',
    'key',
    'session',
    'nonce',
    'bytestart',
    'byteend',
    '_nc_cat',
    '_nc_sid',
    '_nc_ohc',
    '_nc_ht',
    'edm',
    'ccb',
    'st',
    'e',
    'oh',
    'oe',
  };

  String _canonicalUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final cleanParams = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((k, _) => _ephemeralKeys.contains(k.toLowerCase()));

      final base = '${uri.scheme}://${uri.host}${uri.path}';
      if (cleanParams.isEmpty) return base.toLowerCase();
      final sortedKeys = cleanParams.keys.toList()..sort();
      final sortedQuery = sortedKeys.map((k) => '$k=${cleanParams[k]}').join('&');
      return '$base?$sortedQuery'.toLowerCase();
    } catch (_) {
      return rawUrl.split('?').first.toLowerCase();
    }
  }

  String? _detectResolution(String url, {int width = 0, int height = 0}) {
    if (width > 0 && height > 0) {
      return '${width}x$height';
    }
    final clean = url.toLowerCase();

    // 1. Matches e.g. _1440_2560_, _2160_3840_, _720_1280_, 1920x1080 (isolated from longer ID numbers)
    final resMatch = RegExp(r'(?:^|[^0-9])(\d{3,4})[x_](\d{3,4})(?:[^0-9]|$)').firstMatch(clean);
    if (resMatch != null) {
      final d1 = int.tryParse(resMatch.group(1)!) ?? 0;
      final d2 = int.tryParse(resMatch.group(2)!) ?? 0;
      if (d1 >= 240 && d2 >= 240) {
        return '${d1}x$d2';
      }
    }

    // 2. Named tokens
    if (clean.contains('uhd') || clean.contains('2160p') || clean.contains('4k')) {
      return '3840x2160';
    }
    if (clean.contains('1440p') || clean.contains('2k') || clean.contains('qhd')) {
      return '2560x1440';
    }
    if (clean.contains('1080p') || clean.contains('fhd')) {
      return '1920x1080';
    }
    if (clean.contains('720p') || clean.contains('-hd_') || clean.contains('_hd_')) {
      return '1280x720';
    }
    if (clean.contains('540p')) {
      return '960x540';
    }
    if (clean.contains('360p') || clean.contains('-sd_') || clean.contains('_sd_')) {
      return '640x360';
    }

    return null;
  }

  void _probeMediaSizeAsync(String tabId, DetectedMedia media) {
    if (media.sizeBytes > 0 || media.mediaType == MediaType.stream) return;
    final uri = Uri.tryParse(media.url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;

    Future.microtask(() async {
      try {
        final settings = HiveService.getSettings();
        final dio = DioClient.createDio(
          settings,
          targetUrl: media.url,
          refererUrl: media.pageUrl,
          customHeaders: media.headers,
        );
        final response = await dio.head(
          media.url,
          options: Options(
            validateStatus: (status) => status != null && status < 400,
            followRedirects: true,
          ),
        );
        final lengthStr = response.headers.value('content-length');
        if (lengthStr != null) {
          final size = int.tryParse(lengthStr) ?? 0;
          if (size > 0) {
            updateMediaSize(tabId, media.id, size);
          }
        }
      } catch (_) {}
    });
  }

  void updateMediaSize(String tabId, String mediaId, int sizeBytes) {
    final currentTabList = state[tabId];
    if (currentTabList == null) return;
    final idx = currentTabList.indexWhere((m) => m.id == mediaId);
    if (idx != -1 && currentTabList[idx].sizeBytes != sizeBytes) {
      final updatedList = List<DetectedMedia>.from(currentTabList);
      updatedList[idx] = updatedList[idx].copyWith(sizeBytes: sizeBytes);
      state = {
        ...state,
        tabId: updatedList,
      };
    }
  }

  void addMediaBatch({
    required String tabId,
    required List<Map<String, dynamic>> items,
  }) {
    if (tabId.isEmpty || items.isEmpty) return;

    final detectedSet = _tabDetectedUrls.putIfAbsent(tabId, () => <String>{});
    final currentTabList = List<DetectedMedia>.from(state[tabId] ?? []);
    final newItems = <DetectedMedia>[];
    bool hasUpdates = false;

    for (final data in items) {
      final url = data['url'] as String? ?? '';
      if (url.isEmpty || isJunkStreamSegment(url)) continue;

      final canonical = _canonicalUrl(url);
      final pageUrl = data['pageUrl'] as String? ?? '';
      final typeStr = data['type'] as String?;
      final mime = data['mime'] as String?;
      final title = data['title'] as String?;
      final width = data['width'] as int? ?? 0;
      final height = data['height'] as int? ?? 0;
      final sizeBytes = data['sizeBytes'] as int? ?? 0;
      final thumbnailUrl = data['thumbnailUrl'] as String?;
      final domIndex = data['domIndex'] as int? ?? 0;
      final resolvedRes = _detectResolution(url, width: width, height: height);

      // If already exists, smart merge / enrich missing metadata
      if (detectedSet.contains(canonical)) {
        final existingIdx = currentTabList.indexWhere((m) => _canonicalUrl(m.url) == canonical);
        if (existingIdx != -1) {
          final old = currentTabList[existingIdx];
          final updated = old.copyWith(
            sizeBytes: old.sizeBytes > 0 ? old.sizeBytes : sizeBytes,
            resolution: (old.resolution != null && old.resolution!.isNotEmpty)
                ? old.resolution
                : resolvedRes,
            thumbnailUrl: (old.thumbnailUrl != null && old.thumbnailUrl!.isNotEmpty)
                ? old.thumbnailUrl
                : thumbnailUrl,
          );
          if (updated != old) {
            currentTabList[existingIdx] = updated;
            hasUpdates = true;
          }
        }
        continue;
      }

      detectedSet.add(canonical);

      final mediaType = _detectMediaType(url, typeStr, mime);
      final ext = _extractExtension(url, mediaType);
      final filename = _generateFilename(url, title, ext);

      final newItem = DetectedMedia(
        id: const Uuid().v4(),
        tabId: tabId,
        url: url,
        pageUrl: pageUrl,
        filename: filename,
        mediaType: mediaType,
        extension: ext,
        sizeBytes: sizeBytes,
        thumbnailUrl: thumbnailUrl ?? (mediaType == MediaType.image ? url : null),
        detectedAt: DateTime.now(),
        resolution: resolvedRes,
        domIndex: domIndex,
      );

      newItems.add(newItem);
      if (sizeBytes == 0) {
        _probeMediaSizeAsync(tabId, newItem);
      }
    }

    if (newItems.isNotEmpty || hasUpdates) {
      state = {
        ...state,
        tabId: [...newItems, ...currentTabList],
      };
    }
  }

  void addMedia({
    required String tabId,
    required String url,
    required String pageUrl,
    String? title,
    String? typeStr,
    int width = 0,
    int height = 0,
    int sizeBytes = 0,
    String? mime,
    String? thumbnailUrl,
    int domIndex = 0,
    Map<String, String>? headers,
  }) {
    if (url.isEmpty || tabId.isEmpty || isJunkStreamSegment(url)) return;

    final canonical = _canonicalUrl(url);
    final detectedSet = _tabDetectedUrls.putIfAbsent(tabId, () => <String>{});
    final currentTabList = List<DetectedMedia>.from(state[tabId] ?? []);
    final resolvedRes = _detectResolution(url, width: width, height: height);

    // Smart merge / enrich if already detected
    if (detectedSet.contains(canonical)) {
      final existingIdx = currentTabList.indexWhere((m) => _canonicalUrl(m.url) == canonical);
      if (existingIdx != -1) {
        final old = currentTabList[existingIdx];
        final updated = old.copyWith(
          sizeBytes: old.sizeBytes > 0 ? old.sizeBytes : sizeBytes,
          resolution: (old.resolution != null && old.resolution!.isNotEmpty)
              ? old.resolution
              : resolvedRes,
          thumbnailUrl: (old.thumbnailUrl != null && old.thumbnailUrl!.isNotEmpty)
              ? old.thumbnailUrl
              : thumbnailUrl,
          headers: headers != null ? {...old.headers, ...headers} : old.headers,
        );
        if (updated != old) {
          currentTabList[existingIdx] = updated;
          state = {
            ...state,
            tabId: currentTabList,
          };
        }
      }
      return;
    }

    detectedSet.add(canonical);

    final mediaType = _detectMediaType(url, typeStr, mime);
    final ext = _extractExtension(url, mediaType);
    final filename = _generateFilename(url, title, ext);

    final item = DetectedMedia(
      id: const Uuid().v4(),
      tabId: tabId,
      url: url,
      pageUrl: pageUrl,
      filename: filename,
      mediaType: mediaType,
      extension: ext,
      sizeBytes: sizeBytes,
      thumbnailUrl: thumbnailUrl ?? (mediaType == MediaType.image ? url : null),
      headers: headers ?? {},
      detectedAt: DateTime.now(),
      resolution: resolvedRes,
      domIndex: domIndex,
    );

    state = {
      ...state,
      tabId: [item, ...currentTabList],
    };

    if (sizeBytes == 0) {
      _probeMediaSizeAsync(tabId, item);
    }
  }

  void toggleSelect(String mediaId) {
    state = state.map((tabId, list) {
      final updatedList = list.map((item) {
        if (item.id == mediaId) {
          return item.copyWith(isSelected: !item.isSelected);
        }
        return item;
      }).toList();
      return MapEntry(tabId, updatedList);
    });
  }

  void selectVisible(List<String> visibleIds, bool select) {
    final visibleSet = visibleIds.toSet();
    state = state.map((tabId, list) {
      final updatedList = list.map((item) {
        if (visibleSet.contains(item.id)) {
          return item.copyWith(isSelected: select);
        }
        return item;
      }).toList();
      return MapEntry(tabId, updatedList);
    });
  }

  void selectAllForTab(String tabId, bool select) {
    final current = state[tabId];
    if (current == null) return;
    state = {
      ...state,
      tabId: current.map((item) => item.copyWith(isSelected: select)).toList(),
    };
  }

  void clearTabMedia(String tabId) {
    _tabDetectedUrls.remove(tabId);
    state = {
      ...state,
      tabId: [],
    };
  }

  MediaType _detectMediaType(String url, String? typeStr, String? mime) {
    if (typeStr != null) {
      if (typeStr == 'stream') return MediaType.stream;
      if (typeStr == 'video') return MediaType.video;
      if (typeStr == 'image') return MediaType.image;
      if (typeStr == 'audio') return MediaType.audio;
    }

    final lowerMime = (mime ?? '').toLowerCase();
    if (lowerMime.contains('mpegurl') || lowerMime.contains('dash+xml')) return MediaType.stream;
    if (lowerMime.startsWith('video/')) return MediaType.video;
    if (lowerMime.startsWith('image/')) return MediaType.image;
    if (lowerMime.startsWith('audio/')) return MediaType.audio;

    final cleanUrl = url.split('?').first.toLowerCase();
    if (cleanUrl.endsWith('.m3u8') || cleanUrl.endsWith('.mpd')) return MediaType.stream;
    if (cleanUrl.endsWith('.mp4') || cleanUrl.endsWith('.webm') || cleanUrl.endsWith('.mov') || cleanUrl.endsWith('.mkv') || cleanUrl.endsWith('.avi')) return MediaType.video;
    if (cleanUrl.endsWith('.jpg') || cleanUrl.endsWith('.jpeg') || cleanUrl.endsWith('.png') || cleanUrl.endsWith('.webp') || cleanUrl.endsWith('.gif') || cleanUrl.endsWith('.avif')) return MediaType.image;
    if (cleanUrl.endsWith('.mp3') || cleanUrl.endsWith('.aac') || cleanUrl.endsWith('.wav') || cleanUrl.endsWith('.ogg') || cleanUrl.endsWith('.m4a') || cleanUrl.endsWith('.flac')) return MediaType.audio;

    final fullLower = url.toLowerCase();
    if (fullLower.contains('images.unsplash.com') ||
        fullLower.contains('/photo-') ||
        fullLower.contains('format=') ||
        fullLower.contains('auto=format') ||
        fullLower.contains('images.pexels.com') ||
        fullLower.contains('cdn.pixabay.com') ||
        fullLower.contains('i.imgur.com') ||
        fullLower.contains('rule34') ||
        fullLower.contains('donmai') ||
        fullLower.contains('gelbooru')) {
      return MediaType.image;
    }

    return MediaType.other;
  }

  String _extractExtension(String url, MediaType mediaType) {
    try {
      final cleanPath = Uri.parse(url).path;
      final dotIndex = cleanPath.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < cleanPath.length - 1) {
        final ext = cleanPath.substring(dotIndex).toLowerCase();
        if (ext.length <= 5 && RegExp(r'^\.[a-z0-9]+$').hasMatch(ext)) {
          return ext;
        }
      }
    } catch (_) {}

    switch (mediaType) {
      case MediaType.image:
        return '.jpg';
      case MediaType.video:
        return '.mp4';
      case MediaType.stream:
        return '.mp4';
      case MediaType.audio:
        return '.mp3';
      case MediaType.document:
        return '.pdf';
      case MediaType.other:
        return '.dat';
    }
  }

  String _generateFilename(String url, String? title, String extension) {
    String baseName = '';
    if (title != null && title.trim().isNotEmpty) {
      baseName = title.trim();
    } else {
      try {
        final uri = Uri.parse(url);
        final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (segment.isNotEmpty) {
          baseName = Uri.decodeComponent(segment);
        }
      } catch (_) {}
    }

    if (baseName.isEmpty) {
      baseName = 'media_${DateTime.now().millisecondsSinceEpoch}';
    }

    baseName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final extLower = extension.toLowerCase();
    if (baseName.toLowerCase().endsWith(extLower)) {
      baseName = baseName.substring(0, baseName.length - extLower.length);
    }

    final maxBaseLength = 60 - extension.length;
    if (baseName.length > maxBaseLength) {
      baseName = baseName.substring(0, maxBaseLength);
    }

    return '$baseName$extension';
  }
}
