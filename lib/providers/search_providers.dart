import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/data/remote/search_aggregator.dart';
import 'package:bt_torrent/providers/core_providers.dart';

/// 当前搜索查询
final searchQueryProvider = StateProvider<SearchQuery>((ref) {
  return const SearchQuery(query: '');
});

/// 搜索结果状态
final searchResultsProvider =
    AsyncNotifierProvider<SearchNotifier, AggregatedResult>(
  SearchNotifier.new,
);

class SearchNotifier extends AsyncNotifier<AggregatedResult> {
  final AppLogger _logger = AppLogger('SearchNotifier');
  final Map<String, TorrentInfo> _byHash = {};
  SearchQuery? _activeQuery;
  int _page = 1;
  bool _loadingMore = false;

  @override
  Future<AggregatedResult> build() async {
    return const AggregatedResult(
      results: [],
      sourceStatuses: {},
      isComplete: true,
    );
  }

  /// 执行搜索
  Future<void> search(
    String query, {
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
  }) async {
    if (query.trim().isEmpty) return;

    final searchQuery = SearchQuery(
      query: query,
      category: category,
      sortBy: sortBy,
    );

    ref.read(searchQueryProvider.notifier).state = searchQuery;
    _activeQuery = searchQuery;
    _page = 1;
    _byHash.clear();

    state = const AsyncLoading();

    await _runSearch(searchQuery, append: false);
  }

  /// 加载下一页结果（追加到当前列表）
  Future<void> loadMore() async {
    final query = _activeQuery;
    if (query == null || _loadingMore || state.value?.isLoadingMore == true) {
      return;
    }
    _loadingMore = true;
    // 通知 UI 显示加载中
    final current = state.value;
    if (current != null) {
      state = AsyncData(AggregatedResult(
        results: current.results,
        sourceStatuses: current.sourceStatuses,
        isComplete: current.isComplete,
        totalSources: current.totalSources,
        completedSources: current.completedSources,
        isCached: current.isCached,
        hasMore: current.hasMore,
        isLoadingMore: true,
      ));
    }
    try {
      final pageQuery = query.copyWith(page: _page + 1);
      await _runSearch(pageQuery, append: true);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _runSearch(SearchQuery searchQuery, {required bool append}) async {
    try {
      final stream = ref.read(searchAggregatorProvider).searchStream(searchQuery);
      AggregatedResult last = const AggregatedResult(
        results: [],
        sourceStatuses: {},
        isComplete: true,
      );

      await for (final aggResult in stream) {
        last = aggResult;
        _mergeResults(aggResult.results);
        state = AsyncData(_mergedResult(last, isLoadingMore: _loadingMore));
      }

      // 诊断：合并结果按来源分布
      final distribution = <String, int>{};
      for (final t in _byHash.values) {
        distribution[t.sourceProvider] =
            (distribution[t.sourceProvider] ?? 0) + 1;
      }
      _logger.info('合并结果分布: $distribution');

      if (append) {
        _page = searchQuery.page;
        state = AsyncData(_mergedResult(
          last,
          isLoadingMore: false,
          hasMore: last.resultCount >= 10,
        ));
        return;
      }

      // 第一页：所有搜索源都失败/为空时，回退到本地缓存
      if (_byHash.isEmpty) {
        final cached =
            await ref.read(searchRepositoryProvider).searchCached(searchQuery.query);
        if (cached.isNotEmpty) {
          for (final t in cached) {
            _byHash[t.infoHash] = t;
          }
          state = AsyncData(AggregatedResult(
            results: sortAggregatedResults(
                _byHash.values.toList(), searchQuery.sortBy, searchQuery.query),
            sourceStatuses: const {},
            isComplete: true,
            isCached: true,
          ));
          return;
        }
      }

      state = AsyncData(_mergedResult(
        last,
        hasMore: last.resultCount >= 10,
      ));
    } catch (e, st) {
      if (!append) {
        state = AsyncError(e, st);
      }
    }
  }

  void _mergeResults(List<TorrentInfo> results) {
    for (final t in results) {
      final existing = _byHash[t.infoHash];
      if (existing == null) {
        _byHash[t.infoHash] = t;
      } else if (existing.sourceProvider != t.sourceProvider &&
          !existing.additionalSources.contains(t.sourceProvider)) {
        _byHash[t.infoHash] = existing.copyWith(
          additionalSources: [...existing.additionalSources, t.sourceProvider],
        );
      }
    }
  }

  AggregatedResult _mergedResult(
    AggregatedResult latest, {
    bool isLoadingMore = false,
    bool hasMore = false,
  }) {
    final query = _activeQuery;
    return AggregatedResult(
      results: query == null
          ? _byHash.values.toList()
          : sortAggregatedResults(
              _byHash.values.toList(), query.sortBy, query.query),
      sourceStatuses: latest.sourceStatuses,
      isComplete: latest.isComplete,
      totalSources: latest.totalSources,
      completedSources: latest.completedSources,
      isCached: latest.isCached,
      hasMore: hasMore || latest.hasMore,
      isLoadingMore: isLoadingMore,
    );
  }

  /// 添加搜索历史
  Future<void> addToHistory(String query) async {
    final searchRepo = ref.read(searchRepositoryProvider);
    await searchRepo.addSearchHistory(query);
  }
}

/// 搜索历史
final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(searchRepositoryProvider);
  return repo.getSearchHistory();
});

/// 搜索源健康状态
final sourceHealthProvider = FutureProvider<Map<String, bool>>((ref) async {
  final aggregator = ref.read(searchAggregatorProvider);
  return aggregator.healthCheck();
});
