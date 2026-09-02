import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Centralised mapping from [MediaType] to display properties.
/// Eliminates duplicated switch blocks across media_card, media_preview_dialog,
/// and download_task_tile.
class MediaTypeHelper {
  const MediaTypeHelper._();

  /// Returns the [IconData] that represents the given [mediaType].
  static IconData iconFor(MediaType mediaType) {
    return switch (mediaType) {
      MediaType.video  => Icons.movie,
      MediaType.stream => Icons.live_tv,
      MediaType.image  => Icons.image,
      MediaType.audio  => Icons.audiotrack,
      _                => Icons.insert_drive_file,
    };
  }

  /// Returns the accent [Color] associated with the given [mediaType].
  static Color colorFor(MediaType mediaType) {
    return switch (mediaType) {
      MediaType.video  => AppTheme.accentRose,
      MediaType.stream => AppTheme.accentAmber,
      MediaType.image  => AppTheme.accentCyan,
      MediaType.audio  => AppTheme.primaryLight,
      _                => AppTheme.darkTextSecondary,
    };
  }

  /// Convenience: returns both [iconFor] and [colorFor] as a record.
  static ({IconData icon, Color color}) propsFor(MediaType mediaType) {
    return (icon: iconFor(mediaType), color: colorFor(mediaType));
  }
}
