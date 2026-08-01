import 'dart:math';

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
/// 滑动窗口优先级算法：播放位置周围优先下载，
/// 同时始终优先文件尾部（MP4 moov / MKV cues 等元数据）。
class StreamManager {
  final TorrentEngine _engine;
  final AppLogger _logger = AppLogger('StreamManager');

  /// 当前播放的 piece 索引
  int _currentPiece = 0;

  /// 总 piece 数
  int _totalPieces = 0;

  /// 每个 piece 的大小 (bytes)
  int _pieceSize = 0;

  /// 已设置过优先级的 piece（退出时恢复默认）
  final Set<int> _changed = {};

  /// 滑动窗口配置
  static const int _windowSize = 80; // 预取窗口
  static const int _criticalWindow = 3; // 紧急窗口
  static const int _highPriorityWindow = 8; // 高优先级窗口
  static const int _tailPieces = 10; // 尾部元数据 piece 数

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
    await _prioritizeTail(infoHash);
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
    await _updatePriorities(infoHash);
  }

  /// 恢复默认优先级（播放结束后调用，让后台顺序下载继续）
  Future<void> restoreDefaults(String infoHash) async {
    for (final i in _changed) {
      await _engine.setPiecePriority(infoHash, i, PiecePriority.normal);
    }
    _changed.clear();
  }

  /// 更新滑动窗口内的 piece 优先级
  Future<void> _updatePriorities(String infoHash) async {
    final first = max(0, _currentPiece - 2);
    final last = min(_totalPieces - 1, _currentPiece + _windowSize);
    for (int i = first; i <= last; i++) {
      final priority = _calculatePriority(i - _currentPiece);
      if (priority > 0) {
        await _setPriority(infoHash, i, priority);
      }
    }
  }

  /// 始终优先尾部元数据 piece（moov/cues 常在文件末尾）
  Future<void> _prioritizeTail(String infoHash) async {
    for (int i = max(0, _totalPieces - _tailPieces); i < _totalPieces; i++) {
      await _setPriority(infoHash, i, PiecePriority.maximum);
    }
  }

  Future<void> _setPriority(
    String infoHash,
    int pieceIndex,
    int priority,
  ) async {
    if (pieceIndex < 0 || pieceIndex >= _totalPieces) return;
    final result =
        await _engine.setPiecePriority(infoHash, pieceIndex, priority);
    if (result.isSuccess) {
      _changed.add(pieceIndex);
    }
  }

  /// 根据距离计算优先级
  int _calculatePriority(int distanceFromCurrent) {
    if (distanceFromCurrent < 0) {
      // 已过去的 piece，仅保留短距离的
      if (distanceFromCurrent >= -2) return PiecePriority.normal;
      return 0; // 不设置（保持默认）
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

    return 0; // 太远，不设置（保持默认顺序）
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
