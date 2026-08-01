import 'dart:math';
import 'dart:typed_data';

import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/engine/http_stream_server.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';

/// 按 piece 提供文件数据的流媒体数据源
/// 将文件字节区间映射到全局 piece，通过引擎 readPiece 读取。
/// piece 未就绪时轮询等待（超时抛 PieceNotReadyException）。
class PieceStreamDataSource implements StreamDataSource {
  final TorrentEngine engine;
  final String infoHash;
  final int fileIndex;
  final List<TorrentFileInfo> files;
  final int pieceLength;
  final int numPieces;
  final Duration pieceTimeout;
  final AppLogger _logger = AppLogger('PieceStream');

  PieceStreamDataSource({
    required this.engine,
    required this.infoHash,
    required this.fileIndex,
    required this.files,
    required this.pieceLength,
    required this.numPieces,
    this.pieceTimeout = const Duration(seconds: 30),
  });

  /// 文件在种子中的全局起始偏移（多文件种子 piece 按文件拼接）
  int get fileOffset =>
      files.take(fileIndex).fold<int>(0, (sum, f) => sum + f.sizeBytes);

  @override
  Future<int> get length async {
    if (fileIndex < 0 || fileIndex >= files.length) return 0;
    return files[fileIndex].sizeBytes;
  }

  @override
  String get contentType {
    if (fileIndex < 0 || fileIndex >= files.length) {
      return 'application/octet-stream';
    }
    final ext = files[fileIndex].name.split('.').last.toLowerCase();
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

  @override
  Future<Uint8List> readRange(int start, int end) async {
    if (fileIndex < 0 || fileIndex >= files.length) {
      throw StateError('文件索引越界: $fileIndex');
    }

    final globalStart = fileOffset + start;
    final globalEnd = fileOffset + end;
    final firstPiece = globalStart ~/ pieceLength;
    final lastPiece = globalEnd ~/ pieceLength;
    final builder = BytesBuilder(copy: false);

    for (int p = firstPiece; p <= lastPiece; p++) {
      final pieceData = await _readPieceWithWait(p);
      final pieceStart = p * pieceLength;
      final pieceEnd = pieceStart + pieceData.length;
      final clipStart = max(globalStart, pieceStart) - pieceStart;
      final clipEnd = min(globalEnd, pieceEnd - 1) - pieceStart;
      if (clipStart <= clipEnd && clipEnd < pieceData.length) {
        builder.add(
            Uint8List.sublistView(pieceData, clipStart, clipEnd + 1));
      }
    }
    return builder.takeBytes();
  }

  Future<Uint8List> _readPieceWithWait(int pieceIndex) async {
    final deadline = DateTime.now().add(pieceTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = await engine.readPiece(infoHash, pieceIndex);
      if (result.isSuccess && result.value != null && result.value!.isNotEmpty) {
        return Uint8List.fromList(result.value!);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _logger.warning('等待 piece $pieceIndex 超时');
    throw PieceNotReadyException(pieceIndex, pieceTimeout);
  }
}
