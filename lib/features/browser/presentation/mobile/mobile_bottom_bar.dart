import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/browser_tab.dart';
import '../providers/browser_tabs_provider.dart';

class MobileBottomBar extends ConsumerWidget {
  final VoidCallback onOpenTabs;
  final VoidCallback onOpenSettings;
  final VoidCallback? onGoBack;
  final VoidCallback? onGoForward;
  final VoidCallback? onGoHome;

  const MobileBottomBar({
    super.key,
    required this.onOpenTabs,
    required this.onOpenSettings,
    this.onGoBack,
    this.onGoForward,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(browserTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);
    final activeTab = tabs.firstWhere((t) => t.id == activeTabId, orElse: () => const BrowserTab(id: ''));

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          top: BorderSide(color: AppTheme.darkBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Back
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: (onGoBack != null || activeTab.canGoBack) ? AppTheme.darkTextPrimary : AppTheme.darkTextSecondary.withValues(alpha: 0.3),
            ),
            tooltip: 'Back',
            onPressed: () {
              if (onGoBack != null) {
                onGoBack!();
              } else if (activeTab.canGoBack && activeTab.id.isNotEmpty) {
                ref.read(browserTabsProvider.notifier).goBack(activeTab.id);
              }
            },
          ),
          // 2. Forward
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: (onGoForward != null || activeTab.canGoForward) ? AppTheme.darkTextPrimary : AppTheme.darkTextSecondary.withValues(alpha: 0.3),
            ),
            tooltip: 'Forward',
            onPressed: () {
              if (onGoForward != null) {
                onGoForward!();
              } else if (activeTab.canGoForward && activeTab.id.isNotEmpty) {
                ref.read(browserTabsProvider.notifier).goForward(activeTab.id);
              }
            },
          ),
          // 3. Home
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 22, color: AppTheme.darkTextPrimary),
            tooltip: 'Home',
            onPressed: () {
              if (onGoHome != null) {
                onGoHome!();
              } else if (activeTab.id.isNotEmpty) {
                ref.read(browserTabsProvider.notifier).navigateTo(activeTab.id, AppConstants.defaultHomePage);
              }
            },
          ),
          // 4. Tab Switcher
          InkWell(
            key: const Key('mobile_tab_switcher_btn'),
            onTap: onOpenTabs,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentCyan, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${tabs.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
            ),
          ),
          // 5. Menu Hub (Settings, Downloads, Bookmarks, History, Cache)
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22, color: AppTheme.darkTextPrimary),
            tooltip: 'Menu',
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}
