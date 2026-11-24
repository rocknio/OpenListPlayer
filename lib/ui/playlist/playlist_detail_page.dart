/// 播单详情：按本播单的独立进度续播（记住播到哪个文件 + 文件的哪一秒）、拖动排序、左滑删除条目。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/playlist_resume.dart';
import '../../data/app_database.dart';
import '../../providers.dart';
import '../browser/browser_page.dart';
import '../player/audio_page.dart';
import '../player/player_screen.dart';
import '../widgets.dart';

class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId, required this.playlistName});
  final int playlistId;
  final String playlistName;

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  /// 三个流只建一次：避免外层流每次刷新都让内层重新订阅、重新查库
  late final Stream<PlaylistState?> _stateStream;
  late final Stream<List<PlaylistProgress>> _progressStream;
  late final Stream<List<PlaylistItem>> _itemsStream;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    _stateStream = db.playlistStateStream(widget.playlistId);
    _progressStream = db.playlistProgressesStream(widget.playlistId);
    _itemsStream = db.playlistItemsStream(widget.playlistId);
  }

  Future<void> _play(List<PlaylistItem> items, int startIndex) async {
    final playback = ref.read(playbackProvider);
    final queue = items
        .map((e) => QueueItem(path: e.path, name: e.name, isVideo: e.isVideo, size: e.size))
        .toList();
    // 播放 = 复制为"正在播放"队列（播单本体不动），带来源 id 以使用本播单独立进度
    await playback.playQueue(queue, startIndex, playlistId: widget.playlistId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => queue[startIndex].isVideo ? const PlayerScreen() : const AudioPage(),
    ));
  }

  /// 进入文件浏览器为本播单挑选文件
  Future<void> _addFiles() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => BrowserPage(targetPlaylistId: widget.playlistId),
    ));
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加文件到播单')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加文件',
            onPressed: _addFiles,
          ),
        ],
      ),
      // 续播指针（播到哪个文件）+ 每个文件的断点（播到哪一秒）+ 条目列表，三者合并后定位续播起点
      body: StreamBuilder<PlaylistState?>(
        stream: _stateStream,
        builder: (context, stateSnap) => StreamBuilder<List<PlaylistProgress>>(
          stream: _progressStream,
          builder: (context, progressSnap) => StreamBuilder<List<PlaylistItem>>(
            stream: _itemsStream,
            builder: (context, snap) => _buildBody(
              items: snap.data ?? [],
              progress: {for (final p in progressSnap.data ?? []) p.path: p},
              lastPlayedPath: stateSnap.data?.path,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<PlaylistItem> items,
    required Map<String, PlaylistProgress> progress,
    required String? lastPlayedPath,
  }) {
    final db = ref.read(dbProvider);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('播单为空'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加文件'),
              onPressed: _addFiles,
            ),
          ],
        ),
      );
    }
    final resume = locatePlaylistResume(
      paths: [for (final it in items) it.path],
      lastPlayedPath: lastPlayedPath,
      playedPaths: progress.keys.toSet(),
      finishedPaths: {for (final p in progress.values) if (p.finished) p.path},
    );
    final lastPlayedIndex =
        lastPlayedPath == null ? -1 : items.indexWhere((it) => it.path == lastPlayedPath);
    // 续播起点正是上次播到的文件（它还没看完）→ 顶部提示播到了哪一秒
    final lastPlayed = resume.hasProgress && resume.index == lastPlayedIndex
        ? items[lastPlayedIndex]
        : null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (lastPlayed != null) ...[
                _LastPlayedCard(item: lastPlayed, progress: progress[lastPlayed.path]),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(resume.hasProgress
                          ? '继续播放 (${items.length})'
                          : '播放全部 (${items.length})'),
                      onPressed: () => _play(items, resume.index),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('添加文件'),
                    onPressed: _addFiles,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final list = [...items];
              final moved = list.removeAt(oldIndex);
              list.insert(newIndex, moved);
              await db.reorderPlaylistItems(widget.playlistId, list);
            },
            itemBuilder: (context, i) {
              final it = items[i];
              return Dismissible(
                key: ValueKey('pl-item-${it.id}'),
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => db.removePlaylistItem(it.id),
                child: _itemTile(it, progress[it.path],
                    isLastPlayed: i == lastPlayedIndex, onTap: () => _play(items, i)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _itemTile(PlaylistItem it, PlaylistProgress? p,
      {required bool isLastPlayed, required VoidCallback onTap}) {
    final finished = p?.finished == true;
    final ratio = (p != null && p.durationMs > 0)
        ? (p.positionMs / p.durationMs).clamp(0.0, 1.0)
        : 0.0;
    final percent = (ratio * 100).round();
    final sub = finished
        ? '已看完'
        : (p != null && p.durationMs > 0)
            ? '$percent% · ${formatDuration(Duration(milliseconds: p.positionMs))} / ${formatDuration(Duration(milliseconds: p.durationMs))}'
            : formatFileSize(it.size);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: Icon(
            it.isVideo ? Icons.movie_outlined : Icons.music_note_outlined,
            color: isLastPlayed ? cs.primary : null,
          ),
          title: Row(
            children: [
              Expanded(child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isLastPlayed) ...[
                const SizedBox(width: 8),
                const _LastPlayedTag(),
              ],
            ],
          ),
          subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: onTap,
        ),
        if (!finished && ratio > 0)
          LinearProgressIndicator(
            value: ratio,
            minHeight: 2,
            color: cs.primary,
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }
}

/// 列表行上的小标签：标出上次播到的条目
class _LastPlayedTag extends StatelessWidget {
  const _LastPlayedTag();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '上次播到',
        style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 顶部"上次播到"提示：播到哪个文件 + 文件的哪一秒
class _LastPlayedCard extends StatelessWidget {
  const _LastPlayedCard({required this.item, required this.progress});

  final PlaylistItem item;
  final PlaylistProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = progress;
    final hasPosition = p != null && p.durationMs > 0;
    final ratio = hasPosition ? (p.positionMs / p.durationMs).clamp(0.0, 1.0) : 0.0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark_outline, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text('上次播到', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (hasPosition) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatDuration(Duration(milliseconds: p.positionMs))} / '
                '${formatDuration(Duration(milliseconds: p.durationMs))} · ${(ratio * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
