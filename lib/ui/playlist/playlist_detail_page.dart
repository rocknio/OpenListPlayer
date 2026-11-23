/// 播单详情：播放（复制为"正在播放"队列）、拖动排序、左滑删除条目。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
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
  Future<void> _play(List<PlaylistItem> items, int startIndex) async {
    final playback = ref.read(playbackProvider);
    final queue = items
        .map((e) => QueueItem(path: e.path, name: e.name, isVideo: e.isVideo, size: e.size))
        .toList();
    // 播放 = 复制为"正在播放"队列（播单本体不动）
    await playback.playQueue(queue, startIndex);
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
    final db = ref.watch(dbProvider);
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
      body: StreamBuilder<List<PlaylistItem>>(
        stream: db.playlistItemsStream(widget.playlistId),
        builder: (context, snap) {
          final items = snap.data ?? [];
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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text('播放全部 (${items.length})'),
                        onPressed: () => _play(items, 0),
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
                      child: ListTile(
                        dense: true,
                        leading: Icon(it.isVideo ? Icons.movie_outlined : Icons.music_note_outlined),
                        title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatFileSize(it.size)),
                        onTap: () => _play(items, i),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
