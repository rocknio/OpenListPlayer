/// 底部常驻 mini 播放条（一体化暖陶胶囊 + 底部贯穿进度细线 + 左右横滑切歌 + 自底向上模态展开）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../player/playback_controller.dart';
import '../providers.dart';
import 'app_theme.dart';
import 'icons.dart';
import 'player/audio_page.dart';
import 'player/audio_theme.dart';
import 'player/player_screen.dart';
import 'widgets.dart';

class MiniPlayerBar extends ConsumerStatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> {
  double _swipeDx = 0;

  void _openPlayer(BuildContext context, PlaybackController playback, QueueItem item) {
    if (playback.status == PlaybackStatus.idle) {
      unawaited(playback.resumeSession());
    }
    Navigator.of(context).push(buildPlayerSheetRoute<void>(
      item.isVideo ? const PlayerScreen() : const AudioPage(),
    ));
  }

  void _handleSwipeEnd(PlaybackController playback, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dx = _swipeDx;
    if (_swipeDx != 0) setState(() => _swipeDx = 0);
    if (playback.queue.length <= 1) return;
    if (dx < -36 || velocity < -300) {
      HapticFeedback.selectionClick();
      unawaited(playback.next());
    } else if (dx > 36 || velocity > 300) {
      HapticFeedback.selectionClick();
      unawaited(playback.previous());
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

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final card = AppPalette.surfaceOf(context);
        final titleColor = AppPalette.inkOf(context);
        final mutedColor = AppPalette.mutedOf(context);
        final borderColor = AppPalette.sandDeepOf(context);
        final accent = AppPalette.accentOf(context);
        final source = item.parent == '/' ? '网盘' : item.parent.split('/').last;

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              if (playback.queue.length <= 1) return;
              setState(() => _swipeDx = (_swipeDx + d.delta.dx).clamp(-56.0, 56.0));
            },
            onHorizontalDragEnd: (d) => _handleSwipeEnd(playback, d),
            onHorizontalDragCancel: () {
              if (_swipeDx != 0) setState(() => _swipeDx = 0);
            },
            child: Material(
              color: card,
              borderRadius: BorderRadius.circular(22),
              elevation: isDark ? 4 : 8,
              shadowColor: AudioTone.barShadow,
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 0.9),
                ),
                child: Semantics(
                  button: true,
                  label: '打开正在播放：${item.name}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _openPlayer(context, playback, item),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 9, 8, 8),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'olp-player-cover',
                                child: _thumb(context, playback, item, 42, isDark: isDark),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: _swipeDx == 0
                                      ? const Duration(milliseconds: 200)
                                      : Duration.zero,
                                  curve: Curves.easeOutCubic,
                                  transform: Matrix4.translationValues(_swipeDx * 0.35, 0, 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        layoutBuilder: (cur, prev) => Stack(
                                          alignment: Alignment.centerLeft,
                                          children: [...prev, ?cur],
                                        ),
                                        child: Text(
                                          item.name,
                                          key: ValueKey(item.path),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: titleColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      _subtitleLine(playback, source, mutedColor, accent),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _PlayPauseButton(playback: playback, isDark: isDark),
                              if (playback.queue.length > 1) ...[
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: '下一曲',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                                  icon: Icon(AppIcons.next, size: 22, color: mutedColor),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    unawaited(playback.next());
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        _bottomProgressLine(playback, isDark: isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _subtitleLine(
    PlaybackController playback,
    String source,
    Color mutedColor,
    Color accent,
  ) {
    return StreamBuilder<Duration>(
      stream: playback.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? playback.currentPosition;
        final dur = playback.currentDuration;
        String statusPrefix;
        if (playback.status == PlaybackStatus.opening) {
          statusPrefix = '打开中';
        } else if (playback.status == PlaybackStatus.buffering) {
          statusPrefix = '缓冲中';
        } else if (playback.status == PlaybackStatus.error) {
          statusPrefix = '播放失败';
        } else if (dur.inMilliseconds > 0) {
          final pct = ((pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) * 100).round();
          final rem = dur > pos ? dur - pos : Duration.zero;
          statusPrefix = '$pct% · 剩 ${formatDuration(rem)}';
        } else {
          statusPrefix = playback.status == PlaybackStatus.idle ? '待续播' : '准备中';
        }
        return Text(
          '$statusPrefix · $source',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: playback.status == PlaybackStatus.error ? accent : mutedColor,
            fontFeatures: kTabularFigures,
          ),
        );
      },
    );
  }

  Widget _thumb(
    BuildContext context,
    PlaybackController playback,
    QueueItem item,
    double size, {
    required bool isDark,
  }) {
    final radius = size * 0.24;
    final sand = AppPalette.sandOf(context);
    final accent = AppPalette.accentOf(context);
    final activePlaying = playback.status == PlaybackStatus.playing;

    Widget placeholder() {
      if (item.isVideo) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: sand,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(AppIcons.movie, size: size * 0.44, color: accent),
        );
      }
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: sand,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: activePlaying
            ? PlayingWaveBars(playing: true, color: accent, size: 16)
            : AudioPlaceholderArt(isDark: isDark, size: size),
      );
    }

    if (item.thumb.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: placeholder(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        item.thumb,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
      ),
    );
  }

  Widget _bottomProgressLine(PlaybackController playback, {required bool isDark}) {
    return StreamBuilder<Duration>(
      stream: playback.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? playback.currentPosition;
        final dur = playback.currentDuration;
        final ratio = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return LinearProgressIndicator(
          value: ratio,
          minHeight: 2.5,
          backgroundColor: isDark ? AppPalette.darkSandDeep : AudioTone.sandDeep,
          valueColor: AlwaysStoppedAnimation(
            isDark ? AppPalette.darkAccent : AudioTone.accent,
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playback, required this.isDark});
  final PlaybackController playback;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: playback.playingStream,
      builder: (context, snap) {
        final rawPlaying = snap.data ?? playback.isPlaying;
        final playing = rawPlaying &&
            playback.status != PlaybackStatus.error &&
            playback.status != PlaybackStatus.idle;
        return Semantics(
          button: true,
          label: playing ? '暂停' : '播放',
          child: Material(
            color: isDark ? AppPalette.darkAccent : AudioTone.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                playback.togglePlay();
              },
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 21,
                  color: isDark ? AppPalette.darkBg : Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
