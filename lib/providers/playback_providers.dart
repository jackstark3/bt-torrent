import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bt_torrent/core/models/playback_session.dart';
import 'package:bt_torrent/data/repositories/playback_repository_impl.dart';
import 'package:bt_torrent/domain/repositories/playback_repository.dart';
import 'package:bt_torrent/domain/usecases/playback_use_cases.dart';
import 'package:bt_torrent/engine/streaming_service.dart';
import 'package:bt_torrent/providers/core_providers.dart';

/// 在线播放会话仓库
final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  final engine = ref.watch(torrentEngineProvider);
  final repo = PlaybackRepositoryImpl(engine);
  repo.restoreSessions();
  return repo;
});

/// 播放会话列表流
final playbackSessionsProvider =
    StreamProvider<List<PlaybackSession>>((ref) {
  final repo = ref.watch(playbackRepositoryProvider);
  return repo.watchSessions();
});

/// 启动在线播放
final startPlaybackAction = Provider<StartPlaybackUseCase>((ref) {
  return StartPlaybackUseCase(ref.watch(playbackRepositoryProvider));
});

/// 确保播放会话可用
final ensurePlaybackSessionAction =
    Provider<EnsurePlaybackSessionUseCase>((ref) {
  return EnsurePlaybackSessionUseCase(ref.watch(playbackRepositoryProvider));
});

/// 记录播放
final markPlayedAction = Provider<MarkPlayedUseCase>((ref) {
  return MarkPlayedUseCase(ref.watch(playbackRepositoryProvider));
});

/// 删除播放会话
final removePlaybackSessionAction =
    Provider<RemovePlaybackSessionUseCase>((ref) {
  return RemovePlaybackSessionUseCase(ref.watch(playbackRepositoryProvider));
});

/// 一键清理
final clearPlaybackSessionsAction =
    Provider<ClearPlaybackSessionsUseCase>((ref) {
  return ClearPlaybackSessionsUseCase(ref.watch(playbackRepositoryProvider));
});

/// 转存为下载任务
final convertPlaybackToDownloadAction =
    Provider<ConvertPlaybackToDownloadUseCase>((ref) {
  return ConvertPlaybackToDownloadUseCase(
    playbackRepository: ref.watch(playbackRepositoryProvider),
    downloadRepository: ref.watch(downloadRepositoryProvider),
    engine: ref.watch(torrentEngineProvider),
  );
});

/// 在线播放流媒体服务（HTTP 服务器 + piece 优先级管理）
final streamingServiceProvider = Provider<StreamingService>((ref) {
  return StreamingService(ref.watch(torrentEngineProvider));
});
