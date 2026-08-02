import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bt_torrent/core/models/playback_session.dart';
import 'package:bt_torrent/core/utils/error_text.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/magnet_parser.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/domain/repositories/playback_repository.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';
import 'package:bt_torrent/engine/torrent_session.dart';

/// 在线播放会话仓库实现
/// - 临时缓存目录：`<app cache>/bt_stream/<infoHash>`
/// - SharedPreferences 持久化记录，最多保留 2 个会话
class PlaybackRepositoryImpl implements PlaybackRepository {
  final TorrentEngine _engine;
  final AppLogger _logger = AppLogger('PlaybackRepo');

  static const _key = 'playback_sessions';
  static const int maxSessions = 2;

  final Map<String, PlaybackSession> _sessions = {};
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};
  final StreamController<List<PlaybackSession>> _controller =
      StreamController<List<PlaybackSession>>.broadcast();

  bool _restored = false;

  PlaybackRepositoryImpl(this._engine);

  // ===== 持久化 =====

  Future<void> _persist() async {
    try {
      final sorted = _sessions.values.toList()
        ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
      final trimmed = sorted.take(maxSessions).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(trimmed.map((s) => s.toJson()).toList()));
    } catch (e) {
      _logger.warning('保存播放会话失败: $e');
    }
  }

  @override
  Future<void> restoreSessions() async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final m in list.cast<Map<String, dynamic>>()) {
        final session = PlaybackSession.fromJson(m);
        if (session.infoHash.isNotEmpty) {
          _sessions[session.infoHash] = session;
        }
      }
      _logger.info('恢复 ${_sessions.length} 个播放会话');
      _emit();
    } catch (e) {
      _logger.warning('恢复播放会话失败: $e');
    }
  }

  // ===== 会话操作 =====

  @override
  Future<Result<PlaybackSession>> startPlayback(String magnetUri) async {
    await restoreSessions();
    try {
      final tempRoot = Directory(
          '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}bt_stream');
      await tempRoot.create(recursive: true);
      final infoHash = MagnetParser.extractInfoHash(magnetUri) ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final savePath =
          '${tempRoot.path}${Platform.pathSeparator}$infoHash';
      // 确保会话保存目录存在
      await Directory(savePath).create(recursive: true);

      final result =
          await _engine.startDownload(magnetUri, savePath, isStreaming: true);
      if (result.isError) {
        return Result.error(result.error!);
      }
      final session = result.value!;
      final filesResult = await _engine.getFiles(session.infoHash);
      final files = filesResult.value ?? const [];
      final now = DateTime.now();

      // 保留最近 2 个，淘汰最久未播放的
      await _evictIfNeeded(session.infoHash);

      final playback = PlaybackSession(
        infoHash: session.infoHash,
        name: session.name,
        magnetUri: magnetUri,
        savePath: savePath,
        files: files,
        totalBytes:
            files.fold<int>(0, (sum, f) => sum + f.sizeBytes),
        addedAt: now,
        lastPlayedAt: now,
      );
      _sessions[session.infoHash] = playback;
      _subscribe(session);
      await _persist();
      _emit();
      return Result.success(playback);
    } catch (e) {
      _logger.error('启动在线播放失败', e);
      return Result.error(friendlyError(e));
    }
  }

  @override
  Future<Result<PlaybackSession>> ensureSession(PlaybackSession session) async {
    await restoreSessions();
    try {
      var engineSession = _engine.getSession(session.infoHash);
      if (engineSession == null) {
        if (session.magnetUri == null) {
          return Result.error('会话缺少磁力链接，无法恢复');
        }
        final result = await _engine.startDownload(
          session.magnetUri!,
          session.savePath,
          isStreaming: true,
        );
        if (result.isError) {
          return Result.error(result.error!);
        }
        engineSession = result.value!;
      }

      final filesResult = await _engine.getFiles(session.infoHash);
      final files = filesResult.value ?? session.files;
      final updated = session.copyWith(
        name: engineSession.name == '获取种子信息中...'
            ? session.name
            : engineSession.name,
        files: files,
        totalBytes: files.fold<int>(0, (sum, f) => sum + f.sizeBytes),
      );
      _sessions[session.infoHash] = updated;
      _subscribe(engineSession);
      await _persist();
      _emit();
      return Result.success(updated);
    } catch (e) {
      _logger.error('恢复播放会话失败', e);
      return Result.error(friendlyError(e));
    }
  }

  @override
  PlaybackSession? getSession(String infoHash) => _sessions[infoHash];

  @override
  Future<List<PlaybackSession>> getSessions() async {
    await restoreSessions();
    return _sessions.values.toList()
      ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
  }

  @override
  Stream<List<PlaybackSession>> watchSessions() {
    // 先补发当前快照，再接实时推送，避免订阅时初始事件丢失
    return Stream.multi((listener) {
      final current = _sessions.values.toList()
        ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
      listener.add(current);
      _controller.stream.listen(listener.add);
    });
  }

  @override
  Future<void> markPlayed(String infoHash, {int fileIndex = 0}) async {
    final current = _sessions[infoHash];
    if (current == null) return;
    _sessions[infoHash] = current.copyWith(
      lastPlayedAt: DateTime.now(),
      lastFileIndex: fileIndex,
    );
    await _persist();
    _emit();
  }

  @override
  Future<void> removeSession(String infoHash) async {
    await restoreSessions();
    await _subscriptions[infoHash]?.cancel();
    _subscriptions.remove(infoHash);
    await _engine.removeDownload(infoHash, deleteFiles: true);
    _sessions.remove(infoHash);
    await _persist();
    _emit();
  }

  @override
  Future<void> forgetSession(String infoHash) async {
    await _subscriptions[infoHash]?.cancel();
    _subscriptions.remove(infoHash);
    _sessions.remove(infoHash);
    await _persist();
    _emit();
  }

  @override
  Future<void> clearAll() async {
    final hashes = _sessions.keys.toList();
    for (final hash in hashes) {
      await removeSession(hash);
    }
  }

  // ===== 内部 =====

  /// 超过 2 个会话时，淘汰最久未播放的（删除临时文件）
  Future<void> _evictIfNeeded(String newInfoHash) async {
    if (_sessions.length < maxSessions) return;
    final sorted = _sessions.values.toList()
      ..sort((a, b) => a.lastPlayedAt.compareTo(b.lastPlayedAt));
    final evict = sorted.firstWhere(
      (s) => s.infoHash != newInfoHash,
      orElse: () => sorted.first,
    );
    _logger.info('淘汰播放会话: ${evict.infoHash}');
    await _subscriptions[evict.infoHash]?.cancel();
    _subscriptions.remove(evict.infoHash);
    await _engine.removeDownload(evict.infoHash, deleteFiles: true);
    _sessions.remove(evict.infoHash);
  }

  void _subscribe(TorrentSession session) {
    _subscriptions[session.infoHash]?.cancel();
    _subscriptions[session.infoHash] = session.progressStream.listen((p) {
      final current = _sessions[session.infoHash];
      if (current == null) return;
      _sessions[session.infoHash] = current.copyWith(
        name: session.name == '获取种子信息中...'
            ? current.name
            : session.name,
        totalBytes:
            p.totalBytes > 0 ? p.totalBytes : current.totalBytes,
        downloadedBytes: p.downloadedBytes,
        progress: p.progressPercent,
      );
      _emit();
    });
  }

  void _emit() {
    final sorted = _sessions.values.toList()
      ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    if (!_controller.isClosed) {
      _controller.add(sorted);
    }
  }
}
