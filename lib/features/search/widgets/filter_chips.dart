import 'package:flutter/material.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';

/// 分类筛选 Chip 组件（可复用）
class CategoryFilterChip extends StatelessWidget {
  final TorrentCategory? category;
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const CategoryFilterChip({
    super.key,
    this.category,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
    );
  }
}
