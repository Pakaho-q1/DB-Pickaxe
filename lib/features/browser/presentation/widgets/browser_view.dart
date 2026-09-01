import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/browser_tabs_provider.dart';

class BrowserView extends ConsumerWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(browserTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);

    if (tabs.isEmpty) {
      return Container(
        color: AppTheme.darkBackground,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    final activeTab = tabs.firstWhere(
      (t) => t.id == activeTabId,
      orElse: () => tabs.first,
    );

    final controller = activeTab.controller;
    if (controller == null) {
      return Container(
        color: AppTheme.darkBackground,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    return Container(
      color: AppTheme.darkBackground,
      child: ValueListenableBuilder<WebviewValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          if (!value.isInitialized) {
            return Container(
              color: AppTheme.darkBackground,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Starting browser engine for ${activeTab.displayTitle}...',
                      style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return RepaintBoundary(
            key: ValueKey('wv_${activeTab.id}'),
            child: Stack(
              children: [
                Webview(
                  controller,
                  permissionRequested: (url, permissionKind, isUserInitiated) =>
                      _onPermissionRequested(url, permissionKind, isUserInitiated),
                ),
                if (activeTab.isLoading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      color: AppTheme.accentCyan,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    return WebviewPermissionDecision.allow;
  }
}
