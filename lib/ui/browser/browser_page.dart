/// 文件浏览器：目录列表、面包屑、非媒体置灰、下拉刷新、长按多选加播单。
library;

import 'package:flutter/material.dart';
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
  const BrowserPage({super.key, this.targetPlaylistId});

  /// 非空时为"添加文件到指定播单"模式：点按媒体即选中，确认后直接写入该播单并返回。
  /// 为空时是底部 tab 的普通文件页：长按多选，经底部弹层选择目标播单。
  final int? targetPlaylistId;

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  String _path = '/';
  List<FsEntry> _entries = [];
  bool _loading = false;
  String? _error;
  int _loadSerial = 0;
  bool _openingMedia = false;

  bool get _pickMode => widget.targetPlaylistId != null;

  /// 选中的媒体文件：key 为完整路径，value 携带写入播单所需的全部信息。
  /// 普通模式切换目录时清空；选择模式跨目录保留，可一次添加多个目录的文件。
  final Map<String, QueueItem> _selected = <String, QueueItem>{};
  bool get _selecting => _selected.isNotEmpty;

  /// 当前目录可用于加播单的媒体条目
  Iterable<FsEntry> get _selectable =>
      _entries.where((e) => !e.isDirectory && isMediaFile(e.name));
  bool get _hasSelectable => _entries.any((e) => !e.isDirectory && isMediaFile(e.name));

  String _pathOf(FsEntry e) => joinPath(_path, e.name);

  QueueItem _itemOf(FsEntry e) => QueueItem(
        path: _pathOf(e),
        name: e.name,
        isVideo: isVideoFile(e.name),
        size: e.size,
        thumb: e.thumb,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false, String? path}) async {
    final p = path ?? _path;
    final serial = ++_loadSerial;
    setState(() {
      _loading = true;
      _error = null;
      if (path != null) {
        _path = path;
        _entries = [];
        // 选择模式保留跨目录的已选项；普通模式沿用"切目录即清空"的原行为
        if (!_pickMode) _selected.clear();
      }
    });
    try {
      final api = ref.read(apiProvider);
      final entries = await api.listDir(p, refresh: refresh);
      if (!mounted || serial != _loadSerial) return;
      final sort = ref.read(settingsProvider).sortMode;
      setState(() => _entries = sortEntries(entries, sort));
    } catch (e) {
      if (!mounted || serial != _loadSerial) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted && serial == _loadSerial) {
        setState(() => _loading = false);
      }
    }
  }

  void _enter(FsEntry dir) {
    _load(path: joinPath(_path, dir.name));
  }

  void _backTo(String target) {
    _load(path: target);
  }

  Future<void> _tapMedia(FsEntry file) async {
    if (_openingMedia) return;
    _openingMedia = true;
    try {
      final playback = ref.read(playbackProvider);
      // 同目录音视频整体替换"正在播放"队列，从所点文件开播（自动续播进度）
      await playback.playFromDirectory(_path, _entries, file.name);
      if (!mounted) return;
      final nextItem = playback.current;
      final openVideo = nextItem?.isVideo ?? isVideoFile(file.name);
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => openVideo ? const PlayerScreen() : const AudioPage(),
      ));
    } finally {
      _openingMedia = false;
    }
  }

  void _longPressMedia(FsEntry file) {
    setState(() => _selected[_pathOf(file)] = _itemOf(file));
  }

  void _toggleSelect(FsEntry file) {
    setState(() {
      final p = _pathOf(file);
      _selected.containsKey(p) ? _selected.remove(p) : _selected[p] = _itemOf(file);
    });
  }

  /// 全选当前目录的媒体文件（目录与非媒体不参与）
  void _selectAll() {
    setState(() {
      for (final e in _selectable) {
        _selected[_pathOf(e)] = _itemOf(e);
      }
    });
  }

  /// 清空所有已选项（含跨目录）
  void _selectNone() {
    setState(() => _selected.clear());
  }

  /// 反选当前目录的媒体文件
  void _invertSelection() {
    setState(() {
      for (final e in _selectable) {
        final p = _pathOf(e);
        _selected.containsKey(p) ? _selected.remove(p) : _selected[p] = _itemOf(e);
      }
    });
  }

  Future<void> _addSelectedToPlaylist() async {
    final items = _selected.values.toList();
    if (items.isEmpty) return;
    final db = ref.read(dbProvider);
    if (_pickMode) {
      // 选择模式：直接写入目标播单，返回实际新增数量由播单详情页给出提示
      final addedCount = await db.addItemsToPlaylist(widget.targetPlaylistId!, items);
      if (mounted) Navigator.of(context).pop(addedCount);
      return;
    }
    final addedCount = await showAddToPlaylistSheet(context, db, items);
    if (addedCount != null && mounted) {
      setState(() => _selected.clear());
      final msg = addedCount > 0 ? '已添加 $addedCount 个文件到播单' : '所选文件已在播单中';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 站点地址变化（首次配置/修改/清空）→ 自动回到根目录或重置状态
    ref.listen<String?>(settingsProvider.select((s) => s.site?.baseUrl), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        _load(path: '/');
      } else if ((next == null || next.isEmpty) && prev != null && prev.isNotEmpty) {
        _loadSerial++;
        setState(() {
          _path = '/';
          _entries = [];
          _selected.clear();
          _loading = false;
          _error = null;
        });
      }
    });
    // 排序设置修改时立即对当前已加载目录重排，无需用户手动下拉刷新
    ref.listen<SortMode>(settingsProvider.select((s) => s.sortMode), (prev, next) {
      if (prev != next && _entries.isNotEmpty) {
        setState(() => _entries = sortEntries(_entries, next));
      }
    });
    final hasSite = ref.watch(hasSiteProvider);
    final isCurrentTab = _pickMode || ref.watch(tabIndexProvider) == 1;
    if (!hasSite) {
      return Scaffold(
        appBar: AppBar(title: Text(_pickMode ? '添加文件到播单' : '文件')),
        body: NoSiteHint(onGoSettings: () => _goSettings()),
      );
    }
    final interceptBack = !_pickMode && isCurrentTab && (_selecting || _path != '/');
    return PopScope(
      // 选择模式、非当前激活 tab、或已在根目录无多选时交给系统默认返回逻辑
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !interceptBack) return;
        if (_selecting) {
          setState(() => _selected.clear());
          return;
        }
        if (_path != '/') {
          _backTo(_parentOf(_path));
        }
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

  /// 全选 / 反选 / 全不选快捷操作，普通多选态与选择模式共用
  List<Widget> get _bulkActions => [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: '全选当前目录',
          onPressed: !_hasSelectable ? null : _selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: '反选当前目录',
          onPressed: !_hasSelectable ? null : _invertSelection,
        ),
        if (_selecting)
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: '全不选',
            onPressed: _selectNone,
          ),
      ];

  PreferredSizeWidget _normalAppBar() {
    return AppBar(
      title: Text(_pickMode
          ? '添加文件到播单'
          : (_path == '/' ? '文件' : _path.split('/').last)),
      leading: _pickMode
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消添加',
              onPressed: () => Navigator.of(context).pop(),
            )
          : (_path == '/'
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _backTo(_parentOf(_path)),
                )),
      // 选择模式一进页面即可用全选，无需先手动点选一个文件
      actions: _pickMode ? _bulkActions : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(34),
        child: Align(alignment: Alignment.centerLeft, child: _breadcrumb()),
      ),
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          if (_pickMode) {
            Navigator.of(context).pop();
          } else {
            setState(() => _selected.clear());
          }
        },
      ),
      title: Text('已选 ${_selected.length} 项'),
      backgroundColor: cs.secondaryContainer,
      actions: _bulkActions,
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
            label: Text(_pickMode
                ? '确认添加到播单 (${_selected.length})'
                : '添加到播单 (${_selected.length})'),
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
        padding: _selecting ? const EdgeInsets.only(bottom: 84) : null,
        itemCount: _entries.length,
        itemBuilder: (context, i) => _tile(_entries[i]),
      ),
    );
  }

  Widget _tile(FsEntry e) {
    final path = _pathOf(e);
    final selected = _selected.containsKey(path);
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
        // 选择模式下点按媒体即选中（目录照常进入，便于跨目录累积）
        if (_pickMode && media) {
          _toggleSelect(e);
          return;
        }
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
