import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bt_torrent/core/models/torznab_config.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:bt_torrent/providers/core_providers.dart';
import 'package:bt_torrent/providers/search_providers.dart';
import 'package:bt_torrent/providers/settings_providers.dart';

/// 搜索源管理页：启用/禁用、健康检查、Torznab 配置
class SourceManagementScreen extends ConsumerWidget {
  const SourceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(searchProvidersProvider);
    final sourceStatesAsync = ref.watch(sourceStatesProvider);
    final healthAsync = ref.watch(sourceHealthProvider);
    final torznab = ref.watch(torznabConfigProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('搜索源管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: '内置搜索源'),
          Card(
            child: sourceStatesAsync.when(
              data: (states) {
                final health = healthAsync.valueOrNull ?? const <String, bool>{};
                return Column(
                  children: providers.map((provider) {
                    final isEnabled = states[provider.name] ?? true;
                    final isHealthy = health[provider.name];
                    return ListTile(
                      leading: _HealthDot(status: isHealthy),
                      title: Text(provider.name),
                      subtitle: Text(_subtitle(provider)),
                      trailing: Switch(
                        value: isEnabled,
                        onChanged: (value) => _toggleSource(
                          ref,
                          provider.id,
                          provider.name,
                          value,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载状态失败: $e'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                ref.invalidate(sourceHealthProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('正在检查搜索源连通性...')),
                );
              },
              icon: const Icon(Icons.network_check, size: 18),
              label: const Text('检查全部'),
            ),
          ),
          const SizedBox(height: 16),

          _SectionHeader(title: 'Torznab 索引器'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    torznab?.isValid == true
                        ? Icons.link
                        : Icons.link_off,
                    color: torznab?.isValid == true
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(torznab?.indexerName ?? '未配置'),
                  subtitle: Text(
                    torznab?.isValid == true
                        ? torznab!.baseUrl
                        : '对接 Jackett / Prowlarr 聚合搜索',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showTorznabDialog(context, ref, torznab),
                ),
                if (torznab != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('清除 Torznab 配置'),
                    onTap: () async {
                      await ref
                          .read(settingsRepositoryProvider)
                          .setTorznabConfig(null);
                      ref.invalidate(torznabConfigProvider);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '内置搜索源直接抓取公开站点，稳定性受站点反爬影响。'
            'Torznab 协议可对接自建的 Jackett 或 Prowlarr，'
            '搜索更稳定，推荐高级用户配置。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(SearchProvider provider) {
    final flags = <String>[];
    if (provider.supportsCategories) flags.add('分类');
    if (provider.supportsSorting) flags.add('排序');
    if (provider.id == 'torrentgalaxy') flags.add('需代理访问');
    return flags.isEmpty ? provider.baseUrl : flags.join(' · ');
  }

  Future<void> _toggleSource(
    WidgetRef ref,
    String sourceId,
    String sourceName,
    bool enabled,
  ) async {
    await ref
        .read(searchRepositoryProvider)
        .toggleSource(sourceId, enabled);
    ref.invalidate(sourceStatesProvider);
    ref.invalidate(sourceHealthProvider);
  }

  Future<void> _showTorznabDialog(
    BuildContext context,
    WidgetRef ref,
    TorznabConfig? existing,
  ) async {
    final urlController = TextEditingController(text: existing?.baseUrl ?? '');
    final keyController = TextEditingController(text: existing?.apiKey ?? '');
    final nameController =
        TextEditingController(text: existing?.indexerName ?? 'Jackett');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Torznab 配置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '索引器地址',
                  hintText: 'http://192.168.1.10:9117',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Jackett / Prowlarr 中的密钥',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '显示名称',
                  hintText: 'Jackett',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final config = TorznabConfig(
      baseUrl: urlController.text.trim(),
      apiKey: keyController.text.trim(),
      indexerName: nameController.text.trim().isEmpty
          ? 'Jackett'
          : nameController.text.trim(),
    );

    if (!config.isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写索引器地址和 API Key')),
        );
      }
      return;
    }

    await ref.read(settingsRepositoryProvider).setTorznabConfig(config);
    ref.invalidate(torznabConfigProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Torznab 配置已保存')),
      );
    }
  }
}

/// 健康状态圆点：未知=灰、在线=绿、离线=红
class _HealthDot extends StatelessWidget {
  final bool? status;
  const _HealthDot({this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == null
        ? Colors.grey
        : (status! ? Colors.green : Colors.red);
    return Tooltip(
      message: status == null
          ? '未检查'
          : (status! ? '在线' : '离线'),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
