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
        final task = _taskFromPersisted(map);
        _completedTasks[infoHash] = task;
        _controllers[infoHash]?.add(task);
      } else {
        // 未完成任务：重新添加，libtorrent 会校验已有文件续传
        await startDownload(magnetUri, savePath);
      }
    }
  }

  DownloadTask _taskFromPersisted(Map<String, dynamic> map) {
    final files = (map['files'] as List<dynamic>? ?? [])
        .map((f) => TorrentFileInfo(
              index: f['index'] as int? ?? 0,
              path: f['path'] as String? ?? '',
              name: f['name'] as String? ?? '',
              sizeBytes: f['sizeBytes'] as int? ?? 0,
            ))
        .toList();
    return DownloadTask(
      infoHash: map['infoHash'] as String? ?? '',
      name: map['name'] as String? ?? '已完成下载',
      magnetUri: map['magnetUri'] as String?,
      totalBytes: files.fold<int>(0, (sum, f) => sum + f.sizeBytes),
      downloadedBytes: files.fold<int>(0, (sum, f) => sum + f.sizeBytes),
      progress: 1.0,
      status: DownloadStatus.completed,
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
    final now = DateTime.now();
    _addedAt[session.infoHash] = now;
    _completedTasks.remove(session.infoHash);

    final task = _taskFromSession(session, now);
    final controller = StreamController<DownloadTask>.broadcast();
    _controllers[session.infoHash] = controller;
    controller.add(task);

    // 持久化任务记录
    await _upsertPersistedTask(
      session.infoHash,
      name: session.name,
      magnetUri: magnetUri,
      savePath: savePath,
      completed: false,
    );

    // 订阅引擎进度/状态流
    session.progressStream.listen((progress) {
      _updateTask(_taskFromSession(session, now));
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
    final controller = _controllers[infoHash];
    if (controller != null) return controller.stream;

    // 已完成任务
    final completed = _completedTasks[infoHash];
    if (completed != null) {
      final newController = StreamController<DownloadTask>.broadcast();
      _controllers[infoHash] = newController;
      newController.add(completed);
      return newController.stream;
    }

    // 为已存在的任务创建新流
    final newController = StreamController<DownloadTask>.broadcast();
    _controllers[infoHash] = newController;
    final session = _engine.getSession(infoHash);
    if (session != null) {
      newController.add(_taskFromSession(session, _addedAt[infoHash] ?? DateTime.now()));
    }
    return newController.stream;
  }

  @override
  Future<List<DownloadTask>> getAllDownloads() async {
    final now = DateTime.now();
    final active =
        _engine.getAllSessions().map((s) => _taskFromSession(s, now)).toList();
    return [..._completedTasks.values, ...active];
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
    final isComplete = status == DownloadStatus.completed;
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
