import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// 本地 HTTP 流媒体服务器
/// 将已下载的 BT piece 通过 HTTP Range 请求提供给视频播放器
class HttpStreamServer {
  final AppLogger _logger = AppLogger('HttpStreamServer');

  HttpServer? _server;
  int _port = 0;
  bool _isRunning = false;

  // 文件映射: {infoHash}_{fileIndex} -> File
  final Map<String, File> _fileMap = {};

  /// 服务器端口
  int get port => _port;

  /// 是否运行中
  bool get isRunning => _isRunning;

  /// 启动服务器
  Future<int> start() async {
    if (_isRunning) return _port;

    final app = Router();

    // HEAD 请求 — 返回文件信息
    app.get('/stream/<infoHash>/<fileIndex>', (Request request, String infoHash, String fileIndex) async {
      return await _handleStreamRequest(request, infoHash, fileIndex);
    });

    // 将所有请求转为 GET（shelf_router 默认行为）
    app.head('/stream/<infoHash>/<fileIndex>', (Request request, String infoHash, String fileIndex) async {
      return await _handleStreamRequest(
        Request('GET', request.url, body: '', headers: request.headers),
        infoHash,
        fileIndex,
      );
    });

    // 健康检查
    app.get('/health', (Request request) {
      return Response.ok('OK');
    });

    // 绑定到随机端口
    final random = Random();
    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        _port = 18000 + random.nextInt(10000);
        _server = await io.serve(
          app,
          InternetAddress.loopbackIPv4,
          _port,
        );
        _isRunning = true;
        _logger.info('HTTP 流媒体服务器启动在 http://127.0.0.1:$_port');
        return _port;
      } on SocketException {
        _logger.warning('端口 $_port 被占用，重试...');
      }
    }

    throw Exception('无法启动 HTTP 流媒体服务器：所有端口都被占用');
  }

  /// 注册文件
  void registerFile(String infoHash, int fileIndex, File file) {
    final key = '${infoHash}_$fileIndex';
    _fileMap[key] = file;
    _logger.info('注册文件: $key -> ${file.path}');
  }

  /// 处理流媒体请求
  Future<Response> _handleStreamRequest(
    Request request,
    String infoHash,
    String fileIndex,
  ) async {
    final key = '${infoHash}_$fileIndex';
    final file = _fileMap[key];

    if (file == null || !await file.exists()) {
      return Response.notFound('文件不存在');
    }

    try {
      final fileSize = await file.length();
      final rangeHeader = request.headers['Range'] ?? request.headers['range'];

      if (rangeHeader != null) {
        return _handleRangeRequest(file, fileSize, rangeHeader);
      }

      // 无 Range 头 — 返回整个文件
      return Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': _getMimeType(file.path),
          'Content-Length': '$fileSize',
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      _logger.error('流媒体服务错误', e);
      return Response.internalServerError(body: '流媒体服务错误');
    }
  }

  /// 处理 HTTP Range 请求
  Response _handleRangeRequest(File file, int fileSize, String rangeHeader) {
    try {
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
      if (match == null) {
        return Response(416, body: 'Range Not Satisfiable');
      }

      final start = int.parse(match.group(1)!);
      final endStr = match.group(2);
      int end = endStr != null && endStr.isNotEmpty
          ? int.parse(endStr)
          : fileSize - 1;

      end = min(end, fileSize - 1);

      if (start >= fileSize) {
        return Response(416, body: 'Range Not Satisfiable');
      }

      final length = end - start + 1;

      _logger.debug('Range: bytes $start-$end/$fileSize');

      final stream = file.openRead(start, end + 1);

      return Response(
        206, // Partial Content
        body: stream,
        headers: {
          'Content-Type': _getMimeType(file.path),
          'Content-Length': '$length',
          'Content-Range': 'bytes $start-$end/$fileSize',
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      _logger.error('Range 处理错误', e);
      return Response.internalServerError(body: 'Range 处理错误');
    }
  }

  /// 获取 MIME 类型
  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4' => 'video/mp4',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'mov' => 'video/quicktime',
      'flv' => 'video/x-flv',
      'm4v' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      _ => 'application/octet-stream',
    };
  }

  /// 停止服务器
  Future<void> stop() async {
    if (!_isRunning) return;
    _logger.info('停止 HTTP 流媒体服务器');
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _fileMap.clear();
  }
}
