import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/hive_service.dart';
import '../../domain/models/app_settings.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(HiveService.getSettings());

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await HiveService.saveSettings(newSettings);
  }

  Future<void> updateDownloadPath(String path) async {
    final updated = state.copyWith(defaultDownloadPath: path);
    await updateSettings(updated);
  }

  Future<void> updateConcurrency(int count) async {
    final updated = state.copyWith(maxConcurrentDownloads: count);
    await updateSettings(updated);
  }

  Future<void> updateSpeedLimit(double kbps) async {
    final updated = state.copyWith(speedLimitKBps: kbps);
    await updateSettings(updated);
  }
}
