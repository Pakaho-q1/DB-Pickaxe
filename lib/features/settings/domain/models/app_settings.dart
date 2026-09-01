import '../../../../core/constants/app_constants.dart';

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
      'targetImageFormat': targetImageFormat.index,
      'proxyHost': proxyHost,
      'proxyPort': proxyPort,
      'proxyUsername': proxyUsername,
      'proxyPassword': proxyPassword,
      'proxyEnabled': proxyEnabled,
      'selectedDnsPreset': selectedDnsPreset,
      'customDohUrl': customDohUrl,
      'minImageSizeKB': minImageSizeKB,
      'filterTinyIcons': filterTinyIcons,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      maxConcurrentDownloads: map['maxConcurrentDownloads'] as int? ?? 3,
      defaultDownloadPath: map['defaultDownloadPath'] as String? ?? '',
      autoCategorizeFolders: map['autoCategorizeFolders'] as bool? ?? true,
      speedLimitKBps: (map['speedLimitKBps'] as num?)?.toDouble() ?? 0,
      connectionTimeoutSeconds: map['connectionTimeoutSeconds'] as int? ?? 30,
      maxRetries: map['maxRetries'] as int? ?? 3,
      retryDelaySeconds: map['retryDelaySeconds'] as int? ?? 5,
      interTaskDelayMs: map['interTaskDelayMs'] as int? ?? 500,
      targetImageFormat: ImageTargetFormat.values[map['targetImageFormat'] as int? ?? 0],
      proxyHost: map['proxyHost'] as String? ?? '',
      proxyPort: map['proxyPort'] as int? ?? 8080,
      proxyUsername: map['proxyUsername'] as String? ?? '',
      proxyPassword: map['proxyPassword'] as String? ?? '',
      proxyEnabled: map['proxyEnabled'] as bool? ?? false,
      selectedDnsPreset: map['selectedDnsPreset'] as String? ?? 'System Default',
      customDohUrl: map['customDohUrl'] as String? ?? '',
      minImageSizeKB: map['minImageSizeKB'] as int? ?? 20,
      filterTinyIcons: map['filterTinyIcons'] as bool? ?? true,
    );
  }
}
