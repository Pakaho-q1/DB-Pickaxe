class AdBlockerService {
  static const List<String> _blockedDomains = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adsterra.com',
    'popads.net',
    'popcash.net',
    'exoclick.com',
    'propellerads.com',
    'juicyads.com',
    'trafficjunky.com',
    'zergnet.com',
    'adblade.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'revcontent.com',
    'adnxs.com',
    'bidswitch.net',
    'criteo.com',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'smartadserver.com',
    'clickadu.com',
    'hilltopads.com',
    'richpush.co',
    'evadav.com',
    'rollerads.com',
    'yandex.ru/ads',
  ];

  static const List<String> _blockedUrlPatterns = [
    r'/(banners?|ads?|popunder|popup|advert|affiliate|trackers?|sponsor|clicktag|adsystem|analytics)/',
    r'[?&](utm_source|aff_id|click_id|ref_id)=',
    r'/ad[s]?[-_](banner|box|iframe|script|zone|view|click)',
  ];

  static final List<RegExp> _compiledPatterns = _blockedUrlPatterns
      .map((p) => RegExp(p, caseSensitive: false))
      .toList();

  /// Returns `true` if the URL is classified as an advertisement or tracker.
  static bool isAdUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    // 1. Check blocked domain blacklist
    for (final domain in _blockedDomains) {
      if (lower.contains(domain)) return true;
    }

    // 2. Check regex URL patterns
    for (final pattern in _compiledPatterns) {
      if (pattern.hasMatch(lower)) return true;
    }

    return false;
  }
}
