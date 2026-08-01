import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bt_torrent/providers/core_providers.dart';

/// 设置状态
final settingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return {
    'wifiOnly': await repo.getWifiOnly(),
    'downloadPath': await repo.getDownloadPath(),
    'maxDownloads': await repo.getMaxDownloads(),
    'maxConnections': await repo.getMaxConnections(),
    'downloadRateLimit': await repo.getDownloadRateLimit(),
    'uploadRateLimit': await repo.getUploadRateLimit(),
    'dhtEnabled': await repo.getDhtEnabled(),
    'safeMode': await repo.getSafeMode(),
    'darkMode': await repo.getDarkMode(),
  };
});

/// WiFi Only 设置
final wifiOnlyProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getWifiOnly();
});

/// 安全模式
final safeModeProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSafeMode();
});

/// 深色模式
final darkModeProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getDarkMode();
});

/// 搜索源启用状态
final sourceStatesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getSourceStates();
});
