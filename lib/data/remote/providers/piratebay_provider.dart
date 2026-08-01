import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

/// The Pirate Bay 搜索源爬虫
class PirateBayProvider extends SearchProvider {
  final Dio _dio;

  PirateBayProvider(this._dio);

  @override
  String get name => 'PirateBay';

  @override
  String get id => 'piratebay';

  @override
  String get baseUrl => 'https://thepiratebay.org';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => true;

  @override
  bool get supportsSorting => true;

  final _logger = AppLogger('PirateBay');

  /// 常用镜像站，主站不可用时依次尝试
  static const _mirrors = [
    'https://pirateproxy.live',
    'https://pirateproxylive.org',
    'https://thepiratebay.org',
    'https://thepiratebay10.org',
  ];

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    for (final mirror in _mirrors) {
      try {
        final result = await _searchMirror(
          mirror: mirror,
          query: query,
          category: category,
          sortBy: sortBy,
          page: page,
        );
        if (result.isSuccess) return result;
        _logger.warning('$mirror 失败: ${result.error}，尝试下一个镜像');
      } catch (e) {
        _logger.warning('$mirror 异常: $e，尝试下一个镜像');
      }
    }
    return Result.error('所有镜像均不可用');
  }

  Future<Result<List<TorrentInfo>>> _searchMirror({
    required String mirror,
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    final url = '$mirror/search/${Uri.encodeComponent(query)}/$page/99/${_sortCode(sortBy)}';
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
    final rows = doc.querySelectorAll('#searchResult tr');

    for (final row in rows) {
      try {
        // 跳过表头行
        if (row.classes.contains('header')) continue;

        // 兼容新旧 TPB 结构：名称在第二列的第一个链接
        final cells = row.querySelectorAll('td');
        final nameEl = cells.length >= 2
            ? cells[1].querySelector('a')
            : null;
        final fallbackName = row.querySelector('a.detLink');
        final effectiveNameEl = nameEl ?? fallbackName;
        if (effectiveNameEl == null) continue;

        final title = effectiveNameEl.text.trim();
        if (title.isEmpty) continue;

        final magnetEl = row.querySelector('a[href^="magnet:"]');
        final magnet = magnetEl?.attributes['href'];
        final infoHash = magnet != null
            ? ProviderUtils.extractHashFromMagnet(magnet)
            : null;
        final hash = infoHash ?? ProviderUtils.hashString(title + row.outerHtml);

        // 新版结构: [分类][名称][时间][磁力][大小][SE][LE][上传者]
        // 旧版结构: [图标][名称+磁力+描述][SE][LE]
        int seeders = 0;
        int leechers = 0;
        int sizeBytes = 0;
        if (cells.length >= 7) {
          // 新版
          seeders = _parseCount(cells[5].text);
          leechers = _parseCount(cells[6].text);
          sizeBytes = ProviderUtils.parseSize(cells[4].text);
        } else {
          // 旧版：SE/LE 在 align=right 列，大小在描述文本
          final rightCells = row.querySelectorAll('td[align="right"]');
          seeders =
              int.tryParse(rightCells.isNotEmpty ? rightCells.first.text.trim() : '0') ?? 0;
          leechers =
              int.tryParse(rightCells.length > 1 ? rightCells[1].text.trim() : '0') ?? 0;
          final descEl = row.querySelector('font.detDesc');
          sizeBytes = ProviderUtils.parseSize(descEl?.text ?? '');
        }

        final detailPath = effectiveNameEl.attributes['href'] ?? '';

        results.add(TorrentInfo(
          title: title,
          infoHash: hash,
          magnetUri: magnet,
          sizeBytes: sizeBytes,
          seeders: seeders,
          leechers: leechers,
          sourceProvider: name,
          detailUrl: detailPath.startsWith('http') ? detailPath : '$mirror$detailPath',
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
  }

  int _parseCount(String raw) {
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  /// TPB 排序码: 99=做种, 7=大小, 3=时间, 1=名称, 5=上传者
  int _sortCode(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.seeders:
        return 99;
      case SortBy.leechers:
        return 99;
      case SortBy.size:
        return 7;
      case SortBy.date:
        return 3;
      case SortBy.relevance:
        return 99;
    }
  }

  @override
  Future<bool> healthCheck() async {
    for (final mirror in _mirrors) {
      try {
        final response = await _dio.get(
          mirror,
          options: Options(
            validateStatus: (_) => true,
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  String? getCategoryPath(TorrentCategory category) => null;

  @override
  String? getSortParam(SortBy sortBy) => null;
}
