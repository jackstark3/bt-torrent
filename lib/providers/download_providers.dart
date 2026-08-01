import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/domain/usecases/download_use_cases.dart';
import 'package:bt_torrent/providers/core_providers.dart';

/// 所有下载任务流
final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.watchAllDownloads();
});

/// 启动下载
final startDownloadAction = Provider((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return StartDownloadUseCase(repo);
});

/// 特定下载任务进度流
final downloadProgressProvider =
    StreamProvider.family<DownloadTask, String>((ref, infoHash) {
  final repo = ref.watch(downloadRepositoryProvider);
  final useCase = WatchDownloadProgressUseCase(repo);
  return useCase.execute(infoHash);
});

/// 下载任务的文件列表
final downloadFilesProvider =
    FutureProvider.family<List<TorrentFileInfo>, String>((ref, infoHash) async {
  final repo = ref.watch(downloadRepositoryProvider);
  final result = await repo.getFiles(infoHash);
  return result.value ?? [];
});

/// 暂停下载
final pauseDownloadAction = Provider((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return PauseDownloadUseCase(repo);
});

/// 恢复下载
final resumeDownloadAction = Provider((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return ResumeDownloadUseCase(repo);
});

/// 移除下载
final removeDownloadAction = Provider((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return RemoveDownloadUseCase(repo);
});
