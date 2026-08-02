import 'package:dio/dio.dart';

import 'package:bt_torrent/core/utils/logger.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';

/// 从种子详情页解析磁力链接
/// 1337x 等源在列表页不提供磁力，需要进详情页提取
class MagnetResolver {
  final Dio _dio;
  final AppLogger _logger = AppLogger('MagnetResolver');

  /// 详情 URL -> 磁力链接（null 表示解析过但失败），避免重复请求
  final Map<String, String?> _cache = {};

  MagnetResolver(this._dio);

  Future<String?> resolve(String detailUrl) async {
    if (_cache.containsKey(detailUrl)) {
      return _cache[detailUrl];
    }
    try {
      final response = await _dio.get(
        detailUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      final html = response.data as String? ?? '';
      final match = RegExp(r'magnet:\?xt=urn:btih:[A-Fa-f0-9]{40}[^"\s<>]*')
          .firstMatch(html);
      var magnet = match?.group(0);
      // 详情页磁力若无 tracker，补上公共 tracker，提升下载/播放成功率
      if (magnet != null && !ProviderUtils.magnetHasTrackers(magnet)) {
        magnet = '$magnet${ProviderUtils.publicTrackers
            .map((t) => '&tr=${Uri.encodeComponent(t)}')
            .join()}';
      }
      _cache[detailUrl] = magnet;
      if (magnet == null) {
        _logger.warning('详情页未找到磁力: $detailUrl');
      } else {
        _logger.info('已解析磁力: $detailUrl');
      }
      return magnet;
    } catch (e) {
      _logger.warning('解析磁力失败: $detailUrl $e');
      _cache[detailUrl] = null;
      return null;
    }
  }
}
