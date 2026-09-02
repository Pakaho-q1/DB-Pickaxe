import '../../../../core/constants/app_constants.dart';
import 'app_shortcuts.dart';

class AppSettings {
  final int maxConcurrentDownloads;
  final String defaultDownloadPath;
  final bool autoCategorizeFolders;
  final double speedLimitKBps; // 0 = Unlimited
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
  final int threadsPerDownload; // 1 - 16 Threads per download
  final bool enableChunkedDownload; // Multi-thread acceleration
  final int minChunkSizeMB; // Minimum file size in MB to activate multi-threading
  final AppStartupBehavior startupBehavior; // New Tab / Last Tab / Restore All / New + Restore
  final AppShortcuts shortcuts; // Configurable Keybindings
  final SnifferHubStyle snifferHubStyle; // Glass Capsule / Mini FAB / Slim Bar
  final SnifferHubPosition snifferHubPosition; // Bottom-Right / Bottom-Left / Bottom-Center / Top-Right / Top-Left / Custom

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
    this.selectedDnsPreset = 'System Default',
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
      selectedDnsPreset: map['selectedDnsPreset'] as String? ?? 'System Default',
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
    );
  }
}
