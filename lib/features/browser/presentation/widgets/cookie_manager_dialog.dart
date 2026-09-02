import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/cookie_manager_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/browser_tab.dart';
import '../providers/browser_tabs_provider.dart';

class CookieManagerDialog extends ConsumerStatefulWidget {
  const CookieManagerDialog({super.key});

  @override
  ConsumerState<CookieManagerDialog> createState() => _CookieManagerDialogState();
}

class _CookieManagerDialogState extends ConsumerState<CookieManagerDialog> {
  late Map<String, String> _cookies;
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _cookieValueController = TextEditingController();
  bool _domainPrefilled = false;

  @override
  void initState() {
    super.initState();
    _loadCookies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill active domain once (guarded by flag to avoid resetting on every
    // dependency change while the field is empty).
    if (!_domainPrefilled) {
      _domainPrefilled = true;
      try {
        final activeTabId = ref.read(activeTabIdProvider);
        final tabs = ref.read(browserTabsProvider);
        final activeTab = tabs.firstWhere((t) => t.id == activeTabId, orElse: () => const BrowserTab(id: ''));
        if (activeTab.url.isNotEmpty) {
          final host = Uri.parse(activeTab.url).host.replaceFirst(RegExp(r'^www\.'), '');
          if (host.isNotEmpty) {
            _domainController.text = host;
          }
        }
      } catch (_) {}
    }
  }

  void _loadCookies() {
    setState(() {
      _cookies = HiveService.getAllSavedCookies();
    });
  }

  @override
  void dispose() {
    _domainController.dispose();
    _cookieValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTabId = ref.watch(activeTabIdProvider);
    final tabs = ref.watch(browserTabsProvider);
    final activeTab = tabs.firstWhere((t) => t.id == activeTabId, orElse: () => const BrowserTab(id: ''));

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 650,
        height: 540,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cookie, color: AppTheme.accentAmber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Cookie Vault & Injector',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            // Add / Inject Cookie Section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inject Custom Cookie (ฝังคุกกี้)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _domainController,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            labelText: 'Domain (e.g. youtube.com)',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _cookieValueController,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            labelText: 'Cookie Value (name=value; ...)',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Inject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final domain = _domainController.text.trim();
                          final cookieStr = _cookieValueController.text.trim();
                          if (domain.isNotEmpty && cookieStr.isNotEmpty) {
                            if (activeTab.controller != null) {
                              await CookieManagerService.injectCookieIntoWebview(
                                controller: activeTab.controller!,
                                domain: domain,
                                cookieString: cookieStr,
                              );
                            } else {
                              await HiveService.saveCookieForDomain(domain, cookieStr);
                            }
                            _cookieValueController.clear();
                            _loadCookies();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Cookie saved and injected for $domain!')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Saved Cookies List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Domain Cookies (${_cookies.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                ),
                if (_cookies.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(Icons.delete_forever, size: 14, color: AppTheme.accentRose),
                    label: const Text('Clear All', style: TextStyle(fontSize: 11, color: AppTheme.accentRose)),
                    onPressed: () async {
                      await HiveService.clearAllCookies();
                      _loadCookies();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _cookies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cookie_outlined, size: 36, color: AppTheme.darkBorder),
                          const SizedBox(height: 8),
                          const Text(
                            'No cookies saved yet',
                            style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Cookies from logged-in websites and injected cookies appear here.',
                            style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cookies.length,
                      itemBuilder: (context, index) {
                        final domain = _cookies.keys.elementAt(index);
                        final cookieVal = _cookies[domain]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.domain, size: 16, color: AppTheme.accentCyan),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      domain,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cookieVal,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 14),
                                tooltip: 'Copy Cookie',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: cookieVal));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Cookie for $domain copied!')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 15, color: AppTheme.accentRose),
                                tooltip: 'Delete',
                                onPressed: () async {
                                  await HiveService.deleteCookieForDomain(domain);
                                  _loadCookies();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
