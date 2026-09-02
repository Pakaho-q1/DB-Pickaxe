import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/storage/hive_service.dart';
import 'core/theme/app_theme.dart';
import 'features/browser/presentation/providers/browser_tabs_provider.dart';
import 'features/browser/presentation/widgets/browser_navigation_bar.dart';
import 'features/browser/presentation/widgets/browser_tab_bar.dart';
import 'features/browser/presentation/widgets/browser_view.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/sniffer/presentation/widgets/media_deck_panel.dart';
import 'platform/windows/windows_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Local Database
  await HiveService.init();

  // 2. Initialize Desktop Window
  await WindowsInitializer.init();

  runApp(const ProviderScope(child: DBPickaxeApp()));
}

class DBPickaxeApp extends StatelessWidget {
  const DBPickaxeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainWorkstationScreen(),
    );
  }
}

class MainWorkstationScreen extends ConsumerStatefulWidget {
  const MainWorkstationScreen({super.key});

  @override
  ConsumerState<MainWorkstationScreen> createState() =>
      _MainWorkstationScreenState();
}

/// Uses [WindowListener] to intercept the OS close event and gracefully dispose
/// all WebView2 controllers **before** the window is destroyed.
class _MainWorkstationScreenState extends ConsumerState<MainWorkstationScreen>
    with WindowListener {
  bool _isDeckExpanded = true;
  double _sideDeckWidth = 380.0;
  bool _isClosing = false;
  final FocusNode _keyboardFocusNode = FocusNode();

  /// Guard: reject close events that arrive before the app is fully started.
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isReady = true;
      WindowsInitializer.showWebView2ErrorIfNeeded(context);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (!_isReady || _isClosing) return;
    _isClosing = true;

    final tabs = ref.read(browserTabsProvider);
    for (final tab in tabs) {
      try {
        await tab.controller?.dispose();
      } catch (_) {}
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await windowManager.destroy();
    exit(0);
  }

  bool _matchesShortcut(KeyEvent event, String shortcutString) {
    if (event is! KeyDownEvent) return false;
    final parts = shortcutString.toUpperCase().split('+').map((s) => s.trim()).toList();

    final needsCtrl = parts.contains('CTRL') || parts.contains('CONTROL');
    final needsShift = parts.contains('SHIFT');
    final needsAlt = parts.contains('ALT');

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    if (needsCtrl != isCtrl) return false;
    if (needsShift != isShift) return false;
    if (needsAlt != isAlt) return false;

    final keyPart = parts.lastWhere((p) => p != 'CTRL' && p != 'CONTROL' && p != 'SHIFT' && p != 'ALT', orElse: () => '');
    if (keyPart.isEmpty) return false;

    final pressedKey = event.logicalKey.keyLabel.toUpperCase();
    if (pressedKey == keyPart) return true;

    if (keyPart == 'F5' && event.logicalKey == LogicalKeyboardKey.f5) return true;
    if (keyPart == 'F12' && event.logicalKey == LogicalKeyboardKey.f12) return true;
    if (keyPart == 'ESCAPE' && event.logicalKey == LogicalKeyboardKey.escape) return true;
    if (keyPart == 'ENTER' && event.logicalKey == LogicalKeyboardKey.enter) return true;

    return false;
  }

  void _handleKeyEvent(KeyEvent event) {
    final shortcuts = ref.read(settingsProvider).shortcuts;
    final activeId = ref.read(activeTabIdProvider);

    // 1. Close current tab
    if (_matchesShortcut(event, shortcuts.closeTab)) {
      if (activeId.isNotEmpty) {
        ref.read(browserTabsProvider.notifier).closeTab(activeId);
      }
      return;
    }

    // 2. New Tab
    if (_matchesShortcut(event, shortcuts.newTab)) {
      ref.read(browserTabsProvider.notifier).createTab();
      return;
    }

    // 3. Close other tabs
    if (_matchesShortcut(event, shortcuts.closeOtherTabs)) {
      if (activeId.isNotEmpty) {
        ref.read(browserTabsProvider.notifier).closeOtherTabs(activeId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Closed other tabs'), duration: Duration(seconds: 1)),
        );
      }
      return;
    }

    // 4. Detect / Re-detect media
    if (_matchesShortcut(event, shortcuts.detectMedia)) {
      ref.read(browserTabsProvider.notifier).rescanActiveTab();
      final isAuto = ref.read(isAutoDetectEnabledProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAuto ? 'Deep re-detecting media on active page...' : 'Detecting media on active page...'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // 5. Toggle Media Deck
    if (_matchesShortcut(event, shortcuts.toggleMediaDeck)) {
      setState(() {
        _isDeckExpanded = !_isDeckExpanded;
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    const double minAllowedWidth = 360.0;
    final maxAllowedWidth = (screenWidth * 0.50).clamp(minAllowedWidth, 1200.0);
    final clampedWidth = _sideDeckWidth.clamp(minAllowedWidth, maxAllowedWidth);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const BrowserTabBar(),
              const BrowserNavigationBar(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BrowserView(
                        onToggleDeck: () {
                          setState(() {
                            _isDeckExpanded = !_isDeckExpanded;
                          });
                        },
                      ),
                    ),
                    if (_isDeckExpanded)
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _sideDeckWidth -= details.delta.dx;
                              _sideDeckWidth = _sideDeckWidth.clamp(
                                minAllowedWidth,
                                maxAllowedWidth,
                              );
                            });
                          },
                          child: Container(
                            width: 8,
                            color: AppTheme.darkSurface,
                            child: Center(
                              child: Container(
                                width: 3,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBorder,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Collapse / Expand Toggle Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDeckExpanded = !_isDeckExpanded;
                        });
                      },
                      child: Container(
                        width: 14,
                        color: AppTheme.darkSurface,
                        child: Center(
                          child: Icon(
                            _isDeckExpanded
                                ? Icons.chevron_right
                                : Icons.chevron_left,
                            size: 13,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    // Resizable Media Deck Sidebar (Max 50% screen width)
                    if (_isDeckExpanded)
                      SizedBox(
                        width: clampedWidth,
                        child: const MediaDeckPanel(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
