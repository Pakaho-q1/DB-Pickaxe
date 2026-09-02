import 'package:hive/hive.dart';
import '../../features/browser/domain/models/bookmark.dart';
import '../../features/browser/domain/models/history_item.dart';
import '../../features/downloader/domain/models/download_task.dart';
import '../../features/settings/domain/models/app_settings.dart';
import '../../features/sniffer/domain/models/media_filter.dart';
import 'cache_paths.dart';

class HiveService {
  static const String settingsBoxName = 'settings_box';
  static const String bookmarksBoxName = 'bookmarks_box';
  static const String historyBoxName = 'history_box';
  static const String downloadsBoxName = 'downloads_box';
  static const String cookiesBoxName = 'cookies_box';
  static const String sessionBoxName = 'session_box';

  static late Box settingsBox;
  static late Box bookmarksBox;
  static late Box historyBox;
  static late Box downloadsBox;
  static late Box cookiesBox;
  static late Box sessionBox;

  static Future<void> init() async {
    // Ensure all .pickaxe-cache sub-directories exist before any path is accessed.
    CachePaths.ensureDirectoriesExist();

    // Strictly isolate Hive database files inside .pickaxe-cache/database
    final dbDir = CachePaths.databaseDir;
    Hive.init(dbDir.path);

    settingsBox = await Hive.openBox(settingsBoxName);
    bookmarksBox = await Hive.openBox(bookmarksBoxName);
    historyBox = await Hive.openBox(historyBoxName);
    downloadsBox = await Hive.openBox(downloadsBoxName);
    cookiesBox = await Hive.openBox(cookiesBoxName);
    sessionBox = await Hive.openBox(sessionBoxName);
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

  // Sniffer UI Preferences Persistence
  static MediaFilter getSnifferFilter() {
    final map = settingsBox.get('sniffer_filter');
    if (map == null) return const MediaFilter();
    return MediaFilter.fromMap(Map<dynamic, dynamic>.from(map as Map));
  }

  static Future<void> saveSnifferFilter(MediaFilter filter) async {
    await settingsBox.put('sniffer_filter', filter.toMap());
  }

  static bool getIsAutoDetect() {
    return settingsBox.get('is_auto_detect', defaultValue: true) as bool;
  }

  static Future<void> saveIsAutoDetect(bool isAuto) async {
    await settingsBox.put('is_auto_detect', isAuto);
  }

  static bool getKeepMediaAcrossPages() {
    return settingsBox.get('keep_media_across_pages', defaultValue: false) as bool;
  }

  static Future<void> saveKeepMediaAcrossPages(bool keep) async {
    await settingsBox.put('keep_media_across_pages', keep);
  }

  // Browser Session & Tabs Persistence
  static List<Map<String, dynamic>> getSessionTabs() {
    final raw = sessionBox.get('active_tabs');
    if (raw == null) return [];
    try {
      final list = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static String getLastActiveTabId() {
    return sessionBox.get('last_active_tab_id', defaultValue: '') as String;
  }

  static Future<void> saveSessionTabs(List<Map<String, dynamic>> tabs, String activeTabId) async {
    await sessionBox.put('active_tabs', tabs);
    await sessionBox.put('last_active_tab_id', activeTabId);
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
    final clean = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    for (var key in cookiesBox.keys) {
      final k = key.toString().toLowerCase().replaceFirst(RegExp(r'^\.?www\.'), '').replaceFirst(RegExp(r'^\.'),'');
      if (clean == k || clean.endsWith('.$k')) {
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
