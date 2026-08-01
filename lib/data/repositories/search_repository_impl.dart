import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/local/database.dart';
import 'package:bt_torrent/data/remote/search_aggregator.dart';
import 'package:bt_torrent/domain/repositories/search_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchAggregator _aggregator;
  final AppDatabase _database;
  final AppLogger _logger = AppLogger('SearchRepo');

  SearchRepositoryImpl(this._aggregator, this._database);

  @override
  Future<Result<List<TorrentInfo>>> search(SearchQuery query) async {
    _logger.info('搜索: "${query.query}"');
    await _syncSourceStates();

    List<TorrentInfo>? allResults;

    try {
      final stream = _aggregator.searchStream(query);

      await for (final aggregated in stream) {
        allResults = aggregated.results;
      }

      final results = allResults ?? [];

      // 缓存到数据库
      if (results.isNotEmpty) {
        try {
          final torrentRows = results
              .map((t) => {
                    'info_hash': t.infoHash,
                    'title': t.title,
                    'magnet_uri': t.magnetUri,
                    'torrent_url': t.torrentUrl,
                    'size_bytes': t.sizeBytes,
                    'seeders': t.seeders,
                    'leechers': t.leechers,
                    'source_provider': t.sourceProvider,
                    'category': t.category?.apiName,
                    'detail_url': t.detailUrl,
                    'poster_url': t.posterUrl,
                    'cached_at': DateTime.now().toIso8601String(),
                  })
              .toList();
          await _database.upsertTorrents(torrentRows);
        } catch (e) {
          _logger.warning('缓存写入失败: $e');
        }
      }

      return Result.success(results);
    } catch (e) {
      _logger.error('搜索失败，尝试缓存', e);
      try {
        final cached = await searchCached(query.query);
        if (cached.isNotEmpty) {
          return Result.success(cached);
        }
      } catch (_) {}
      return Result.error('搜索失败: $e');
    }
  }

  TorrentInfo _mapFromCache(Map<String, dynamic> map) {
    return TorrentInfo(
      title: map['title'] as String? ?? '',
      infoHash: map['info_hash'] as String? ?? '',
      magnetUri: map['magnet_uri'] as String?,
      torrentUrl: map['torrent_url'] as String?,
      sizeBytes: map['size_bytes'] as int? ?? 0,
      seeders: map['seeders'] as int? ?? 0,
      leechers: map['leechers'] as int? ?? 0,
      sourceProvider: map['source_provider'] as String? ?? '',
      detailUrl: map['detail_url'] as String?,
      posterUrl: map['poster_url'] as String?,
    );
  }

  @override
  Future<List<TorrentInfo>> searchCached(String query) async {
    final cached = await _database.searchCached(query);
    return cached.map(_mapFromCache).toList();
  }

  @override
  Future<List<String>> getSearchHistory() => _database.getSearchHistory();

  @override
  Future<void> addSearchHistory(String query) =>
      _database.addSearchHistory(query);

  @override
  Future<void> clearSearchHistory() => _database.clearSearchHistory();

  @override
  List<String> getEnabledSources() =>
      _aggregator.enabledProviders.map((p) => p.name).toList();

  @override
  Future<void> toggleSource(String sourceId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('source_$sourceId', enabled);
    _aggregator.setProviderEnabled(sourceId, enabled);
  }

  @override
  Future<Map<String, bool>> getSourceStates() async {
    await _syncSourceStates();
    final prefs = await SharedPreferences.getInstance();
    final states = <String, bool>{};
    for (final provider in _aggregator.enabledProviders) {
      states[provider.name] = prefs.getBool('source_${provider.id}') ?? true;
    }
    return states;
  }

  /// 从 SharedPreferences 同步所有搜索源的启用状态到聚合器
  Future<void> _syncSourceStates() async {
    final prefs = await SharedPreferences.getInstance();
    for (final provider in _aggregator.allProviders) {
      final enabled = prefs.getBool('source_${provider.id}') ?? true;
      _aggregator.setProviderEnabled(provider.id, enabled);
    }
  }
}
