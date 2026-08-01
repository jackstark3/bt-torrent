import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/utils/result.dart';

/// 下载仓库接口
abstract class DownloadRepository {
  /// 启动下载
  Future<Result<DownloadTask>> startDownload(String magnetUri, String savePath);

  /// 采纳一个已存在的引擎会话为正式下载任务（在线播放转存用）
  Future<Result<DownloadTask>> adoptSession(String infoHash);

  /// 暂停下载
  Future<Result<void>> pauseDownload(String infoHash);

  /// 恢复下载
  Future<Result<void>> resumeDownload(String infoHash);

  /// 移除下载
  Future<Result<void>> removeDownload(String infoHash, {bool deleteFiles = false});

  /// 获取下载进度流
  Stream<DownloadTask> watchProgress(String infoHash);

  /// 获取所有下载任务
  Future<List<DownloadTask>> getAllDownloads();

  /// 获取所有下载任务流
  Stream<List<DownloadTask>> watchAllDownloads();

  /// 设置 piece 优先级
  Future<Result<void>> setPiecePriority(
    String infoHash,
    int pieceIndex,
    int priority,
  );

  /// 获取已下载的 piece 数据
  Future<Result<List<int>>> readPiece(String infoHash, int pieceIndex);

  /// 获取种子内文件列表
  Future<Result<List<TorrentFileInfo>>> getFiles(String infoHash);
}
