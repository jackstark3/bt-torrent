import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bt_torrent/core/models/torznab_config.dart';
import 'package:bt_torrent/data/local/database.dart';
import 'package:bt_torrent/data/remote/providers/leetx_provider.dart';
import 'package:bt_torrent/data/remote/providers/piratebay_provider.dart';
import 'package:bt_torrent/data/remote/providers/ciligou_provider.dart';
import 'package:bt_torrent/data/remote/providers/cilimao_provider.dart';
import 'package:bt_torrent/data/remote/providers/sokitty_provider.dart';
import 'package:bt_torrent/data/remote/providers/dmhy_provider.dart';
import 'package:bt_torrent/data/remote/providers/animetosho_provider.dart';
import 'package:bt_torrent/data/remote/providers/solidtorrents_provider.dart';
import 'package:bt_torrent/data/remote/providers/torrentgalaxy_provider.dart';
import 'package:bt_torrent/data/remote/providers/torznab_provider.dart';
import 'package:bt_torrent/data/remote/magnet_resolver.dart';
import 'package:bt_torrent/data/remote/search_aggregator.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:bt_torrent/data/repositories/download_repository_impl.dart';
import 'package:bt_torrent/data/repositories/search_repository_impl.dart';
import 'package:bt_torrent/data/repositories/settings_repository_impl.dart';
import 'package:bt_torrent/domain/repositories/download_repository.dart';
import 'package:bt_torrent/domain/repositories/search_repository.dart';
import 'package:bt_torrent/domain/repositories/settings_repository.dart';
import 'package:bt_torrent/engine/torrent_engine.dart';

/// Dio 实例
final dioProvider = Provider<Dio>((ref) {
  final proxy = ref.watch(proxyConfigProvider).valueOrNull ?? '';
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
    followRedirects: true,
    maxRedirects: 3,
  ));
  // 应用 HTTP 代理（走代理出网，解决种子站被墙问题）
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      if (proxy.isNotEmpty) {
        client.findProxy = (uri) => 'PROXY $proxy';
      }
      return client;
    },
  );
  return dio;
});

/// 网络代理配置（"host:port"，空串 = 直连）
final proxyConfigProvider = FutureProvider<String>((ref) async {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('proxy') ?? '';
});

/// Drift 数据库
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// SharedPreferences
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('需要在 ProviderScope 中 override');
});

/// Torznab 索引器配置（从 SharedPreferences 读取，设置页更新后 invalidate）
final torznabConfigProvider = FutureProvider<TorznabConfig?>((ref) async {
  final prefs = ref.watch(sharedPrefsProvider);
  return TorznabConfig.loadFromPrefs(prefs);
});

/// 搜索源列表
final searchProvidersProvider = Provider<List<SearchProvider>>((ref) {
  final dio = ref.watch(dioProvider);
  final torznab = ref.watch(torznabConfigProvider).valueOrNull;
  final providers = <SearchProvider>[
    LeetXProvider(dio),
    PirateBayProvider(dio),
    CiliGouProvider(dio),
    CiliMaoProvider(dio),
    SoKittyProvider(dio),
    DmhyProvider(dio),
    AnimeToshoProvider(dio),
    SolidTorrentsProvider(dio),
    TorrentGalaxyProvider(dio),
  ];
  if (torznab != null && torznab.isValid) {
    providers.add(TorznabProvider(
      dio,
      baseUrl: torznab.baseUrl,
      apiKey: torznab.apiKey,
      indexerName: torznab.indexerName,
      indexerId: torznab.indexerId,
    ));
  }
  return providers;
});

/// 搜索聚合器
final searchAggregatorProvider = Provider<SearchAggregator>((ref) {
  final providers = ref.watch(searchProvidersProvider);
  return SearchAggregator(providers);
});

/// 磁力解析器（1337x 等详情页懒解析）
final magnetResolverProvider = Provider<MagnetResolver>((ref) {
  return MagnetResolver(ref.watch(dioProvider));
});

/// 搜索仓库
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final aggregator = ref.watch(searchAggregatorProvider);
  final database = ref.watch(databaseProvider);
  return SearchRepositoryImpl(aggregator, database);
});

/// 下载仓库
final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final engine = ref.watch(torrentEngineProvider);
  final repo = DownloadRepositoryImpl(engine);
  // 启动时恢复持久化的下载任务（未完成任务续传）
  repo.restoreDownloads();
  return repo;
});

/// BT 引擎单例
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = TorrentEngine();
  engine.initialize();
  return engine;
});

/// 设置仓库
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});
