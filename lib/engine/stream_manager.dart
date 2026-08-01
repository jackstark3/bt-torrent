import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';

/// Piece 优先级常量
class PiecePriority {
  static const int ignore = 0;
  static const int normal = 1;
  static const int low = 2;
  static const int medium = 4;
  static const int high = 5;
  static const int veryHigh = 6;
  static const int maximum = 7;
}

/// 流媒体 piece 管理器
/// 实现滑动窗口优先级算法，确保播放位置周围的 piece 优先下载
class StreamManager {
  final TorrentEngine _engine;
  final AppLogger _logger = AppLogger('StreamManager');

  /// 当前播放的 piece 索引
  int _currentPiece = 0;

  /// 总 piece 数
  int _totalPieces = 0;

  /// 每个 piece 的大小 (bytes)
  int _pieceSize = 0;

  /// 滑动窗口配置
  static const int _windowSize = 80; // 预取窗口
  static const int _criticalWindow = 3; // 紧急窗口
  static const int _highPriorityWindow = 8; // 高优先级窗口

  StreamManager(this._engine);

  /// 初始化流媒体，设置初始 piece 优先级
  Future<void> initialize({
    required String infoHash,
    required int totalPieces,
    required int pieceSize,
    int startPiece = 0,
  }) async {
    _totalPieces = totalPieces;
    _pieceSize = pieceSize;
    _currentPiece = startPiece;

    _logger.info('初始化流媒体: $totalPieces pieces, ${pieceSize}bytes/piece');
    await _updatePriorities(infoHash);
  }

  /// 当播放位置前进时调用
  Future<void> onPlaybackAdvanced(String infoHash, int newPiece) async {
    if (newPiece == _currentPiece) return;
    _currentPiece = newPiece;
    await _updatePriorities(infoHash);
  }

  /// 当用户拖拽到新位置时调用
  Future<void> onSeek(String infoHash, int targetPiece) async {
    _logger.info('拖拽到 piece $targetPiece');
    _currentPiece = targetPiece;

    // 清除所有 deadline
    // await _engine.clearPieceDeadlines(infoHash);

    await _updatePriorities(infoHash);
  }

  /// 更新滑动窗口内的 piece 优先级
  Future<void> _updatePriorities(String infoHash) async {
    for (int i = 0; i < _totalPieces; i++) {
      final distance = i - _currentPiece;
      final priority = _calculatePriority(distance);

      if (priority > 0) {
        await _engine.setPiecePriority(infoHash, i, priority);
      }
    }
  }

  /// 根据距离计算优先级
  int _calculatePriority(int distanceFromCurrent) {
    if (distanceFromCurrent < 0) {
      // 已过去的 piece，仅保留短距离的
      if (distanceFromCurrent >= -2) return PiecePriority.normal;
      return PiecePriority.ignore;
    }

    if (distanceFromCurrent < _criticalWindow) {
      return PiecePriority.maximum; // 7 - 立即需要
    }
    if (distanceFromCurrent < _highPriorityWindow) {
      return PiecePriority.veryHigh; // 6 - 马上需要
    }
    if (distanceFromCurrent < 20) {
      return PiecePriority.high; // 5
    }
    if (distanceFromCurrent < 50) {
      return PiecePriority.medium; // 4
    }
    if (distanceFromCurrent < _windowSize) {
      return PiecePriority.normal; // 1 - 普通预取
    }

    return PiecePriority.ignore; // 0 - 太远，暂不下载
  }

  /// 检查是否有足够的缓冲开始播放
  bool canStartPlayback(int downloadedPieces) {
    final required = (_totalPieces * 0.05).ceil(); // 5%
    final minPieces = (20 * 1024 * 1024 / _pieceSize).ceil(); // 20MB worth
    final threshold = required > minPieces ? required : minPieces;
    return downloadedPieces >= threshold;
  }

  /// 获取当前播放位置
  int get currentPiece => _currentPiece;

  /// 获取总 piece 数
  int get totalPieces => _totalPieces;
}
