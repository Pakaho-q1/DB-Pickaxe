import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/browser_tabs_provider.dart';

class BrowserTabBar extends ConsumerWidget {
  const BrowserTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(browserTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);

    return Container(
      height: 38,
      color: const Color(0xFF070B12), // Deep header container
      padding: const EdgeInsets.only(left: 6, right: 6, top: 3),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...tabs.map((tab) {
                  final isActive = tab.id == activeTabId;
                  final titleText = tab.displayTitle;

                  return GestureDetector(
                    onTap: () {
                      ref.read(activeTabIdProvider.notifier).state = tab.id;
                    },
                    child: Tooltip(
                      message: tab.url.isNotEmpty ? tab.url : titleText,
                      child: Container(
                        width: 170,
                        margin: const EdgeInsets.only(right: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF22304A) : const Color(0xFF0F172A),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          border: Border(
                            top: BorderSide(
                              color: isActive ? AppTheme.primaryLight : Colors.transparent,
                              width: 3.0,
                            ),
                            left: BorderSide(
                              color: isActive ? AppTheme.darkBorder : const Color(0xFF1E293B).withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                            right: BorderSide(
                              color: isActive ? AppTheme.darkBorder : const Color(0xFF1E293B).withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (tab.isLoading)
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 1.8, color: AppTheme.accentCyan),
                              )
                            else
                              Icon(
                                Icons.language,
                                size: 15,
                                color: isActive ? AppTheme.accentCyan : const Color(0xFF64748B),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                titleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                ref.read(browserTabsProvider.notifier).closeTab(tab.id);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isActive ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // Standard "+" New Tab Button right next to the last tab
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      ref.read(browserTabsProvider.notifier).createTab();
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.6)),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 16, color: AppTheme.darkTextPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
