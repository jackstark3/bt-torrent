import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/engine/http_stream_server.dart';
import 'package:bt_torrent/engine/piece_stream_source.dart';
import 'package:bt_torrent/engine/stream_manager.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';

/// 在线播放流媒体服务
/// 本地 HTTP 服务器 + piece 优先级滑动窗口的统一入口
class StreamingService {
  final TorrentEngine _engine;
  final HttpStreamServer _server;
  final AppLogger _logger = AppLogger('StreamingService');

  final Map<String, StreamManager> _managers = {};
  final Map<String, int> _refCounts = {};

  StreamingService(this._engine) : _server = HttpStreamServer();

  /// 开始在线播放：注册数据源、启动服务器、初始化优先级窗口
  /// 返回播放器可用的流 URL
  Future<String> startStreaming({
    required String infoHash,
    required int fileIndex,
    required List<TorrentFileInfo> files,
    required int pieceLength,
    required int numPieces,
  }) async {
    final port = await _server.start();

    if (!_server.hasSource(infoHash, fileIndex)) {
      _server.registerSource(
        infoHash,
        fileIndex,
        PieceStreamDataSource(
          engine: _engine,
          infoHash: infoHash,
          fileIndex: fileIndex,
          files: files,
          pieceLength: pieceLength,
          numPieces: numPieces,
        ),
      );
    }
    _refCounts[infoHash] = (_refCounts[infoHash] ?? 0) + 1;

    final manager = _managers.putIfAbsent(
        infoHash, () => StreamManager(_engine));
    await manager.initialize(
      infoHash: infoHash,
      totalPieces: numPieces,
      pieceSize: pieceLength,
    );
    _logger.info('开始在线播放: $infoHash #$fileIndex -> $port');
    return 'http://127.0.0.1:$port/stream/$infoHash/$fileIndex';
  }

  /// 播放位置前进
  Future<void> onPositionChanged(String infoHash, int piece) async {
    await _managers[infoHash]?.onPlaybackAdvanced(infoHash, piece);
  }

  /// 拖拽跳转
  Future<void> onSeek(String infoHash, int piece) async {
    await _managers[infoHash]?.onSeek(infoHash, piece);
  }

  /// 结束在线播放（某个文件或整个会话）
  Future<void> stopStreaming(String infoHash, {int? fileIndex}) async {
    if (fileIndex != null) {
      _server.unregisterSource(infoHash, fileIndex);
      final count = (_refCounts[infoHash] ?? 1) - 1;
      if (count > 0) {
        _refCounts[infoHash] = count;
        return;
      }
    }

    final manager = _managers.remove(infoHash);
    if (manager != null) {
      try {
        await manager.restoreDefaults(infoHash);
      } catch (e) {
        _logger.warning('恢复默认优先级失败: $e');
      }
    }
    _refCounts.remove(infoHash);

    if (_server.activeSourceCount == 0) {
      await _server.stop();
    }
  }
}
