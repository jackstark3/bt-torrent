import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/providers/download_providers.dart';

class DownloadListScreen extends ConsumerWidget {
  const DownloadListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(downloadTasksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('下载管理')),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('暂无下载任务',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('在搜索页面搜索种子并开始下载',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _DownloadItem(
                task: task,
                onTap: () => context.pushNamed(
                  'downloadDetail',
                  pathParameters: {'infoHash': task.infoHash},
                ),
                onPlay: () {
                  final videoFiles =
                      task.files.where((f) => f.isVideo).toList();
                  if (videoFiles.isEmpty) return;
                  context.pushNamed('player',
                      pathParameters: {
                        'infoHash': task.infoHash,
                        'fileIndex': '${videoFiles.first.index}',
                      });
                },
                onShare: () => _shareTask(context, task),
                onPauseResume: () {
                  if (task.status == DownloadStatus.downloading) {
                    ref.read(pauseDownloadAction).execute(task.infoHash);
                  } else {
                    ref.read(resumeDownloadAction).execute(task.infoHash);
                  }
                },
                onRemove: () {
                  ref
                      .read(removeDownloadAction)
                      .execute(task.infoHash, deleteFiles: true);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/');
            case 1: break;
            case 2: context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.download), label: '下载'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  /// 分享已完成任务的文件（优先公共下载目录，回退私有目录）
  Future<void> _shareTask(BuildContext context, DownloadTask task) async {
    final file = task.files.isNotEmpty
        ? task.files.first
        : null;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可分享的文件')),
      );
      return;
    }

    final publicPath = '/storage/emulated/0/Download/${file.name}';
    final privatePath = '${task.savePath}/${file.path}';
    final path =
        File(publicPath).existsSync() ? publicPath : privatePath;

    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        text: task.name,
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }
}

class _DownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onPauseResume;
  final VoidCallback onRemove;

  const _DownloadItem({
    required this.task,
    required this.onTap,
    required this.onPlay,
    required this.onShare,
    required this.onPauseResume,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = task.status == DownloadStatus.completed ||
        task.progress >= 1.0;
    final hasVideo = task.files.any((f) => f.isVideo);
    final statusColor = switch (task.status) {
      DownloadStatus.completed => Colors.green,
      DownloadStatus.error => theme.colorScheme.error,
      DownloadStatus.paused => Colors.orange,
      DownloadStatus.checking => Colors.blueGrey,
      _ => theme.colorScheme.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  // 状态徽章
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isComplete ? '已完成' : task.status.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                color: isComplete ? Colors.green : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isComplete) ...[
                    Text('100%', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Text(task.sizeFormatted,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '文件已保存到"下载"目录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ] else ...[
                    Text(task.progressFormatted,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Text(task.speedFormatted,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.status == DownloadStatus.checking ||
                                task.status == DownloadStatus.queued
                            ? task.status.displayName
                            : 'ETA: ${task.etaFormatted}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 已完成且有视频 → 播放按钮；否则暂停/继续
                  if (isComplete && hasVideo)
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill,
                          color: Colors.green, size: 28),
                      tooltip: '播放',
                      onPressed: onPlay,
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    IconButton(
                      icon: Icon(
                        task.status == DownloadStatus.downloading
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 22,
                      ),
                      onPressed: onPauseResume,
                      visualDensity: VisualDensity.compact,
                    ),
                  // 已完成：分享按钮
                  if (isComplete)
                    IconButton(
                      icon: const Icon(Icons.share,
                          size: 20, color: Colors.blueGrey),
                      tooltip: '分享文件',
                      onPressed: onShare,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
