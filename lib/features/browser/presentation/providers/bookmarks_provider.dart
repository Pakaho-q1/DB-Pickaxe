import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/storage/hive_service.dart';
import '../../domain/models/bookmark.dart';

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<Bookmark>>((ref) {
  return BookmarksNotifier();
});

class BookmarksNotifier extends StateNotifier<List<Bookmark>> {
  BookmarksNotifier() : super(HiveService.getBookmarks());

  Future<void> addBookmark({
    required String title,
    required String url,
    String? faviconUrl,
    String folder = 'Default',
  }) async {
    final bookmark = Bookmark(
      id: const Uuid().v4(),
      title: title.isEmpty ? url : title,
      url: url,
      faviconUrl: faviconUrl,
      folder: folder,
      createdAt: DateTime.now(),
    );
    await HiveService.saveBookmark(bookmark);
    state = HiveService.getBookmarks();
  }

  Future<void> removeBookmark(String id) async {
    await HiveService.deleteBookmark(id);
    state = HiveService.getBookmarks();
  }

  bool isBookmarked(String url) {
    return state.any((b) => b.url.toLowerCase() == url.toLowerCase());
  }
}
