import 'dart:async';
import 'package:bt_torrent/engine/pigeon/torrent_api.gen.dart';

/// Dart 端种子下载会话
class TorrentSession {
  final String infoHash;
  String name;
  final String? magnetUri;
  final String savePath;
  final StreamController<TorrentProgress> _progressController;
  final StreamController<SessionStatus> _statusController;

  TorrentProgress _progress = const TorrentProgress();
  SessionStatus _status = SessionStatus.queued;

  TorrentSession({
    required this.infoHash,
    required this.name,
    this.magnetUri,
    required this.savePath,
  })  : _progressController = StreamController<TorrentProgress>.broadcast(),
        _statusController = StreamController<SessionStatus>.broadcast();

  Stream<TorrentProgress> get progressStream => _progressController.stream;
  Stream<SessionStatus> get statusStream => _statusController.stream;

  TorrentProgress get currentProgress => _progress;
  SessionStatus get currentStatus => _status;

  void updateProgress(TorrentProgress progress) {
    _progress = progress;
    _progressController.add(progress);
  }

  /// 更新种子名称（元数据就绪后由原生端推送）
  void updateName(String newName) {
    if (newName.isEmpty || newName == name) return;
    name = newName;
    _statusController.add(_status);
  }

  /// 从 Pigeon 推送的进度数据更新会话
  void updateFromPigeon(DownloadProgressData data) {
    updateName(data.name);
    _progress = TorrentProgress(
      totalBytes: data.totalBytes,
      downloadedBytes: data.downloadedBytes,
      uploadBytes: data.uploadBytes,
      progressPercent: data.progressPercent,
      downloadSpeed: data.downloadSpeed,
      uploadSpeed: data.uploadSpeed,
      etaSeconds: data.etaSeconds,
      connectedPeers: data.connectedPeers,
      connectedSeeds: data.connectedSeeds,
    );
    _progressController.add(_progress);

    final newStatus = _statusFromCode(data.status);
    if (newStatus != _status) {
      updateStatus(newStatus);
    }
  }

  SessionStatus _statusFromCode(int code) {
    switch (code) {
      case 0:
        return SessionStatus.queued;
      case 1:
        return SessionStatus.checking;
      case 2:
        return SessionStatus.downloading;
      case 3:
        return SessionStatus.paused;
      case 4:
        return SessionStatus.seeding;
      case 5:
        return SessionStatus.completed;
      case 6:
        return SessionStatus.error;
      default:
        return _status;
    }
  }

  void updateStatus(SessionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void pause() {
    updateStatus(SessionStatus.paused);
  }

  void resume() {
    updateStatus(SessionStatus.downloading);
  }

  void close() {
    _progressController.close();
    _statusController.close();
  }
}

/// 下载进度
class TorrentProgress {
  final int totalBytes;
  final int downloadedBytes;
  final int uploadBytes;
  final double progressPercent;
  final int downloadSpeed;
  final int uploadSpeed;
  final int etaSeconds;
  final int connectedPeers;
  final int connectedSeeds;

  const TorrentProgress({
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.uploadBytes = 0,
    this.progressPercent = 0.0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.etaSeconds = 0,
    this.connectedPeers = 0,
    this.connectedSeeds = 0,
  });
}

/// 会话状态
enum SessionStatus {
  queued,
  checking,
  downloading,
  paused,
  seeding,
  completed,
  error;
}
