import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/storage/hive_service.dart';
import 'core/theme/app_theme.dart';
import 'features/browser/presentation/widgets/browser_navigation_bar.dart';
import 'features/browser/presentation/widgets/browser_tab_bar.dart';
import 'features/browser/presentation/widgets/browser_view.dart';
import 'features/sniffer/presentation/widgets/media_deck_panel.dart';
import 'platform/windows/windows_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Local Database
  await HiveService.init();

  // 2. Initialize Desktop Window
  await WindowsInitializer.init();

  runApp(
    const ProviderScope(
      child: DBPickaxeApp(),
    ),
  );
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

class MainWorkstationScreen extends StatefulWidget {
  const MainWorkstationScreen({super.key});

  @override
  State<MainWorkstationScreen> createState() => _MainWorkstationScreenState();
}

class _MainWorkstationScreenState extends State<MainWorkstationScreen> {
  bool _isDeckExpanded = true;
  double _sideDeckWidth = 380.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxAllowedWidth = (screenWidth * 0.50).clamp(320.0, 1200.0);
    final clampedWidth = _sideDeckWidth.clamp(260.0, maxAllowedWidth);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Bar
            const BrowserTabBar(),
            // Navigation Bar
            const BrowserNavigationBar(),
            // Workstation Workspace: Browser on Left + Resizable Media Deck on Right
            Expanded(
              child: Row(
                children: [
                  // Browser View Area
                  const Expanded(
                    child: BrowserView(),
                  ),
                  // Draggable Divider & Collapse Button
                  if (_isDeckExpanded)
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            // Dragging left increases width, right decreases width
                            _sideDeckWidth -= details.delta.dx;
                            _sideDeckWidth = _sideDeckWidth.clamp(260.0, maxAllowedWidth);
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
                          _isDeckExpanded ? Icons.chevron_right : Icons.chevron_left,
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
    );
  }
}
