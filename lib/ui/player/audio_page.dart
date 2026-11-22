/// 音频全屏页（按 Ardot「简约音频播放器 UI」设计稿重构）：
/// 米白底 + 陶土主色 + 大号墨色标题 + 环形进度滑块 + 圆形播放键 + 队列卡片。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../widgets.dart';
import 'audio_theme.dart';
import 'panels.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  final _scroll = ScrollController();
  final _queueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _scroll.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _scrollToQueue() {
    final ctx = _queueKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
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
            backgroundColor: AudioTone.bg,
            appBar: AppBar(title: const Text('音频'), backgroundColor: AudioTone.bg),
            body: const Center(child: Text('没有正在播放的内容')),
          );
        }

        final rows = <int>[
          for (var i = 0; i < playback.queue.length; i++)
            if (i != playback.index) i,
        ];

        return Scaffold(
          backgroundColor: AudioTone.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(playback),
                Expanded(
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AudioTone.pageH, 4, AudioTone.pageH, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _cover(item),
                            const SizedBox(height: AudioTone.gap + 4),
                            _titleBlock(item),
                            const SizedBox(height: AudioTone.gap + 4),
                            _progress(playback),
                            const SizedBox(height: AudioTone.gap - 6),
                            _controls(playback),
                            const SizedBox(height: AudioTone.gap),
                            _utilityRow(playback),
                            if (playback.status == PlaybackStatus.error) ...[
                              const SizedBox(height: AudioTone.gap),
                              _errorCard(playback),
                            ],
                            const SizedBox(height: 26),
                            Row(
                              key: _queueKey,
                              children: [
                                const Text('正在播放', style: AudioTone.sectionLabel),
                                const Spacer(),
                                Text('共 ${playback.queue.length} 集', style: AudioTone.rowMeta),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _currentCard(playback, item),
                            const SizedBox(height: 22),
                            const Text('接下来播放', style: AudioTone.sectionLabel),
                            const SizedBox(height: 6),
                          ]),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AudioTone.pageH),
                        sliver: SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, n) {
                            final i = rows[n];
                            return _queueRow(playback, i);
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- 顶栏 ----------

  Widget _topBar(PlaybackController playback) {
    final label = switch (playback.status) {
      PlaybackStatus.opening => '打开中',
      PlaybackStatus.buffering => '缓冲中',
      _ => '正在播放',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(AudioTone.pageH - 10, 6, AudioTone.pageH - 10, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.chevron_left, size: 26, color: AudioTone.ink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(label, textAlign: TextAlign.center, style: AudioTone.topBarTitle),
          ),
          IconButton(
            tooltip: '播放队列',
            icon: const Icon(Icons.queue_music, size: 22, color: AudioTone.ink),
            onPressed: _scrollToQueue,
          ),
        ],
      ),
    );
  }

  // ---------- 封面 ----------

  Widget _cover(QueueItem item) {
    final hasThumb = item.thumb.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 300,
        color: const Color(0xFFF1EDE5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumb)
              Image.network(
                item.thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (!hasThumb) ...[
              const CustomPaint(painter: GridBackdrop()),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 196,
                      height: 124,
                      decoration: BoxDecoration(
                        color: AudioTone.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.music_note, size: 56, color: AudioTone.taupe),
                    ),
                    const SizedBox(height: 16),
                    const Text('暂无图片', style: AudioTone.meta),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- 标题 / 元信息 ----------

  Widget _titleBlock(QueueItem item) {
    final source = item.parent == '/' ? '网盘根目录' : item.parent.split('/').last;
    return Column(
      children: [
        Text(
          item.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AudioTone.title,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AudioTone.meta,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AudioTone.sand,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.isVideo ? '视频' : '音频',
                style: const TextStyle(fontSize: 11, color: AudioTone.accent, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- 进度 ----------

  Widget _progress(PlaybackController playback) {
    return StreamBuilder<Duration>(
      stream: playback.player.stream.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = playback.player.state.duration;
        final remaining = dur - pos;
        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: AudioTone.accent,
                inactiveTrackColor: AudioTone.sandDeep,
                thumbColor: AudioTone.accent,
                // overlay 参与高度计算，22 → 44pt 命中区
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                thumbShape: const _RingThumbShape(),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: dur.inMilliseconds > 0
                    ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble()
                    : 0,
                max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                onChanged: (v) => playback.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    formatDuration(pos),
                    style: AudioTone.time.copyWith(color: AudioTone.accent),
                  ),
                  const Spacer(),
                  Text(
                    dur.inMilliseconds > 0 ? '-${formatDuration(remaining)}' : '--:--',
                    style: AudioTone.time,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- 主控制 ----------

  Widget _controls(PlaybackController playback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: '上一个',
          iconSize: 32,
          icon: const Icon(Icons.skip_previous, color: AudioTone.ink),
          onPressed: () => playback.previous(),
        ),
        _playButton(playback),
        IconButton(
          tooltip: '下一个',
          iconSize: 32,
          icon: const Icon(Icons.skip_next, color: AudioTone.ink),
          onPressed: () => playback.next(),
        ),
      ],
    );
  }

  Widget _playButton(PlaybackController playback) {
    return StreamBuilder<bool>(
      stream: playback.player.stream.playing,
      builder: (context, snap) {
        final playing = snap.data ?? playback.player.state.playing;
        final busy = playback.status == PlaybackStatus.buffering ||
            playback.status == PlaybackStatus.opening;
        return Semantics(
          button: true,
          label: busy ? '缓冲中' : (playing ? '暂停' : '播放'),
          child: Tooltip(
            message: busy ? '缓冲中' : (playing ? '暂停' : '播放'),
            child: Material(
              color: AudioTone.accent,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: AudioTone.accent.withValues(alpha: 0.45),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: busy ? null : () => playback.togglePlay(),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.6,
                            ),
                          )
                        : Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            size: 38,
                            color: Colors.white,
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

  // ---------- 次控制：倍速 / 播放模式 / 队列 ----------

  Widget _utilityRow(PlaybackController playback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => showSpeedPanel(context, playback),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AudioTone.sand,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              formatSpeed(playback.speed),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AudioTone.accent,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            switch (playback.mode) {
              PlayMode.sequentialLoop => Icons.repeat,
              PlayMode.repeatOne => Icons.repeat_one,
              PlayMode.shuffle => Icons.shuffle,
            },
            size: 21,
            color: AudioTone.muted,
          ),
          tooltip: switch (playback.mode) {
            PlayMode.sequentialLoop => '列表循环',
            PlayMode.repeatOne => '单曲循环',
            PlayMode.shuffle => '随机',
          },
          onPressed: () => playback.cycleMode(),
        ),
        IconButton(
          icon: const Icon(Icons.format_list_bulleted, size: 21, color: AudioTone.muted),
          tooltip: '播放队列',
          onPressed: _scrollToQueue,
        ),
      ],
    );
  }

  Widget _errorCard(PlaybackController playback) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AudioTone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AudioTone.sandDeep),
      ),
      child: Column(
        children: [
          Text(
            playback.errorText ?? '播放失败',
            textAlign: TextAlign.center,
            style: AudioTone.meta.copyWith(color: AudioTone.ink),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AudioTone.accent),
                onPressed: () => playback.retryNow(),
                child: const Text('重试'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AudioTone.accent,
                  side: const BorderSide(color: AudioTone.taupe),
                ),
                onPressed: () => playback.skipAfterError(),
                child: const Text('跳过'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 队列 ----------

  Widget _thumb(QueueItem item, double size, {bool active = false}) {
    final radius = size * 0.22;
    if (item.thumb.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? AudioTone.sand : const Color(0xFFF1EDE5),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          item.isVideo ? Icons.movie_outlined : Icons.music_note,
          size: size * 0.42,
          color: active ? AudioTone.accent : AudioTone.taupe,
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
          color: const Color(0xFFF1EDE5),
          child: Icon(Icons.music_note, size: size * 0.42, color: AudioTone.taupe),
        ),
      ),
    );
  }

  Widget _currentCard(PlaybackController playback, QueueItem item) {
    return StreamBuilder<Duration>(
      stream: playback.player.stream.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = playback.player.state.duration;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AudioTone.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0D21201D), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              _thumb(item, 56, active: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AudioTone.rowTitle.copyWith(color: AudioTone.accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDuration(pos)} / ${formatDuration(dur)}',
                      style: AudioTone.rowMeta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.graphic_eq, size: 20, color: AudioTone.accent),
            ],
          ),
        );
      },
    );
  }

  Widget _queueRow(PlaybackController playback, int index) {
    final item = playback.queue[index];
    final source = item.parent == '/' ? '网盘' : item.parent.split('/').last;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => playback.jumpTo(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: AudioTone.rowMeta.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            _thumb(item, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AudioTone.rowTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: AudioTone.rowMeta),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(formatFileSize(item.size), style: AudioTone.rowMeta),
          ],
        ),
      ),
    );
  }
}

/// 设计稿的进度滑块拇指：陶土实心 + 白色圆环
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(18, 18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(center, 6.5, Paint()..color = AudioTone.accent);
  }
}
