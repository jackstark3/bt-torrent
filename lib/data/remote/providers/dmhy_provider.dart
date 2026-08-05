import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// 动漫花园搜索源（RSS XML 接口，磁力 btih 为 base32 编码）
class DmhyProvider extends SearchProvider {
  final Dio _dio;
  final AppLogger _logger = AppLogger('动漫花园');

  DmhyProvider(this._dio);

  @override
  String get name => '动漫花园';

  @override
  String get id => 'dmhy';

  @override
  String get baseUrl => 'https://share.dmhy.org';

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
          '$baseUrl/topics/rss/rss.xml?keyword=${Uri.encodeComponent(query)}';
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

      final doc = XmlDocument.parse(response.data as String);
      final results = <TorrentInfo>[];

      for (final item in doc.findAllElements('item')) {
        try {
          final title =
              item.findElements('title').firstOrNull?.innerText.trim() ?? '';
          if (title.isEmpty) continue;
          final magnet =
              item.findElements('enclosure').firstOrNull?.getAttribute('url') ??
                  '';
          final hash = ProviderUtils.extractHashFromMagnet(magnet);
          if (hash == null) continue;
          final pubDate = item.findElements('pubDate').firstOrNull?.innerText;

          results.add(TorrentInfo(
            title: title,
            infoHash: hash,
            magnetUri: magnet.isEmpty
                ? ProviderUtils.buildMagnetWithTrackers(hash, title)
                : magnet,
            sizeBytes: 0, // RSS 不提供大小
            seeders: 0, // RSS 不提供做种数
            leechers: 0,
            sourceProvider: name,
            detailUrl: item.findElements('link').firstOrNull?.innerText,
            addedDate:
                pubDate != null ? DateTime.tryParse(pubDate) : null,
            category: ProviderUtils.detectCategory(title),
            isVerified: true,
          ));
        } catch (e) {
          _logger.debug('解析 item 失败: $e');
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
