import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/core/utils/title_matcher.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';

/// 多源并行搜索聚合器
/// 负责并行调用多个搜索源，合并去重排序结果
class SearchAggregator {
  final List<SearchProvider> _providers;
  final AppLogger _logger = AppLogger('SearchAggregator');
  final Set<String> _disabledIds = {};

  SearchAggregator(this._providers);

  /// 所有搜索源（含已禁用的）
  List<SearchProvider> get allProviders =>
      List.unmodifiable(_providers);

  /// 设置搜索源启用状态
  void setProviderEnabled(String id, bool enabled) {
    if (enabled) {
      _disabledIds.remove(id);
    } else {
      _disabledIds.add(id);
    }
  }

  /// 获取启用的搜索源列表
  List<SearchProvider> get enabledProviders =>
      _providers
          .where((p) => p.isEnabled && !_disabledIds.contains(p.id))
          .toList();

  /// 执行聚合搜索
  /// 并行调用所有启用的搜索源，流式返回结果
  Stream<AggregatedResult> searchStream(SearchQuery query) async* {
    final activeProviders = enabledProviders;
    if (activeProviders.isEmpty) {
      _logger.warning('没有启用的搜索源');
      yield AggregatedResult(
        results: [],
        sourceStatuses: {},
        isComplete: true,
        isCached: false,
      );
      return;
    }

    final allResults = <TorrentInfo>[];
    final seenHashes = <String>{};
    final sourceStatuses = <String, SourceStatus>{};
    int completedCount = 0;

    _logger.info('并行搜索 ${activeProviders.length} 个源: "${query.query}"');

    // 为每个搜索源创建 Future
    final futures = <Future<ProviderResult>>[];
    for (final provider in activeProviders) {
      futures.add(_searchProvider(provider, query));
    }

    // 使用 Stream 逐个获取结果（先完成的先 emit）
    final completions = Stream.fromFutures(futures);

    await for (final providerResult in completions) {
      completedCount++;

      if (providerResult.result.isSuccess) {
        final results = providerResult.result.value!;
        sourceStatuses[providerResult.providerName] = SourceStatus.success(
          resultCount: results.length,
        );

        // 去重合并
        for (final item in results) {
          if (!seenHashes.contains(item.infoHash)) {
            seenHashes.add(item.infoHash);
            allResults.add(item);
          }
        }

        _logger.info('${providerResult.providerName}: ${results.length} 条结果');
      } else {
        sourceStatuses[providerResult.providerName] = SourceStatus.error(
          message: providerResult.result.error!,
        );
        _logger.warning(
          '${providerResult.providerName}: 搜索失败 - ${providerResult.result.error}',
        );
      }

      // 流式返回中间结果：不过滤，全部保留，按相关度优先排序
      final queryText = query.query.trim();
      final sorted = sortAggregatedResults(allResults, query.sortBy, queryText);
      yield AggregatedResult(
        results: List.unmodifiable(sorted),
        sourceStatuses: Map.unmodifiable(sourceStatuses),
        isComplete: completedCount >= activeProviders.length,
        totalSources: activeProviders.length,
        completedSources: completedCount,
        isCached: false,
      );
    }
  }

  /// 单个搜索源搜索
  Future<ProviderResult> _searchProvider(
    SearchProvider provider,
    SearchQuery query,
  ) async {
    try {
      final result = await provider.search(
        query: query.query,
        category: query.category,
        sortBy: query.sortBy,
        page: query.page,
      );
      return ProviderResult(
        providerName: provider.name,
        result: result,
      );
    } catch (e) {
      return ProviderResult(
        providerName: provider.name,
        result: Result.error('搜索异常: $e'),
      );
    }
  }

  /// 搜索源健康检查
  Future<Map<String, bool>> healthCheck() async {
    final statuses = <String, bool>{};
    for (final provider in enabledProviders) {
      try {
        statuses[provider.name] = await provider.healthCheck();
      } catch (_) {
        statuses[provider.name] = false;
      }
    }
    return statuses;
  }

  void dispose() {
    _logger.info('SearchAggregator disposed');
  }
}

/// 排序结果：相关度优先，匹配度高的排前面、低的排后面，
/// 同相关度内再按用户选择的排序键排列
List<TorrentInfo> sortAggregatedResults(
  List<TorrentInfo> results,
  SortBy sortBy,
  String query,
) {
  final sorted = List<TorrentInfo>.from(results);
  final queryText = query.trim();

  int compareByRelevanceThen(
    TorrentInfo a,
    TorrentInfo b,
    int Function(TorrentInfo, TorrentInfo) tiebreak,
  ) {
    final sa = TitleMatcher.score(a.title, queryText);
    final sb = TitleMatcher.score(b.title, queryText);
    final cmp = sb.compareTo(sa);
    if (cmp != 0) return cmp;
    return tiebreak(a, b);
  }

  switch (sortBy) {
    case SortBy.seeders:
      sorted.sort((a, b) =>
          compareByRelevanceThen(a, b, (x, y) => y.seeders.compareTo(x.seeders)));
    case SortBy.leechers:
      sorted.sort((a, b) => compareByRelevanceThen(
          a, b, (x, y) => y.leechers.compareTo(x.leechers)));
    case SortBy.size:
      sorted.sort((a, b) =>
          compareByRelevanceThen(a, b, (x, y) => y.sizeBytes.compareTo(x.sizeBytes)));
    case SortBy.date:
      sorted.sort((a, b) => compareByRelevanceThen(a, b, (x, y) {
            final xDate = x.addedDate ?? DateTime(2000);
            final yDate = y.addedDate ?? DateTime(2000);
            return yDate.compareTo(xDate);
          }));
    case SortBy.relevance:
      sorted.sort((a, b) {
        final scoreCompare = TitleMatcher.score(b.title, query)
            .compareTo(TitleMatcher.score(a.title, query));
        if (scoreCompare != 0) return scoreCompare;
        return b.seeders.compareTo(a.seeders);
      });
  }
  return sorted;
}

/// 聚合搜索结果
class AggregatedResult {
  final List<TorrentInfo> results;
  final Map<String, SourceStatus> sourceStatuses;
  final bool isComplete;
  final int totalSources;
  final int completedSources;
  final bool isCached;
  final bool hasMore;
  final bool isLoadingMore;

  const AggregatedResult({
    required this.results,
    required this.sourceStatuses,
    required this.isComplete,
    this.totalSources = 0,
    this.completedSources = 0,
    this.isCached = false,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// 成功的搜索源数量
  int get successCount =>
      sourceStatuses.values.where((s) => s.isSuccess).length;

  /// 搜索结果是否为空
  bool get isEmpty => results.isEmpty;

  /// 总搜索结果数
  int get resultCount => results.length;
}

/// 搜索源状态
class SourceStatus {
  final bool isSuccess;
  final int resultCount;
  final String? message;

  const SourceStatus({
    required this.isSuccess,
    this.resultCount = 0,
    this.message,
  });

  factory SourceStatus.success({int resultCount = 0}) => SourceStatus(
        isSuccess: true,
        resultCount: resultCount,
      );

  factory SourceStatus.error({String? message}) => SourceStatus(
        isSuccess: false,
        message: message ?? '未知错误',
      );
}

/// 单个搜索源返回结果
class ProviderResult {
  final String providerName;
  final Result<List<TorrentInfo>> result;

  const ProviderResult({
    required this.providerName,
    required this.result,
  });
}
