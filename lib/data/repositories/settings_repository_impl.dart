import 'package:bt_torrent/domain/repositories/settings_repository.dart';
import 'package:bt_torrent/core/models/torznab_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _keyWifiOnly = 'wifi_only';
  static const _keyDownloadPath = 'download_path';
  static const _keyMaxDownloads = 'max_downloads';
  static const _keyMaxConnections = 'max_connections';
  static const _keyDownloadRateLimit = 'download_rate_limit';
  static const _keyUploadRateLimit = 'upload_rate_limit';
  static const _keyDhtEnabled = 'dht_enabled';
  static const _keySafeMode = 'safe_mode';
  static const _keyDarkMode = 'dark_mode';
  static const _keySourceState = 'source_';
  static const _keyProxy = 'proxy';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<bool> getWifiOnly() async => (await _prefs).getBool(_keyWifiOnly) ?? true;

  @override
  Future<void> setWifiOnly(bool value) async => (await _prefs).setBool(_keyWifiOnly, value);

  @override
  Future<String> getDownloadPath() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDownloadPath) ??
        '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}downloads';
  }

  @override
  Future<void> setDownloadPath(String path) async => (await _prefs).setString(_keyDownloadPath, path);

  @override
  Future<int> getMaxDownloads() async => (await _prefs).getInt(_keyMaxDownloads) ?? 3;

  @override
  Future<void> setMaxDownloads(int value) async => (await _prefs).setInt(_keyMaxDownloads, value);

  @override
  Future<int> getMaxConnections() async => (await _prefs).getInt(_keyMaxConnections) ?? 200;

  @override
  Future<void> setMaxConnections(int value) async => (await _prefs).setInt(_keyMaxConnections, value);

  @override
  Future<int> getDownloadRateLimit() async => (await _prefs).getInt(_keyDownloadRateLimit) ?? 0;

  @override
  Future<void> setDownloadRateLimit(int bytesPerSec) async => (await _prefs).setInt(_keyDownloadRateLimit, bytesPerSec);

  @override
  Future<int> getUploadRateLimit() async => (await _prefs).getInt(_keyUploadRateLimit) ?? 102400;

  @override
  Future<void> setUploadRateLimit(int bytesPerSec) async => (await _prefs).setInt(_keyUploadRateLimit, bytesPerSec);

  @override
  Future<bool> getDhtEnabled() async => (await _prefs).getBool(_keyDhtEnabled) ?? false;

  @override
  Future<void> setDhtEnabled(bool value) async => (await _prefs).setBool(_keyDhtEnabled, value);

  @override
  Future<bool> getSafeMode() async => (await _prefs).getBool(_keySafeMode) ?? false;

  @override
  Future<void> setSafeMode(bool value) async => (await _prefs).setBool(_keySafeMode, value);

  @override
  Future<bool> getDarkMode() async => (await _prefs).getBool(_keyDarkMode) ?? false;

  @override
  Future<void> setDarkMode(bool value) async => (await _prefs).setBool(_keyDarkMode, value);

  @override
  Future<Map<String, bool>> getSourceStates() async {
    final prefs = await _prefs;
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keySourceState));
    final states = <String, bool>{};
    for (final key in keys) {
      states[key.substring(_keySourceState.length)] =
          prefs.getBool(key) ?? true;
    }
    return states;
  }

  @override
  Future<void> setSourceState(String sourceId, bool enabled) async => (await _prefs).setBool('${_keySourceState}$sourceId', enabled);

  @override
  Future<TorznabConfig?> getTorznabConfig() async =>
      TorznabConfig.loadFromPrefs(await _prefs);

  @override
  Future<void> setTorznabConfig(TorznabConfig? config) async {
    final prefs = await _prefs;
    if (config == null) {
      await TorznabConfig.clear(prefs);
    } else {
      await config.save(prefs);
    }
  }

  @override
  Future<String> getProxy() async => (await _prefs).getString(_keyProxy) ?? '';

  @override
  Future<void> setProxy(String proxy) async =>
      (await _prefs).setString(_keyProxy, proxy.trim());
}
