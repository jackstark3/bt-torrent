import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:bt_torrent/core/models/download_task.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/extensions.dart';
import 'package:bt_torrent/core/utils/magnet_parser.dart';
import 'package:bt_torrent/data/remote/search_aggregator.dart';
import 'package:bt_torrent/features/search/widgets/search_bar.dart' as custom;
import 'package:bt_torrent/features/search/widgets/torrent_card.dart';
import 'package:bt_torrent/providers/core_providers.dart';
import 'package:bt_torrent/providers/download_providers.dart';
import 'package:bt_torrent/providers/playback_providers.dart';
import 'package:bt_torrent/providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  TorrentCategory? _selectedCategory;
  SortBy _sortBy = SortBy.seeders;
  String _sourceFilter = '全部'; // 来源筛选，默认全部
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_updateSuggestions);
    _searchController.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 根据输入和焦点更新历史建议
  void _updateSuggestions() {
    final query = _searchController.text.trim();
    final history =
        ref.read(searchHistoryProvider).valueOrNull ?? const <String>[];
    setState(() {
      _suggestions = _focusNode.hasFocus && query.isNotEmpty
          ? history
              .where((h) => h.toLowerCase().contains(query.toLowerCase()))
              .take(5)
              .toList()
          : [];
    });
  }

  void _applySuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection =
        TextSelection.collapsed(offset: suggestion.length);
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    _handleSearch(suggestion);
  }

  /// 用当前筛选条件重新搜索
  void _reSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    ref.read(searchResultsProvider.notifier).search(
          query,
          category: _selectedCategory,
          sortBy: _sortBy,
        );
  }

  void _handleSearch(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (MagnetParser.isMagnetUri(trimmed)) {
      final infoHash = MagnetParser.extractInfoHash(trimmed);
      if (infoHash != null) {
        context.pushNamed('downloadDetail',
            pathParameters: {'infoHash': infoHash});
        return;
      }
    }

    if (MagnetParser.isTorrentUrl(trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('种子 URL 下载功能开发中')),
      );
      return;
    }

    _focusNode.unfocus();
    setState(() => _suggestions = []);
    ref.read(searchResultsProvider.notifier).search(
          trimmed,
          category: _selectedCategory,
          sortBy: _sortBy,
        );
    ref.read(searchResultsProvider.notifier).addToHistory(trimmed);
  }

  /// 在线播放：创建临时播放会话并进入播放器
  Future<void> _playOnline(TorrentInfo torrent) async {
    final magnet = await _resolveMagnet(torrent);
    if (!mounted) return;
    if (magnet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该结果没有磁力链接')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MetadataLoadingDialog(),
    );

    final result = await ref.read(startPlaybackAction).execute(magnet);
    if (!mounted) return;
    // 关闭"获取种子信息中"加载框
    try {
      Navigator.of(context).pop();
    } catch (_) {}

    if (result.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('在线播放失败：${result.error}')),
      );
      return;
    }

    final session = result.value!;
    final videos = session.videoFiles;
    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该种子中没有可播放的视频文件')),
      );
      return;
    }

    int fileIndex = videos.first.index;
    if (videos.length > 1) {
      final picked = await _pickVideoFile(videos);
      if (picked == null) return;
      fileIndex = picked;
    }
    if (!mounted) return;

    context.pushNamed(
      'player',
      pathParameters: {
        'infoHash': session.infoHash,
        'fileIndex': '$fileIndex',
      },
      queryParameters: {'stream': '1'},
    );
  }

  /// 获取磁力链接：结果自带则直接使用，否则从详情页懒解析
  Future<String?> _resolveMagnet(TorrentInfo torrent) async {
    if (torrent.magnetUri != null) return torrent.magnetUri;
    final detailUrl = torrent.detailUrl;
    if (detailUrl == null) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Flexible(child: Text('正在解析磁力链接...')),
            ],
          ),
        ),
      ),
    );
    try {
      return await ref.read(magnetResolverProvider).resolve(detailUrl);
    } finally {
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }
    }
  }

  /// 多视频种子：选择要播放的文件
  Future<int?> _pickVideoFile(List<TorrentFileInfo> videos) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择要播放的视频（${videos.length} 个）',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              ...videos.map(
                (f) => ListTile(
                  leading: const Icon(Icons.movie),
                  title: Text(f.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(f.sizeFormatted),
                  onTap: () => Navigator.of(context).pop(f.index),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 按来源筛选结果（"全部"不过滤）
  List<TorrentInfo> _visibleResults(AggregatedResult result) {
    if (_sourceFilter == '全部') return result.results;
    final filter = _sourceFilter.trim();
    final filtered = result.results.where((t) {
      if (t.sourceProvider.trim() == filter) return true;
      return t.additionalSources.any((s) => s.trim() == filter);
    }).toList();
    debugPrint(
        '[来源筛选] 总数=${result.results.length} 筛选=$_sourceFilter 匹配=${filtered.length}');
    return filtered;
  }

  /// 当前启用的搜索源名称（用于筛选下拉）
  List<String> _enabledSources() =>
      ref.read(searchAggregatorProvider).enabledProviders
          .map((p) => p.name)
          .toList();

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: custom.SearchBar(
                controller: _searchController,
                focusNode: _focusNode,
                hintText: '搜索种子或粘贴磁力链接...',
                onSubmitted: _handleSearch,
                onClear: () => _searchController.clear(),
              ),
            ),

            // 历史建议面板
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.map((suggestion) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(suggestion,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _applySuggestion(suggestion),
                    );
                  }).toList(),
                ),
              ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CategoryChip(
                    label: '全部',
                    isSelected: _selectedCategory == null,
                    onSelected: () {
                      setState(() => _selectedCategory = null);
                      _reSearch();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...TorrentCategory.values
                      .where((c) => c != TorrentCategory.xxx)
                      .map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoryChip(
                              label: cat.displayName,
                              isSelected: _selectedCategory == cat,
                              onSelected: () {
                                setState(() => _selectedCategory = cat);
                                _reSearch();
                              },
                            ),
                          )),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<SortBy>(
                      value: _sortBy,
                      isDense: true,
                      style: theme.textTheme.bodySmall,
                      items: SortBy.values
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.displayName)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _sortBy = v);
                          _reSearch();
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  searchResults.when(
                    data: (r) {
                      final visible = _visibleResults(r);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 来源筛选（默认"全部"）
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sourceFilter,
                              isDense: true,
                              style: theme.textTheme.bodySmall,
                              underline: const SizedBox.shrink(),
                              icon: const Icon(Icons.filter_list, size: 16),
                              items: [
                                const DropdownMenuItem(
                                    value: '全部', child: Text('全部')),
                                ..._enabledSources()
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s))),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _sourceFilter = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${visible.length} 个结果，${r.successCount} 个源',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          if (r.isCached)
                            Text(
                              '结果来自本地缓存',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: searchResults.when(
                data: (result) {
                  if (result.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text('输入关键词搜索种子资源',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }
                  final visible = _visibleResults(result);
                  if (visible.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_alt_off,
                              size: 56,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('"$_sourceFilter" 来源暂无搜索结果',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () =>
                                setState(() => _sourceFilter = '全部'),
                            child: const Text('查看全部'),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      final query = ref.read(searchQueryProvider).query;
                      if (query.isNotEmpty) {
                        _reSearch();
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: visible.length +
                          (result.isComplete && !result.hasMore ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index >= visible.length) {
                          if (!result.isComplete || result.isLoadingMore) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator()));
                          }
                          if (result.hasMore) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(searchResultsProvider.notifier)
                                      .loadMore(),
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('加载更多'),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        final torrent = visible[index];
                        return TorrentCard(
                          torrent: torrent,
                          onTap: () {
                            if (torrent.magnetUri != null) {
                              context.pushNamed('downloadDetail',
                                  pathParameters: {
                                    'infoHash': torrent.infoHash
                                  });
                            }
                          },
                          onDownload: () async {
                            final magnet = await _resolveMagnet(torrent);
                            if (!context.mounted) return;
                            if (magnet == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('该结果没有磁力链接')),
                              );
                              return;
                            }
                            final savePath = await ref
                                .read(settingsRepositoryProvider)
                                .getDownloadPath();
                            final result = await ref
                                .read(startDownloadAction)
                                .execute(magnet, savePath);
                            if (result.isSuccess) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '开始下载: ${torrent.title.truncate(30)}')),
                                );
                                context.go('/downloads');
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('下载失败: ${result.error}')),
                                );
                              }
                            }
                          },
                          onPlayOnline: () => _playOnline(torrent),
                          onCopyMagnet: () async {
                            final magnet = await _resolveMagnet(torrent);
                            if (!context.mounted) return;
                            if (magnet == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('该结果没有磁力链接')),
                              );
                              return;
                            }
                            await Clipboard.setData(ClipboardData(text: magnet));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('磁力链接已复制')),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('搜索出错',
                          style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          final q = ref.read(searchQueryProvider).query;
                          if (q.isNotEmpty) {
                            _reSearch();
                          }
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              context.go('/downloads');
            case 2:
              context.go('/settings');
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
}

/// 获取种子信息加载框
class _MetadataLoadingDialog extends StatelessWidget {
  const _MetadataLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Flexible(
              child: Text('获取种子信息中...\n（连接 peers 获取元数据，可能需要几十秒）'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _CategoryChip(
      {required this.label, required this.isSelected, required this.onSelected});

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
