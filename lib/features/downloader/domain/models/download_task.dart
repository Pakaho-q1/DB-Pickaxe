import '../../../../core/constants/app_constants.dart';

class DownloadTask {
  final String id;
  final String url;
  final String pageUrl;
  final String filename;
  final String savedPath;
  final MediaType mediaType;
  final DownloadStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final double speedBytesPerSec;
  final String? errorMessage;
  final Map<String, String> headers;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int retryCount;
  final bool isResumable;
  final int chunkCount;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.pageUrl,
    required this.filename,
    required this.savedPath,
    required this.mediaType,
    this.status = DownloadStatus.pending,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0,
    this.errorMessage,
    this.headers = const {},
    required this.createdAt,
    this.completedAt,
    this.retryCount = 0,
    this.isResumable = false,
    this.chunkCount = 1,
  });

  double get progress {
    if (totalBytes <= 0) return 0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  DownloadTask copyWith({
    String? id,
    String? url,
    String? pageUrl,
    String? filename,
    String? savedPath,
    MediaType? mediaType,
    DownloadStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    double? speedBytesPerSec,
    String? errorMessage,
    Map<String, String>? headers,
    DateTime? createdAt,
    DateTime? completedAt,
    int? retryCount,
    bool? isResumable,
    int? chunkCount,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      pageUrl: pageUrl ?? this.pageUrl,
      filename: filename ?? this.filename,
      savedPath: savedPath ?? this.savedPath,
      mediaType: mediaType ?? this.mediaType,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      errorMessage: errorMessage ?? this.errorMessage,
      headers: headers ?? this.headers,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      retryCount: retryCount ?? this.retryCount,
      isResumable: isResumable ?? this.isResumable,
      chunkCount: chunkCount ?? this.chunkCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'pageUrl': pageUrl,
      'filename': filename,
      'savedPath': savedPath,
      // Store enum name (string) instead of index (int) to be resilient against
      // future enum reordering that would otherwise corrupt stored data.
      'mediaType': mediaType.name,
      'status': status.name,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'speedBytesPerSec': speedBytesPerSec,
      'errorMessage': errorMessage,
      'headers': headers,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'retryCount': retryCount,
      'isResumable': isResumable,
      'chunkCount': chunkCount,
    };
  }

  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) {
    // Support both legacy int-index format and new string-name format for backward compatibility.
    final rawMediaType = map['mediaType'];
    final mediaType = rawMediaType is int
        ? MediaType.values[rawMediaType.clamp(0, MediaType.values.length - 1)]
        : MediaType.values.firstWhere(
            (e) => e.name == rawMediaType,
            orElse: () => MediaType.other,
          );

    final rawStatus = map['status'];
    final status = rawStatus is int
        ? DownloadStatus.values[rawStatus.clamp(0, DownloadStatus.values.length - 1)]
        : DownloadStatus.values.firstWhere(
            (e) => e.name == rawStatus,
            orElse: () => DownloadStatus.pending,
          );

    return DownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      pageUrl: map['pageUrl'] as String? ?? '',
      filename: map['filename'] as String,
      savedPath: map['savedPath'] as String,
      mediaType: mediaType,
      status: status,
      totalBytes: map['totalBytes'] as int? ?? 0,
      downloadedBytes: map['downloadedBytes'] as int? ?? 0,
      speedBytesPerSec: (map['speedBytesPerSec'] as num?)?.toDouble() ?? 0,
      errorMessage: map['errorMessage'] as String?,
      headers: Map<String, String>.from(map['headers'] as Map? ?? {}),
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
      retryCount: map['retryCount'] as int? ?? 0,
      isResumable: map['isResumable'] as bool? ?? false,
      chunkCount: map['chunkCount'] as int? ?? 1,
    );
  }
}
