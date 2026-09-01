import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/detected_media.dart';
import '../../domain/models/media_filter.dart';

final snifferFilterProvider = StateProvider<MediaFilter>((ref) => const MediaFilter());

final snifferProvider = StateNotifierProvider<SnifferNotifier, List<DetectedMedia>>((ref) {
  return SnifferNotifier();
});

final filteredMediaProvider = Provider<List<DetectedMedia>>((ref) {
  final items = ref.watch(snifferProvider);
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

class SnifferNotifier extends StateNotifier<List<DetectedMedia>> {
  SnifferNotifier() : super([]);

  final Set<String> _detectedUrls = {};

  void addMedia({
    required String url,
    required String pageUrl,
    String? title,
    String? typeStr,
    int width = 0,
    int height = 0,
    String? mime,
    String? thumbnailUrl,
    int domIndex = 0,
    Map<String, String>? headers,
  }) {
    if (url.isEmpty || _detectedUrls.contains(url)) return;
    _detectedUrls.add(url);

    final mediaType = _detectMediaType(url, typeStr, mime);
    final ext = _extractExtension(url, mediaType);
    final filename = _generateFilename(url, title, ext);

    final item = DetectedMedia(
      id: const Uuid().v4(),
      url: url,
      pageUrl: pageUrl,
      filename: filename,
      mediaType: mediaType,
      extension: ext,
      thumbnailUrl: thumbnailUrl ?? (mediaType == MediaType.image ? url : null),
      headers: headers ?? {},
      detectedAt: DateTime.now(),
      resolution: width > 0 && height > 0 ? '${width}x$height' : null,
      domIndex: domIndex,
    );

    state = [item, ...state];
  }

  void toggleSelect(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isSelected: !item.isSelected);
      }
      return item;
    }).toList();
  }

  void selectVisible(List<String> visibleIds, bool select) {
    final visibleSet = visibleIds.toSet();
    state = state.map((item) {
      if (visibleSet.contains(item.id)) {
        return item.copyWith(isSelected: select);
      }
      return item;
    }).toList();
  }

  void selectAll(bool select) {
    state = state.map((item) => item.copyWith(isSelected: select)).toList();
  }

  void clearAll() {
    _detectedUrls.clear();
    state = [];
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
        return sanitized.length > 50 ? '${sanitized.substring(0, 50)}$ext' : '$sanitized$ext';
      }
    }
    try {
      final uri = Uri.parse(url);
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media';
      if (segment.isNotEmpty) {
        final sanitized = segment.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        return sanitized.contains('.') ? sanitized : '$sanitized$ext';
      }
    } catch (_) {}
    return 'media_${DateTime.now().millisecondsSinceEpoch}$ext';
  }
}
