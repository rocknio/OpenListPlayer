/// 首页：继续播放卡片 + 最近播放。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../data/app_database.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../tab_index.dart';
import '../widgets.dart';
import '../player/audio_page.dart';
import '../player/player_screen.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSite = ref.watch(hasSiteProvider);
    if (!hasSite) {
      return Scaffold(
        appBar: AppBar(title: const Text('OpenListPlayer')),
        body: NoSiteHint(
          onGoSettings: () => ref.read(tabIndexProvider.notifier).set(3),
        ),
      );
    }
    final db = ref.watch(dbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('OpenListPlayer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _ResumeCard(),
          const SizedBox(height: 16),
          Text('最近播放', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<PlayHistory>>(
            stream: db.historyStream(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('暂无播放记录，去"文件"页选一个吧')),
                );
              }
              return Column(
                children: [
                  for (final h in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(h.isVideo ? Icons.movie_outlined : Icons.music_note_outlined),
                      title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      // 进度合并进 subtitle：大字号下 trailing 文本会占满整行并触发
                      // ListTile "Trailing widget consumes the entire tile width" 断言。
                      subtitle: _HistorySubtitle(playedAt: h.playedAt, path: h.path),
                      onTap: () => _openFromHistory(context, ref, h),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openFromHistory(BuildContext context, WidgetRef ref, PlayHistory h) async {
    final playback = ref.read(playbackProvider);
    final api = ref.read(apiProvider);
    final item = QueueItem(path: h.path, name: h.name, isVideo: h.isVideo);
    final parent = item.parent;
    try {
      final entries = await api.listDir(parent);
      await playback.playFromDirectory(parent, entries, h.name);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => h.isVideo ? const PlayerScreen() : const AudioPage(),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开失败: $e')));
      }
    }
  }
}

/// 继续播放卡片：恢复上次会话（队列 + 文件 + 位置）
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final item = playback.current;
    // 只在未开播（会话恢复态）时显示；播放中由 mini 播放条承担入口
    if (item == null || playback.status != PlaybackStatus.idle) return const SizedBox.shrink();
    return Card(
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
            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('${item.isVideo ? '视频' : '音频'} · ${item.parent}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// 历史条目上的进度角标（有未看完进度时显示）
class _HistoryProgress extends ConsumerWidget {
  const _HistoryProgress({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    return StreamBuilder<PlayProgress?>(
      stream: db.progressStream(path),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const SizedBox.shrink();
        final pos = Duration(milliseconds: p.positionMs);
        final dur = Duration(milliseconds: p.durationMs);
        if (dur == Duration.zero) return const SizedBox.shrink();
        return Text('看到 ${formatDuration(pos)} / ${formatDuration(dur)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall);
      },
    );
  }
}

/// 副标题：相对时间 + 播放进度（同一行，超长省略）
class _HistorySubtitle extends StatelessWidget {
  const _HistorySubtitle({required this.playedAt, required this.path});
  final DateTime playedAt;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(relTime(playedAt)),
        const SizedBox(width: 8),
        Flexible(child: _HistoryProgress(path: path)),
      ],
    );
  }
}

String relTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
