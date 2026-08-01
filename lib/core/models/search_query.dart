import 'package:bt_torrent/core/models/torrent_info.dart';

/// 搜索参数
class SearchQuery {
  final String query;
  final TorrentCategory? category;
  final SortBy sortBy;
  final int page;
  final int resultsPerPage;

  const SearchQuery({
    required this.query,
    this.category,
    this.sortBy = SortBy.seeders,
    this.page = 1,
    this.resultsPerPage = 50,
  });

  SearchQuery copyWith({
    String? query,
    TorrentCategory? category,
    SortBy? sortBy,
    int? page,
    int? resultsPerPage,
  }) {
    return SearchQuery(
      query: query ?? this.query,
      category: category ?? this.category,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      resultsPerPage: resultsPerPage ?? this.resultsPerPage,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.query == query &&
      other.category == category &&
      other.sortBy == sortBy &&
      other.page == page;

  @override
  int get hashCode => Object.hash(query, category, sortBy, page);
}
