/// 音频全屏页：封面占位、完整控制、倍速、播放模式、队列。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../widgets.dart';
import 'panels.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    // PlaybackController 是 ChangeNotifier，Provider 不会因 notifyListeners 重建
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('音频')),
            body: const Center(child: Text('没有正在播放的内容')),
          );
        }
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('正在播放')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              // 封面：有 OpenList 缩略图用真实封面，否则回退占位图标
              Center(
                child: CoverArt(
                  size: 220,
                  thumbUrl: item.thumb,
                  fallbackIcon: Icons.music_note,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(item.parent, style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 24),
              // 进度
              StreamBuilder<Duration>(
                stream: playback.player.stream.position,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final dur = playback.player.state.duration;
                  return Column(
                    children: [
                      SliderTheme(
                        data: const SliderThemeData(
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 22),
                        ),
                        child: Slider(
                          value: dur.inMilliseconds > 0
                              ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble()
                              : 0,
                          max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                          onChanged: (v) => playback.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(pos)),
                          Text(formatDuration(dur)),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // 主控制
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '上一个',
                    iconSize: 32,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => playback.previous(),
                  ),
                  const SizedBox(width: 24),
                  StreamBuilder<bool>(
                    stream: playback.player.stream.playing,
                    builder: (context, snap) {
                      final playing = snap.data ?? playback.player.state.playing;
                      // 用 IconButton.filled 而非 FAB：语义角色是按钮而不是浮动操作
                      return IconButton.filled(
                        tooltip: playing ? '暂停' : '播放',
                        iconSize: 40,
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(88),
                          shape: const CircleBorder(),
                        ),
                        onPressed: () => playback.togglePlay(),
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    tooltip: '下一个',
                    iconSize: 32,
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => playback.next(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 副控制：模式 / 倍速
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(switch (playback.mode) {
                      PlayMode.sequentialLoop => Icons.repeat,
                      PlayMode.repeatOne => Icons.repeat_one,
                      PlayMode.shuffle => Icons.shuffle,
                    }),
                    tooltip: switch (playback.mode) {
                      PlayMode.sequentialLoop => '列表循环',
                      PlayMode.repeatOne => '单曲循环',
                      PlayMode.shuffle => '随机',
                    },
                    onPressed: () => playback.cycleMode(),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => showSpeedPanel(context, playback),
                    child: Text(formatSpeed(playback.speed)),
                  ),
                ],
              ),
              // 状态提示
              if (playback.status == PlaybackStatus.buffering || playback.status == PlaybackStatus.opening)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: Text('缓冲中…')),
                ),
              if (playback.status == PlaybackStatus.error)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(playback.errorText ?? '播放失败',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton(onPressed: () => playback.retryNow(), child: const Text('重试')),
                          const SizedBox(width: 12),
                          OutlinedButton(onPressed: () => playback.skipAfterError(), child: const Text('跳过')),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text('播放队列 (${playback.queue.length})', style: Theme.of(context).textTheme.titleSmall),
              for (var i = 0; i < playback.queue.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  selected: i == playback.index,
                  selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
                  leading: Icon(
                    playback.queue[i].isVideo ? Icons.movie_outlined : Icons.music_note_outlined,
                    size: 20,
                  ),
                  title: Text(playback.queue[i].name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  onTap: () => playback.jumpTo(i),
                ),
            ],
          ),
        );
      },
    );
  }
}
