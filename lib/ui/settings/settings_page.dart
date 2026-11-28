/// 设置页（Inset Grouped 分组圆角白卡）：服务器连接、外观主题（浅色/深色/跟随系统）、浏览与播放、关于云序。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/openlist_client.dart';
import '../../providers.dart';
import '../app_theme.dart';
import '../icons.dart';
import '../widgets.dart';

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
  bool _saving = false;

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
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _testResult = '请输入地址');
      return;
    }
    final normalized = SiteConfig.tryNormalizeUrl(raw);
    if (normalized == null) {
      setState(() => _testResult = '地址格式无效，请输入以 http:// 或 https:// 开头的完整地址');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final client = OpenListClient(site: SiteConfig(baseUrl: normalized));
    try {
      final n = await client.testConnection();
      if (!mounted) return;
      setState(() => _testResult = '连接成功，根目录 $n 个条目');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '连接失败: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveSite() async {
    if (_saving) return;
    _saving = true;
    try {
      final raw = _urlCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      if (raw.isEmpty) {
        await ref.read(settingsProvider.notifier).setSite(null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空服务器地址')));
        }
        return;
      }
      final normalized = SiteConfig.tryNormalizeUrl(raw);
      if (normalized == null) {
        setState(() => _testResult = '地址格式无效，请输入以 http:// 或 https:// 开头的完整地址');
        return;
      }
      _urlCtrl.text = normalized;
      await ref.read(settingsProvider.notifier).setSite(
            SiteConfig(baseUrl: normalized, name: name),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存服务器地址')));
      }
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SiteConfig?>(settingsProvider.select((s) => s.site), (prev, next) {
      if (prev == next) return;
      final nextUrl = next?.baseUrl ?? '';
      final nextName = next?.name ?? '';
      if (_urlCtrl.text != nextUrl) _urlCtrl.text = nextUrl;
      if (_nameCtrl.text != nextName) _nameCtrl.text = nextName;
    });

    final settings = ref.watch(settingsProvider);
    final playback = ref.watch(playbackProvider);
    final dividerColor = AppPalette.sandDeepOf(context);
    final successColor = AppPalette.successOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w600))),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final bottomPad = playback.current != null ? kMiniPlayerReservedPadding : 28.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
            children: [
              _section(context, '服务器'),
              InsetSectionCard(
                padding: const EdgeInsets.all(16),
                children: [
                  if (settings.site != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: successColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            settings.site!.display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.inkOf(context),
                            ),
                          ),
                        ),
                        const ToneBadge(label: '已配置', success: true),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '名称（可选）',
                      hintText: '如：家里的网盘',
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
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('测试连接'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: _saveSite, child: const Text('保存')),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _testResult!.startsWith('连接成功')
                            ? successColor
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: dividerColor),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启动时检测 OpenP2P'),
                    subtitle: const Text('未连通时提示并一键拉起 OpenP2P'),
                    value: settings.checkOpenP2pOnStart,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setCheckOpenP2pOnStart(v),
                  ),
                ],
              ),

              _section(context, '外观与显示'),
              InsetSectionCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '主题模式',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppPalette.inkOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '纸感暖陶浅色与夜读暖曜深色',
                              style: TextStyle(fontSize: 12, color: AppPalette.mutedOf(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ThemeSegmentedPicker(
                    value: settings.themePreference,
                    onChanged: (pref) =>
                        ref.read(settingsProvider.notifier).setThemePreference(pref),
                  ),
                ],
              ),

              _section(context, '浏览与播放'),
              InsetSectionCard(
                children: [
                  ListTile(
                    title: const Text('排序方式'),
                    subtitle: const Text('文件列表与自动生成播放队列的顺序'),
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
                  Divider(height: 1, indent: 16, color: dividerColor),
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
                  Divider(height: 1, indent: 16, color: dividerColor),
                  SwitchListTile(
                    title: const Text('视频退后台继续播放声音'),
                    subtitle: const Text('关闭后视频切到后台即暂停；音频不受影响'),
                    value: settings.videoBackgroundAudio,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setVideoBackgroundAudio(v),
                  ),
                  Divider(height: 1, indent: 16, color: dividerColor),
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
                ],
              ),

              _section(context, '关于'),
              InsetSectionCard(
                children: [
                  ListTile(
                    leading: const YunxuLogoMark(size: 38),
                    title: const Text('云序', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('v1.1.0 · OpenList 云端音视频播放器'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppPalette.mutedOf(context),
            letterSpacing: 0.4,
          ),
        ),
      );
}

class _ThemeSegmentedPicker extends StatelessWidget {
  const _ThemeSegmentedPicker({required this.value, required this.onChanged});

  final AppThemePreference value;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final sand = AppPalette.sandOf(context);
    final surface = AppPalette.surfaceOf(context);
    final ink = AppPalette.inkOf(context);
    final muted = AppPalette.mutedOf(context);
    final accent = AppPalette.accentOf(context);

    const options = [
      AppThemePreference.light,
      AppThemePreference.dark,
      AppThemePreference.system,
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == opt ? surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: value == opt ? FontWeight.w600 : FontWeight.w500,
                      color: value == opt ? accent : (muted == ink ? ink : muted),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
      underline: const SizedBox.shrink(),
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
