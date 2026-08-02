import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/providers/core_providers.dart';
import 'package:bt_torrent/providers/download_providers.dart';
import 'package:bt_torrent/providers/playback_providers.dart';
import 'package:bt_torrent/providers/player_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String infoHash;
  final int fileIndex;
  final bool streaming;

  const PlayerScreen({
    super.key,
    required this.infoHash,
    required this.fileIndex,
    this.streaming = false,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isLandscape = true; // 默认横屏
  String? _error;
  String _fileName = '';
  bool _usingLocalFile = false;
  bool _converted = false;
  bool _switchingToLocal = false;
  bool _disposed = false;

  int? _lastPositionMs;
  int _trackedPiece = -1;
  int _pieceLength = 0;
  StreamSubscription<dynamic>? _progressSub;

  @override
  void initState() {
    super.initState();
    // 进入播放器默认横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.streaming) {
        _initStreamingPlayer();
      } else {
        _initLocalPlayer();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSub?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    try {
      if (widget.streaming) {
        final service = ref.read(streamingServiceProvider);
        unawaited(service.stopStreaming(
          widget.infoHash,
          fileIndex: widget.fileIndex,
        ));
      }
    } catch (_) {
      // 播放器销毁时不能因 provider 异常中断控制器释放
    }
    final controller = _controller;
    _controller = null;
    controller?.pause();
    controller?.dispose();
    super.dispose();
  }

  // ===== 本地文件播放（下载完成） =====

  Future<void> _initLocalPlayer() async {
    final task =
        ref.read(downloadProgressProvider(widget.infoHash)).valueOrNull;
    final taskFiles = task?.files ?? const <TorrentFileInfo>[];
    final engineFiles =
        ref.read(downloadFilesProvider(widget.infoHash)).valueOrNull ?? [];
    final files = taskFiles.isNotEmpty ? taskFiles : engineFiles;

    if (task == null) {
      setState(() => _error = '未找到下载任务');
      return;
    }
    if (files.isEmpty || widget.fileIndex >= files.length) {
      setState(() => _error = '未找到视频文件信息');
      return;
    }

    final file = files[widget.fileIndex];
    if (!file.isVideo) {
      setState(() => _error = '所选文件不是视频');
      return;
    }
    _fileName = file.name;

    final isComplete = task.status == DownloadStatus.completed ||
        task.status == DownloadStatus.seeding ||
        task.progress >= 1.0;

    // 已完成的文件应导出到公共下载目录；若导出失败则回退到私有目录
    final publicPath = '/storage/emulated/0/Download/${file.name}';
    final privatePath = '${task.savePath}/${file.path}';
    String? path;
    if (isComplete && File(publicPath).existsSync()) {
      path = publicPath;
    } else if (File(privatePath).existsSync()) {
      path = privatePath;
    }

    if (path == null) {
      setState(() => _error =
          '文件不存在，已尝试：\n$publicPath\n$privatePath');
      return;
    }

    try {
      final controller = VideoPlayerController.file(File(path));
      await _prepareController(controller);
    } catch (e) {
      setState(() => _error = '无法播放视频：$e');
      ref.read(playerStateProvider.notifier).error('无法播放: $e');
    }
  }

  // ===== 在线播放（磁力直连流播） =====

  Future<void> _initStreamingPlayer() async {
    try {
      final repo = ref.read(playbackRepositoryProvider);
      var session = repo.getSession(widget.infoHash);
      if (session == null) {
        setState(() => _error = '播放会话不存在，请重新在线播放');
        return;
      }

      // 引擎会话可能已被清理（重启后），先重新挂载（阻塞等待元数据）
      final ensured =
          await ref.read(ensurePlaybackSessionAction).execute(session);
      if (ensured.isError) {
        setState(() => _error = '会话恢复失败：${ensured.error}');
        return;
      }
      session = ensured.value!;

      if (session.files.isEmpty || widget.fileIndex >= session.files.length) {
        setState(() => _error = '未找到视频文件信息');
        return;
      }
      final file = session.files[widget.fileIndex];
      if (!file.isVideo) {
        setState(() => _error = '所选文件不是视频');
        return;
      }
      _fileName = file.name;

      final engine = ref.read(torrentEngineProvider);
      final metaResult = await engine.getTorrentMeta(widget.infoHash);
      if (metaResult.isError ||
          metaResult.value == null ||
          metaResult.value!.pieceLength <= 0) {
        setState(() => _error =
            '获取种子元数据失败：${metaResult.error ?? 'piece 信息为空'}');
        return;
      }
      final meta = metaResult.value!;
      _pieceLength = meta.pieceLength;

      final service = ref.read(streamingServiceProvider);
      final url = await service.startStreaming(
        infoHash: widget.infoHash,
        fileIndex: widget.fileIndex,
        files: session.files,
        pieceLength: meta.pieceLength,
        numPieces: meta.numPieces,
      );
      if (!mounted) return;

      final controller =
          VideoPlayerController.networkUrl(Uri.parse(url));
      await _prepareController(controller);

      // 下载完成后无缝切换本地文件（避免导出后流中断）
      final engineSession = engine.getSession(widget.infoHash);
      _progressSub = engineSession?.progressStream.listen((p) {
        if (p.progressPercent >= 1.0) {
          unawaited(_trySwitchToLocal());
        }
      });

      ref.read(markPlayedAction)
          .execute(widget.infoHash, fileIndex: widget.fileIndex);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '在线播放失败：$e');
        ref.read(playerStateProvider.notifier).error('在线播放失败: $e');
      }
    }
  }

  /// 准备播放控制器（初始化 + 播放 + 进度联动）
  Future<void> _prepareController(VideoPlayerController controller) async {
    // 立即持有引用：初始化期间退出播放器也必须能释放，否则音频会继续播放
    _controller = controller;
    if (mounted) setState(() {});

    try {
      await controller.initialize();
      await controller.setLooping(false);
    } catch (e) {
      if (_disposed || !mounted) {
        controller.dispose();
      } else {
        setState(() => _error = '无法播放视频：$e');
        ref.read(playerStateProvider.notifier).error('无法播放: $e');
      }
      return;
    }

    if (_disposed || !mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    ref.read(playerStateProvider.notifier).ready();
    controller.play();
    _lastPositionMs = null;
    _trackedPiece = -1;
    controller.addListener(_onControllerTick);
  }

  /// 播放进度 → piece 优先级窗口联动
  void _onControllerTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (mounted) setState(() {});
    if (!widget.streaming || _usingLocalFile) return;

    final pos = controller.value.position;
    final dur = controller.value.duration;
    if (dur.inMilliseconds <= 0) return;

    final repo = ref.read(playbackRepositoryProvider);
    final session = repo.getSession(widget.infoHash);
    final meta = session?.files;
    if (meta == null ||
        meta.isEmpty ||
        widget.fileIndex >= meta.length) {
      return;
    }
    final fileLength = meta[widget.fileIndex].sizeBytes;
    if (fileLength <= 0) return;

    final fileOffset = meta
        .take(widget.fileIndex)
        .fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final byte =
        (pos.inMilliseconds / dur.inMilliseconds * fileLength).round();
    final globalByte = fileOffset + byte;

    final pieceLength = _pieceLength;
    if (pieceLength <= 0) return;
    final piece = globalByte ~/ pieceLength;
    if (piece == _trackedPiece) return;
    _trackedPiece = piece;

    final service = ref.read(streamingServiceProvider);
    if (_lastPositionMs != null) {
      final delta = pos.inMilliseconds - _lastPositionMs!;
      if (delta > 2000 || delta < -1500) {
        unawaited(service.onSeek(widget.infoHash, piece));
      } else {
        unawaited(service.onPositionChanged(widget.infoHash, piece));
      }
    } else {
      unawaited(service.onPositionChanged(widget.infoHash, piece));
    }
    _lastPositionMs = pos.inMilliseconds;
  }

  /// 下载完成后切换到本地文件继续播放
  Future<void> _trySwitchToLocal() async {
    if (_switchingToLocal || _usingLocalFile) return;
    final repo = ref.read(playbackRepositoryProvider);
    final session = repo.getSession(widget.infoHash);
    if (session == null ||
        session.files.isEmpty ||
        widget.fileIndex >= session.files.length) {
      return;
    }
    final file = session.files[widget.fileIndex];
    final publicPath = '/storage/emulated/0/Download/${file.name}';
    final privatePath = '${session.savePath}/${file.path}';
    String? path;
    if (File(publicPath).existsSync()) {
      path = publicPath;
    } else if (File(privatePath).existsSync()) {
      path = privatePath;
    }
    if (path == null) return;

    _switchingToLocal = true;
    try {
      final old = _controller;
      if (old == null) return;
      final position = old.value.position;
      final wasPlaying = old.value.isPlaying;
      final local = VideoPlayerController.file(File(path));
      await local.initialize();
      await local.seekTo(position);
      if (wasPlaying) await local.play();
      if (_disposed || !mounted) {
        local.dispose();
        return;
      }
      setState(() {
        _controller = local;
        _usingLocalFile = true;
        old.dispose();
      });
      local.addListener(_onControllerTick);
    } catch (e) {
      _switchingToLocal = false;
    }
  }

  // ===== 操作 =====

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
      ref.read(playerStateProvider.notifier).pause();
    } else {
      controller.play();
      ref.read(playerStateProvider.notifier).resume();
    }
  }

  /// 切换横竖屏
  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  /// 转存为下载任务
  Future<void> _convertToDownload() async {
    final result = await ref
        .read(convertPlaybackToDownloadAction)
        .execute(widget.infoHash);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _converted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已转存为下载任务，可在"下载"页面查看')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转存失败：${result.error}')),
      );
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 安全的视频宽高比（初始化阶段可能为 0/1，避免画面被拉伸）
  double _safeAspectRatio(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size.width > 0 && size.height > 0) {
      return size.width / size.height;
    }
    final ratio = controller.value.aspectRatio;
    return ratio > 0.1 ? ratio : 16 / 9;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // 视频画面
            Positioned.fill(
              child: controller != null && controller.value.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _safeAspectRatio(controller),
                        child: VideoPlayer(controller),
                      ),
                    )
                  : Center(
                      child: _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 56, color: Colors.white54),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : const CircularProgressIndicator(
                              color: Colors.white70),
                    ),
            ),

            // 控制层
            if (_showControls)
              SafeArea(
                child: Column(
                  children: [
                    // 顶部栏
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          // 文件名
                          Expanded(
                            child: Text(
                              _fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // 在线播放标识
                          if (widget.streaming && !_usingLocalFile)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '在线播放',
                                style: TextStyle(
                                    color: Colors.greenAccent, fontSize: 11),
                              ),
                            ),
                          // 转存为下载任务
                          if (widget.streaming && !_converted)
                            IconButton(
                              icon: const Icon(Icons.save_alt,
                                  color: Colors.white),
                              tooltip: '转存为下载任务',
                              onPressed: _convertToDownload,
                            ),
                          // 横竖屏切换
                          IconButton(
                            icon: Icon(
                              _isLandscape
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            tooltip: _isLandscape ? '退出全屏' : '全屏',
                            onPressed: _toggleOrientation,
                          ),
                          const Spacer(),
                          if (controller != null &&
                              controller.value.isBuffering)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 底部控制
                    if (controller != null && controller.value.isInitialized)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 进度条
                            VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.white,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(controller.value.position),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  _formatDuration(controller.value.duration),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white24,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      controller.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    onPressed: _togglePlay,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
