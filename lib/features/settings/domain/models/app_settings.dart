import '../../../../core/constants/app_constants.dart';
import 'app_shortcuts.dart';

class AppSettings {
  final int maxConcurrentDownloads;
  final String defaultDownloadPath;
  final bool autoCategorizeFolders;
  final double speedLimitKBps;
  final int connectionTimeoutSeconds;
  final int maxRetries;
  final int retryDelaySeconds;
  final int interTaskDelayMs;
  final ImageTargetFormat targetImageFormat;
  final String proxyHost;
  final int proxyPort;
  final String proxyUsername;
  final String proxyPassword;
  final bool proxyEnabled;
  final String selectedDnsPreset;
  final String customDohUrl;
  final int minImageSizeKB;
  final bool filterTinyIcons;
  final int threadsPerDownload;
  final bool enableChunkedDownload;
  final int minChunkSizeMB;
  final AppStartupBehavior startupBehavior;
  final AppShortcuts shortcuts;
  final SnifferHubStyle snifferHubStyle;
  final SnifferHubPosition snifferHubPosition;
  final bool enableAutoScroll;
  final bool enableAutoVideoTrigger;
  final String filenameTemplate; // e.g. {title} - {filename}
  final bool autoCreateSubfolders; // Auto create subfolder by website/album
  final bool enableAdBlocker; // Block popup / popunder ads
  final bool enableHlsMultiThread; // Download HLS/m3u8 with multi-threaded segment pooling
  final bool autoMergeAudioVideo; // Auto merge separate DASH video + audio streams
  final bool autoGrabSubtitles; // Auto-grab subtitles (.vtt / .srt)
  final bool embedMetadataAndCoverArt; // Embed cover art and metadata tags

  const AppSettings({
    this.maxConcurrentDownloads = 3,
    this.defaultDownloadPath = '',
    this.autoCategorizeFolders = true,
    this.speedLimitKBps = 0,
    this.connectionTimeoutSeconds = 30,
    this.maxRetries = 3,
    this.retryDelaySeconds = 5,
    this.interTaskDelayMs = 500,
    this.targetImageFormat = ImageTargetFormat.original,
    this.proxyHost = '',
    this.proxyPort = 8080,
    this.proxyUsername = '',
    this.proxyPassword = '',
    this.proxyEnabled = false,
    this.selectedDnsPreset = 'Cloudflare (1.1.1.1)',
    this.customDohUrl = '',
    this.minImageSizeKB = 20,
    this.filterTinyIcons = true,
    this.threadsPerDownload = 4,
    this.enableChunkedDownload = true,
    this.minChunkSizeMB = 2,
    this.startupBehavior = AppStartupBehavior.restoreAll,
    this.shortcuts = const AppShortcuts(),
    this.snifferHubStyle = SnifferHubStyle.glassCapsule,
    this.snifferHubPosition = SnifferHubPosition.bottomRight,
    this.enableAutoScroll = false,
    this.enableAutoVideoTrigger = false,
    this.filenameTemplate = '{title} - {filename}',
    this.autoCreateSubfolders = true,
    this.enableAdBlocker = true,
    this.enableHlsMultiThread = true,
    this.autoMergeAudioVideo = true,
    this.autoGrabSubtitles = true,
    this.embedMetadataAndCoverArt = true,
  });

