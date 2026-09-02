import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
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

    // 3. Min Size MB (0 = no filter)
    if (filter.minSizeMB > 0) {
      final sizeMB = item.sizeBytes / (1024 * 1024);
      if (item.sizeBytes > 0 && sizeMB < filter.minSizeMB) return false;
    }

    // 4. Max Size MB (0 = no filter)
    if (filter.maxSizeMB > 0) {
      final sizeMB = item.sizeBytes / (1024 * 1024);
      if (item.sizeBytes > 0 && sizeMB > filter.maxSizeMB) return false;
    }

    // 5. Width / Height Filters (0 = no filter)
    if (filter.minWidth > 0 || filter.minHeight > 0) {
      if (item.resolution != null && item.resolution!.contains('x')) {
        final parts = item.resolution!.split('x');
        final w = int.tryParse(parts[0]) ?? 0;
        final h = int.tryParse(parts[1]) ?? 0;
        if (filter.minWidth > 0 && w > 0 && w < filter.minWidth) return false;
        if (filter.minHeight > 0 && h > 0 && h < filter.minHeight) return false;
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

class SnifferNotifier extends StateNotifier<Map<String, List<DetectedMedia>>> {
  SnifferNotifier() : super({});

  final Map<String, Set<String>> _tabDetectedUrls = {};

  /// Smart Canonical URL Stripping for deduplication & sizing normalization
  String _canonicalUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final cleanParams = Map<String, dynamic>.from(uri.queryParameters)
        ..removeWhere((k, v) => const [
              '_',
              'token',
              't',
              'timestamp',
              'sig',
              '_t',
              'auth',
              'expires',
              'key',
              'session',
              'nonce',
              'auto',
              'w',
              'h',
              'width',
              'height',
              'fit',
              'crop',
              'q',
              'quality',
              'dpr',
              'bytestart',
              'byteend',
              '_nc_cat',
              '_nc_sid',
              '_nc_ohc',
              '_nc_ht',
              'edm',
              'ccb'
            ].contains(k.toLowerCase()));

      final base = '${uri.scheme}://${uri.host}${uri.path}';
      if (cleanParams.isEmpty) return base.toLowerCase();
      final sortedQuery = cleanParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      return '$base?$sortedQuery'.toLowerCase();
    } catch (_) {
      return rawUrl.split('?').first.toLowerCase();
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
      if (url.isEmpty) continue;

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

      // If already exists, smart merge / enrich missing metadata
      if (detectedSet.contains(canonical)) {
        final existingIdx = currentTabList.indexWhere((m) => _canonicalUrl(m.url) == canonical);
        if (existingIdx != -1) {
          final old = currentTabList[existingIdx];
          final updated = old.copyWith(
            sizeBytes: old.sizeBytes > 0 ? old.sizeBytes : sizeBytes,
            resolution: (old.resolution != null && old.resolution!.isNotEmpty)
                ? old.resolution
                : (width > 0 && height > 0 ? '${width}x$height' : null),
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

      newItems.add(DetectedMedia(
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
        resolution: width > 0 && height > 0 ? '${width}x$height' : null,
        domIndex: domIndex,
      ));
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
    if (url.isEmpty || tabId.isEmpty) return;

    final canonical = _canonicalUrl(url);
    final detectedSet = _tabDetectedUrls.putIfAbsent(tabId, () => <String>{});
    final currentTabList = List<DetectedMedia>.from(state[tabId] ?? []);

    // Smart merge / enrich if already detected
    if (detectedSet.contains(canonical)) {
      final existingIdx = currentTabList.indexWhere((m) => _canonicalUrl(m.url) == canonical);
      if (existingIdx != -1) {
        final old = currentTabList[existingIdx];
        final updated = old.copyWith(
          sizeBytes: old.sizeBytes > 0 ? old.sizeBytes : sizeBytes,
          resolution: (old.resolution != null && old.resolution!.isNotEmpty)
              ? old.resolution
              : (width > 0 && height > 0 ? '${width}x$height' : null),
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
      resolution: width > 0 && height > 0 ? '${width}x$height' : null,
      domIndex: domIndex,
    );

    state = {
      ...state,
      tabId: [item, ...currentTabList],
    };
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
    _tabDetectedUrls[tabId]?.clear();
    state = {
      ...state,
      tabId: [],
    };
  }

  void clearAll() {
    _tabDetectedUrls.clear();
    state = {};
  }

  MediaType _detectMediaType(String url, String? typeStr, String? mime) {
    final clean = url.split('?')[0].toLowerCase();
    if (clean.endsWith('.m3u8') || (mime?.contains('mpegurl') ?? false)) {
      return MediaType.stream;
    }
    if (typeStr == 'video' ||
        clean.endsWith('.mp4') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.mkv') ||
        (mime?.contains('video') ?? false)) {
      return MediaType.video;
    }
    if (typeStr == 'image' ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.avif') ||
        clean.endsWith('.gif') ||
        (mime?.contains('image') ?? false)) {
      return MediaType.image;
    }
    if (typeStr == 'audio' ||
        clean.endsWith('.mp3') ||
        clean.endsWith('.aac') ||
        clean.endsWith('.wav') ||
        clean.endsWith('.m4a') ||
        (mime?.contains('audio') ?? false)) {
      return MediaType.audio;
    }
    return MediaType.other;
  }

  String _extractExtension(String url, MediaType type) {
    final clean = url.split('?')[0];
    final lastDot = clean.lastIndexOf('.');
    if (lastDot != -1 && lastDot > clean.lastIndexOf('/')) {
      return clean.substring(lastDot);
    }
    switch (type) {
      case MediaType.video:
        return '.mp4';
      case MediaType.stream:
        return '.m3u8';
      case MediaType.image:
        return '.jpg';
      case MediaType.audio:
        return '.mp3';
      default:
        return '.dat';
    }
  }

  String _generateFilename(String url, String? title, String ext) {
    if (title != null && title.trim().isNotEmpty) {
      final sanitized = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (sanitized.isNotEmpty) {
        final withExt = sanitized.toLowerCase().endsWith(ext.toLowerCase())
            ? sanitized
            : '$sanitized$ext';
        return withExt.length > 60 ? '${withExt.substring(0, 56)}$ext' : withExt;
      }
    }
    try {
      final uri = Uri.parse(url);
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media';
      if (segment.isNotEmpty) {
        final sanitized = segment.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').split('?').first;
        return sanitized.toLowerCase().endsWith(ext.toLowerCase())
            ? sanitized
            : '$sanitized$ext';
      }
    } catch (_) {}
    return 'media_${DateTime.now().millisecondsSinceEpoch}$ext';
  }
}
