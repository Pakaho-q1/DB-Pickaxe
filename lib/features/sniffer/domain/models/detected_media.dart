import '../../../../core/constants/app_constants.dart';

class DetectedMedia {
  final String id;
  final String tabId;
  final String url;
  final String pageUrl;
  final String filename;
  final MediaType mediaType;
  final String extension;
  final int sizeBytes;
  final String? thumbnailUrl;
  final Map<String, String> headers;
  final DateTime detectedAt;
  final String? resolution;
  final int domIndex;
  final bool isSelected;

  const DetectedMedia({
    required this.id,
    this.tabId = '',
    required this.url,
    required this.pageUrl,
    required this.filename,
    required this.mediaType,
    required this.extension,
    this.sizeBytes = 0,
    this.thumbnailUrl,
    this.headers = const {},
    required this.detectedAt,
    this.resolution,
    this.domIndex = 0,
    this.isSelected = false,
  });

  DetectedMedia copyWith({
    String? id,
    String? tabId,
    String? url,
    String? pageUrl,
    String? filename,
    MediaType? mediaType,
    String? extension,
    int? sizeBytes,
    String? thumbnailUrl,
    Map<String, String>? headers,
    DateTime? detectedAt,
    String? resolution,
    int? domIndex,
    bool? isSelected,
  }) {
    return DetectedMedia(
      id: id ?? this.id,
      tabId: tabId ?? this.tabId,
      url: url ?? this.url,
      pageUrl: pageUrl ?? this.pageUrl,
      filename: filename ?? this.filename,
      mediaType: mediaType ?? this.mediaType,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      headers: headers ?? this.headers,
      detectedAt: detectedAt ?? this.detectedAt,
      resolution: resolution ?? this.resolution,
      domIndex: domIndex ?? this.domIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
