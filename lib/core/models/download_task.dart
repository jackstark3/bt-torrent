/// 下载任务状态
class DownloadTask {
  final String infoHash;
  final String name;
  final String? magnetUri;
  final int totalBytes;
  final int downloadedBytes;
  final int uploadBytes;
  final double progress; // 0.0 ~ 1.0
  final int downloadSpeed; // bytes/sec
  final int uploadSpeed; // bytes/sec
  final int etaSeconds;
  final DownloadStatus status;
  final int connectedPeers;
  final int connectedSeeds;
  final List<TorrentFileInfo> files;
  final DateTime addedAt;
  final String savePath;

  const DownloadTask({
    required this.infoHash,
    required this.name,
    this.magnetUri,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.uploadBytes = 0,
    this.progress = 0.0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.etaSeconds = 0,
    this.status = DownloadStatus.paused,
    this.connectedPeers = 0,
    this.connectedSeeds = 0,
    this.files = const [],
    required this.addedAt,
    required this.savePath,
  });

  DownloadTask copyWith({
    String? infoHash,
    String? name,
    String? magnetUri,
    int? totalBytes,
    int? downloadedBytes,
    int? uploadBytes,
    double? progress,
    int? downloadSpeed,
    int? uploadSpeed,
    int? etaSeconds,
    DownloadStatus? status,
    int? connectedPeers,
    int? connectedSeeds,
    List<TorrentFileInfo>? files,
    DateTime? addedAt,
    String? savePath,
  }) {
    return DownloadTask(
      infoHash: infoHash ?? this.infoHash,
      name: name ?? this.name,
      magnetUri: magnetUri ?? this.magnetUri,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      uploadBytes: uploadBytes ?? this.uploadBytes,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      status: status ?? this.status,
      connectedPeers: connectedPeers ?? this.connectedPeers,
      connectedSeeds: connectedSeeds ?? this.connectedSeeds,
      files: files ?? this.files,
      addedAt: addedAt ?? this.addedAt,
      savePath: savePath ?? this.savePath,
    );
  }

  String get progressFormatted => '${(progress * 100).toStringAsFixed(1)}%';

  String get speedFormatted => _formatSpeed(downloadSpeed);

  String get etaFormatted {
    if (etaSeconds <= 0) return '--';
    if (etaSeconds < 60) return '${etaSeconds}s';
    if (etaSeconds < 3600) return '${etaSeconds ~/ 60}m';
    if (etaSeconds < 86400) {
      return '${etaSeconds ~/ 3600}h ${(etaSeconds % 3600) ~/ 60}m';
    }
    return '${etaSeconds ~/ 86400}d ${(etaSeconds % 86400) ~/ 3600}h';
  }

  String get sizeFormatted => _formatSize(totalBytes);
  String get downloadedFormatted => _formatSize(downloadedBytes);

  static String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  static String _formatSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

enum DownloadStatus {
  paused,
  downloading,
  seeding,
  completed,
  error,
  checking,
  queued;

  String get displayName {
    switch (this) {
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.seeding:
        return '做种中';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.error:
        return '错误';
      case DownloadStatus.checking:
        return '校验中';
      case DownloadStatus.queued:
        return '排队中';
    }
  }
}

/// 种子内文件信息
class TorrentFileInfo {
  final int index;
  final String path;
  final String name;
  final int sizeBytes;
  final bool selected;

  const TorrentFileInfo({
    required this.index,
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.selected = true,
  });

  bool get isVideo {
    final ext = name.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v'].contains(ext);
  }

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
}
