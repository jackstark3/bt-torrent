import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

/// AnimeTosho 搜索源（动漫资源聚合，服务端渲染，磁力带 tracker 且有做种数）
class AnimeToshoProvider extends SearchProvider {
  final Dio _dio;
  final AppLogger _logger = AppLogger('AnimeTosho');

  AnimeToshoProvider(this._dio);

  @override
  String get name => 'AnimeTosho';

  @override
  String get id => 'animetosho';

  @override
  String get baseUrl => 'https://animetosho.org';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => false;

  @override
  bool get supportsSorting => false;

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    try {
      final url = '$baseUrl/search?q=${Uri.encodeComponent(query)}';
      _logger.info('搜索: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      if (response.statusCode != 200) {
        return Result.error('HTTP ${response.statusCode}');
      }

      final doc = parse(response.data as String);
      final results = <TorrentInfo>[];
      final entries = doc.querySelectorAll('div.home_list_entry');

      for (final entry in entries) {
        try {
          final linkEl = entry.querySelector('.link a');
          final magnetEl = entry.querySelector('.links a[href^="magnet:"]');
          if (linkEl == null || magnetEl == null) continue;

          final title =
              linkEl.text.trim().replaceAll('\u200b', ''); // 去掉 wbr 零宽空格
          if (title.isEmpty) continue;
          final magnet =
              (magnetEl.attributes['href'] ?? '').replaceAll('&amp;', '&');
          final hash = ProviderUtils.extractHashFromMagnet(magnet);
          if (hash == null) continue;

          final sizeText = entry.querySelector('.size')?.text.trim() ?? '';
          int seeders = 0;
          int leechers = 0;
          final seederInfo =
              entry.querySelector('.links span[title*="Seeders:"]');
          final seedTitle = seederInfo?.attributes['title'] ?? '';
          final sm = RegExp(
            r'Seeders:\s*(\d+).*?Leechers:\s*(\d+)',
            caseSensitive: false,
          ).firstMatch(seedTitle);
          if (sm != null) {
            seeders = int.tryParse(sm.group(1)!) ?? 0;
            leechers = int.tryParse(sm.group(2)!) ?? 0;
          }

          results.add(TorrentInfo(
            title: title,
            infoHash: hash,
            magnetUri: magnet,
            sizeBytes: ProviderUtils.parseSize(sizeText),
            seeders: seeders,
            leechers: leechers,
            sourceProvider: name,
            detailUrl: linkEl.attributes['href'],
            category: ProviderUtils.detectCategory(title),
            isVerified: true,
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
