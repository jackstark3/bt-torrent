import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/result.dart';

/// 搜索仓库接口
abstract class SearchRepository {
  /// 执行搜索
  Future<Result<List<TorrentInfo>>> search(SearchQuery query);

  /// 获取搜索历史
  Future<List<String>> getSearchHistory();

  /// 添加搜索历史
  Future<void> addSearchHistory(String query);

  /// 清除搜索历史
  Future<void> clearSearchHistory();

  /// 获取搜索源名称列表（当前启用的）
  List<String> getEnabledSources();

  /// 切换搜索源启用状态
  Future<void> toggleSource(String sourceId, bool enabled);

  /// 获取搜索源启用状态
  Future<Map<String, bool>> getSourceStates();

  /// 从本地缓存搜索（网络不可用时的回退）
  Future<List<TorrentInfo>> searchCached(String query);
}
