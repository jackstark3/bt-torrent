import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bt_torrent/providers/core_providers.dart';
import 'package:bt_torrent/providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 下载设置
              _SectionHeader(title: '下载设置'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('仅 WiFi 下下载'),
                      subtitle: const Text('避免消耗移动数据'),
                      value: settings['wifiOnly'] as bool? ?? true,
                      onChanged: (v) {
                        // TODO: 更新设置
                      },
                    ),
                    ListTile(
                      title: const Text('下载路径'),
                      subtitle: Text(settings['downloadPath'] as String? ?? '/'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: 选择目录
                      },
                    ),
                    ListTile(
                      title: const Text('最大并发下载数'),
                      subtitle: Text('${settings['maxDownloads'] ?? 3}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    ListTile(
                      title: const Text('最大连接数'),
                      subtitle: Text('${settings['maxConnections'] ?? 200}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 限速设置
              _SectionHeader(title: '限速设置'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('下载限速'),
                      subtitle: Text(
                          _formatSpeed(settings['downloadRateLimit'] as int? ?? 0)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    ListTile(
                      title: const Text('上传限速'),
                      subtitle: Text(
                          _formatSpeed(settings['uploadRateLimit'] as int? ?? 102400)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 搜索设置
              _SectionHeader(title: '搜索设置'),
              Card(
                child: Column(
                  children: [
                    const _ProxyTile(),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('安全模式'),
                      subtitle: const Text('过滤成人内容'),
                      value: settings['safeMode'] as bool? ?? false,
                      onChanged: (v) {},
                    ),
                    ListTile(
                      title: const Text('搜索源管理'),
                      subtitle: const Text('启用/禁用搜索源'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.pushNamed('sourceManagement');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 外观设置
              _SectionHeader(title: '外观'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('深色模式'),
                      subtitle: const Text('切换深色/浅色主题'),
                      value: settings['darkMode'] as bool? ?? false,
                      onChanged: (v) {
                        // TODO: 更新主题设置
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 高级设置
              _SectionHeader(title: '高级'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('DHT 网络'),
                      subtitle: const Text('启用 DHT 节点（耗电更高）'),
                      value: settings['dhtEnabled'] as bool? ?? false,
                      onChanged: (v) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 关于
              Center(
                child: Text(
                  'BT 种子搜索器 v1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载设置失败: $e')),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              // Can't use context.go in static context - use Navigator
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.download), label: '下载'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec == 0) return '不限速';
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

/// 网络代理配置项
class _ProxyTile extends ConsumerWidget {
  const _ProxyTile();

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final proxyAsync = widgetRef.watch(proxyConfigProvider);
    final proxy = proxyAsync.valueOrNull ?? '';

    return ListTile(
      title: const Text('网络代理'),
      subtitle: Text(
        proxy.isEmpty ? '未配置（直连）' : proxy,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showProxyDialog(context, widgetRef, proxy),
    );
  }

  Future<void> _showProxyDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('网络代理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '代理地址',
                hintText: '如 127.0.0.1:7890，留空 = 直连',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '用于访问被墙的种子站。可填本机代理工具（Clash/V2Ray 等）的混合端口，'
              '需先开启"允许局域网连接"。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
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
    final proxy = controller.text.trim();
    await ref.read(settingsRepositoryProvider).setProxy(proxy);
    ref.invalidate(proxyConfigProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(proxy.isEmpty ? '已切换为直连' : '代理已保存：$proxy')),
      );
    }
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
      child: Text(title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}
