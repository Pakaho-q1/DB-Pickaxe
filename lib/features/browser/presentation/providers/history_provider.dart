import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/storage/hive_service.dart';
import '../../domain/models/history_item.dart';

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  HistoryNotifier() : super(HiveService.getHistory());

  Future<void> recordVisit({
    required String title,
    required String url,
  }) async {
    if (url.isEmpty || url.startsWith('about:') || url.startsWith('data:')) return;

    final existingIndex = state.indexWhere((h) => h.url == url);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final updated = existing.copyWith(
        title: title.isNotEmpty ? title : existing.title,
        visitedAt: DateTime.now(),
        visitCount: existing.visitCount + 1,
      );
      await HiveService.saveHistoryItem(updated);
    } else {
      final item = HistoryItem(
        id: const Uuid().v4(),
        title: title.isEmpty ? url : title,
        url: url,
        visitedAt: DateTime.now(),
        visitCount: 1,
      );
      await HiveService.saveHistoryItem(item);
    }
    state = HiveService.getHistory();
  }

  Future<void> clearAll() async {
    await HiveService.clearHistory();
    state = [];
  }
}
