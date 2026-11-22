/// 底部常驻 mini 播放条：当前曲目 + 播放/暂停 + 下一曲，点击进播放页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/playback_controller.dart';
import '../providers.dart';
import 'player/audio_page.dart';
import 'player/player_screen.dart';
import 'widgets.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    // PlaybackController 是 ChangeNotifier：Provider 只在首次创建时求值，
    // notifyListeners 不会重建。必须用 ListenableBuilder 订阅，
    // 否则播放开始后 mini bar 永不出现、进度条永不更新。
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        if (item == null) return const SizedBox.shrink();

        return Material(
          elevation: 4,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => item.isVideo ? const PlayerScreen() : const AudioPage(),
              ));
            },
            child: SizedBox(
              height: 60,
              child: Column(
                children: [
                  // 进度细条
                  StreamBuilder<Duration>(
                    stream: playback.player.stream.position,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final dur = playback.player.state.duration;
                      final ratio = dur.inMilliseconds > 0
                          ? pos.inMilliseconds / dur.inMilliseconds
                          : 0.0;
                      return LinearProgressIndicator(
                        value: ratio.clamp(0, 1),
                        minHeight: 2,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CoverArt(
                          size: 40,
                          thumbUrl: item.thumb,
                          fallbackIcon:
                              item.isVideo ? Icons.movie_outlined : Icons.music_note_outlined,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        _PlayPauseButton(playback: playback),
                        IconButton(
                          tooltip: '下一个',
                          icon: const Icon(Icons.skip_next),
                          onPressed: () => playback.next(),
                        ),
                      ],
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

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: playback.player.stream.playing,
      builder: (context, snap) {
        final playing = snap.data ?? playback.player.state.playing;
        return IconButton(
          tooltip: playing ? '暂停' : '播放',
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          iconSize: 32,
          onPressed: () => playback.togglePlay(),
        );
      },
    );
  }
}
