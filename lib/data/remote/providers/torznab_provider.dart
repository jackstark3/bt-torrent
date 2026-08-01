import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// Torznab 协议搜索源（对接 Jackett / Prowlarr）
class TorznabProvider extends SearchProvider {
  final Dio _dio;
  final String _apiKey;
  final String _indexerName;
  final String _indexerId;

  TorznabProvider(
    this._dio, {
    required String baseUrl,
    required this._apiKey,
    this._indexerName = 'Jackett',
    this._indexerId = 'jackett',
  }) : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  final String _baseUrl;
  final _logger = AppLogger('Torznab');

  @override
  String get name => _indexerName;

  @override
  String get id => _indexerId;

  @override
  String get baseUrl => _baseUrl;

  /// 未配置 API Key 时自动禁用
  @override
  bool get isEnabled => _apiKey.isNotEmpty;

  @override
  bool get supportsCategories => true;

  @override
  bool get supportsSorting => true;

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    if (!isEnabled) return Result.error('未配置 API Key');

    try {
      final url = '$_baseUrl/api';
      final params = <String, dynamic>{
        't': 'search',
        'q': query,
        'apikey': _apiKey,
        'limit': 50,
        'offset': (page - 1) * 50,
      };
      if (category != null) {
        final catPath = getCategoryPath(category);
        if (catPath != null) params['cat'] = catPath;
      }

      _logger.info('搜索: $_baseUrl/api?t=search&q=$query');

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/rss+xml, application/xml, text/xml',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      if (response.statusCode != 200) {
        return Result.error('HTTP ${response.statusCode}');
      }

      final document = XmlDocument.parse(response.data as String);
      final results = <TorrentInfo>[];

      for (final item in document.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'item')) {
        try {
          final titleEls = item.findElements('title').toList();
          final titleEl = titleEls.isEmpty ? null : titleEls.first;
          final title = titleEl?.innerText.trim() ?? '';
          if (title.isEmpty) continue;

          final linkEls = item.findElements('link').toList();
          final linkEl = linkEls.isEmpty ? null : linkEls.first;
          final magnet = linkEl?.innerText;
          final hashFromMagnet =
              magnet != null ? ProviderUtils.extractHashFromMagnet(magnet) : null;

          final guidEls = item.findElements('guid').toList();
          final guidEl = guidEls.isEmpty ? null : guidEls.first;
          final guid = guidEl?.innerText;
          final hash = hashFromMagnet ??
              (guid != null && guid.length == 40 && RegExp(r'^[a-f0-9]+$', caseSensitive: false).hasMatch(guid)
                  ? guid.toLowerCase()
                  : ProviderUtils.hashString(title));

          final sizeEls = item.findElements('size').toList();
          final sizeEl = sizeEls.isEmpty ? null : sizeEls.first;
          final sizeBytes = int.tryParse(sizeEl?.innerText ?? '') ?? 0;

          final pubDateEls = item.findElements('pubDate').toList();
          final pubDateEl = pubDateEls.isEmpty ? null : pubDateEls.first;
          final addedDate = _parseRfc822(pubDateEl?.innerText);

          // 解析 torznab:attr
          int seeders = 0;
          int leechers = 0;
          for (final el in item.descendants.whereType<XmlElement>()) {
            if (el.name.local != 'attr') continue;
            final attrName = el.getAttribute('name');
            final attrValue = int.tryParse(el.getAttribute('value') ?? '') ?? 0;
            if (attrName == 'seeders') {
              seeders = attrValue;
            } else if (attrName == 'peers') {
              final peers = (attrValue - seeders).clamp(0, 1 << 31);
              leechers = peers.toInt();
            }
          }

          results.add(TorrentInfo(
            title: title,
            infoHash: hash,
            magnetUri: magnet,
            sizeBytes: sizeBytes,
            seeders: seeders,
            leechers: leechers,
            category: ProviderUtils.detectCategory(title),
            sourceProvider: name,
            addedDate: addedDate,
            isVerified: magnet != null,
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

  /// Jackett 分类 ID 映射
  @override
  String? getCategoryPath(TorrentCategory category) {
    switch (category) {
      case TorrentCategory.movies:
        return '2000';
      case TorrentCategory.tv:
        return '5000';
      case TorrentCategory.music:
        return '3000';
      case TorrentCategory.games:
        return '1000';
      case TorrentCategory.software:
        return '4000';
      case TorrentCategory.anime:
        return '5000';
      case TorrentCategory.xxx:
        return '6000';
      case TorrentCategory.other:
        return null;
    }
  }

  @override
  String? getSortParam(SortBy sortBy) => null;

  @override
  Future<bool> healthCheck() async {
    if (!isEnabled) return false;
    try {
      final response = await _dio.get(
        '$_baseUrl/api',
        queryParameters: {'t': 'caps', 'apikey': _apiKey},
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

  /// 解析 RFC 822 日期（"Wed, 31 Jul 2024 10:00:00 +0000"）
  DateTime? _parseRfc822(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceFirst(RegExp(r'[A-Za-z]{3}, '), ''));
  }
}
