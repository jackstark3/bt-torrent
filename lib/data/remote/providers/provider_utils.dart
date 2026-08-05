import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/magnet_parser.dart';

/// 搜索源爬虫共享工具
class ProviderUtils {
  /// 公共 tracker 列表（DHT 聚合站的裸磁力补上 tracker，提升连 peer 成功率）
  static const List<String> publicTrackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.stealth.si:80/announce',
    'udp://tracker.torrent.eu.org:451/announce',
    'udp://tracker.internetwarriors.net:1337/announce',
    'udp://exodus.desync.com:6969/announce',
    'http://p4p.arenabg.com:1337/announce',
  ];

  /// 根据 info_hash 构造带公共 tracker 的磁力链接
  static String buildMagnetWithTrackers(String infoHash, String title) {
    final buffer = StringBuffer('magnet:?xt=urn:btih:$infoHash');
    if (title.isNotEmpty) {
      buffer.write('&dn=${Uri.encodeComponent(title)}');
    }
    for (final tracker in publicTrackers) {
      buffer.write('&tr=${Uri.encodeComponent(tracker)}');
    }
    return buffer.toString();
  }

  /// 磁力链接是否已带 tracker
  static bool magnetHasTrackers(String magnet) {
    return Uri.tryParse(magnet)?.queryParameters.containsKey('tr') ?? false;
  }

  /// 解析 "2.5 GiB" / "1.2 GB" / "750 MB" 等大小字符串为字节
  static int parseSize(String sizeStr) {
    final match = RegExp(
      r'([\d.]+)\s*(B|KB|MB|GB|GiB|TB|TiB)',
      caseSensitive: false,
    ).firstMatch(sizeStr);
    if (match == null) return 0;

    final value = double.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toUpperCase().replaceAll('I', '');
    switch (unit) {
      case 'B':
        return value.toInt();
      case 'KB':
        return (value * 1024).toInt();
      case 'MB':
        return (value * 1024 * 1024).toInt();
      case 'GB':
        return (value * 1024 * 1024 * 1024).toInt();
      case 'TB':
        return (value * 1024 * 1024 * 1024 * 1024).toInt();
      default:
        return value.toInt();
    }
  }

  /// 简单字符串哈希作为 info_hash 替代（用于无磁力链接的源）
  static String hashString(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash |= 0;
    }
    return hash.toRadixString(16).padLeft(40, '0');
  }

  /// 从磁力链接提取 info_hash
  static String? extractHashFromMagnet(String magnet) {
    final match = RegExp(
      r'btih:([A-Za-z0-9]{32,40})',
      caseSensitive: false,
    ).firstMatch(magnet);
    final raw = match?.group(1);
    if (raw == null) return null;
    return MagnetParser.normalizeInfoHash(raw);
  }

  /// 根据标题粗判分类
  static TorrentCategory? detectCategory(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('xxx') ||
        lower.contains('porn') ||
        lower.contains('adult') ||
        lower.contains('onlyfans')) {
      return TorrentCategory.xxx;
    }
    if (lower.contains('anime') || lower.contains('subbed') || lower.contains('dubbed')) {
      return TorrentCategory.anime;
    }
    if (lower.contains('s0') ||
        RegExp(r'\bs\d{1,2}e\d{1,2}\b').hasMatch(lower)) {
      return TorrentCategory.tv;
    }
    if (lower.contains('flac') ||
        lower.contains('mp3') ||
        lower.contains('lossless')) {
      return TorrentCategory.music;
    }
    return null;
  }
}
