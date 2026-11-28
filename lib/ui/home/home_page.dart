/// 首页（收听中枢 Listening Hub）：品牌抬头 + 常驻续播/正在播放英雄卡 + 最近播放 + 我的播单精选。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/openp2p_probe.dart';
import '../../data/app_database.dart';
import '../../data/openp2p_service.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../app_theme.dart';
import '../icons.dart';
import '../player/audio_page.dart';
import '../player/player_screen.dart';
import '../playlist/current_queue_page.dart';
import '../playlist/playlist_detail_page.dart';
import '../tab_index.dart';
import '../widgets.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  AppDatabase? _cachedDb;
  Stream<List<Playlist>>? _playlistsStream;
  Stream<List<PlayHistory>>? _historyStream;
  bool _openingHistory = false;

  void _ensureStreams(AppDatabase db) {
    if (!identical(_cachedDb, db) || _playlistsStream == null || _historyStream == null) {
      _cachedDb = db;
      _playlistsStream = db.playlistsStream();
      _historyStream = db.historyStream(limit: 10);
    }
  }

  Future<void> _openHistoryItem(PlayHistory h) async {
    if (_openingHistory) return;
    _openingHistory = true;
    try {
      final playback = ref.read(playbackProvider);
      final item = QueueItem(path: h.path, name: h.name, isVideo: h.isVideo);
      await playback.replaceQueue([item], 0);
      if (!mounted) return;
      final active = playback.current ?? item;
      await Navigator.of(context).push(buildPlayerSheetRoute<void>(
        active.isVideo ? const PlayerScreen() : const AudioPage(),
      ));
    } finally {
      _openingHistory = false;
    }
  }

  Future<void> _clearHistory(AppDatabase db) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空最近播放'),
        content: const Text('仅清空历史记录列表，不影响各文件的播放进度和播单。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await db.clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = ref.watch(settingsProvider.select((s) => s.site));
    if (site == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              YunxuLogoMark(size: 26),
              SizedBox(width: 10),
              Text('云序', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        body: NoSiteHint(
          onGoSettings: () => ref.read(tabIndexProvider.notifier).set(3),
        ),
      );
    }

    final db = ref.watch(dbProvider);
    _ensureStreams(db);
    final playback = ref.watch(playbackProvider);
    final openP2p = ref.watch(openP2pMonitorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const YunxuLogoMark(size: 26),
            const SizedBox(width: 10),
            const Text('云序', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            _SiteStatusPill(
              label: site.display,
              hasIssue: openP2p.needsAttention,
              onTap: () => ref.read(tabIndexProvider.notifier).set(3),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final bottomPad = playback.current != null ? kMiniPlayerReservedPadding : 24.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPad),
            children: [
              if (openP2p.needsAttention) ...[
                _OpenP2pBanner(
                  state: openP2p,
                  onLaunch: () async {
                    final ok = await ref.read(openP2pMonitorProvider.notifier).launchOpenP2p();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('未能拉起 OpenP2P，请手动打开')),
                      );
                    }
                  },
                  onRecheck: () =>
                      ref.read(openP2pMonitorProvider.notifier).check(allowPrompt: false),
                ),
                const SizedBox(height: 12),
              ],
              const _HeroResumeCard(),
              // 最近播放（盘活 DB 既有 historyStream）
              StreamBuilder<List<PlayHistory>>(
                stream: _historyStream,
                builder: (context, snap) {
                  final list = snap.data ?? const [];
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: '最近播放',
                        trailing: TextButton(
                          onPressed: () => _clearHistory(db),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            '清空',
                            style: TextStyle(fontSize: 12, color: AppPalette.mutedOf(context)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InsetSectionCard(
                        children: [
                          for (var i = 0; i < list.length && i < 6; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 56,
                                color: AppPalette.sandDeepOf(context),
                              ),
                            _HistoryRow(
                              history: list[i],
                              onTap: () => _openHistoryItem(list[i]),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
              // 我的播单精选区
              _SectionHeader(
                title: '我的播单',
                trailing: TextButton(
                  onPressed: () => ref.read(tabIndexProvider.notifier).set(2),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    '全部',
                    style: TextStyle(fontSize: 12, color: AppPalette.mutedOf(context)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InsetSectionCard(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: CurrentPlaylistTile(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Playlist>>(
                stream: _playlistsStream,
                builder: (context, snap) {
                  final list = snap.data ?? const [];
                  if (list.isEmpty) {
                    return _EmptyPlaylistsCard(
                      onTap: () => ref.read(tabIndexProvider.notifier).set(2),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _PlaylistGridCard(
                      playlist: list[i],
                      index: i,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PlaylistDetailPage(
                          playlistId: list[i].id,
                          playlistName: list[i].name,
                        ),
                      )),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SiteStatusPill extends StatelessWidget {
  const _SiteStatusPill({
    required this.label,
    required this.onTap,
    this.hasIssue = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool hasIssue;

  @override
  Widget build(BuildContext context) {
    final dotColor =
        hasIssue ? Theme.of(context).colorScheme.error : AppPalette.successOf(context);
    final sand = AppPalette.sandOf(context);
    final ink = AppPalette.inkOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sand,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenP2pBanner extends StatelessWidget {
  const _OpenP2pBanner({
    required this.state,
    required this.onLaunch,
    required this.onRecheck,
  });

  final OpenP2pState state;
  final VoidCallback onLaunch;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canLaunch = state.status != OpenP2pStatus.notInstalled;
    final checking = state.isChecking;
    final (title, subtitle) = switch (state.status) {
      OpenP2pStatus.notInstalled => ('未检测到 OpenP2P', '请先安装并运行 OpenP2P 端口映射后重试'),
      OpenP2pStatus.unreachable => ('无法连接 OpenList', '本地映射端口已开启，请检查 OpenP2P 隧道状态'),
      _ => ('OpenP2P 未运行', '需要启动手机上的 OpenP2P 才能连上家里的 OpenList'),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.cloud, size: 18, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (canLaunch) ...[
                FilledButton.tonal(
                  onPressed: onLaunch,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: const Text('启动 OpenP2P'),
                ),
                const SizedBox(width: 8),
              ],
              TextButton(
                onPressed: checking ? null : onRecheck,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: checking
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: cs.onErrorContainer,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('检测中'),
                        ],
                      )
                    : const Text('重新检测'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppPalette.mutedOf(context),
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// 常驻「正在收听 / 继续播放」英雄卡：
/// 恢复态（idle）展示「继续播放」行动卡，播放/暂停态保留为「正在收听」实时进度英雄卡。
class _HeroResumeCard extends ConsumerStatefulWidget {
  const _HeroResumeCard();

  @override
  ConsumerState<_HeroResumeCard> createState() => _HeroResumeCardState();
}

class _HeroResumeCardState extends ConsumerState<_HeroResumeCard> {
  bool _opening = false;

  Future<void> _onPrimaryTap(PlaybackController playback, QueueItem item) async {
    if (_opening) return;
    _opening = true;
    try {
      if (playback.status == PlaybackStatus.idle) {
        await playback.resumeSession();
      }
      if (!mounted) return;
      final cur = playback.current ?? item;
      await Navigator.of(context).push(buildPlayerSheetRoute<void>(
        cur.isVideo ? const PlayerScreen() : const AudioPage(),
      ));
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        if (item == null) return const SizedBox.shrink();

        final isIdle = playback.status == PlaybackStatus.idle;
        final isPlaying = playback.status == PlaybackStatus.playing;
        final accent = AppPalette.accentOf(context);
        final ink = AppPalette.inkOf(context);
        final muted = AppPalette.mutedOf(context);
        final sand = AppPalette.sandOf(context);
        final sandDeep = AppPalette.sandDeepOf(context);
        final fmt = mediaFormatBadge(item.name);
        final typeLabel = fmt.isEmpty
            ? (item.isVideo ? '视频' : '音频')
            : '${item.isVideo ? '视频' : '音频'} · $fmt';

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: InsetSectionCard(
            padding: const EdgeInsets.all(16),
            children: [
              StreamBuilder<Duration>(
                stream: playback.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? playback.currentPosition;
                  final dur = playback.currentDuration;
                  final hasDur = dur.inMilliseconds > 0;
                  final ratio = hasDur
                      ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0;
                  final pct = (ratio * 100).round();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isIdle ? AppIcons.clock : Icons.graphic_eq_rounded,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isIdle ? '继续播放' : (isPlaying ? '正在收听' : '已暂停'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const Spacer(),
                          ToneBadge(label: typeLabel, accent: true),
                          if (hasDur) ...[
                            const SizedBox(width: 6),
                            ToneBadge(label: '$pct%'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: sand,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: isPlaying
                                ? PlayingWaveBars(playing: true, color: accent, size: 18)
                                : Icon(
                                    item.isVideo ? AppIcons.movie : AppIcons.musicNote,
                                    color: accent,
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.isVideo ? '视频' : '音频'} · ${item.parent}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hasDur) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            backgroundColor: sandDeep,
                            valueColor: AlwaysStoppedAnimation(accent),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(pos),
                              style: TextStyle(
                                fontSize: 11,
                                color: accent,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                            Text(
                              formatDuration(dur),
                              style: TextStyle(
                                fontSize: 11,
                                color: muted,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: Icon(
                                isIdle
                                    ? Icons.play_arrow
                                    : (isPlaying ? Icons.open_in_full_rounded : Icons.play_arrow),
                                size: 18,
                              ),
                              label: Text(isIdle ? '继续播放' : '进入播放器'),
                              onPressed: () => _onPrimaryTap(playback, item),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => ref.read(tabIndexProvider.notifier).set(1),
                            child: const Text('浏览文件'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.history, required this.onTap});
  final PlayHistory history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sand = AppPalette.sandOf(context);
    final muted = AppPalette.mutedOf(context);
    final ink = AppPalette.inkOf(context);
    final parent = _parentName(history.path);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: sand,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                history.isVideo ? AppIcons.movie : AppIcons.musicNote,
                size: 17,
                color: muted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relativeTime(history.playedAt),
              style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures),
            ),
          ],
        ),
      ),
    );
  }

  String _parentName(String path) {
    final i = path.lastIndexOf('/');
    if (i <= 0) return '网盘根目录';
    final dir = path.substring(0, i);
    return dir.split('/').last;
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.month}/${t.day}';
  }
}

class _PlaylistGridCard extends StatelessWidget {
  const _PlaylistGridCard({
    required this.playlist,
    required this.index,
    required this.onTap,
  });

  final Playlist playlist;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = AppPalette.surfaceOf(context);
    final sand = AppPalette.sandOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);
    final accent = AppPalette.accentOf(context);
    final success = AppPalette.successOf(context);
    final ink = AppPalette.inkOf(context);
    final muted = AppPalette.mutedOf(context);

    final swatches = index.isEven
        ? [accent, sand, ink]
        : [success, sandDeep, accent];

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sandDeep, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < swatches.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: swatches[i],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(AppIcons.chevronRight, size: 16, color: muted),
                ],
              ),
              const Spacer(),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
              ),
              const SizedBox(height: 3),
              Text(
                '${playlist.createdAt.year}-${playlist.createdAt.month.toString().padLeft(2, '0')}-${playlist.createdAt.day.toString().padLeft(2, '0')} 创建',
                style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaylistsCard extends StatelessWidget {
  const _EmptyPlaylistsCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taupe = AppPalette.taupeOf(context);
    final muted = AppPalette.mutedOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: taupe.withValues(alpha: 0.7)),
        ),
        child: Center(
          child: Text(
            '还没有播单，去"播单"tab 新建一个吧',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
      ),
    );
  }
}
