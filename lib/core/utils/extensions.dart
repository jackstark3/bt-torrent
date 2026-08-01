/// 通用扩展方法
extension StringExtensions on String {
  /// 截断到指定长度并添加省略号
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// 判断是否为有效的 URL
  bool get isValidUrl {
    final regex = RegExp(r'^https?://[^\s/$.?#].[^\s]*$', caseSensitive: false);
    return regex.hasMatch(this);
  }

  /// 提取文件的扩展名
  String get fileExtension {
    final lastDot = lastIndexOf('.');
    if (lastDot == -1) return '';
    return substring(lastDot + 1).toLowerCase();
  }

  /// 人性化文件大小
  String get humanReadableSize {
    final bytes = int.tryParse(this);
    if (bytes == null) return this;
    return bytes.humanReadableSize;
  }
}

extension IntExtensions on int {
  /// 人性化文件大小
  String get humanReadableSize {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  /// 人性化时间
  String get humanReadableDuration {
    if (this < 60) return '${this}s';
    if (this < 3600) return '${this ~/ 60}m';
    if (this < 86400) return '${this ~/ 3600}h ${(this % 3600) ~/ 60}m';
    return '${this ~/ 86400}d ${(this % 86400) ~/ 3600}h';
  }
}

extension DateTimeExtensions on DateTime {
  /// 相对时间描述
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} 个月前';
    return '${diff.inDays ~/ 365} 年前';
  }
}

extension DurationExtensions on Duration {
  /// 格式化为 HH:MM:SS
  String get toHHMMSS {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    if (inHours > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}
