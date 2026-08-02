import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bt_torrent/core/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// 流媒体数据源接口（按字节区间提供数据）
abstract class StreamDataSource {
  /// 文件总长度（字节）
  Future<int> get length;

  /// 读取 [start, end]（含端点）区间的数据
  Future<Uint8List> readRange(int start, int end);

  /// MIME 类型
  String get contentType;
}

/// piece 在超时时间内未就绪
class PieceNotReadyException implements Exception {
  final int pieceIndex;
  final Duration timeout;

  PieceNotReadyException(this.pieceIndex, this.timeout);

  @override
  String toString() => 'piece $pieceIndex 在 $timeout 内未就绪';
}

/// 本地 HTTP 流媒体服务器
/// 将在线播放会话的 piece 数据通过 HTTP Range 请求提供给视频播放器
class HttpStreamServer {
  final AppLogger _logger = AppLogger('HttpStreamServer');

  /// 单次响应最大字节数（开放区间请求按此分块，避免阻塞整个文件）
  static const int _maxChunkBytes = 8 * 1024 * 1024; // 8MB

  HttpServer? _server;
  int _port = 0;
  bool _isRunning = false;

  // 数据源映射: {infoHash}_{fileIndex} -> StreamDataSource
  final Map<String, StreamDataSource> _sources = {};

  /// 服务器端口
  int get port => _port;

  /// 是否运行中
  bool get isRunning => _isRunning;

  /// 当前注册的数据源数量
  int get activeSourceCount => _sources.length;

  /// 启动服务器
  Future<int> start() async {
    if (_isRunning) return _port;

    final app = Router();

    app.get(
        '/stream/<infoHash>/<fileIndex>',
        (Request request, String infoHash, String fileIndex) async {
      return _handleRequest(request, infoHash, fileIndex, isHead: false);
    });

    app.head(
        '/stream/<infoHash>/<fileIndex>',
        (Request request, String infoHash, String fileIndex) async {
      return _handleRequest(request, infoHash, fileIndex, isHead: true);
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
          app.call,
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

  /// 注册数据源
  void registerSource(
    String infoHash,
    int fileIndex,
    StreamDataSource source,
  ) {
    final key = _key(infoHash, fileIndex);
    _sources[key] = source;
    _logger.info('注册数据源: $key');
  }

  /// 注销数据源
  void unregisterSource(String infoHash, int fileIndex) {
    _sources.remove(_key(infoHash, fileIndex));
  }

  /// 是否已有数据源
  bool hasSource(String infoHash, int fileIndex) {
    return _sources.containsKey(_key(infoHash, fileIndex));
  }

  String _key(String infoHash, int fileIndex) =>
      '${infoHash}_$fileIndex';

  /// 处理流媒体请求
  Future<Response> _handleRequest(
    Request request,
    String infoHash,
    String fileIndex,
    {required bool isHead}
  ) async {
    final source = _sources[_key(infoHash, int.tryParse(fileIndex) ?? -1)];
    if (source == null) {
      return Response.notFound('数据源不存在');
    }

    try {
      final fileSize = await source.length;
      final baseHeaders = <String, String>{
        'Content-Type': source.contentType,
        'Content-Length': '$fileSize',
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
      };

      // HEAD 请求：只返回头信息，不带 body
      if (isHead) {
        return Response(200, body: '', headers: baseHeaders);
      }

      final rangeHeader = _rangeHeader(request.headers);
      if (rangeHeader != null) {
        return _handleRangeRequest(source, fileSize, rangeHeader);
      }

      // 无 Range 头 — 按从头开始的开放区间处理（ExoPlayer 初始请求）
      return _handleRangeRequest(source, fileSize, 'bytes=0-');
    } on PieceNotReadyException catch (e) {
      _logger.warning('piece 未就绪: $e');
      return Response(503, body: '数据未就绪，请稍后重试');
    } catch (e) {
      _logger.error('流媒体服务错误', e);
      return Response.internalServerError(body: '流媒体服务错误');
    }
  }

  String? _rangeHeader(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'range') return entry.value;
    }
    return null;
  }

  /// 处理 HTTP Range 请求
  Future<Response> _handleRangeRequest(
    StreamDataSource source,
    int fileSize,
    String rangeHeader,
  ) async {
    try {
      final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
      if (match == null) {
        return _rangeNotSatisfiable(fileSize);
      }

      final startStr = match.group(1);
      final endStr = match.group(2);
      int start;
      int end;

      if (startStr == null || startStr.isEmpty) {
        // 后缀范围: bytes=-N → 最后 N 字节
        final suffix = int.parse(endStr ?? '');
        if (suffix <= 0) return _rangeNotSatisfiable(fileSize);
        start = max(0, fileSize - suffix);
        end = fileSize - 1;
      } else {
        start = int.parse(startStr);
        if (endStr == null || endStr.isEmpty) {
          // 开放区间：限制单次响应大小，剩余部分由客户端继续 Range 请求
          end = min(start + _maxChunkBytes - 1, fileSize - 1);
        } else {
          end = min(int.parse(endStr), fileSize - 1);
        }
      }

      if (start >= fileSize || start > end) {
        return _rangeNotSatisfiable(fileSize);
      }

      final length = end - start + 1;

      final sw = Stopwatch()..start();
      final data = await source.readRange(start, end);
      sw.stop();
      _logger.info(
          'GET bytes=$start-$end/$fileSize -> ${data.length}B ${sw.elapsedMilliseconds}ms');

      return Response(
        206, // Partial Content
        body: data,
        headers: {
          'Content-Type': source.contentType,
          'Content-Length': '$length',
          'Content-Range': 'bytes $start-$end/$fileSize',
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } on PieceNotReadyException catch (e) {
      _logger.warning('piece 未就绪: $e');
      return Response(503, body: '数据未就绪，请稍后重试');
    } catch (e) {
      _logger.error('Range 处理错误', e);
      return Response.internalServerError(body: 'Range 处理错误');
    }
  }

  Response _rangeNotSatisfiable(int fileSize) {
    return Response(416,
        body: 'Range Not Satisfiable',
        headers: {'Content-Range': 'bytes */$fileSize'});
  }

  /// 停止服务器
  Future<void> stop() async {
    if (!_isRunning) return;
    _logger.info('停止 HTTP 流媒体服务器');
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _sources.clear();
  }
}
