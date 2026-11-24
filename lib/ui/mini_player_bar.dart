/// 底部常驻 mini 播放条（按 Arudio 设计稿：白色圆角卡片 + 陶土进度 + 圆形播放键）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../player/playback_controller.dart';
import '../providers.dart';
import 'app_theme.dart';
import 'widgets.dart';
import 'player/audio_page.dart';
import 'player/audio_theme.dart';
import 'player/player_screen.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    // PlaybackController 是 ChangeNotifier：Provider 只在首次创建时求值，
    // notifyListeners 不会重建。必须用 ListenableBuilder 订阅。
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        if (item == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final card = isDark ? AppPalette.darkSurface : AudioTone.surface;
        final titleColor = isDark ? AppPalette.darkInk : AudioTone.ink;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Material(
            color: card,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            shadowColor: AudioTone.barShadow,
            child: Semantics(
              button: true,
              label: '打开正在播放：${item.name}',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => item.isVideo ? const PlayerScreen() : const AudioPage(),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Row(
                    children: [
                      _thumb(item, 44, isDark: isDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _progressLine(playback, isDark: isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PlayPauseButton(playback: playback, isDark: isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(QueueItem item, double size, {required bool isDark}) {
    final radius = size * 0.22;
    // 音频无封面 / 加载失败回退到主题对应的矢量占位图；视频仍用影片图标。
    Widget placeholder() {
      if (item.isVideo) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AudioTone.sand,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.movie_outlined,
            size: size * 0.44,
            color: AudioTone.accent,
          ),
        );
      }
      return AudioPlaceholderArt(isDark: isDark, size: size);
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

  Widget _progressLine(PlaybackController playback, {required bool isDark}) {
    return StreamBuilder<Duration>(
      stream: playback.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? playback.currentPosition;
        final dur = playback.currentDuration;
        final ratio = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 3,
            backgroundColor: isDark ? AppPalette.darkSandDeep : AudioTone.sandDeep,
            valueColor: AlwaysStoppedAnimation(
              isDark ? AppPalette.darkAccent : AudioTone.accent,
            ),
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
        final playing = snap.data ?? playback.isPlaying;
        return Semantics(
          button: true,
          label: playing ? '暂停' : '播放',
          child: Material(
            color: isDark ? AppPalette.darkAccent : AudioTone.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => playback.togglePlay(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 22,
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
