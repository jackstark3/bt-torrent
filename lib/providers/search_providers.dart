import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
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

    state = const AsyncLoading();

    try {
      final stream = ref.read(searchAggregatorProvider).searchStream(searchQuery);
      AggregatedResult last = const AggregatedResult(
        results: [],
        sourceStatuses: {},
        isComplete: true,
      );

      await for (final aggResult in stream) {
        last = aggResult;
        state = AsyncData(aggResult);
      }

      // 所有搜索源都失败时，回退到本地缓存
      if (last.results.isEmpty) {
        final cached =
            await ref.read(searchRepositoryProvider).searchCached(query);
        if (cached.isNotEmpty) {
          state = AsyncData(AggregatedResult(
            results: cached,
            sourceStatuses: const {},
            isComplete: true,
            isCached: true,
          ));
        }
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
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
