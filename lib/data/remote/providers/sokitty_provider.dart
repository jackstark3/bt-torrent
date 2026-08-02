import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

/// SoKitty 搜索源（DHT 磁力聚合站）
/// 服务端渲染搜索结果，详情链接里的 40 位哈希即 info_hash，
/// 可直接拼出磁力链接，无需逐条进详情页。
class SoKittyProvider extends SearchProvider {
  final Dio _dio;
  final AppLogger _logger = AppLogger('SoKitty');

  SoKittyProvider(this._dio);

  @override
  String get name => 'SoKitty';

  @override
  String get id => 'sokitty';

  @override
  String get baseUrl => 'https://w1.sokitty.me';

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
      final url =
          '$baseUrl/search?key=${Uri.encodeComponent(query)}&page=$page';
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
      final items = doc.querySelectorAll('div.panel.search-panel');

      for (final panel in items) {
        try {
          final a = panel.querySelector('a.list-title');
          if (a == null) continue;
          final title = a.text.trim();
          final href = a.attributes['href'] ?? '';
          final hashMatch = RegExp(r'/bt/([a-f0-9]{40})').firstMatch(href);
          if (hashMatch == null) continue;
          final hash = hashMatch.group(1)!;

          final footerText = panel.querySelector('.panel-footer')?.text ?? '';
          final sizeMatch =
              RegExp(r'文件大小[：:]\s*([\d.]+\s*[KMGT]?i?B)',
                      caseSensitive: false)
                  .firstMatch(footerText);
          final dateMatch =
              RegExp(r'收录时间[：:]\s*(\d{4}-\d{2}-\d{2})')
                  .firstMatch(footerText);

          results.add(TorrentInfo(
            title: title,
            infoHash: hash,
            magnetUri: ProviderUtils.buildMagnetWithTrackers(hash, title),
            sizeBytes: ProviderUtils.parseSize(sizeMatch?.group(1) ?? ''),
            seeders: 0, // 该站不提供做种数据
            leechers: 0,
            sourceProvider: name,
            detailUrl: '$baseUrl/bt/$hash',
            addedDate: dateMatch != null
                ? DateTime.tryParse(dateMatch.group(1)!)
                : null,
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
