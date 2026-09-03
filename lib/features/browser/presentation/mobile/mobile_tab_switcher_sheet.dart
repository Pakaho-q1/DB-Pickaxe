import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/browser_tabs_provider.dart';

class MobileTabSwitcherSheet extends ConsumerWidget {
  const MobileTabSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(browserTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          // Top Action Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tab_rounded, size: 20, color: AppTheme.accentCyan),
                    const SizedBox(width: 8),
                    Text(
                      'Open Tabs (${tabs.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16, color: AppTheme.accentCyan),
                      label: const Text('New Tab', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(browserTabsProvider.notifier).createTab();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppTheme.darkTextSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          // Swipeable Tab Cards List
          Expanded(
            child: tabs.isEmpty
                ? const Center(
                    child: Text('No open tabs', style: TextStyle(color: AppTheme.darkTextSecondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isActive = tab.id == activeTabId;
                      final uri = Uri.tryParse(tab.url);
                      final host = uri?.host.isNotEmpty == true ? uri!.host : 'Home';

                      return Dismissible(
                        key: ValueKey(tab.id),
                        direction: DismissDirection.horizontal,
                        dismissThresholds: const {
                          DismissDirection.startToEnd: 0.45,
                          DismissDirection.endToStart: 0.45,
                        },
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text('Close Tab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Close Tab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(width: 8),
                              Icon(Icons.delete_outline, color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          ref.read(browserTabsProvider.notifier).closeTab(tab.id);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? AppTheme.accentCyan : AppTheme.darkBorder,
                              width: isActive ? 1.8 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: isActive ? AppTheme.accentCyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                              child: Icon(
                                Icons.language_rounded,
                                color: isActive ? AppTheme.accentCyan : AppTheme.darkTextSecondary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              tab.title.isEmpty ? 'New Tab' : tab.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                color: isActive ? AppTheme.accentCyan : AppTheme.darkTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppTheme.darkTextSecondary),
                              onPressed: () => ref.read(browserTabsProvider.notifier).closeTab(tab.id),
                            ),
                            onTap: () {
                              ref.read(activeTabIdProvider.notifier).state = tab.id;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
