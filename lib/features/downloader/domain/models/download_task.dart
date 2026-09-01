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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'pageUrl': pageUrl,
      'filename': filename,
      'savedPath': savedPath,
      'mediaType': mediaType.index,
      'status': status.index,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'speedBytesPerSec': speedBytesPerSec,
      'errorMessage': errorMessage,
      'headers': headers,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      pageUrl: map['pageUrl'] as String? ?? '',
      filename: map['filename'] as String,
      savedPath: map['savedPath'] as String,
      mediaType: MediaType.values[map['mediaType'] as int? ?? 0],
      status: DownloadStatus.values[map['status'] as int? ?? 0],
      totalBytes: map['totalBytes'] as int? ?? 0,
      downloadedBytes: map['downloadedBytes'] as int? ?? 0,
      speedBytesPerSec: (map['speedBytesPerSec'] as num?)?.toDouble() ?? 0,
      errorMessage: map['errorMessage'] as String?,
      headers: Map<String, String>.from(map['headers'] as Map? ?? {}),
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
      retryCount: map['retryCount'] as int? ?? 0,
    );
  }
}
