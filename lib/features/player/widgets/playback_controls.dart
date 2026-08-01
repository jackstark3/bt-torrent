import 'package:flutter/material.dart';

/// 播放器覆盖控件
class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipForward;
  final VoidCallback? onSkipBackward;

  const PlaybackControls({
    super.key,
    this.isPlaying = false,
    this.onPlayPause,
    this.onSkipForward,
    this.onSkipBackward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
          onPressed: onSkipBackward,
        ),
        const SizedBox(width: 24),
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
            onPressed: onPlayPause,
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
          onPressed: onSkipForward,
        ),
      ],
    );
  }
}
