import 'package:flutter/material.dart';
import 'package:bt_torrent/data/remote/search_aggregator.dart';

/// 搜索源状态指示器
class SourceIndicator extends StatelessWidget {
  final Map<String, SourceStatus> sourceStatuses;

  const SourceIndicator({super.key, required this.sourceStatuses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sourceStatuses.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: entry.value.isSuccess
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.value.isSuccess ? Icons.check_circle : Icons.error,
                size: 14,
                color: entry.value.isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.key}${entry.value.isSuccess ? " (${entry.value.resultCount})" : ""}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: entry.value.isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
