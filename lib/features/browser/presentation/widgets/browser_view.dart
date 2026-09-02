import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sniffer/presentation/widgets/floating_sniffer_hub.dart';
import '../providers/browser_tabs_provider.dart';

class BrowserView extends ConsumerWidget {
  final VoidCallback? onToggleDeck;

  const BrowserView({super.key, this.onToggleDeck});

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
                      _onPermissionRequested(context, url, permissionKind, isUserInitiated),
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
                // Modern Floating Sniffer Hub
                FloatingSnifferHub(onToggleDeck: onToggleDeck),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shows a dialog asking the user to allow or deny a WebView2 permission request.
  Future<WebviewPermissionDecision> _onPermissionRequested(
    BuildContext context,
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    // Only prompt for user-initiated permission requests (e.g. getUserMedia).
    // Silent background requests (e.g. from ads) are denied automatically.
    if (!isUserInitiated) return WebviewPermissionDecision.deny;

    final kindLabel = switch (kind) {
      WebviewPermissionKind.microphone => 'Microphone',
      WebviewPermissionKind.camera => 'Camera',
      WebviewPermissionKind.geoLocation => 'Location',
      WebviewPermissionKind.notifications => 'Notifications',
      _ => kind.name,
    };

    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.security, color: AppTheme.accentAmber, size: 20),
            const SizedBox(width: 8),
            Text('Permission Request', style: const TextStyle(fontSize: 15, color: AppTheme.darkTextPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A page is requesting access to your $kindLabel.',
              style: const TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Deny', style: TextStyle(color: AppTheme.accentRose)),
            onPressed: () => Navigator.of(ctx).pop(WebviewPermissionDecision.deny),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Allow', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(WebviewPermissionDecision.allow),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.deny;
  }
}
