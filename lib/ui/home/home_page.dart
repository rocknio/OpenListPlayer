/// 首页：继续播放卡片 + 播单列表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../player/audio_page.dart';
import '../player/player_screen.dart';
import '../playlist/current_queue_page.dart';
import '../playlist/playlist_detail_page.dart';
import '../tab_index.dart';
import '../widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSite = ref.watch(hasSiteProvider);
    if (!hasSite) {
      return Scaffold(
        appBar: AppBar(title: const Text('云序')),
        body: NoSiteHint(
          onGoSettings: () => ref.read(tabIndexProvider.notifier).set(3),
        ),
      );
    }
    final db = ref.watch(dbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('云序')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _ResumeCard(),
          Text('播单', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const CurrentPlaylistTile(),
          const Divider(height: 1),
          StreamBuilder<List<Playlist>>(
            stream: db.playlistsStream(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('还没有播单，去"播单"tab 新建一个吧')),
                );
              }
              return Column(
                children: [
                  for (final p in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.playlist_play),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_fmtDate(p.createdAt)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PlaylistDetailPage(playlistId: p.id, playlistName: p.name),
                      )),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 创建';
}

/// 继续播放卡片：恢复上次会话（队列 + 文件 + 位置）
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        // 只在未开播（会话恢复态）时显示；播放中由 mini 播放条承担入口
        if (item == null || playback.status != PlaybackStatus.idle) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('继续播放', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${item.isVideo ? '视频' : '音频'} · ${item.parent}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('继续播放'),
                      onPressed: () async {
                        await playback.resumeSession();
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => item.isVideo ? const PlayerScreen() : const AudioPage(),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
