import 'package:flutter/material.dart';

/// 视频播放器视图 (ExoPlayer wrapper)
/// 当前为占位实现
class VideoPlayerView extends StatelessWidget {
  final String? streamUrl;
  final bool isPlaying;

  const VideoPlayerView({super.key, this.streamUrl, this.isPlaying = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 80,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
