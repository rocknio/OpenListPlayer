/// 设置页：服务器地址+测试连接、排序、播放模式、后台声音、缓冲档。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/openlist_client.dart';
import '../../providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final site = ref.read(settingsProvider).site;
    _nameCtrl = TextEditingController(text: site?.name ?? '');
    _urlCtrl = TextEditingController(text: site?.baseUrl ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _testResult = '请输入地址');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final n = await OpenListClient(site: SiteConfig(baseUrl: url)).testConnection();
      setState(() => _testResult = '连接成功，根目录 $n 个条目');
    } catch (e) {
      setState(() => _testResult = '连接失败: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveSite() async {
    final url = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    await ref.read(settingsProvider.notifier).setSite(
          url.isEmpty ? null : SiteConfig(baseUrl: url, name: name),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存服务器地址')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _section(context, '服务器'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名称（可选）',
                    hintText: '如：家里的网盘',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'OpenList 地址',
                    hintText: 'http://192.168.2.29:5244',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      child: _testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('测试连接'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: _saveSite, child: const Text('保存')),
                    if (_testResult != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testResult!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _testResult!.startsWith('连接成功')
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _section(context, '浏览与播放'),
          ListTile(
            title: const Text('排序方式'),
            subtitle: const Text('文件列表与自动生成播放队列的顺序'),
            // trailing 必须限宽：大字号下 DropdownButton 会撑满整行并触发
            // ListTile "Trailing widget consumes the entire tile width" 断言。
            trailing: _trailingDropdown<SortMode>(
              value: settings.sortMode,
              onChanged: (v) {
                if (v != null) ref.read(settingsProvider.notifier).setSortMode(v);
              },
              items: const [
                DropdownMenuItem(value: SortMode.natural, child: Text('自然排序 (2<10<100)')),
                DropdownMenuItem(value: SortMode.name, child: Text('名称字典序')),
                DropdownMenuItem(value: SortMode.modified, child: Text('修改时间')),
              ],
            ),
          ),
          ListTile(
            title: const Text('默认播放模式'),
            trailing: _trailingDropdown<PlayMode>(
              value: settings.defaultPlayMode,
              onChanged: (v) {
                if (v != null) ref.read(settingsProvider.notifier).setDefaultPlayMode(v);
              },
              items: const [
                DropdownMenuItem(value: PlayMode.sequentialLoop, child: Text('列表循环')),
                DropdownMenuItem(value: PlayMode.repeatOne, child: Text('单曲循环')),
                DropdownMenuItem(value: PlayMode.shuffle, child: Text('随机')),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('视频退后台继续播放声音'),
            subtitle: const Text('关闭后视频切到后台即暂停；音频不受影响'),
            value: settings.videoBackgroundAudio,
            onChanged: (v) => ref.read(settingsProvider.notifier).setVideoBackgroundAudio(v),
          ),
          ListTile(
            title: const Text('缓冲策略（弱网容错）'),
            subtitle: const Text('缓冲中会一直等待，不会自动跳过或从头播放'),
            trailing: _trailingDropdown<BufferProfile>(
              value: settings.bufferProfile,
              onChanged: (v) {
                if (v != null) ref.read(settingsProvider.notifier).setBufferProfile(v);
              },
              items: [
                for (final p in BufferProfile.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
            ),
          ),
          _section(context, '关于'),
          const ListTile(title: Text('OpenListPlayer'), subtitle: Text('v1.0.0 · 网络音视频播放器')),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}

/// ListTile.trailing 用的下拉：限宽 + 选中值省略，避免大字号下撑满整行
Widget _trailingDropdown<T>({
  required T value,
  required ValueChanged<T?> onChanged,
  required List<DropdownMenuItem<T>> items,
}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 150),
    child: DropdownButton<T>(
      value: value,
      onChanged: onChanged,
      isExpanded: true,
      items: [
        for (final it in items)
          DropdownMenuItem<T>(
            value: it.value,
            child: Text(
              (it.child as Text).data ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
}
