import 'dart:convert';

import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

/// 磁力猫搜索源（torrentkitty 系老牌磁力聚合站）
/// 搜索 URL 为 /magnet_search/{关键词 UTF-8 转 hex}-{页码}-{排序}.html，
/// 结果页中每条标题链接 /magnet_download/{40位hash}.html 直接携带 info_hash，
/// 无需逐条进详情页即可拼出磁力链接。
class CiliMaoProvider extends SearchProvider {
  final Dio _dio;
  final AppLogger _logger = AppLogger('磁力猫');

  CiliMaoProvider(this._dio);

  @override
  String get name => '磁力猫';

  @override
  String get id => 'cilimao';

  @override
  String get baseUrl => 'https://www.cilimao.rest';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => false;

  @override
  bool get supportsSorting => true;

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    try {
      // 关键词 UTF-8 字节转 hex（站点要求，如 rick -> 7269636b）
      final hexKeyword = encodeKeywordHex(query);
      if (hexKeyword.isEmpty) {
        return Result.error('关键词为空');
      }
      final url = '$baseUrl/magnet_search/$hexKeyword-$page-${_sortParam(sortBy)}.html';
      _logger.info('搜索: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': '$baseUrl/',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      if (response.statusCode != 200) {
        return Result.error('HTTP ${response.statusCode}');
      }

      final doc = parse(response.data as String);
      final results = <TorrentInfo>[];
      final items = doc.querySelectorAll('ul#Search_list_wrapper li');

      for (final li in items) {
        try {
          final a = li.querySelector('a.SearchListTitle_result_title');
          if (a == null) continue;
          final title = a.text.trim();
          final href = a.attributes['href'] ?? '';
          final hashMatch =
              RegExp(r'/magnet_download/([a-f0-9]{40})').firstMatch(href);
          if (hashMatch == null) continue;
          final hash = hashMatch.group(1)!;

          final infoText = li.querySelector('.Search_list_info')?.text ?? '';
          final sizeMatch =
              RegExp(r'文件大小：\s*([\d.]+\s*[KMGT]?i?B)', caseSensitive: false)
                  .firstMatch(infoText);
          // 热度（站点展示的访问热度，非做种数）
          final heat = int.tryParse(
                  li.querySelector('.Search_result_type')?.text.trim() ?? '') ??
              0;

          results.add(TorrentInfo(
            title: title,
            infoHash: hash,
            magnetUri: ProviderUtils.buildMagnetWithTrackers(hash, title),
            sizeBytes: ProviderUtils.parseSize(sizeMatch?.group(1) ?? ''),
            seeders: 0, // 该站不提供做种数据
            leechers: 0,
            completedDownloads: heat > 0 ? heat : null,
            sourceProvider: name,
            detailUrl: '$baseUrl/magnet_download/$hash',
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

  /// 关键词 UTF-8 转 hex（站点要求，如 rick -> 7269636b，麻豆 -> e9babbe8b186）
  static String encodeKeywordHex(String keyword) {
    return utf8.encode(keyword.trim()).map((b) {
      return b.toRadixString(16).padLeft(2, '0');
    }).join();
  }

  /// 磁力猫排序参数：空=相关度, id=最新收录, length=文件大小, requests=访问热度
  String _sortParam(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.size:
        return 'length';
      case SortBy.date:
        return 'id';
      case SortBy.leechers:
      case SortBy.seeders:
        return 'requests';
      case SortBy.relevance:
        return '';
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
