import 'package:bt_torrent/core/models/torrent_info.dart';

/// 搜索源爬虫共享工具
class ProviderUtils {
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
      r'btih:([a-fA-F0-9]{40})',
      caseSensitive: false,
    ).firstMatch(magnet);
    return match?.group(1)?.toLowerCase();
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
