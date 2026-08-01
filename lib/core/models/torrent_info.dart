/// 种子元数据
class TorrentInfo {
  final String title;
  final String infoHash;
  final String? magnetUri;
  final String? torrentUrl;
  final int sizeBytes;
  final int seeders;
  final int leechers;
  final int? completedDownloads;
  final TorrentCategory? category;
  final String sourceProvider;
  final String? detailUrl;
  final String? posterUrl;
  final DateTime? addedDate;
  final bool isVerified;

  const TorrentInfo({
    required this.title,
    required this.infoHash,
    this.magnetUri,
    this.torrentUrl,
    required this.sizeBytes,
    required this.seeders,
    required this.leechers,
    this.completedDownloads,
    this.category,
    required this.sourceProvider,
    this.detailUrl,
    this.posterUrl,
    this.addedDate,
    this.isVerified = false,
  });

  String get sizeFormatted {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = sizeBytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String get seedersFormatted => seeders >= 1000 ? '${(seeders / 1000).toStringAsFixed(1)}K' : '$seeders';
  String get leechersFormatted => leechers >= 1000 ? '${(leechers / 1000).toStringAsFixed(1)}K' : '$leechers';

  /// 健康度分数 0-100，基于做种/下载比例
  int get healthScore {
    if (seeders == 0) return 0;
    final ratio = seeders / (leechers + 1);
    return (ratio * 20).clamp(0, 100).toInt();
  }

  @override
  bool operator ==(Object other) =>
      other is TorrentInfo && other.infoHash == infoHash;

  @override
  int get hashCode => infoHash.hashCode;
}

/// 种子分类
enum TorrentCategory {
  movies,
  tv,
  music,
  games,
  software,
  anime,
  xxx,
  other;

  String get displayName {
    switch (this) {
      case TorrentCategory.movies:
        return '电影';
      case TorrentCategory.tv:
        return '剧集';
      case TorrentCategory.music:
        return '音乐';
      case TorrentCategory.games:
        return '游戏';
      case TorrentCategory.software:
        return '软件';
      case TorrentCategory.anime:
        return '动漫';
      case TorrentCategory.xxx:
        return 'XXX';
      case TorrentCategory.other:
        return '其他';
    }
  }

  String get apiName {
    switch (this) {
      case TorrentCategory.movies:
        return 'movies';
      case TorrentCategory.tv:
        return 'tv';
      case TorrentCategory.music:
        return 'music';
      case TorrentCategory.games:
        return 'games';
      case TorrentCategory.software:
        return 'apps';
      case TorrentCategory.anime:
        return 'anime';
      case TorrentCategory.xxx:
        return 'xxx';
      case TorrentCategory.other:
        return 'other';
    }
  }
}

/// 排序方式
enum SortBy {
  seeders,
  leechers,
  size,
  date,
  relevance;

  String get displayName {
    switch (this) {
      case SortBy.seeders:
        return '做种数';
      case SortBy.leechers:
        return '下载数';
      case SortBy.size:
        return '文件大小';
      case SortBy.date:
        return '发布时间';
      case SortBy.relevance:
        return '相关度';
    }
  }
}
