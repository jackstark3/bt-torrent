import 'package:shared_preferences/shared_preferences.dart';

/// Torznab 索引器配置（Jackett / Prowlarr）
class TorznabConfig {
  final String baseUrl;
  final String apiKey;
  final String indexerName;
  final String indexerId;

  const TorznabConfig({
    required this.baseUrl,
    required this.apiKey,
    this.indexerName = 'Jackett',
    this.indexerId = 'jackett',
  });

  /// 是否已配置完整（可启用）
  bool get isValid =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  static const _keyBaseUrl = 'torznab_base_url';
  static const _keyApiKey = 'torznab_api_key';
  static const _keyName = 'torznab_name';
  static const _keyId = 'torznab_id';

  /// 从 SharedPreferences 读取配置
  static Future<TorznabConfig?> loadFromPrefs(
      SharedPreferences prefs) async {
    final baseUrl = prefs.getString(_keyBaseUrl) ?? '';
    final apiKey = prefs.getString(_keyApiKey) ?? '';
    if (baseUrl.isEmpty && apiKey.isEmpty) return null;
    return TorznabConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      indexerName: prefs.getString(_keyName) ?? 'Jackett',
      indexerId: prefs.getString(_keyId) ?? 'jackett',
    );
  }

  /// 保存到 SharedPreferences
  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyName, indexerName);
    await prefs.setString(_keyId, indexerId);
  }

  /// 清除配置
  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyName);
    await prefs.remove(_keyId);
  }
}
