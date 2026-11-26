/// 文件浏览器：胶囊面包屑、目录内即时过滤、排序切换、媒体级播放进度条与「已播」徽章、下拉刷新、浮动多选操作岛。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media_types.dart';
import '../../core/models.dart';
import '../../core/queue_builder.dart';
import '../../data/app_database.dart';
import '../../providers.dart';
import '../app_theme.dart';
import '../icons.dart';
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

  /// 目录内即时过滤状态（零网络开销）
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  /// 按当前目录缓存数据库进度与历史流，避免 build 时重复订阅
  AppDatabase? _cachedDb;
  String? _cachedStreamPath;
  Stream<Map<String, PlayProgress>>? _progressStream;
  Stream<Set<String>>? _historyStream;

  bool get _pickMode => widget.targetPlaylistId != null;

  /// 选中的媒体文件：key 为完整路径，value 携带写入播单所需的全部信息。
  final Map<String, QueueItem> _selected = <String, QueueItem>{};
  bool get _selecting => _selected.isNotEmpty;

  /// 按搜索词过滤后的可见列表
  List<FsEntry> get _visibleEntries {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  /// 当前目录可用于加播单的媒体条目
  Iterable<FsEntry> get _selectable =>
      _visibleEntries.where((e) => !e.isDirectory && isMediaFile(e.name));
  bool get _hasSelectable =>
      _visibleEntries.any((e) => !e.isDirectory && isMediaFile(e.name));

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _ensureDirectoryStreams(AppDatabase db) {
    if (!identical(_cachedDb, db) ||
        _cachedStreamPath != _path ||
        _progressStream == null ||
        _historyStream == null) {
      _cachedDb = db;
      _cachedStreamPath = _path;
      _progressStream = db.directoryProgressesStream(_path);
      _historyStream = db.directoryHistoryPathsStream(_path);
    }
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
        _searchQuery = '';
        _searchCtrl.clear();
        _searching = false;
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
      // 同目录音视频整体替换"正在播放"队列（基于完整目录条目，避免过滤状态截断队列）
      await playback.playFromDirectory(_path, _entries, file.name);
      if (!mounted) return;
      final nextItem = playback.current;
      final openVideo = nextItem?.isVideo ?? isVideoFile(file.name);
      await Navigator.of(context).push(buildPlayerSheetRoute<void>(
        openVideo ? const PlayerScreen() : const AudioPage(),
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

  void _selectAll() {
    setState(() {
      for (final e in _selectable) {
        _selected[_pathOf(e)] = _itemOf(e);
      }
    });
  }

  void _selectNone() {
    setState(() => _selected.clear());
  }

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

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchQuery = '';
        _searchCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(settingsProvider.select((s) => s.site?.baseUrl), (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        _load(path: '/');
      } else if ((next == null || next.isEmpty) && prev != null && prev.isNotEmpty) {
        _loadSerial++;
        setState(() {
          _path = '/';
          _entries = [];
          _selected.clear();
          _searchQuery = '';
          _searchCtrl.clear();
          _searching = false;
          _loading = false;
          _error = null;
        });
      }
    });
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
        body: NoSiteHint(onGoSettings: _goSettings),
      );
    }

    final db = ref.watch(dbProvider);
    _ensureDirectoryStreams(db);

    final interceptBack =
        !_pickMode && isCurrentTab && (_selecting || _searching || _path != '/');
    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !interceptBack) return;
        if (_selecting) {
          setState(() => _selected.clear());
          return;
        }
        if (_searching) {
          _toggleSearch();
          return;
        }
        if (_path != '/') {
          _backTo(_parentOf(_path));
        }
      },
      child: Scaffold(
        appBar: _selecting ? _selectionAppBar() : _normalAppBar(),
        body: Stack(
          children: [
            _buildBody(),
            // 浮动多选操作岛（M6 平滑上浮）
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: AnimatedSlide(
                offset: _selecting ? Offset.zero : const Offset(0, 1.4),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _selecting ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_selecting,
                    child: _selectionIsland(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goSettings() {
    ref.read(tabIndexProvider.notifier).set(3);
  }

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
    final sortMode = ref.watch(settingsProvider.select((s) => s.sortMode));
    return AppBar(
      title: Text(
        _pickMode ? '添加文件到播单' : (_path == '/' ? '文件' : _path.split('/').last),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
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
      actions: [
        if (_pickMode) ..._bulkActions,
        IconButton(
          tooltip: _searching ? '关闭筛选' : '目录内筛选',
          icon: Icon(_searching ? Icons.close : AppIcons.search),
          onPressed: _toggleSearch,
        ),
        if (!_pickMode)
          PopupMenuButton<SortMode>(
            tooltip: '排序方式',
            icon: const Icon(AppIcons.sort),
            initialValue: sortMode,
            onSelected: (m) => ref.read(settingsProvider.notifier).setSortMode(m),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortMode.natural, child: Text('自然排序 (2<10<100)')),
              PopupMenuItem(value: SortMode.name, child: Text('名称字典序')),
              PopupMenuItem(value: SortMode.modified, child: Text('修改时间')),
            ],
          ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_searching ? 88 : 38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _breadcrumb(),
            if (_searching) _searchBar(),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    final sand = AppPalette.sandOf(context);
    final muted = AppPalette.mutedOf(context);
    final matchCount = _visibleEntries.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: sand,
          borderRadius: BorderRadius.circular(11),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(AppIcons.search, size: 17, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 13.5, color: AppPalette.inkOf(context)),
                decoration: InputDecoration(
                  hintText: '在当前目录中筛选文件名…',
                  hintStyle: TextStyle(fontSize: 13, color: muted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              Text(
                '$matchCount 项',
                style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.cancel_rounded, size: 16, color: muted),
              ),
            ],
          ],
        ),
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

  Widget _selectionIsland() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final islandBg = isDark ? AppPalette.darkSurface : AppPalette.inkOf(context);
    final islandFg = isDark ? AppPalette.darkInk : AppPalette.bgOf(context);
    return SafeArea(
      top: false,
      child: Material(
        color: islandBg,
        borderRadius: BorderRadius.circular(18),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Text(
                '已选 ${_selected.length} 项',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: islandFg,
                  fontFeatures: kTabularFigures,
                ),
              ),
              if (_pickMode) ...[
                const SizedBox(width: 8),
                Text(
                  '跨目录保留',
                  style: TextStyle(fontSize: 11.5, color: islandFg.withValues(alpha: 0.65)),
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: Text(_pickMode ? '确认添加' : '加入播单'),
                onPressed: _selected.isEmpty ? null : _addSelectedToPlaylist,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breadcrumb() {
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        children: [
          _crumb('网盘', '/', isCurrent: segments.isEmpty),
          for (var i = 0; i < segments.length; i++)
            _crumb(
              segments[i],
              '/${segments.sublist(0, i + 1).join('/')}',
              isCurrent: i == segments.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _crumb(String label, String target, {required bool isCurrent}) {
    final sand = AppPalette.sandOf(context);
    final accent = AppPalette.accentOf(context);
    final ink = AppPalette.inkOf(context);
    final muted = AppPalette.mutedOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: isCurrent ? null : () => _backTo(target),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent ? sand : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                color: isCurrent ? ink : accent,
              ),
            ),
          ),
        ),
        if (!isCurrent) Icon(AppIcons.chevronRight, size: 15, color: muted),
      ],
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
      return ErrorRetryView(message: '加载失败: $_error', onRetry: () => _load());
    }
    final visible = _visibleEntries;
    if (_entries.isEmpty) {
      return const Center(child: Text('空目录'));
    }
    if (visible.isEmpty) {
      return Center(
        child: Text(
          '当前目录下没有匹配“$_searchQuery”的文件',
          style: TextStyle(color: AppPalette.mutedOf(context)),
        ),
      );
    }

    final playback = ref.watch(playbackProvider);
    return StreamBuilder<Map<String, PlayProgress>>(
      stream: _progressStream,
      builder: (context, progressSnap) {
        final progressMap = progressSnap.data ?? const <String, PlayProgress>{};
        return StreamBuilder<Set<String>>(
          stream: _historyStream,
          builder: (context, historySnap) {
            final historySet = historySnap.data ?? const <String>{};
            return ListenableBuilder(
              listenable: playback,
              builder: (context, _) {
                final bottomPad = _selecting
                    ? 96.0
                    : (!_pickMode && playback.current != null
                        ? kMiniPlayerReservedPadding
                        : 20.0);
                return RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 62,
                      color: AppPalette.sandDeepOf(context).withValues(alpha: 0.7),
                    ),
                    itemBuilder: (context, i) {
                      final entry = visible[i];
                      final fullPath = _pathOf(entry);
                      return _tile(
                        entry,
                        progress: progressMap[fullPath],
                        finished: !progressMap.containsKey(fullPath) && historySet.contains(fullPath),
                        isPlayingCurrent: playback.current?.path == fullPath,
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _tile(
    FsEntry e, {
    required PlayProgress? progress,
    required bool finished,
    required bool isPlayingCurrent,
  }) {
    final path = _pathOf(e);
    final selected = _selected.containsKey(path);
    final media = !e.isDirectory && isMediaFile(e.name);
    final video = media && isVideoFile(e.name);
    final sand = AppPalette.sandOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);
    final accent = AppPalette.accentOf(context);
    final ink = AppPalette.inkOf(context);
    final muted = AppPalette.mutedOf(context);
    final disabled = Theme.of(context).disabledColor;
    final fmt = media ? mediaFormatBadge(e.name) : '';

    final hasProgress = progress != null && progress.durationMs > 0 && progress.positionMs > 0;
    final ratio = hasProgress
        ? (progress.positionMs / progress.durationMs).clamp(0.0, 1.0)
        : 0.0;
    final pct = (ratio * 100).round();

    String subText;
    if (e.isDirectory) {
      subText = '';
    } else if (hasProgress) {
      subText =
          '已播 $pct% · ${formatDuration(Duration(milliseconds: progress.positionMs))} / ${formatDuration(Duration(milliseconds: progress.durationMs))}';
    } else {
      subText = formatFileSize(e.size);
    }

    Widget leading;
    if (selected) {
      leading = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(AppIcons.check, size: 20, color: Theme.of(context).colorScheme.onPrimary),
      );
    } else if (e.isDirectory) {
      leading = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: sand,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(AppIcons.folder, size: 20, color: muted),
      );
    } else if (media) {
      leading = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPlayingCurrent ? accent.withValues(alpha: 0.14) : sand,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(
          video ? AppIcons.movie : AppIcons.musicNote,
          size: 20,
          color: accent,
        ),
      );
    } else {
      leading = SizedBox(
        width: 40,
        height: 40,
        child: Icon(AppIcons.file, size: 20, color: disabled),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onLongPress: media ? () => _longPressMedia(e) : null,
      onTap: (e.isDirectory || media)
          ? () {
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
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isPlayingCurrent ? FontWeight.w600 : FontWeight.w500,
                      height: 1.3,
                      color: !(media || e.isDirectory)
                          ? disabled
                          : (isPlayingCurrent ? accent : ink),
                    ),
                  ),
                  if (subText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: hasProgress ? accent : muted,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ],
                  if (hasProgress) ...[
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 2.5,
                        backgroundColor: sandDeep,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (e.isDirectory)
              Icon(AppIcons.chevronRight, size: 18, color: muted)
            else if (media && finished)
              const ToneBadge(label: '已播', success: true, icon: AppIcons.check)
            else if (fmt.isNotEmpty)
              ToneBadge(label: fmt, accent: isLosslessAudio(e.name)),
          ],
        ),
      ),
    );
  }
}
