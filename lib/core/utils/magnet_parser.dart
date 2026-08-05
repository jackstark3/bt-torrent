/// 磁力链接解析器
class MagnetParser {
  static const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// 将 btih 归一化为 40 位十六进制小写
  /// 兼容两种编码：40 位十六进制 / 32 位 base32（dmhy 等站点使用）
  static String? normalizeInfoHash(String raw) {
    final clean = raw.trim();
    if (RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(clean)) {
      return clean.toLowerCase();
    }
    if (RegExp(r'^[A-Za-z2-7]{32}$').hasMatch(clean)) {
      return _base32ToHex(clean);
    }
    return null;
  }

  static String? _base32ToHex(String input) {
    final bits = StringBuffer();
    for (final ch in input.toUpperCase().split('')) {
      final v = _base32Alphabet.indexOf(ch);
      if (v < 0) return null;
      bits.write(v.toRadixString(2).padLeft(5, '0'));
    }
    final bytes = <int>[];
    final bitStr = bits.toString();
    for (var i = 0; i + 8 <= bitStr.length; i += 8) {
      bytes.add(int.parse(bitStr.substring(i, i + 8), radix: 2));
    }
    if (bytes.length != 20) return null;
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

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
          return normalizeInfoHash(xt.substring(9));
        }
      }

      // 某些链接使用 btih (无 urn: 前缀)
      final btihParams = uri.queryParametersAll['btih'] ?? [];
      if (btihParams.isNotEmpty) {
        return normalizeInfoHash(btihParams.first);
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
