import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/providers/download_providers.dart';
import 'package:bt_torrent/providers/player_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String infoHash;
  final int fileIndex;

  const PlayerScreen({
    super.key,
    required this.infoHash,
    required this.fileIndex,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isLandscape = false;
  String? _error;
  String _fileName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlayer());
  }

  @override
  void dispose() {
    // 退出播放器时恢复默认屏幕方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final task =
        ref.read(downloadProgressProvider(widget.infoHash)).valueOrNull;
    // 优先任务自带文件列表（本地清单），原生引擎拉取仅作补充
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
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      ref.read(playerStateProvider.notifier).ready();
      controller.play();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      setState(() => _error = '无法播放视频：$e');
      ref.read(playerStateProvider.notifier).error('无法播放: $e');
    }
  }

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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
                        aspectRatio: controller.value.aspectRatio,
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
