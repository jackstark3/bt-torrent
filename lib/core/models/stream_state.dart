/// 视频流播状态
class StreamState {
  final String infoHash;
  final int fileIndex;
  final int port;
  final bool isReady;
  final int totalPieces;
  final int downloadedPieces;
  final int currentPiece;
  final double playbackPosition; // 播放位置(字节)
  final double bufferAhead; // 预缓冲了多少字节

  const StreamState({
    required this.infoHash,
    required this.fileIndex,
    required this.port,
    this.isReady = false,
    this.totalPieces = 0,
    this.downloadedPieces = 0,
    this.currentPiece = 0,
    this.playbackPosition = 0,
    this.bufferAhead = 0,
  });

  double get progress =>
      totalPieces > 0 ? downloadedPieces / totalPieces : 0.0;

  /// 流媒体 URL
  String get streamUrl => 'http://127.0.0.1:$port/stream/$infoHash/$fileIndex';

  /// 是否有足够的缓冲继续播放
  bool get hasEnoughBuffer => bufferAhead > 5 * 1024 * 1024; // 5MB 缓冲

  StreamState copyWith({
    String? infoHash,
    int? fileIndex,
    int? port,
    bool? isReady,
    int? totalPieces,
    int? downloadedPieces,
    int? currentPiece,
    double? playbackPosition,
    double? bufferAhead,
  }) {
    return StreamState(
      infoHash: infoHash ?? this.infoHash,
      fileIndex: fileIndex ?? this.fileIndex,
      port: port ?? this.port,
      isReady: isReady ?? this.isReady,
      totalPieces: totalPieces ?? this.totalPieces,
      downloadedPieces: downloadedPieces ?? this.downloadedPieces,
      currentPiece: currentPiece ?? this.currentPiece,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      bufferAhead: bufferAhead ?? this.bufferAhead,
    );
  }
}
