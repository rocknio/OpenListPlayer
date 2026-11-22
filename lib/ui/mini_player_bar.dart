/// 底部常驻 mini 播放条（按 Arudio 设计稿：白色圆角卡片 + 陶土进度 + 圆形播放键）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../player/playback_controller.dart';
import '../providers.dart';
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
        final card = isDark ? const Color(0xFF2A2724) : AudioTone.surface;
        final titleColor = isDark ? const Color(0xFFF2EDE6) : AudioTone.ink;
        final subColor = isDark ? const Color(0xFF9E958A) : AudioTone.muted;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Material(
            color: card,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            shadowColor: const Color(0x1A21201D),
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
                    _thumb(item, 44),
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
                          _progressLine(playback, subColor),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PlayPauseButton(playback: playback),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(QueueItem item, double size) {
    final radius = size * 0.22;
    if (item.thumb.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AudioTone.sand,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          item.isVideo ? Icons.movie_outlined : Icons.music_note,
          size: size * 0.44,
          color: AudioTone.accent,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        item.thumb,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: AudioTone.sand,
          child: Icon(Icons.music_note, size: size * 0.44, color: AudioTone.accent),
        ),
      ),
    );
  }

  Widget _progressLine(PlaybackController playback, Color trackColor) {
    return StreamBuilder<Duration>(
      stream: playback.player.stream.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = playback.player.state.duration;
        final ratio = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 3,
            backgroundColor: trackColor.withValues(alpha: 0.22),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFB85C38)),
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: playback.player.stream.playing,
      builder: (context, snap) {
        final playing = snap.data ?? playback.player.state.playing;
        return Semantics(
          button: true,
          label: playing ? '暂停' : '播放',
          child: Material(
            color: AudioTone.accent,
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
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
