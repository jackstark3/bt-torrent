import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/domain/repositories/download_repository.dart';

/// 启动下载用例
class StartDownloadUseCase {
  final DownloadRepository _repository;
  const StartDownloadUseCase(this._repository);

  Future<Result<DownloadTask>> execute(String magnetUri, String savePath) {
    return _repository.startDownload(magnetUri, savePath);
  }
}

/// 暂停下载用例
class PauseDownloadUseCase {
  final DownloadRepository _repository;
  const PauseDownloadUseCase(this._repository);

  Future<Result<void>> execute(String infoHash) => _repository.pauseDownload(infoHash);
}

/// 恢复下载用例
class ResumeDownloadUseCase {
  final DownloadRepository _repository;
  const ResumeDownloadUseCase(this._repository);

  Future<Result<void>> execute(String infoHash) => _repository.resumeDownload(infoHash);
}

/// 移除下载用例
class RemoveDownloadUseCase {
  final DownloadRepository _repository;
  const RemoveDownloadUseCase(this._repository);

  Future<Result<void>> execute(String infoHash, {bool deleteFiles = false}) {
    return _repository.removeDownload(infoHash, deleteFiles: deleteFiles);
  }
}

/// 监控下载进度用例
class WatchDownloadProgressUseCase {
  final DownloadRepository _repository;
  const WatchDownloadProgressUseCase(this._repository);

  Stream<DownloadTask> execute(String infoHash) => _repository.watchProgress(infoHash);
}

/// 获取所有下载用例
class GetAllDownloadsUseCase {
  final DownloadRepository _repository;
  const GetAllDownloadsUseCase(this._repository);

  Future<List<DownloadTask>> execute() => _repository.getAllDownloads();
}
