import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/models/playback_session.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/domain/repositories/download_repository.dart';
import 'package:bt_torrent/domain/repositories/playback_repository.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';

/// 启动在线播放（阻塞等待元数据，最多约 60 秒）
class StartPlaybackUseCase {
  final PlaybackRepository _repository;
  const StartPlaybackUseCase(this._repository);

  Future<Result<PlaybackSession>> execute(String magnetUri) {
    return _repository.startPlayback(magnetUri);
  }
}

/// 确保播放会话的引擎会话可用（重启后重新挂载）
class EnsurePlaybackSessionUseCase {
  final PlaybackRepository _repository;
  const EnsurePlaybackSessionUseCase(this._repository);

  Future<Result<PlaybackSession>> execute(PlaybackSession session) {
    return _repository.ensureSession(session);
  }
}

/// 记录播放时间与上次播放的文件
class MarkPlayedUseCase {
  final PlaybackRepository _repository;
  const MarkPlayedUseCase(this._repository);

  Future<void> execute(String infoHash, {int fileIndex = 0}) {
    return _repository.markPlayed(infoHash, fileIndex: fileIndex);
  }
}

/// 删除播放会话（含临时文件）
class RemovePlaybackSessionUseCase {
  final PlaybackRepository _repository;
  const RemovePlaybackSessionUseCase(this._repository);

  Future<void> execute(String infoHash) => _repository.removeSession(infoHash);
}

/// 一键清理所有播放会话
class ClearPlaybackSessionsUseCase {
  final PlaybackRepository _repository;
  const ClearPlaybackSessionsUseCase(this._repository);

  Future<void> execute() => _repository.clearAll();
}

/// 在线播放转存为正式下载任务
class ConvertPlaybackToDownloadUseCase {
  final PlaybackRepository playbackRepository;
  final DownloadRepository downloadRepository;
  final TorrentEngine engine;

  const ConvertPlaybackToDownloadUseCase({
    required this.playbackRepository,
    required this.downloadRepository,
    required this.engine,
  });

  Future<Result<DownloadTask>> execute(String infoHash) async {
    final session = playbackRepository.getSession(infoHash);
    if (session == null) {
      return Result.error('播放会话不存在');
    }

    // 引擎会话可能已被清理（重启后），先重新挂载
    if (engine.getSession(infoHash) == null) {
      final ensured = await playbackRepository.ensureSession(session);
      if (ensured.isError) {
        return Result.error(ensured.error!);
      }
    }

    final converted = await engine.convertToDownload(infoHash);
    if (converted.isError) {
      return Result.error(converted.error!);
    }

    final adopted = await downloadRepository.adoptSession(infoHash);
    if (adopted.isError) {
      return Result.error(adopted.error!);
    }

    // 从最近播放移除记录（保留文件与引擎会话，任务继续下载）
    await playbackRepository.forgetSession(infoHash);
    return adopted;
  }
}
