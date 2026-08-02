import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

/// 1337x 搜索源爬虫
class LeetXProvider extends SearchProvider {
  final Dio _dio;

  LeetXProvider(this._dio);

  @override
  String get name => '1337x';

  @override
  String get id => '1337x';

  @override
  String get baseUrl => 'https://www.1377x.to';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => true;

  @override
  bool get supportsSorting => true;

  final _logger = AppLogger('1337x');

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    try {
      final url = _buildSearchUrl(query, category, sortBy, page);
      _logger.info('搜索: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
        ),
      );

      if (response.statusCode != 200) {
        return Result.error('HTTP ${response.statusCode}');
      }

      final doc = parse(response.data as String);
      final results = <TorrentInfo>[];

      // 解析搜索结果表格
      final rows = doc.querySelectorAll('table.table-list tbody tr');

      for (final row in rows) {
        try {
          // 名称单元格最后一个 a 是标题链接（html 包不支持 :nth-child）
          final nameLinks = row.querySelectorAll('td.name a');
          final nameEl = nameLinks.isNotEmpty ? nameLinks.last : null;
          if (nameEl == null) continue;

          final title = nameEl.text.trim();
          final detailPath = nameEl.attributes['href'] ?? '';

          final seedsEl = row.querySelector('td.seeds');
          final leechesEl = row.querySelector('td.leeches');
          final sizeEl = row.querySelector('td.size');

          final seeders =
              int.tryParse(seedsEl?.text.trim() ?? '0') ?? 0;
          final leechers =
              int.tryParse(leechesEl?.text.trim() ?? '0') ?? 0;
          final sizeStr = sizeEl?.text.trim() ?? '0 B';
          final sizeBytes = _parseSize(sizeStr);

          // 从详情路径提取 info_hash（简化处理，用URL作为唯一标识）
          final hashSource = '$baseUrl$detailPath';

          results.add(TorrentInfo(
            title: title,
            infoHash: _hashString(hashSource),
            sizeBytes: sizeBytes,
            seeders: seeders,
            leechers: leechers,
            sourceProvider: name,
            detailUrl: '$baseUrl$detailPath',
            category: _detectCategory(title),
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

  String _buildSearchUrl(
    String query,
    TorrentCategory? category,
    SortBy sortBy,
    int page,
  ) {
    final encodedQuery = Uri.encodeComponent(query);
    final base = '$baseUrl/search/$encodedQuery/$page/';
    return base;
  }

  int _parseSize(String sizeStr) {
    try {
      final parts = sizeStr.split(' ');
      if (parts.length < 2) return 0;
      final value = double.tryParse(parts[0]) ?? 0;
      final unit = parts[1].toUpperCase();
      switch (unit) {
        case 'B':
          return value.toInt();
        case 'KB':
          return (value * 1024).toInt();
        case 'MB':
          return (value * 1024 * 1024).toInt();
        case 'GB':
          return (value * 1024 * 1024 * 1024).toInt();
        case 'TB':
          return (value * 1024 * 1024 * 1024 * 1024).toInt();
        default:
          return value.toInt();
      }
    } catch (_) {
      return 0;
    }
  }

  TorrentCategory? _detectCategory(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('xxx') || lower.contains('porn') || lower.contains('adult')) {
      return TorrentCategory.xxx;
    }
    return null;
  }

  /// 简单字符串哈希作为 info_hash 替代
  String _hashString(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash |= 0;
    }
    return hash.toRadixString(16).padLeft(40, '0');
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        baseUrl,
        options: Options(
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  String? getCategoryPath(TorrentCategory category) {
    return category.apiName;
  }

  @override
  String? getSortParam(SortBy sortBy) {
    return null; // 1337x 默认按做种排序
  }
}
