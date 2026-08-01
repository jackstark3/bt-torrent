import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 简单的本地持久化存储
/// 使用 JSON 文件存储种子缓存和书签
/// 使用 SharedPreferences 存储搜索历史
class AppDatabase {
  static AppDatabase? _instance;

  factory AppDatabase() => _instance ??= AppDatabase._();

  AppDatabase._();

  File? _torrentsFile;

  Future<File> get _dbFile async {
    if (_torrentsFile != null) return _torrentsFile!;
    final dir = await getApplicationDocumentsDirectory();
    _torrentsFile = File('${dir.path}/bt_torrents.json');
    return _torrentsFile!;
  }

  // ===== 种子缓存 =====

  Future<List<Map<String, dynamic>>> _readTorrents() async {
    try {
      final file = await _dbFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('读取缓存失败: $e');
      return [];
    }
  }

  Future<void> _writeTorrents(List<Map<String, dynamic>> torrents) async {
    try {
      final file = await _dbFile;
      await file.writeAsString(jsonEncode(torrents));
    } catch (e) {
      debugPrint('写入缓存失败: $e');
    }
  }

  /// 插入或更新种子
  Future<void> upsertTorrents(List<Map<String, dynamic>> torrents) async {
    final existing = await _readTorrents();
    final existingMap = <String, Map<String, dynamic>>{};
    for (final t in existing) {
      existingMap[t['info_hash'] as String] = t;
    }
    for (final t in torrents) {
      existingMap[t['info_hash'] as String] = t;
    }
    await _writeTorrents(existingMap.values.toList());
  }

  /// 搜索缓存
  Future<List<Map<String, dynamic>>> searchCached(String query) async {
    final torrents = await _readTorrents();
    final lowerQuery = query.toLowerCase();
    return torrents.where((t) {
      final title = (t['title'] as String?)?.toLowerCase() ?? '';
      return title.contains(lowerQuery);
    }).toList()
      ..sort((a, b) =>
          (b['seeders'] as int?)?.compareTo(a['seeders'] as int? ?? 0) ?? 0);
  }

  /// 获取书签
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final torrents = await _readTorrents();
    return torrents.where((t) => t['is_bookmarked'] == true).toList();
  }

  /// 切换书签
  Future<void> toggleBookmark(String infoHash) async {
    final torrents = await _readTorrents();
    for (int i = 0; i < torrents.length; i++) {
      if (torrents[i]['info_hash'] == infoHash) {
        torrents[i]['is_bookmarked'] =
            !(torrents[i]['is_bookmarked'] == true);
        await _writeTorrents(torrents);
        return;
      }
    }
  }

  // ===== 搜索历史 =====

  static const _historyKey = 'search_history';

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addSearchHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history =
        List<String>.from(prefs.getStringList(_historyKey) ?? []);
    history.remove(query);
    history.insert(0, query);
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    await prefs.setStringList(_historyKey, history);
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
