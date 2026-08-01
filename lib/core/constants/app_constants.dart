/// 应用全局常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'BT种子搜索器';

  /// 搜索缓存 TTL
  static const Duration searchCacheTtl = Duration(minutes: 15);

  /// 搜索历史最大条数
  static const int maxSearchHistory = 50;

  /// 搜索结果每页条数
  static const int searchResultsPerPage = 50;

  /// 最大并发下载数
  static const int maxConcurrentDownloads = 3;

  /// 最大连接数 (WiFi)
  static const int maxConnectionsWifi = 200;

  /// 最大连接数 (蜂窝网络)
  static const int maxConnectionsCellular = 50;

  /// 低电量阈值
  static const double lowBatteryThreshold = 0.2;

  /// 低电量时最大连接数
  static const int maxConnectionsLowBattery = 50;

  /// DHT 默认启用
  static const bool dhtEnabled = false;

  /// 默认下载限速 (bytes/sec, 0 = 不限速)
  static const int defaultDownloadRateLimit = 0;

  /// 默认上传限速 (bytes/sec)
  static const int defaultUploadRateLimit = 1024 * 100; // 100KB/s

  /// 流播放启动缓冲阈值 (字节)
  static const int streamBufferThreshold = 20 * 1024 * 1024; // 20MB

  /// 流播放启动缓冲百分比
  static const double streamBufferPercent = 0.05; // 5%

  /// 种子文件最大大小 (10MB)
  static const int maxTorrentFileSize = 10 * 1024 * 1024;

  /// HTTP 流服务器绑定地址
  static const String streamServerHost = '127.0.0.1';

  /// 搜索间隔 (两次请求之间，毫秒)
  static const int searchRateLimitMs = 2000;

  /// 通知频道 ID
  static const String notificationChannelId = 'bt_download_channel';
  static const String notificationChannelName = '下载任务';
}
