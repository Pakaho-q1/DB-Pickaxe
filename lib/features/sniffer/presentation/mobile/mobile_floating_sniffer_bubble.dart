import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/sniffer_provider.dart';
import 'mobile_sniffer_bottom_sheet.dart';

class MobileFloatingSnifferBubble extends ConsumerStatefulWidget {
  const MobileFloatingSnifferBubble({super.key});

  @override
  ConsumerState<MobileFloatingSnifferBubble> createState() => _MobileFloatingSnifferBubbleState();
}

class _MobileFloatingSnifferBubbleState extends ConsumerState<MobileFloatingSnifferBubble> {
  double _x = 0;
  double _y = 0;
  bool _isInitialized = false;

  void _snapToEdge(double screenWidth, double screenHeight) {
    const bubbleWidth = 72.0;
    final midX = screenWidth / 2;

    setState(() {
      // Snap to nearest left or right edge with 12px margin
      if (_x < midX) {
        _x = 12.0;
      } else {
        _x = screenWidth - bubbleWidth - 12.0;
      }

      // Constrain vertical bounds
      _y = _y.clamp(60.0, screenHeight - 120.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = ref.watch(filteredMediaProvider);
    if (mediaList.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    if (!_isInitialized) {
      _x = size.width - 72.0 - 16.0;
      _y = size.height - 180.0;
      _isInitialized = true;
    }

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;
          });
        },
        onPanEnd: (_) => _snapToEdge(size.width, size.height),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const MobileSnifferBottomSheet(),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accentCyan, Color(0xFF00B4D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentCyan.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pickaxe ⛏️ Icon
                  const Icon(Icons.hardware_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    '${mediaList.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
