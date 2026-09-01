import 'package:hive/hive.dart';
import '../../features/browser/domain/models/bookmark.dart';
import '../../features/browser/domain/models/history_item.dart';
import '../../features/downloader/domain/models/download_task.dart';
import '../../features/settings/domain/models/app_settings.dart';
import 'cache_paths.dart';

class HiveService {
  static const String settingsBoxName = 'settings_box';
  static const String bookmarksBoxName = 'bookmarks_box';
  static const String historyBoxName = 'history_box';
  static const String downloadsBoxName = 'downloads_box';
  static const String cookiesBoxName = 'cookies_box';

  static late Box settingsBox;
  static late Box bookmarksBox;
  static late Box historyBox;
  static late Box downloadsBox;
  static late Box cookiesBox;

  static Future<void> init() async {
    // Strictly isolate Hive database files inside .pickaxe-cache/database
    final dbDir = CachePaths.databaseDir;
    Hive.init(dbDir.path);

    settingsBox = await Hive.openBox(settingsBoxName);
    bookmarksBox = await Hive.openBox(bookmarksBoxName);
    historyBox = await Hive.openBox(historyBoxName);
    downloadsBox = await Hive.openBox(downloadsBoxName);
    cookiesBox = await Hive.openBox(cookiesBoxName);
  }

  // Settings
  static AppSettings getSettings() {
    final map = settingsBox.get('current_settings');
    if (map == null) return const AppSettings();
    return AppSettings.fromMap(Map<dynamic, dynamic>.from(map as Map));
  }

  static Future<void> saveSettings(AppSettings settings) async {
    await settingsBox.put('current_settings', settings.toMap());
  }

  // Bookmarks
  static List<Bookmark> getBookmarks() {
    final list = <Bookmark>[];
    for (var key in bookmarksBox.keys) {
      final map = bookmarksBox.get(key);
      if (map != null) {
        list.add(Bookmark.fromMap(Map<dynamic, dynamic>.from(map as Map)));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> saveBookmark(Bookmark bookmark) async {
    await bookmarksBox.put(bookmark.id, bookmark.toMap());
  }

  static Future<void> deleteBookmark(String id) async {
    await bookmarksBox.delete(id);
  }

  // History
  static List<HistoryItem> getHistory() {
    final list = <HistoryItem>[];
    for (var key in historyBox.keys) {
      final map = historyBox.get(key);
      if (map != null) {
        list.add(HistoryItem.fromMap(Map<dynamic, dynamic>.from(map as Map)));
      }
    }
    list.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return list;
  }

  static Future<void> saveHistoryItem(HistoryItem item) async {
    await historyBox.put(item.id, item.toMap());
  }

  static Future<void> clearHistory() async {
    await historyBox.clear();
  }

  // Downloads
  static List<DownloadTask> getDownloadTasks() {
    final list = <DownloadTask>[];
    for (var key in downloadsBox.keys) {
      final map = downloadsBox.get(key);
      if (map != null) {
        list.add(DownloadTask.fromMap(Map<dynamic, dynamic>.from(map as Map)));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> saveDownloadTask(DownloadTask task) async {
    await downloadsBox.put(task.id, task.toMap());
  }

  static Future<void> deleteDownloadTask(String id) async {
    await downloadsBox.delete(id);
  }

  // Cookies Management
  static Map<String, String> getAllSavedCookies() {
    final map = <String, String>{};
    for (var key in cookiesBox.keys) {
      final val = cookiesBox.get(key);
      if (val != null) {
        map[key.toString()] = val.toString();
      }
    }
    return map;
  }

  static String? getCookiesForDomain(String domain) {
    // Exact or wildcard domain match
    final clean = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    for (var key in cookiesBox.keys) {
      final k = key.toString().toLowerCase().replaceFirst(RegExp(r'^\.?www\.'), '').replaceFirst(RegExp(r'^\.'), '');
      if (clean.contains(k) || k.contains(clean)) {
        return cookiesBox.get(key)?.toString();
      }
    }
    return null;
  }

  static Future<void> saveCookieForDomain(String domain, String cookieString) async {
    final clean = domain.toLowerCase().trim();
    await cookiesBox.put(clean, cookieString.trim());
  }

  static Future<void> deleteCookieForDomain(String domain) async {
    await cookiesBox.delete(domain.toLowerCase().trim());
  }

  static Future<void> clearAllCookies() async {
    await cookiesBox.clear();
  }
}
