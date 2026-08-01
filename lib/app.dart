import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bt_torrent/features/search/search_screen.dart';
import 'package:bt_torrent/features/download/download_list_screen.dart';
import 'package:bt_torrent/features/download/download_detail_screen.dart';
import 'package:bt_torrent/features/player/player_screen.dart';
import 'package:bt_torrent/features/settings/settings_screen.dart';
import 'package:bt_torrent/features/settings/source_management_screen.dart';
import 'package:bt_torrent/providers/settings_providers.dart';

/// 路由配置
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (context, state) => const DownloadListScreen(),
      ),
      GoRoute(
        path: '/download/:infoHash',
        name: 'downloadDetail',
        builder: (context, state) {
          final infoHash = state.pathParameters['infoHash']!;
          return DownloadDetailScreen(infoHash: infoHash);
        },
      ),
      GoRoute(
        path: '/player/:infoHash/:fileIndex',
        name: 'player',
        builder: (context, state) {
          final infoHash = state.pathParameters['infoHash']!;
          final fileIndex = int.parse(state.pathParameters['fileIndex']!);
          return PlayerScreen(infoHash: infoHash, fileIndex: fileIndex);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/sources',
        name: 'sourceManagement',
        builder: (context, state) => const SourceManagementScreen(),
      ),
    ],
  );
});

/// 应用根 Widget
class BtApp extends ConsumerWidget {
  const BtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final darkModeAsync = ref.watch(darkModeProvider);

    return MaterialApp.router(
      title: 'BT种子搜索器',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      themeMode: darkModeAsync.when(
        data: (dark) => dark ? ThemeMode.dark : ThemeMode.light,
        loading: () => ThemeMode.system,
        error: (_, __) => ThemeMode.system,
      ),
    );
  }
}
