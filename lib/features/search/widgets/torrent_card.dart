import 'package:flutter/material.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';

class TorrentCard extends StatelessWidget {
  final TorrentInfo torrent;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onPlayOnline;
  final VoidCallback? onCopyMagnet;

  const TorrentCard({
    super.key,
    required this.torrent,
    this.onTap,
    this.onDownload,
    this.onPlayOnline,
    this.onCopyMagnet,
  });

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
              Text(
                torrent.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatChip(icon: Icons.storage, label: torrent.sizeFormatted),
                  const SizedBox(width: 12),
                  _StatChip(
                      icon: Icons.arrow_upward,
                      label: torrent.seedersFormatted,
                      color: Colors.green),
                  const SizedBox(width: 12),
                  _StatChip(
                      icon: Icons.arrow_downward,
                      label: torrent.leechersFormatted,
                      color: Colors.orange),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      torrent.sourceProvider,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onCopyMagnet,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('磁力'),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onPlayOnline,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('在线播放'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('下载'),
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14, color: color ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: color ?? theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
