import 'package:bt_torrent/core/utils/error_text.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/engine/pigeon/torrent_api.gen.dart';
import 'package:bt_torrent/engine/torrent_session.dart';

/// Dart 端 BT 引擎门面
/// 封装 Pigeon 通信，提供 Dart-友好的 API
class TorrentEngine {
  final AppLogger _logger = AppLogger('TorrentEngine');
  final Map<String, TorrentSession> _sessions = {};
  final TorrentHostApi _hostApi = TorrentHostApi();

  TorrentEngine();

  bool _isInitialized = false;
  bool _apiRegistered = false;

  /// 注册 FlutterApi 回调（接收 Kotlin 端进度推送）
  void _registerApi() {
    if (_apiRegistered) return;
    TorrentFlutterApi.setUp(_TorrentFlutterApiHandler(this));
    _apiRegistered = true;
    _logger.info('TorrentFlutterApi 回调已注册');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _registerApi();
    _logger.info('初始化 BT 引擎...');
    _isInitialized = true;
  }

  Future<Result<TorrentSession>> startDownload(
    String magnetUri,
    String savePath, {
    bool isStreaming = false,
  }
  ) async {
    try {
      _logger.info(
          '启动下载: $magnetUri${isStreaming ? ' [在线播放]' : ''} -> $savePath');
      final infoHash =
          await _hostApi.startDownload(magnetUri, savePath, isStreaming);
      final session = TorrentSession(
        infoHash: infoHash,
        name: '获取种子信息中...',
        magnetUri: magnetUri,
        savePath: savePath,
        isStreaming: isStreaming,
      );
      _sessions[infoHash] = session;
      return Result.success(session);
    } catch (e) {
      _logger.error('启动下载失败', e);
      return Result.error(friendlyError(e));
    }
  }

  Future<Result<void>> pauseDownload(String infoHash) async {
    try {
      await _hostApi.pauseDownload(infoHash);
      _sessions[infoHash]?.pause();
      return Result.success(null);
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  Future<Result<void>> resumeDownload(String infoHash) async {
    try {
      await _hostApi.resumeDownload(infoHash);
      _sessions[infoHash]?.resume();
      return Result.success(null);
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  Future<Result<void>> removeDownload(
    String infoHash, {
    bool deleteFiles = false,
  }) async {
    try {
      await _hostApi.removeDownload(infoHash, deleteFiles);
      _sessions.remove(infoHash)?.close();
      return Result.success(null);
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  Future<Result<void>> setPiecePriority(
    String infoHash,
    int pieceIndex,
    int priority,
  ) async {
    try {
      await _hostApi.setPiecePriority(infoHash, pieceIndex, priority);
      return Result.success(null);
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  Future<Result<void>> setPieceDeadline(
    String infoHash,
    int pieceIndex,
    int millis,
  ) async {
    try {
      await _hostApi.setPieceDeadline(infoHash, pieceIndex, millis);
      return Result.success(null);
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  Future<Result<List<int>>> readPiece(
    String infoHash,
    int pieceIndex,
  ) async {
    try {
      final data = await _hostApi.readPiece(infoHash, pieceIndex);
      return Result.success(data);
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  /// 获取种子内文件列表
  Future<Result<List<TorrentFileInfo>>> getFiles(String infoHash) async {
    try {
      final files = await _hostApi.getFiles(infoHash);
      return Result.success(files
          .map((f) => TorrentFileInfo(
                index: f.index,
                path: f.path,
                name: f.name,
                sizeBytes: f.sizeBytes,
              ))
          .toList());
    } catch (e) {
      return Result.error(friendlyError(e));
    }
  }

  /// 获取种子元数据（piece 长度、数量等，在线播放使用）
  Future<Result<TorrentMetaData>> getTorrentMeta(String infoHash) async {
    try {
      final meta = await _hostApi.getTorrentMeta(infoHash);
      return Result.success(meta);
    } catch (e) {
      _logger.error('获取种子元数据失败', e);
      return Result.error(friendlyError(e));
    }
  }

  /// 将在线播放会话转存为正式下载任务
  Future<Result<void>> convertToDownload(String infoHash) async {
    try {
      await _hostApi.convertToDownload(infoHash);
      return Result.success(null);
    } catch (e) {
      _logger.error('转存下载任务失败', e);
      return Result.error(friendlyError(e));
    }
  }

  TorrentSession? getSession(String infoHash) => _sessions[infoHash];

  /// 正式下载会话（在线播放会话不进入下载管理列表）
  List<TorrentSession> getAllSessions() =>
      _sessions.values.where((s) => !s.isStreaming).toList();

  void dispose() {
    for (final session in _sessions.values) {
      session.close();
    }
    _sessions.clear();
  }
}

/// TorrentFlutterApi 实现：接收 Kotlin 端推送
class _TorrentFlutterApiHandler extends TorrentFlutterApi {
  final TorrentEngine _engine;

  _TorrentFlutterApiHandler(this._engine);

  @override
  void onProgressChanged(DownloadProgressData progress) {
    _engine.getSession(progress.infoHash)?.updateFromPigeon(progress);
  }

  @override
  void onDownloadFinished(String infoHash) {
    _engine.getSession(infoHash)?.updateStatus(SessionStatus.completed);
  }

  @override
  void onDownloadError(String infoHash, String error) {
    _engine.getSession(infoHash)?.updateStatus(SessionStatus.error);
  }
}
