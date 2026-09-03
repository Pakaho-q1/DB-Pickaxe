import 'package:flutter/material.dart';
import '../../../../core/utils/platform_helper.dart';
import '../../../browser/presentation/mobile/mobile_browser_screen.dart';
import 'desktop_main_screen.dart';

class AdaptiveMainScreen extends StatelessWidget {
  const AdaptiveMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (PlatformHelper.isMobile || constraints.maxWidth < 720) {
          return const MobileBrowserScreen();
        }
        return const DesktopMainScreen();
      },
    );
  }
}
