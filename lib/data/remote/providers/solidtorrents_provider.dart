import 'dart:convert';

import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';

/// SolidTorrents 搜索源（使用官方 JSON API）
class SolidTorrentsProvider extends SearchProvider {
  final Dio _dio;

  SolidTorrentsProvider(this._dio);

  @override
  String get name => 'SolidTorrents';

  @override
  String get id => 'solidtorrents';

  @override
  String get baseUrl => 'https://solidtorrents.to';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => true;

  @override
  bool get supportsSorting => false;

  final _logger = AppLogger('SolidTorrents');

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'page': page,
        'sort': 'seeders',
        'category': _categoryFilter(category),
      };
      final url = '$baseUrl/api/v1/search';
      _logger.info('搜索: $url?q=$query&page=$page');

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      if (response.statusCode != 200) {
        return Result.error('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.data as String) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final torrents = data['torrents'] as List<dynamic>? ?? [];
      final results = <TorrentInfo>[];

      for (final item in torrents) {
        try {
          final map = item as Map<String, dynamic>;
          final title = (map['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;

          final magnet = map['magnet'] as String?;
          final hashFromMagnet =
              magnet != null ? ProviderUtils.extractHashFromMagnet(magnet) : null;
          final hash = (map['hash'] as String?) ??
              hashFromMagnet ??
              ProviderUtils.hashString(title);

          final rawSize = map['size'];
          final sizeBytes = rawSize is num
              ? rawSize.toInt()
              : ProviderUtils.parseSize(rawSize?.toString() ?? '');

          results.add(TorrentInfo(
            title: title,
            infoHash: hash.toLowerCase(),
            magnetUri: magnet,
            sizeBytes: sizeBytes,
            seeders: (map['seeders'] as num?)?.toInt() ?? 0,
            leechers: (map['leechers'] as num?)?.toInt() ?? 0,
            completedDownloads: (map['completed'] as num?)?.toInt(),
            category: _mapCategory(map['category']?.toString()),
            sourceProvider: name,
            detailUrl: _buildDetailUrl(hash),
            posterUrl: map['poster'] as String?,
            addedDate: _parseDate(map['date'] as String?),
            isVerified: true,
          ));
        } catch (e) {
          _logger.debug('解析条目失败: $e');
          continue;
        }
      }

      _logger.info('找到 ${results.length} 个结果');
      return Result.success(results);
    } on DioException catch (e) {
      _logger.error('请求失败', e);
      return Result.error('网络请求失败: ${e.message}');
    } catch (e) {
      _logger.error('解析失败', e);
      return Result.error('搜索失败: $e');
    }
  }

  String _categoryFilter(TorrentCategory? category) {
    switch (category) {
      case TorrentCategory.movies:
        return 'Video>Movies';
      case TorrentCategory.tv:
        return 'Video>TV';
      case TorrentCategory.music:
        return 'Audio';
      case TorrentCategory.games:
        return 'Games';
      case TorrentCategory.software:
        return 'Applications';
      case TorrentCategory.anime:
        return 'Video';
      case TorrentCategory.xxx:
        return 'Porn';
      case TorrentCategory.other:
        return '';
      case null:
        return '';
    }
  }

  TorrentCategory? _mapCategory(String? raw) {
    if (raw == null) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('movies')) return TorrentCategory.movies;
    if (lower.contains('tv') || lower.contains('series')) return TorrentCategory.tv;
    if (lower.contains('music') || lower.contains('audio')) return TorrentCategory.music;
    if (lower.contains('games')) return TorrentCategory.games;
    if (lower.contains('app') || lower.contains('software')) return TorrentCategory.software;
    if (lower.contains('anime')) return TorrentCategory.anime;
    if (lower.contains('porn') || lower.contains('xxx')) return TorrentCategory.xxx;
    return null;
  }

  String _buildDetailUrl(String hash) => '$baseUrl/torrent/$hash';

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/v1/search',
        queryParameters: {'q': 'test', 'page': 1},
        options: Options(
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  String? getCategoryPath(TorrentCategory category) => null;

  @override
  String? getSortParam(SortBy sortBy) => null;
}
