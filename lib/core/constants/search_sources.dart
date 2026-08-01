/// 搜索源配置
class SearchSourceConfig {
  SearchSourceConfig._();

  /// 内置搜索源列表
  static const builtinSources = [
    source1337x,
    sourcePirateBay,
    sourceSolidTorrents,
    sourceTorrentGalaxy,
  ];

  /// 1337x
  static const source1337x = SearchSourceInfo(
    id: '1337x',
    name: '1337x',
    baseUrl: 'https://1337x.to',
    isEnabled: true,
    supportsCategories: true,
    supportsSorting: true,
  );

  /// The Pirate Bay
  static const sourcePirateBay = SearchSourceInfo(
    id: 'piratebay',
    name: 'The Pirate Bay',
    baseUrl: 'https://thepiratebay.org',
    isEnabled: true,
    supportsCategories: true,
    supportsSorting: true,
  );

  /// SolidTorrents
  static const sourceSolidTorrents = SearchSourceInfo(
    id: 'solidtorrents',
    name: 'SolidTorrents',
    baseUrl: 'https://solidtorrents.to',
    isEnabled: true,
    supportsCategories: true,
    supportsSorting: true,
  );

  /// TorrentGalaxy
  static const sourceTorrentGalaxy = SearchSourceInfo(
    id: 'torrentgalaxy',
    name: 'TorrentGalaxy',
    baseUrl: 'https://torrentgalaxy.to',
    isEnabled: true,
    supportsCategories: true,
    supportsSorting: true,
  );
}

class SearchSourceInfo {
  final String id;
  final String name;
  final String baseUrl;
  final bool isEnabled;
  final bool supportsCategories;
  final bool supportsSorting;

  const SearchSourceInfo({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.isEnabled,
    required this.supportsCategories,
    required this.supportsSorting,
  });
}
