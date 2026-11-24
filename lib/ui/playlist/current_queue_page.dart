/// "当前播放"：把正在播放队列作为默认播单，入口条目 + 详情列表。
/// 数据来自 PlaybackController.queue（内存会话），不属于数据库播单。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../player/audio_page.dart';
import '../player/player_screen.dart';

/// 播单列表顶部的默认条目："当前播放"
class CurrentPlaylistTile extends ConsumerWidget {
  const CurrentPlaylistTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    // PlaybackController 是 ChangeNotifier，Provider 不会因 notifyListeners 重建
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final count = playback.queue.length;
        final current = playback.current;
        final cs = Theme.of(context).colorScheme;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.play_circle_fill, color: cs.primary),
          title: Text('当前播放', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
          subtitle: Text(
            count == 0
                ? '暂无播放内容'
                : current == null
                    ? '共 $count 集'
                    : '共 $count 集 · ${current.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const CurrentQueuePage(),
          )),
        );
      },
    );
  }
}

/// "当前播放"详情：列出正在播放队列，当前项高亮，点击跳转播放。
class CurrentQueuePage extends ConsumerStatefulWidget {
  const CurrentQueuePage({super.key});

  @override
  ConsumerState<CurrentQueuePage> createState() => _CurrentQueuePageState();
}

class _CurrentQueuePageState extends ConsumerState<CurrentQueuePage> {
  Future<void> _open(QueueItem item) async {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => item.isVideo ? const PlayerScreen() : const AudioPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('当前播放')),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final queue = playback.queue;
          if (queue.isEmpty) {
            return const Center(child: Text('暂无正在播放的内容'));
          }
          return ListView.builder(
            itemCount: queue.length,
            itemBuilder: (context, i) {
              final item = queue[i];
              final isCurrent = i == playback.index;
              final cs = Theme.of(context).colorScheme;
              return ListTile(
                dense: true,
                leading: Icon(
                  item.isVideo ? Icons.movie_outlined : Icons.music_note_outlined,
                  color: isCurrent ? cs.primary : null,
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isCurrent
                      ? TextStyle(color: cs.primary, fontWeight: FontWeight.w600)
                      : null,
                ),
                subtitle: Text(
                  _sourceOf(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  // 非当前项跳转；恢复会话 idle 态下点当前项则触发续播开播，已开播则直接进播放页
                  if (!isCurrent) {
                    await playback.jumpTo(i);
                  } else if (playback.status == PlaybackStatus.idle) {
                    await playback.resumeSession();
                  }
                  await _open(item);
                },
              );
            },
          );
        },
      ),
    );
  }

  String _sourceOf(QueueItem item) =>
      item.parent == '/' ? '网盘' : item.parent.split('/').last;
}
