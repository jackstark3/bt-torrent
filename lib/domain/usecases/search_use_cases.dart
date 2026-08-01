import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/domain/repositories/search_repository.dart';

/// 搜索种子用例
class SearchTorrentsUseCase {
  final SearchRepository _repository;
  const SearchTorrentsUseCase(this._repository);

  Future<Result<List<TorrentInfo>>> execute(SearchQuery query) {
    return _repository.search(query);
  }
}

/// 获取搜索历史用例
class GetSearchHistoryUseCase {
  final SearchRepository _repository;
  const GetSearchHistoryUseCase(this._repository);

  Future<List<String>> execute() => _repository.getSearchHistory();
}

/// 清除搜索历史用例
class ClearSearchHistoryUseCase {
  final SearchRepository _repository;
  const ClearSearchHistoryUseCase(this._repository);

  Future<void> execute() => _repository.clearSearchHistory();
}
