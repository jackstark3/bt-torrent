import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bt_torrent/core/models/stream_state.dart';

/// 当前流播状态
class PlayerState {
  final StreamState? streamState;
  final bool isPlaying;
  final bool isLoading;
  final String? errorMessage;

  const PlayerState({
    this.streamState,
    this.isPlaying = false,
    this.isLoading = false,
    this.errorMessage,
  });

  PlayerState copyWith({
    StreamState? streamState,
    bool? isPlaying,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PlayerState(
      streamState: streamState ?? this.streamState,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// 播放器状态
final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(const PlayerState());

  void startStreaming(StreamState streamState) {
    state = state.copyWith(
      streamState: streamState,
      isLoading: true,
      isPlaying: false,
      errorMessage: null,
    );
  }

  void ready() {
    state = state.copyWith(isLoading: false, isPlaying: true);
  }

  void pause() {
    state = state.copyWith(isPlaying: false);
  }

  void resume() {
    state = state.copyWith(isPlaying: true);
  }

  void error(String message) {
    state = state.copyWith(
      isLoading: false,
      isPlaying: false,
      errorMessage: message,
    );
  }

  void stop() {
    state = const PlayerState();
  }
}
