import 'package:bt_torrent/core/models/playback_session.dart';
import 'package:bt_torrent/core/utils/result.dart';

/// 在线播放会话仓库
abstract class PlaybackRepository {
  /// 根据磁力链接创建在线播放会话（阻塞等待元数据，最多约 60 秒）
  Future<Result<PlaybackSession>> startPlayback(String magnetUri);

  /// 确保会话的引擎会话存在（重启后需要重新挂载）
  Future<Result<PlaybackSession>> ensureSession(PlaybackSession session);

  /// 获取单个会话
  PlaybackSession? getSession(String infoHash);

  /// 所有会话（按最近播放排序）
  Future<List<PlaybackSession>> getSessions();

  /// 会话列表流
  Stream<List<PlaybackSession>> watchSessions();

  /// 记录播放时间（用于排序与淘汰）
  Future<void> markPlayed(String infoHash, {int fileIndex = 0});

  /// 删除会话（引擎任务 + 临时文件）
  Future<void> removeSession(String infoHash);

  /// 只移除播放记录（转存为下载任务后调用，保留引擎会话与文件）
  Future<void> forgetSession(String infoHash);

  /// 一键清理所有播放会话
  Future<void> clearAll();

  /// 启动时恢复持久化的播放会话记录
  Future<void> restoreSessions();
}
