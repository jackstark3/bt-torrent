import 'download_task.dart';

/// 在线播放会话
/// 基于磁力链接的临时缓存会话，保留最近 1-2 个，可一键清理。
/// 不进入下载管理列表，下载完成也不导出到公共目录。
class PlaybackSession {
  final String infoHash;
  final String name;
  final String? magnetUri;
  final String savePath;
  final List<TorrentFileInfo> files;
  final int lastFileIndex;
  final int totalBytes;
  final int downloadedBytes;
  final double progress; // 0.0 ~ 1.0
  final DateTime addedAt;
  final DateTime lastPlayedAt;

  const PlaybackSession({
    required this.infoHash,
    required this.name,
    this.magnetUri,
    required this.savePath,
    this.files = const [],
    this.lastFileIndex = 0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.progress = 0.0,
    required this.addedAt,
    required this.lastPlayedAt,
  });

  List<TorrentFileInfo> get videoFiles => files.where((f) => f.isVideo).toList();

  PlaybackSession copyWith({
    String? name,
    List<TorrentFileInfo>? files,
    int? lastFileIndex,
    int? totalBytes,
    int? downloadedBytes,
    double? progress,
    DateTime? lastPlayedAt,
  }) {
    return PlaybackSession(
      infoHash: infoHash,
      name: name ?? this.name,
      magnetUri: magnetUri,
      savePath: savePath,
      files: files ?? this.files,
      lastFileIndex: lastFileIndex ?? this.lastFileIndex,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      progress: progress ?? this.progress,
      addedAt: addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  String get progressFormatted => '${(progress * 100).toStringAsFixed(0)}%';

  String get sizeFormatted {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = totalBytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  Map<String, dynamic> toJson() {
    return {
      'infoHash': infoHash,
      'name': name,
      'magnetUri': magnetUri,
      'savePath': savePath,
      'files': files
          .map((f) => {
                'index': f.index,
                'path': f.path,
                'name': f.name,
                'sizeBytes': f.sizeBytes,
              })
          .toList(),
      'lastFileIndex': lastFileIndex,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'progress': progress,
      'addedAt': addedAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
    };
  }

  factory PlaybackSession.fromJson(Map<String, dynamic> map) {
    final files = (map['files'] as List<dynamic>? ?? [])
        .map((f) => TorrentFileInfo(
              index: f['index'] as int? ?? 0,
              path: f['path'] as String? ?? '',
              name: f['name'] as String? ?? '',
              sizeBytes: f['sizeBytes'] as int? ?? 0,
            ))
        .toList();
    return PlaybackSession(
      infoHash: map['infoHash'] as String? ?? '',
      name: map['name'] as String? ?? '在线播放',
      magnetUri: map['magnetUri'] as String?,
      savePath: map['savePath'] as String? ?? '',
      files: files,
      lastFileIndex: map['lastFileIndex'] as int? ?? 0,
      totalBytes: map['totalBytes'] as int? ?? 0,
      downloadedBytes: map['downloadedBytes'] as int? ?? 0,
      progress: (map['progress'] as num? ?? 0.0).toDouble(),
      addedAt:
          DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
      lastPlayedAt:
          DateTime.tryParse(map['lastPlayedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
