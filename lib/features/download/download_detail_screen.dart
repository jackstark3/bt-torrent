import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/utils/extensions.dart';
import 'package:bt_torrent/providers/download_providers.dart';
import 'package:go_router/go_router.dart';

class DownloadDetailScreen extends ConsumerWidget {
  final String infoHash;

  const DownloadDetailScreen({super.key, required this.infoHash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(downloadProgressProvider(infoHash));
    final filesAsync = ref.watch(downloadFilesProvider(infoHash));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('下载详情')),
      body: progressAsync.when(
        data: (task) {
          final files = filesAsync.value ?? task.files;
          final isComplete = task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.seeding ||
              task.progress >= 1.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 名称
              Text(task.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // 进度
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(task.progressFormatted,
                              style: theme.textTheme.headlineMedium),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(isComplete ? '已完成' : task.status.displayName,
                                  style: TextStyle(
                                      color: _statusColor(task.status))),
                              if (isComplete)
                                Text(
                                  '文件在 "下载" 目录',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: task.progress),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _InfoItem('下载', task.downloadedFormatted),
                          _InfoItem('大小', task.sizeFormatted),
                          _InfoItem('速度', task.speedFormatted),
                          _InfoItem('ETA', task.etaFormatted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Peer 信息
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('连接信息',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoItem('Peers', '${task.connectedPeers}'),
                          _InfoItem('Seeds', '${task.connectedSeeds}'),
                          _InfoItem('上传', task.uploadBytes.humanReadableSize),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 文件列表
              if (files.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('文件列表',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ...files.map((f) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                f.isVideo
                                    ? Icons.movie
                                    : Icons.insert_drive_file,
                                size: 20,
                              ),
                              title: Text(f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(f.sizeFormatted),
                              trailing: f.isVideo && isComplete
                                  ? Icon(Icons.play_circle,
                                      color: theme.colorScheme.primary)
                                  : null,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (task.status == DownloadStatus.downloading) {
                          ref
                              .read(pauseDownloadAction)
                              .execute(infoHash);
                        } else {
                          ref
                              .read(resumeDownloadAction)
                              .execute(infoHash);
                        }
                      },
                      icon: Icon(task.status == DownloadStatus.downloading
                          ? Icons.pause
                          : Icons.play_arrow),
                      label: Text(task.status == DownloadStatus.downloading
                          ? '暂停'
                          : task.status == DownloadStatus.paused
                              ? '恢复'
                              : '开始'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 如果包含视频文件且已下载完成，显示播放按钮
                  if (isComplete && files.any((f) => f.isVideo))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final videoFile = files.firstWhere((f) => f.isVideo);
                          context.pushNamed('player',
                              pathParameters: {
                                'infoHash': infoHash,
                                'fileIndex': '${videoFile.index}',
                              });
                        },
                        icon: const Icon(Icons.play_circle),
                        label: const Text('播放'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(removeDownloadAction)
                      .execute(infoHash, deleteFiles: true);
                  if (context.canPop()) context.pop();
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('删除下载',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Color _statusColor(DownloadStatus status) => switch (status) {
        DownloadStatus.downloading => Colors.blue,
        DownloadStatus.seeding || DownloadStatus.completed => Colors.green,
        DownloadStatus.paused => Colors.orange,
        DownloadStatus.error => Colors.red,
        _ => Colors.grey,
      };
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.bodySmall),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}
