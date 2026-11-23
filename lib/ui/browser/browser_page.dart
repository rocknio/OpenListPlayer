/// 文件浏览器：目录列表、面包屑、非媒体置灰、下拉刷新、长按多选加播单。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media_types.dart';
import '../../core/models.dart';
import '../../core/queue_builder.dart';
import '../../providers.dart';
import '../player/audio_page.dart';
import '../player/player_screen.dart';
import '../tab_index.dart';
import '../widgets.dart';
import 'add_to_playlist_sheet.dart';

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  String _path = '/';
  List<FsEntry> _entries = [];
  bool _loading = false;
  String? _error;

  /// 多选模式：选中的媒体文件（完整路径）
  final Set<String> _selected = <String>{};
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false, String? path}) async {
    final p = path ?? _path;
    setState(() {
      _loading = true;
      _error = null;
      if (path != null) {
        _path = path;
        _entries = [];
        _selected.clear();
      }
    });
    try {
      final api = ref.read(apiProvider);
      final entries = await api.listDir(p, refresh: refresh);
      if (!mounted) return;
      final sort = ref.read(settingsProvider).sortMode;
      setState(() => _entries = sortEntries(entries, sort));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enter(FsEntry dir) {
    _load(path: joinPath(_path, dir.name));
  }

  void _backTo(String target) {
    _load(path: target);
  }

  Future<void> _tapMedia(FsEntry file) async {
    final playback = ref.read(playbackProvider);
    // 同目录音视频整体替换"正在播放"队列，从所点文件开播（自动续播进度）
    await playback.playFromDirectory(_path, _entries, file.name);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => isVideoFile(file.name) ? const PlayerScreen() : const AudioPage(),
    ));
  }

  void _longPressMedia(FsEntry file) {
    setState(() => _selected.add(joinPath(_path, file.name)));
  }

  void _toggleSelect(FsEntry file) {
    setState(() {
      final p = joinPath(_path, file.name);
      _selected.contains(p) ? _selected.remove(p) : _selected.add(p);
      if (_selected.isEmpty) Navigator.of(context).maybePop(); // 退出多选 appbar
    });
  }

  Future<void> _addSelectedToPlaylist() async {
    final items = _entries
        .where((e) => !e.isDirectory && _selected.contains(joinPath(_path, e.name)))
        .map((e) => QueueItem(
              path: joinPath(_path, e.name),
              name: e.name,
              isVideo: isVideoFile(e.name),
              size: e.size,
              thumb: e.thumb,
            ))
        .toList();
    final db = ref.read(dbProvider);
    final added = await showAddToPlaylistSheet(context, db, items);
    if (added && mounted) {
      setState(() => _selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${items.length} 个文件到播单')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 站点地址变化（首次配置/修改）→ 自动回到根目录重新加载
    ref.listen<String?>(settingsProvider.select((s) => s.site?.baseUrl), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        _load(path: '/');
      }
    });
    final hasSite = ref.watch(hasSiteProvider);
    if (!hasSite) {
      return Scaffold(
        appBar: AppBar(title: const Text('文件')),
        body: NoSiteHint(onGoSettings: () => _goSettings()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selecting) {
          setState(() => _selected.clear());
          return;
        }
        if (_path != '/') {
          _backTo(_parentOf(_path));
          return;
        }
        // 根目录：退出应用
        SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: _selecting ? _selectionAppBar() : _normalAppBar(),
        body: _buildBody(),
        bottomSheet: _selecting ? _selectionBottomBar() : null,
      ),
    );
  }

  void _goSettings() {
    // 切换到设置 tab
    ref.read(tabIndexProvider.notifier).set(3);
  }

  PreferredSizeWidget _normalAppBar() {
    return AppBar(
      title: Text(_path == '/' ? '文件' : _path.split('/').last),
      leading: _path == '/'
          ? null
          : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _backTo(_parentOf(_path))),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(34),
        child: Align(alignment: Alignment.centerLeft, child: _breadcrumb()),
      ),
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selected.clear())),
      title: Text('已选 ${_selected.length} 项'),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _selectionBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: Text('添加到播单 (${_selected.length})'),
            onPressed: _selected.isEmpty ? null : _addSelectedToPlaylist,
          ),
        ),
      ),
    );
  }

  Widget _breadcrumb() {
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _crumb('网盘', '/', isCurrent: segments.isEmpty),
          for (var i = 0; i < segments.length; i++)
            _crumb(segments[i], '/${segments.sublist(0, i + 1).join('/')}',
                isCurrent: i == segments.length - 1),
        ],
      ),
    );
  }

  Widget _crumb(String label, String target, {required bool isCurrent}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isCurrent ? null : () => _backTo(target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              if (!isCurrent)
                Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  String _parentOf(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  Widget _buildBody() {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      // 重试不强制驱动刷新（guest 无刷新权限，客户端已带降级兜底）
      return ErrorRetryView(message: '加载失败: $_error', onRetry: () => _load());
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('空目录'));
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _entries.length,
        itemBuilder: (context, i) => _tile(_entries[i]),
      ),
    );
  }

  Widget _tile(FsEntry e) {
    final path = joinPath(_path, e.name);
    final selected = _selected.contains(path);
    final media = !e.isDirectory && isMediaFile(e.name);
    final sub = e.isDirectory ? '' : formatFileSize(e.size);

    late Widget leading;
    if (e.isDirectory) {
      leading = const Icon(Icons.folder_outlined);
    } else if (media) {
      leading = Icon(isVideoFile(e.name) ? Icons.movie_outlined : Icons.music_note_outlined);
    } else {
      leading = Icon(Icons.insert_drive_file_outlined,
          color: Theme.of(context).disabledColor);
    }

    return ListTile(
      leading: selected
          ? CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.onPrimary),
            )
          : leading,
      title: Text(
        e.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: media || e.isDirectory
            ? null
            : TextStyle(color: Theme.of(context).disabledColor), // 非媒体置灰
      ),
      subtitle: sub.isEmpty ? null : Text(sub),
      enabled: e.isDirectory || media,
      onLongPress: media ? () => _longPressMedia(e) : null,
      onTap: () {
        if (_selecting) {
          if (media) _toggleSelect(e);
          return;
        }
        if (e.isDirectory) {
          _enter(e);
        } else if (media) {
          _tapMedia(e);
        }
        // 非媒体文件：置灰无响应
      },
    );
  }
}
