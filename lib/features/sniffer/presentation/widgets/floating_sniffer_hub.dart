import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../browser/presentation/providers/browser_tabs_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/sniffer_provider.dart';

class FloatingSnifferHub extends ConsumerStatefulWidget {
  final VoidCallback? onToggleDeck;

  const FloatingSnifferHub({super.key, this.onToggleDeck});

  @override
  ConsumerState<FloatingSnifferHub> createState() => _FloatingSnifferHubState();
}

class _FloatingSnifferHubState extends ConsumerState<FloatingSnifferHub>
    with SingleTickerProviderStateMixin {
  Offset? _dragPosition;
  bool _isHovered = false;
  bool _isScanning = false;
  String? _scanResultText;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerDetection(bool isAuto) async {
    setState(() {
      _isScanning = true;
      _scanResultText = null;
    });

    await ref.read(browserTabsProvider.notifier).rescanActiveTab();

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      final total = ref.read(activeTabMediaProvider).length;
      setState(() {
        _isScanning = false;
        _scanResultText = total > 0 ? '✓ Found $total items' : 'No new media';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _scanResultText = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final activeTabMedia = ref.watch(activeTabMediaProvider);
    final isAuto = ref.watch(isAutoDetectEnabledProvider);

    final videoCount = activeTabMedia
        .where((m) => m.mediaType == MediaType.video || m.mediaType == MediaType.stream)
        .length;
    final imageCount = activeTabMedia.where((m) => m.mediaType == MediaType.image).length;
    final audioCount = activeTabMedia.where((m) => m.mediaType == MediaType.audio).length;
    final totalCount = activeTabMedia.length;

    final hubContent = switch (settings.snifferHubStyle) {
      SnifferHubStyle.glassCapsule => _buildGlassCapsule(
          isAuto: isAuto,
          videoCount: videoCount,
          imageCount: imageCount,
          audioCount: audioCount,
          totalCount: totalCount,
        ),
      SnifferHubStyle.miniFab => _buildMiniFab(
          isAuto: isAuto,
          totalCount: totalCount,
          videoCount: videoCount,
          imageCount: imageCount,
        ),
      SnifferHubStyle.slimBar => _buildSlimBar(
          isAuto: isAuto,
          videoCount: videoCount,
          imageCount: imageCount,
          audioCount: audioCount,
          totalCount: totalCount,
        ),
    };

    // If Draggable mode
    if (settings.snifferHubPosition == SnifferHubPosition.customDraggable) {
      return Positioned(
        left: _dragPosition?.dx ?? (MediaQuery.of(context).size.width - 450).clamp(20.0, 1920.0),
        top: _dragPosition?.dy ?? (MediaQuery.of(context).size.height - 180).clamp(20.0, 1080.0),
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _dragPosition = (_dragPosition ?? const Offset(200, 400)) + details.delta;
            });
          },
          child: hubContent,
        ),
      );
    }

    // Fixed Docking Presets
    return switch (settings.snifferHubPosition) {
      SnifferHubPosition.bottomRight => Positioned(
          bottom: 24,
          right: 24,
          child: hubContent,
        ),
      SnifferHubPosition.bottomLeft => Positioned(
          bottom: 24,
          left: 24,
          child: hubContent,
        ),
      SnifferHubPosition.bottomCenter => Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(child: hubContent),
        ),
      SnifferHubPosition.topRight => Positioned(
          top: 24,
          right: 24,
          child: hubContent,
        ),
      SnifferHubPosition.topLeft => Positioned(
          top: 24,
          left: 24,
          child: hubContent,
        ),
      SnifferHubPosition.customDraggable => const SizedBox.shrink(),
    };
  }

  /// Style 1: Premium Glass Capsule (Recommended)
  Widget _buildGlassCapsule({
    required bool isAuto,
    required int videoCount,
    required int imageCount,
    required int audioCount,
    required int totalCount,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isScanning
                    ? AppTheme.accentCyan
                    : (_isHovered
                        ? (isAuto ? AppTheme.accentCyan : AppTheme.primaryLight).withValues(alpha: 0.8)
                        : const Color(0x336366F1)),
                width: _isScanning ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isScanning
                          ? AppTheme.accentCyan
                          : (isAuto ? AppTheme.accentCyan : AppTheme.primaryColor))
                      .withValues(alpha: _isScanning ? 0.45 : (_isHovered ? 0.35 : 0.18)),
                  blurRadius: _isScanning ? 18 : (_isHovered ? 16 : 10),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Mode Switcher (Auto vs Manual)
                _buildModeToggle(isAuto),
                const SizedBox(width: 8),

                // 2. Dynamic Middle State (Scanning / Result / Badges)
                if (_isScanning) ...[
                  RotationTransition(
                    turns: _pulseController,
                    child: const Icon(Icons.radar, size: 16, color: AppTheme.accentCyan),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Scanning...',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                  ),
                  const SizedBox(width: 8),
                ] else if (_scanResultText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _scanResultText!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  // Live Media Counter Badges (Clicking triggers deck toggle)
                  InkWell(
                    onTap: widget.onToggleDeck,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x331E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatBadge(Icons.movie_outlined, '$videoCount', AppTheme.accentRose),
                          const SizedBox(width: 5),
                          _buildStatBadge(Icons.image_outlined, '$imageCount', AppTheme.accentCyan),
                          if (audioCount > 0) ...[
                            const SizedBox(width: 5),
                            _buildStatBadge(Icons.audiotrack_outlined, '$audioCount', AppTheme.primaryLight),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 3. Smart Action Button: Re-detect (Auto) or Detect (Manual)
                _buildSmartDetectButton(isAuto: isAuto),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Style 2: Compact Mini FAB Ring
  Widget _buildMiniFab({
    required bool isAuto,
    required int totalCount,
    required int videoCount,
    required int imageCount,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xEE0F172A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isAuto ? AppTheme.accentCyan : AppTheme.primaryLight,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isAuto ? AppTheme.accentCyan : AppTheme.primaryLight).withValues(alpha: 0.3),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse Radar Icon
                GestureDetector(
                  onTap: () => _triggerDetection(isAuto),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isAuto
                            ? [AppTheme.accentCyan, AppTheme.primaryColor]
                            : [AppTheme.primaryColor, AppTheme.accentRose],
                      ),
                    ),
                    child: Icon(
                      _isScanning ? Icons.sync : (isAuto ? Icons.refresh : Icons.radar),
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Live total badge
                InkWell(
                  onTap: widget.onToggleDeck,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _scanResultText ?? '$totalCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      if (_scanResultText == null) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'Media',
                          style: TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_isHovered) ...[
                  const SizedBox(width: 8),
                  _buildModeToggle(isAuto),
                  const SizedBox(width: 6),
                  _buildSmartDetectButton(isAuto: isAuto, compact: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Style 3: Minimal Slim Bar
  Widget _buildSlimBar({
    required bool isAuto,
    required int videoCount,
    required int imageCount,
    required int audioCount,
    required int totalCount,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xF01E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeToggle(isAuto),
            const SizedBox(width: 8),
            if (_isScanning) ...[
              const Text('Scanning...', style: TextStyle(fontSize: 10, color: AppTheme.accentCyan)),
              const SizedBox(width: 8),
            ] else if (_scanResultText != null) ...[
              Text(_scanResultText!, style: const TextStyle(fontSize: 10, color: AppTheme.accentGreen)),
              const SizedBox(width: 8),
            ] else ...[
              _buildStatBadge(Icons.movie, '$videoCount', AppTheme.accentRose),
              const SizedBox(width: 4),
              _buildStatBadge(Icons.image, '$imageCount', AppTheme.accentCyan),
              const SizedBox(width: 8),
            ],
            _buildSmartDetectButton(isAuto: isAuto, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(bool isAuto) {
    return InkWell(
      onTap: () {
        ref.read(isAutoDetectEnabledProvider.notifier).state = !isAuto;
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isAuto
              ? AppTheme.accentCyan.withValues(alpha: 0.18)
              : AppTheme.primaryColor.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAuto
                ? AppTheme.accentCyan.withValues(alpha: 0.5)
                : AppTheme.primaryLight.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAuto ? Icons.bolt : Icons.touch_app,
              size: 11,
              color: isAuto ? AppTheme.accentCyan : AppTheme.primaryLight,
            ),
            const SizedBox(width: 3),
            Text(
              isAuto ? 'Auto' : 'Manual',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isAuto ? AppTheme.accentCyan : AppTheme.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          count,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildSmartDetectButton({required bool isAuto, bool compact = false}) {
    final label = _isScanning
        ? 'Scanning'
        : (isAuto ? 'Re-detect' : 'Detect');
    final icon = _isScanning
        ? Icons.sync
        : (isAuto ? Icons.refresh : Icons.radar);

    return InkWell(
      onTap: _isScanning ? null : () => _triggerDetection(isAuto),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAuto
                ? const [Color(0xFF0284C7), Color(0xFF06B6D4)]
                : const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isAuto ? AppTheme.accentCyan : AppTheme.primaryColor).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
