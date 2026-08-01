import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/result.dart';

/// 搜索源抽象接口
abstract class SearchProvider {
  /// 搜索源标识名
  String get name;

  /// 搜索源 ID
  String get id;

  /// 基础 URL
  String get baseUrl;

  /// 是否可用
  bool get isEnabled;

  /// 支持分类筛选
  bool get supportsCategories;

  /// 支持排序
  bool get supportsSorting;

  /// 执行搜索
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  });

  /// 健康检查
  Future<bool> healthCheck();

  /// 获取分类对应的搜索路径
  String? getCategoryPath(TorrentCategory category);

  /// 获取排序对应的参数
  String? getSortParam(SortBy sortBy);
}
