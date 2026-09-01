enum MediaType {
  video,
  image,
  audio,
  stream,
  document,
  other,
}

enum ImageTargetFormat {
  original,
  jpg,
  png,
  webp,
}

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  converting,
  cancelled,
}

class AppConstants {
  static const String appName = 'DB-Pickaxe';
  static const String appVersion = '1.0.0';
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
  static const String defaultHomePage = 'https://www.google.com';
}

class DnsPreset {
  final String name;
  final String description;
  final String primaryDns;
  final String secondaryDns;
  final String dohUrl;

  const DnsPreset({
    required this.name,
    required this.description,
    required this.primaryDns,
    required this.secondaryDns,
    required this.dohUrl,
  });

  static const List<DnsPreset> presets = [
    DnsPreset(
      name: 'System Default',
      description: 'Use OS default DNS settings',
      primaryDns: '',
      secondaryDns: '',
      dohUrl: '',
    ),
    DnsPreset(
      name: 'Cloudflare (1.1.1.1)',
      description: 'Fastest privacy-first DNS',
      primaryDns: '1.1.1.1',
      secondaryDns: '1.0.0.1',
      dohUrl: 'https://cloudflare-dns.com/dns-query',
    ),
    DnsPreset(
      name: 'Google Public DNS',
      description: 'Reliable and globally distributed',
      primaryDns: '8.8.8.8',
      secondaryDns: '8.8.4.4',
      dohUrl: 'https://dns.google/dns-query',
    ),
    DnsPreset(
      name: 'AdGuard DNS',
      description: 'Blocks ads and tracking domains',
      primaryDns: '94.140.14.14',
      secondaryDns: '94.140.15.15',
      dohUrl: 'https://dns.adguard-dns.com/dns-query',
    ),
    DnsPreset(
      name: 'Quad9',
      description: 'Enhanced malware and phishing protection',
      primaryDns: '9.9.9.9',
      secondaryDns: '149.112.112.112',
      dohUrl: 'https://dns.quad9.net/dns-query',
    ),
    DnsPreset(
      name: 'Custom DNS / DoH',
      description: 'Enter your custom DNS or DoH server URL',
      primaryDns: '',
      secondaryDns: '',
      dohUrl: '',
    ),
  ];
}
