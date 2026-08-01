/// 磁力链接解析器
class MagnetParser {
  /// 从磁力链接提取 info_hash
  /// 支持格式: magnet:?xt=urn:btih:HASH
  static String? extractInfoHash(String magnetUri) {
    try {
      final uri = Uri.parse(magnetUri);
      if (uri.scheme != 'magnet') return null;

      // 从 xt 参数提取
      final xtParams = uri.queryParametersAll['xt'] ?? [];
      for (final xt in xtParams) {
        if (xt.startsWith('urn:btih:')) {
          return xt.substring(9).toLowerCase();
        }
      }

      // 某些链接使用 btih (无 urn: 前缀)
      final btihParams = uri.queryParametersAll['btih'] ?? [];
      if (btihParams.isNotEmpty) {
        return btihParams.first.toLowerCase();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从磁力链接提取显示名称
  static String? extractDisplayName(String magnetUri) {
    try {
      final uri = Uri.parse(magnetUri);
      final dn = uri.queryParameters['dn'];
      if (dn != null && dn.isNotEmpty) {
        return Uri.decodeComponent(dn);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从磁力链接提取 tracker URLs
  static List<String> extractTrackers(String magnetUri) {
    try {
      final uri = Uri.parse(magnetUri);
      return uri.queryParametersAll['tr'] ?? [];
    } catch (_) {
      return [];
    }
  }

  /// 检测字符串是否为磁力链接
  static bool isMagnetUri(String text) {
    return text.trim().startsWith('magnet:?');
  }

  /// 检测字符串是否为种子文件 URL
  static bool isTorrentUrl(String text) {
    final trimmed = text.trim().toLowerCase();
    return trimmed.startsWith('http') && trimmed.endsWith('.torrent');
  }

  /// 计算 info_hash 的磁力链接
  static String buildMagnetUri(String infoHash, {String? displayName}) {
    final buffer = StringBuffer('magnet:?xt=urn:btih:$infoHash');
    if (displayName != null && displayName.isNotEmpty) {
      buffer.write('&dn=${Uri.encodeComponent(displayName)}');
    }
    return buffer.toString();
  }
}
