import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../../browser/presentation/providers/browser_tabs_provider.dart';
import '../../../browser/presentation/widgets/browser_navigation_bar.dart';
import '../../../browser/presentation/widgets/browser_tab_bar.dart';
import '../../../browser/presentation/widgets/browser_view.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../sniffer/presentation/widgets/media_deck_panel.dart';
import '../../../../platform/windows/windows_initializer.dart';

class DesktopMainScreen extends ConsumerStatefulWidget {
  const DesktopMainScreen({super.key});

  @override
  ConsumerState<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends ConsumerState<DesktopMainScreen> with WindowListener {
  bool _isDeckExpanded = true;
  double _sideDeckWidth = 380.0;
  bool _isClosing = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isReady = true;
      if (Platform.isWindows) {
        WindowsInitializer.showWebView2ErrorIfNeeded(context);
      }
    });
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
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
    if (Platform.isWindows) {
      await windowManager.destroy();
    }
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

    if (_matchesShortcut(event, shortcuts.closeTab)) {
      if (activeId.isNotEmpty) {
        ref.read(browserTabsProvider.notifier).closeTab(activeId);
      }
      return;
    }

    if (_matchesShortcut(event, shortcuts.newTab)) {
      ref.read(browserTabsProvider.notifier).createTab();
      return;
    }

    if (_matchesShortcut(event, shortcuts.closeOtherTabs)) {
      if (activeId.isNotEmpty) {
        ref.read(browserTabsProvider.notifier).closeOtherTabs(activeId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Closed other tabs'), duration: Duration(seconds: 1)),
        );
      }
      return;
    }

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
                            });
                          },
                          child: Container(
                            width: 6,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                width: 1.5,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                        ),
                      ),
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
