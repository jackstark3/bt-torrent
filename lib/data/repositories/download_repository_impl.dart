import 'dart:async';
import 'dart:convert';

import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/domain/repositories/download_repository.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';
import 'package:bt_torrent/engine/torrent_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 下载仓库实现（对接 Pigeon 原生 BT 引擎）
/// 任务清单持久化到本地，重启后自动恢复（未完成任务续传）
class DownloadRepositoryImpl implements DownloadRepository {
  final TorrentEngine _engine;
  final AppLogger _logger = AppLogger('DownloadRepo');
  final Map<String, StreamController<DownloadTask>> _controllers = {};
  final Map<String, DateTime> _addedAt = {};
  final Map<String, DownloadTask> _completedTasks = {};
  final Map<String, DownloadTask> _restoringTasks = {};
  final Map<String, double> _lastPersistedProgress = {};
  final Map<String, DateTime> _lastPersistTime = {};

  static const _tasksKey = 'download_tasks';

  DownloadRepositoryImpl(this._engine);

  // ===== 持久化 =====

  Future<List<Map<String, dynamic>>> _loadPersistedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tasksKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.warning('读取任务清单失败: $e');
      return [];
    }
  }

  Future<void> _savePersistedTasks(List<Map<String, dynamic>> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tasksKey, jsonEncode(tasks));
    } catch (e) {
      _logger.warning('保存任务清单失败: $e');
    }
  }

  Future<void> _upsertPersistedTask(
    String infoHash, {
    String? name,
    String? magnetUri,
    String? savePath,
    bool? completed,
    List<TorrentFileInfo>? files,
    double? progress,
    int? totalBytes,
  }) async {
    final tasks = await _loadPersistedTasks();
    final index = tasks.indexWhere((t) => t['infoHash'] == infoHash);
    final map = index >= 0
        ? Map<String, dynamic>.from(tasks[index])
        : <String, dynamic>{
            'infoHash': infoHash,
            'addedAt': DateTime.now().toIso8601String(),
          };
    if (name != null) map['name'] = name;
    if (magnetUri != null) map['magnetUri'] = magnetUri;
    if (savePath != null) map['savePath'] = savePath;
    if (completed != null) map['completed'] = completed;
    if (files != null) {
      map['files'] = files
          .map((f) => {
                'index': f.index,
                'path': f.path,
                'name': f.name,
                'sizeBytes': f.sizeBytes,
              })
          .toList();
    }
    if (progress != null) map['progress'] = progress;
    if (totalBytes != null) map['totalBytes'] = totalBytes;
    if (index >= 0) {
      tasks[index] = map;
    } else {
      tasks.add(map);
    }
    await _savePersistedTasks(tasks);
  }

  Future<void> _removePersistedTask(String infoHash) async {
    final tasks = await _loadPersistedTasks();
    tasks.removeWhere((t) => t['infoHash'] == infoHash);
    await _savePersistedTasks(tasks);
  }

  /// 启动时恢复任务：已完成直接显示，未完成重新添加续传
  Future<void> restoreDownloads() async {
    final tasks = await _loadPersistedTasks();
    if (tasks.isEmpty) return;
    _logger.info('恢复 ${tasks.length} 个下载任务');

    for (final map in tasks) {
      final infoHash = map['infoHash'] as String?;
      final magnetUri = map['magnetUri'] as String?;
      final savePath = map['savePath'] as String?;
      if (infoHash == null || magnetUri == null || savePath == null) continue;

      if (map['completed'] == true) {
        // 已完成任务：文件已导出到公共下载目录
        _completedTasks[infoHash] = _taskFromPersisted(map);
      } else {
        // 未完成任务：立即显示"恢复中"（含上次进度），后台并行续传
        _restoringTasks[infoHash] = _taskFromPersisted(map, restoring: true);
        unawaited(_restoreOne(magnetUri, savePath));
      }
    }
  }

  /// 后台恢复单个任务（引擎校验已有文件后自动续传）
  Future<void> _restoreOne(String magnetUri, String savePath) async {
    final result = await startDownload(magnetUri, savePath);
    if (result.isError) {
      _logger.warning('恢复任务失败: ${result.error}');
    }
  }

  DownloadTask _taskFromPersisted(
    Map<String, dynamic> map, {
    bool restoring = false,
  }) {
    final files = (map['files'] as List<dynamic>? ?? [])
        .map((f) => TorrentFileInfo(
              index: f['index'] as int? ?? 0,
              path: f['path'] as String? ?? '',
              name: f['name'] as String? ?? '',
              sizeBytes: f['sizeBytes'] as int? ?? 0,
            ))
        .toList();
    final filesTotal = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final totalBytes = map['totalBytes'] as int? ?? filesTotal;
    return DownloadTask(
      infoHash: map['infoHash'] as String? ?? '',
      name: map['name'] as String? ?? '已完成下载',
      magnetUri: map['magnetUri'] as String?,
      totalBytes: totalBytes,
      downloadedBytes: restoring
          ? ((map['progress'] as num? ?? 0.0) * totalBytes).round()
          : files.fold<int>(0, (sum, f) => sum + f.sizeBytes),
      progress: restoring ? (map['progress'] as num? ?? 0.0).toDouble() : 1.0,
      status: restoring ? DownloadStatus.checking : DownloadStatus.completed,
      files: files,
      addedAt: DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
      savePath: map['savePath'] as String? ?? '',
    );
  }

  // ===== 下载操作 =====

  @override
  Future<Result<DownloadTask>> startDownload(
    String magnetUri,
    String savePath,
  ) async {
    _logger.info('启动下载: $magnetUri -> $savePath');

    final result = await _engine.startDownload(magnetUri, savePath);
    if (result.isError) {
      return Result.error(result.error!);
    }

    final session = result.value!;
    return _registerSession(session);
  }

  /// 采纳已存在的引擎会话为正式下载任务（在线播放转存）
  @override
  Future<Result<DownloadTask>> adoptSession(String infoHash) async {
    final session = _engine.getSession(infoHash);
    if (session == null) {
      return Result.error('引擎会话不存在: $infoHash');
    }
    _logger.info('采纳会话为下载任务: $infoHash');
    return _registerSession(session);
  }

  /// 注册会话到下载管理（任务记录、控制器、持久化、进度订阅）
  Future<Result<DownloadTask>> _registerSession(TorrentSession session) async {
    final now = DateTime.now();
    _addedAt[session.infoHash] = now;
    _completedTasks.remove(session.infoHash);
    _restoringTasks.remove(session.infoHash);

    final task = _taskFromSession(session, now);
    final controller = StreamController<DownloadTask>.broadcast();
    _controllers[session.infoHash] = controller;
    controller.add(task);

    // 持久化任务记录
    await _upsertPersistedTask(
      session.infoHash,
      name: session.name,
      magnetUri: session.magnetUri,
      savePath: session.savePath,
      completed: false,
    );

    // 订阅引擎进度/状态流
    session.progressStream.listen((progress) {
      _updateTask(_taskFromSession(session, now));
      _maybePersistProgress(session);
    });
    session.statusStream.listen((status) async {
      _updateTask(_taskFromSession(session, now));
      if (status == SessionStatus.completed) {
        await _markCompleted(session);
      } else {
        await _upsertPersistedTask(session.infoHash, name: session.name);
      }
    });

    return Result.success(task);
  }

  /// 标记任务完成：拉取文件列表并持久化
  Future<void> _markCompleted(TorrentSession session) async {
    _logger.info('下载完成: ${session.infoHash}');
    final filesResult = await _engine.getFiles(session.infoHash);
    await _upsertPersistedTask(
      session.infoHash,
      name: session.name,
      completed: true,
      files: filesResult.value ?? [],
    );
    // 让 UI 能拿到已完成状态
    _updateTask(_taskFromSession(session, _addedAt[session.infoHash] ?? DateTime.now()));
  }

  /// 节流持久化进度（每 5% 或 10 秒写一次，重启后能显示上次进度）
  Future<void> _maybePersistProgress(TorrentSession session) async {
    final progress = session.currentProgress.progressPercent;
    final last = _lastPersistedProgress[session.infoHash] ?? -1.0;
    final lastTime = _lastPersistTime[session.infoHash] ?? DateTime(2000);
    if ((progress - last) >= 0.05 ||
        DateTime.now().difference(lastTime).inSeconds >= 10) {
      _lastPersistedProgress[session.infoHash] = progress;
      _lastPersistTime[session.infoHash] = DateTime.now();
      await _upsertPersistedTask(
        session.infoHash,
        name: session.name,
        progress: progress,
        totalBytes: session.currentProgress.totalBytes,
      );
    }
  }

  @override
  Future<Result<void>> pauseDownload(String infoHash) async {
    _logger.info('暂停: $infoHash');
    return _engine.pauseDownload(infoHash);
  }

  @override
  Future<Result<void>> resumeDownload(String infoHash) async {
    _logger.info('恢复: $infoHash');
    return _engine.resumeDownload(infoHash);
  }

  @override
  Future<Result<void>> removeDownload(
    String infoHash, {
    bool deleteFiles = false,
  }) async {
    _logger.info('移除: $infoHash, deleteFiles=$deleteFiles');
    final result =
        await _engine.removeDownload(infoHash, deleteFiles: deleteFiles);
    await _controllers[infoHash]?.close();
    _controllers.remove(infoHash);
    _addedAt.remove(infoHash);
    _completedTasks.remove(infoHash);
    await _removePersistedTask(infoHash);
    return result;
  }

  @override
  Stream<DownloadTask> watchProgress(String infoHash) {
    final existing = _controllers[infoHash];
    final controller = existing ?? _createController(infoHash);

    // 先补发当前快照，再接实时推送，避免初始事件丢失导致一直 loading
    return Stream.multi((listener) {
      final current = _currentTask(infoHash);
      if (current != null) listener.add(current);
      controller.stream.listen(listener.add);
    });
  }

  StreamController<DownloadTask> _createController(String infoHash) {
    final controller = StreamController<DownloadTask>.broadcast();
    _controllers[infoHash] = controller;
    return controller;
  }

  /// 当前任务快照（已完成 > 引擎实时 > 恢复中）
  DownloadTask? _currentTask(String infoHash) {
    final completed = _completedTasks[infoHash];
    if (completed != null) return completed;
    final restoring = _restoringTasks[infoHash];
    if (restoring != null) return restoring;
    final session = _engine.getSession(infoHash);
    if (session != null) {
      return _taskFromSession(session, _addedAt[infoHash] ?? DateTime.now());
    }
    return null;
  }

  @override
  Future<List<DownloadTask>> getAllDownloads() async {
    final now = DateTime.now();
    final merged = <String, DownloadTask>{};
    // 优先级：引擎实时任务 > 恢复中 > 已完成
    for (final s in _engine.getAllSessions()) {
      merged[s.infoHash] = _taskFromSession(s, now);
    }
    for (final e in _restoringTasks.entries) {
      merged.putIfAbsent(e.key, () => e.value);
    }
    for (final e in _completedTasks.entries) {
      merged.putIfAbsent(e.key, () => e.value);
    }
    return merged.values.toList();
  }

  @override
  Stream<List<DownloadTask>> watchAllDownloads() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) => getAllDownloads(),
    ).asyncMap((future) => future);
  }

  @override
  Future<Result<void>> setPiecePriority(
    String infoHash,
    int pieceIndex,
    int priority,
  ) {
    return _engine.setPiecePriority(infoHash, pieceIndex, priority);
  }

  @override
  Future<Result<List<int>>> readPiece(
    String infoHash,
    int pieceIndex,
  ) {
    return _engine.readPiece(infoHash, pieceIndex);
  }

  @override
  Future<Result<List<TorrentFileInfo>>> getFiles(String infoHash) {
    return _engine.getFiles(infoHash);
  }

  DownloadTask _taskFromSession(TorrentSession session, DateTime addedAt) {
    final progress = session.currentProgress;
    final status = _mapStatus(session.currentStatus);
    final isComplete = status == DownloadStatus.completed ||
        status == DownloadStatus.seeding ||
        progress.progressPercent >= 1.0;
    return DownloadTask(
      infoHash: session.infoHash,
      name: session.name,
      magnetUri: session.magnetUri,
      totalBytes: progress.totalBytes,
      downloadedBytes: progress.downloadedBytes,
      uploadBytes: progress.uploadBytes,
      progress: progress.progressPercent,
      // 完成后速度清零，避免残留瞬时值造成困惑
      downloadSpeed: isComplete ? 0 : progress.downloadSpeed,
      uploadSpeed: isComplete ? 0 : progress.uploadSpeed,
      etaSeconds: progress.etaSeconds,
      status: status,
      connectedPeers: progress.connectedPeers,
      connectedSeeds: progress.connectedSeeds,
      addedAt: addedAt,
      savePath: session.savePath,
    );
  }

  DownloadStatus _mapStatus(SessionStatus status) {
    switch (status) {
      case SessionStatus.queued:
        return DownloadStatus.queued;
      case SessionStatus.checking:
        return DownloadStatus.checking;
      case SessionStatus.downloading:
        return DownloadStatus.downloading;
      case SessionStatus.paused:
        return DownloadStatus.paused;
      case SessionStatus.seeding:
        return DownloadStatus.seeding;
      case SessionStatus.completed:
        return DownloadStatus.completed;
      case SessionStatus.error:
        return DownloadStatus.error;
    }
  }

  void _updateTask(DownloadTask task) {
    _controllers[task.infoHash]?.add(task);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _engine.dispose();
  }
}
