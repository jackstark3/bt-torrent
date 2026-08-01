import 'package:flutter/material.dart';
import 'package:bt_torrent/core/models/download_task.dart';

/// 下载项 Widget（详情页用）
class DownloadItemWidget extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onTap;

  const DownloadItemWidget({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  _StatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: task.progress),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(task.progressFormatted,
                      style: theme.textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Text(task.speedFormatted,
                      style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text('${task.connectedPeers} peers',
                      style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DownloadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      DownloadStatus.downloading => (Colors.blue, '下载中'),
      DownloadStatus.seeding => (Colors.green, '做种中'),
      DownloadStatus.completed => (Colors.green, '已完成'),
      DownloadStatus.paused => (Colors.orange, '已暂停'),
      DownloadStatus.error => (Colors.red, '错误'),
      DownloadStatus.checking => (Colors.purple, '校验中'),
      DownloadStatus.queued => (Colors.grey, '排队中'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
