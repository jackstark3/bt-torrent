import 'package:bt_torrent/core/models/torznab_config.dart';

/// 设置仓库接口
abstract class SettingsRepository {
  /// WiFi 下才能下载
  Future<bool> getWifiOnly();
  Future<void> setWifiOnly(bool value);

  /// 下载路径
  Future<String> getDownloadPath();
  Future<void> setDownloadPath(String path);

  /// 最大并发下载数
  Future<int> getMaxDownloads();
  Future<void> setMaxDownloads(int value);

  /// 最大连接数
  Future<int> getMaxConnections();
  Future<void> setMaxConnections(int value);

  /// 下载限速 (bytes/sec, 0 = 不限速)
  Future<int> getDownloadRateLimit();
  Future<void> setDownloadRateLimit(int bytesPerSec);

  /// 上传限速 (bytes/sec)
  Future<int> getUploadRateLimit();
  Future<void> setUploadRateLimit(int bytesPerSec);

  /// DHT 启用
  Future<bool> getDhtEnabled();
  Future<void> setDhtEnabled(bool value);

  /// 安全模式（过滤成人内容）
  Future<bool> getSafeMode();
  Future<void> setSafeMode(bool value);

  /// 深色主题
  Future<bool> getDarkMode();
  Future<void> setDarkMode(bool value);

  /// 搜索源状态
  Future<Map<String, bool>> getSourceStates();
  Future<void> setSourceState(String sourceId, bool enabled);

  /// Torznab 索引器配置
  Future<TorznabConfig?> getTorznabConfig();
  Future<void> setTorznabConfig(TorznabConfig? config);

  /// 网络代理（"host:port"，空串 = 直连）
  Future<String> getProxy();
  Future<void> setProxy(String proxy);
}