  AppSettings copyWith({
    int? maxConcurrentDownloads,
    String? defaultDownloadPath,
    bool? autoCategorizeFolders,
    double? speedLimitKBps,
    int? connectionTimeoutSeconds,
    int? maxRetries,
    int? retryDelaySeconds,
    int? interTaskDelayMs,
    ImageTargetFormat? targetImageFormat,
    String? proxyHost,
    int? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
    bool? proxyEnabled,
    String? selectedDnsPreset,
    String? customDohUrl,
    int? minImageSizeKB,
    bool? filterTinyIcons,
    int? threadsPerDownload,
    bool? enableChunkedDownload,
    int? minChunkSizeMB,
    AppStartupBehavior? startupBehavior,
    AppShortcuts? shortcuts,
    SnifferHubStyle? snifferHubStyle,
    SnifferHubPosition? snifferHubPosition,
    bool? enableAutoScroll,
    bool? enableAutoVideoTrigger,
    String? filenameTemplate,
    bool? autoCreateSubfolders,
    bool? enableAdBlocker,
    bool? enableHlsMultiThread,
    bool? autoMergeAudioVideo,
    bool? autoGrabSubtitles,
    bool? embedMetadataAndCoverArt,
  }) {
    return AppSettings(
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      defaultDownloadPath: defaultDownloadPath ?? this.defaultDownloadPath,
      autoCategorizeFolders: autoCategorizeFolders ?? this.autoCategorizeFolders,
      speedLimitKBps: speedLimitKBps ?? this.speedLimitKBps,
      connectionTimeoutSeconds: connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelaySeconds: retryDelaySeconds ?? this.retryDelaySeconds,
      interTaskDelayMs: interTaskDelayMs ?? this.interTaskDelayMs,
      targetImageFormat: targetImageFormat ?? this.targetImageFormat,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      proxyUsername: proxyUsername ?? this.proxyUsername,
      proxyPassword: proxyPassword ?? this.proxyPassword,
      proxyEnabled: proxyEnabled ?? this.proxyEnabled,
      selectedDnsPreset: selectedDnsPreset ?? this.selectedDnsPreset,
      customDohUrl: customDohUrl ?? this.customDohUrl,
      minImageSizeKB: minImageSizeKB ?? this.minImageSizeKB,
      filterTinyIcons: filterTinyIcons ?? this.filterTinyIcons,
      threadsPerDownload: threadsPerDownload ?? this.threadsPerDownload,
      enableChunkedDownload: enableChunkedDownload ?? this.enableChunkedDownload,
      minChunkSizeMB: minChunkSizeMB ?? this.minChunkSizeMB,
      startupBehavior: startupBehavior ?? this.startupBehavior,
      shortcuts: shortcuts ?? this.shortcuts,
      snifferHubStyle: snifferHubStyle ?? this.snifferHubStyle,
      snifferHubPosition: snifferHubPosition ?? this.snifferHubPosition,
      enableAutoScroll: enableAutoScroll ?? this.enableAutoScroll,
      enableAutoVideoTrigger: enableAutoVideoTrigger ?? this.enableAutoVideoTrigger,
      filenameTemplate: filenameTemplate ?? this.filenameTemplate,
      autoCreateSubfolders: autoCreateSubfolders ?? this.autoCreateSubfolders,
      enableAdBlocker: enableAdBlocker ?? this.enableAdBlocker,
      enableHlsMultiThread: enableHlsMultiThread ?? this.enableHlsMultiThread,
      autoMergeAudioVideo: autoMergeAudioVideo ?? this.autoMergeAudioVideo,
      autoGrabSubtitles: autoGrabSubtitles ?? this.autoGrabSubtitles,
      embedMetadataAndCoverArt: embedMetadataAndCoverArt ?? this.embedMetadataAndCoverArt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maxConcurrentDownloads': maxConcurrentDownloads,
      'defaultDownloadPath': defaultDownloadPath,
      'autoCategorizeFolders': autoCategorizeFolders,
      'speedLimitKBps': speedLimitKBps,
      'connectionTimeoutSeconds': connectionTimeoutSeconds,
      'maxRetries': maxRetries,
      'retryDelaySeconds': retryDelaySeconds,
      'interTaskDelayMs': interTaskDelayMs,
      'targetImageFormat': targetImageFormat.name,
      'proxyHost': proxyHost,
      'proxyPort': proxyPort,
      'proxyUsername': proxyUsername,
      'proxyPassword': proxyPassword,
      'proxyEnabled': proxyEnabled,
      'selectedDnsPreset': selectedDnsPreset,
      'customDohUrl': customDohUrl,
      'minImageSizeKB': minImageSizeKB,
      'filterTinyIcons': filterTinyIcons,
      'threadsPerDownload': threadsPerDownload,
      'enableChunkedDownload': enableChunkedDownload,
      'minChunkSizeMB': minChunkSizeMB,
      'startupBehavior': startupBehavior.name,
      'shortcuts': shortcuts.toMap(),
      'snifferHubStyle': snifferHubStyle.name,
      'snifferHubPosition': snifferHubPosition.name,
      'enableAutoScroll': enableAutoScroll,
      'enableAutoVideoTrigger': enableAutoVideoTrigger,
      'filenameTemplate': filenameTemplate,
      'autoCreateSubfolders': autoCreateSubfolders,
      'enableAdBlocker': enableAdBlocker,
      'enableHlsMultiThread': enableHlsMultiThread,
      'autoMergeAudioVideo': autoMergeAudioVideo,
      'autoGrabSubtitles': autoGrabSubtitles,
      'embedMetadataAndCoverArt': embedMetadataAndCoverArt,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    final rawFormat = map['targetImageFormat'];
    final targetImageFormat = rawFormat is int
        ? ImageTargetFormat.values[rawFormat.clamp(0, ImageTargetFormat.values.length - 1)]
        : ImageTargetFormat.values.firstWhere(
            (e) => e.name == rawFormat,
            orElse: () => ImageTargetFormat.original,
          );

    final rawStartup = map['startupBehavior'] as String?;
    final startupBehavior = AppStartupBehavior.values.firstWhere(
      (e) => e.name == rawStartup,
      orElse: () => AppStartupBehavior.restoreAll,
    );

    final rawShortcuts = map['shortcuts'] as Map?;
    final shortcuts = AppShortcuts.fromMap(rawShortcuts != null ? Map<dynamic, dynamic>.from(rawShortcuts) : null);

    final rawHubStyle = map['snifferHubStyle'] as String?;
    final snifferHubStyle = SnifferHubStyle.values.firstWhere(
      (e) => e.name == rawHubStyle,
      orElse: () => SnifferHubStyle.glassCapsule,
    );

    final rawHubPos = map['snifferHubPosition'] as String?;
    final snifferHubPosition = SnifferHubPosition.values.firstWhere(
      (e) => e.name == rawHubPos,
      orElse: () => SnifferHubPosition.bottomRight,
    );

    return AppSettings(
      maxConcurrentDownloads: map['maxConcurrentDownloads'] as int? ?? 3,
      defaultDownloadPath: map['defaultDownloadPath'] as String? ?? '',
      autoCategorizeFolders: map['autoCategorizeFolders'] as bool? ?? true,
      speedLimitKBps: (map['speedLimitKBps'] as num?)?.toDouble() ?? 0,
      connectionTimeoutSeconds: map['connectionTimeoutSeconds'] as int? ?? 30,
      maxRetries: map['maxRetries'] as int? ?? 3,
      retryDelaySeconds: map['retryDelaySeconds'] as int? ?? 5,
      interTaskDelayMs: map['interTaskDelayMs'] as int? ?? 500,
      targetImageFormat: targetImageFormat,
      proxyHost: map['proxyHost'] as String? ?? '',
      proxyPort: map['proxyPort'] as int? ?? 8080,
      proxyUsername: map['proxyUsername'] as String? ?? '',
      proxyPassword: map['proxyPassword'] as String? ?? '',
      proxyEnabled: map['proxyEnabled'] as bool? ?? false,
      selectedDnsPreset: map['selectedDnsPreset'] as String? ?? 'Cloudflare (1.1.1.1)',
      customDohUrl: map['customDohUrl'] as String? ?? '',
      minImageSizeKB: map['minImageSizeKB'] as int? ?? 20,
      filterTinyIcons: map['filterTinyIcons'] as bool? ?? true,
      threadsPerDownload: (map['threadsPerDownload'] as int? ?? 4).clamp(1, 16),
      enableChunkedDownload: map['enableChunkedDownload'] as bool? ?? true,
      minChunkSizeMB: map['minChunkSizeMB'] as int? ?? 2,
      startupBehavior: startupBehavior,
      shortcuts: shortcuts,
      snifferHubStyle: snifferHubStyle,
      snifferHubPosition: snifferHubPosition,
      enableAutoScroll: map['enableAutoScroll'] as bool? ?? false,
      enableAutoVideoTrigger: map['enableAutoVideoTrigger'] as bool? ?? false,
      filenameTemplate: map['filenameTemplate'] as String? ?? '{title} - {filename}',
      autoCreateSubfolders: map['autoCreateSubfolders'] as bool? ?? true,
      enableAdBlocker: map['enableAdBlocker'] as bool? ?? true,
      enableHlsMultiThread: map['enableHlsMultiThread'] as bool? ?? true,
      autoMergeAudioVideo: map['autoMergeAudioVideo'] as bool? ?? true,
      autoGrabSubtitles: map['autoGrabSubtitles'] as bool? ?? true,
      embedMetadataAndCoverArt: map['embedMetadataAndCoverArt'] as bool? ?? true,
    );
  }
}
