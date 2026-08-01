import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

/// TorrentGalaxy 搜索源爬虫
class TorrentGalaxyProvider extends SearchProvider {
  final Dio _dio;

  TorrentGalaxyProvider(this._dio);

  @override
  String get name => 'TorrentGalaxy';

  @override
  String get id => 'torrentgalaxy';

  @override
  String get baseUrl => 'https://torrentgalaxy.to';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => false;

  @override
  bool get supportsSorting => true;

  final _logger = AppLogger('TorrentGalaxy');

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    try {
      final url =
          '$baseUrl/torrents.php?search=${Uri.encodeComponent(query)}'
          '&lang=0&nox=2&sort=${_sortParam(sortBy)}&order=desc&page=$page';
      _logger.info('搜索: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      if (response.statusCode != 200) {
        return Result.error('HTTP ${response.statusCode}');
      }

      final doc = parse(response.data as String);
      final results = <TorrentInfo>[];
      final rows = doc.querySelectorAll('div.tgxtablerow');

      for (final row in rows) {
        try {
          final titleEl = row.querySelector('a.txlight');
          if (titleEl == null) continue;

          final title = titleEl.text.trim();
          if (title.isEmpty) continue;

          // 磁力链接
          final magnetEl = row.querySelector('a[href^="magnet:"]');
          final magnet = magnetEl?.attributes['href'];
          final hashFromMagnet =
              magnet != null ? ProviderUtils.extractHashFromMagnet(magnet) : null;
          final hash = hashFromMagnet ?? ProviderUtils.hashString(title + row.outerHtml);

          // 大小
          final sizeBytes = ProviderUtils.parseSize(row.text);

          // 做种/下载数
          final seedsEl = row.querySelector('span.badge.tx-success');
          final leechesEl = row.querySelector('span.badge.tx-danger');
          final seeders =
              int.tryParse(seedsEl?.text.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
          final leechers =
              int.tryParse(leechesEl?.text.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;

          final detailPath = titleEl.attributes['href'] ?? '';

          results.add(TorrentInfo(
            title: title,
            infoHash: hash,
            magnetUri: magnet,
            sizeBytes: sizeBytes,
            seeders: seeders,
            leechers: leechers,
            sourceProvider: name,
            detailUrl: detailPath.startsWith('http') ? detailPath : '$baseUrl$detailPath',
            category: ProviderUtils.detectCategory(title),
            isVerified: magnet != null,
          ));
        } catch (e) {
          _logger.debug('解析行失败: $e');
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

  String _sortParam(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.seeders:
        return 'seeders';
      case SortBy.leechers:
        return 'leechers';
      case SortBy.size:
        return 'size';
      case SortBy.date:
        return 'id';
      case SortBy.relevance:
        return 'seeders';
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        baseUrl,
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
