/// 音频全屏页（一屏锁定架构）：
/// 下拉跟手收起 + 暖陶留声机唱片卡（24s/圈匀速微旋 + 阻尼停盘 + 唱臂 + 长按 2x 临时快进）⇄ 同目录 .lrc 滚动歌词
/// + 按压增粗进度条（4pt→8pt）+ 五键对称主控（±15s 微旋浮标 + 弹簧大播放键）+ 四键工具栏（倍速/睡眠定时/循环/底部队列抽屉）。
library;

import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/lrc_parser.dart';
import '../../core/models.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../app_theme.dart';
import '../icons.dart';
import '../widgets.dart';
import 'audio_theme.dart';
import 'panels.dart';
import 'player_screen.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  PlaybackController? _playback;
  String? _lastItemPath;
  double? _dragMs;
  bool _wakelockActive = false;
  bool _switchingRoute = false;

  /// 下拉跟手收起偏移量（像素）
  double _dismissDy = 0;

  /// 右侧时间显示模式：true 显示 `-剩余时间`，false 显示总时长
  bool _showRemaining = true;

  /// 舞台模式：false 唱片/封面态，true 同目录 LRC 歌词态
  bool _showLyrics = false;

  /// ±15s 步进浮标反馈
  String? _stepToastText;
  Timer? _stepToastTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playback = ref.read(playbackProvider);
    if (identical(playback, _playback)) return;
    _playback?.removeListener(_onPlaybackChanged);
    _playback = playback..addListener(_onPlaybackChanged);
    _lastItemPath = playback.current?.path;
    _syncWakelock();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    _syncWakelock();
    final cur = _playback?.current;
    final curPath = cur?.path;
    final switched = curPath != _lastItemPath;
    if (switched) {
      _lastItemPath = curPath;
      if (_showLyrics && _playback?.hasLyrics != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _showLyrics && _playback?.hasLyrics != true) {
            setState(() => _showLyrics = false);
          }
        });
      }
    }
    if (!_switchingRoute && cur != null && cur.isVideo) {
      _switchingRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == true && _playback?.current?.isVideo == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
          );
        } else {
          _switchingRoute = false;
        }
      });
      return;
    }
    if (_dragMs != null && (switched || _playback?.status == PlaybackStatus.opening)) {
      _dragMs = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _syncWakelock() {
    final s = _playback?.status;
    final shouldWake = s == PlaybackStatus.opening ||
        s == PlaybackStatus.buffering ||
        s == PlaybackStatus.playing;
    if (shouldWake == _wakelockActive) return;
    _wakelockActive = shouldWake;
    if (shouldWake) {
      unawaited(WakelockPlus.enable().catchError((_) {}));
    } else {
      unawaited(WakelockPlus.disable().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _stepToastTimer?.cancel();
    _playback?.restoreSpeed();
    _playback?.removeListener(_onPlaybackChanged);
    if (_wakelockActive) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
    }
    super.dispose();
  }

  void _triggerStep(PlaybackController playback, int seconds) {
    HapticFeedback.selectionClick();
    unawaited(playback.seekRelative(seconds));
    _stepToastTimer?.cancel();
    setState(() => _stepToastText = seconds > 0 ? '+${seconds}s' : '${seconds}s');
    _stepToastTimer = Timer(const Duration(milliseconds: 680), () {
      if (mounted) setState(() => _stepToastText = null);
    });
  }

  void _openQueueDrawer(PlaybackController playback) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppPalette.darkSurface : AudioTone.surface,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _QueueDrawer(playback: playback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        final bg = AppPalette.bgOf(context);
        final ink = AppPalette.inkOf(context);
        final muted = AppPalette.mutedOf(context);

        if (item == null) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(title: const Text('音频'), backgroundColor: bg),
            body: Center(child: Text('没有正在播放的内容', style: TextStyle(color: muted))),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dismissProgress = (_dismissDy / 280.0).clamp(0.0, 1.0);
        final pageScale = 1.0 - dismissProgress * 0.06;
        final pageRadius = dismissProgress * 24.0;
        final tempSpeedActive = (playback.effectiveSpeed - playback.speed).abs() > 0.01;

        return Scaffold(
          backgroundColor: bg,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) {
              if (_showLyrics) return; // 歌词态保留纵向滚动
              final next = _dismissDy + d.delta.dy;
              if (next > 0 || _dismissDy > 0) {
                setState(() => _dismissDy = next.clamp(0.0, 320.0));
              }
            },
            onVerticalDragEnd: (d) {
              if (_dismissDy <= 0) return;
              final vy = d.primaryVelocity ?? 0;
              if (_dismissDy > 110 || vy > 700) {
                Navigator.of(context).maybePop();
              } else {
                setState(() => _dismissDy = 0);
              }
            },
            onVerticalDragCancel: () {
              if (_dismissDy != 0) setState(() => _dismissDy = 0);
            },
            child: AnimatedContainer(
              duration: _dismissDy == 0 ? const Duration(milliseconds: 220) : Duration.zero,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _dismissDy, 0)
                ..scaleByDouble(pageScale, pageScale, 1.0, 1.0),
              transformAlignment: Alignment.topCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(pageRadius)),
                child: ColoredBox(
                  color: bg,
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AudioTone.pageH, 2, AudioTone.pageH, 12),
                          child: Column(
                            children: [
                              _topBar(playback, ink: ink, muted: muted),
                              const SizedBox(height: 8),
                              // 上半屏弹性舞台：留声机唱片卡 ⇄ LRC 滚动歌词
                              Expanded(
                                child: _stageArea(playback, item, isDark: isDark),
                              ),
                              const SizedBox(height: 16),
                              _titleBlock(item, ink: ink, muted: muted),
                              const SizedBox(height: 14),
                              if (playback.status == PlaybackStatus.error) ...[
                                _errorCard(playback),
                                const SizedBox(height: 12),
                              ],
                              _progress(playback),
                              const SizedBox(height: 10),
                              _controls(playback, ink: ink),
                              const SizedBox(height: 14),
                              _utilityRow(playback),
                            ],
                          ),
                        ),
                        // 长按临时倍速顶部提示胶囊
                        if (tempSpeedActive)
                          Positioned(
                            top: 56,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppPalette.scrimStrong,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.fast_forward_rounded,
                                        size: 16,
                                        color: AppPalette.darkAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${formatSpeed(playback.effectiveSpeed)} 快进中',
                                        style: const TextStyle(
                                          color: AppPalette.darkInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // ±15s 步进浮标反馈（M5）
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 186,
                          child: IgnorePointer(
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: _stepToastText != null ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: AnimatedSlide(
                                  offset: _stepToastText != null
                                      ? Offset.zero
                                      : const Offset(0, 0.25),
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ink.withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _stepToastText ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: bg,
                                        fontFeatures: kTabularFigures,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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

  // ---------- 顶栏 ----------

  Widget _topBar(PlaybackController playback, {required Color ink, required Color muted}) {
    final label = _showLyrics
        ? '歌词 · 同目录 .lrc'
        : switch (playback.status) {
            PlaybackStatus.opening => '打开中',
            PlaybackStatus.buffering => '缓冲中',
            _ => '正在播放',
          };
    return Row(
      children: [
        IconButton(
          tooltip: '收起',
          icon: Icon(AppIcons.collapseDown, size: 28, color: ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted),
          ),
        ),
        IconButton(
          tooltip: '播放队列',
          icon: Icon(AppIcons.queue, size: 22, color: ink),
          onPressed: () => _openQueueDrawer(playback),
        ),
      ],
    );
  }

  // ---------- 上半屏舞台：唱片卡 ⇄ LRC 歌词 ----------

  Widget _stageArea(PlaybackController playback, QueueItem item, {required bool isDark}) {
    final hasLyrics = playback.hasLyrics;
    final accent = AppPalette.accentOf(context);
    final surface = AppPalette.surfaceOf(context);
    final ink = AppPalette.inkOf(context);
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    final isPlaying = playback.status == PlaybackStatus.playing;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: (_showLyrics && hasLyrics)
                ? _LyricsStage(
                    key: const ValueKey('lyrics-stage'),
                    playback: playback,
                  )
                : GestureDetector(
                    key: const ValueKey('disc-stage'),
                    onLongPressStart: (_) {
                      HapticFeedback.lightImpact();
                      playback.setTemporarySpeed(2.0);
                    },
                    onLongPressEnd: (_) => playback.restoreSpeed(),
                    onLongPressCancel: () => playback.restoreSpeed(),
                    onTap: hasLyrics ? () => setState(() => _showLyrics = true) : null,
                    child: Hero(
                      tag: 'olp-player-cover',
                      child: _TurntableCard(
                        item: item,
                        playing: isPlaying,
                        isDark: isDark,
                      ),
                    ),
                  ),
          ),
        ),
        if (hasLyrics)
          Positioned(
            right: 12,
            bottom: 12,
            child: Semantics(
              button: true,
              label: _showLyrics ? '切换回唱片封面' : '显示歌词',
              child: Material(
                color: _showLyrics ? accent : surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showLyrics = !_showLyrics);
                  },
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Text(
                        '词',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _showLyrics ? onAccent : ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- 标题与元信息（长文件名自适应字号） ----------

  Widget _titleBlock(QueueItem item, {required Color ink, required Color muted}) {
    final source = item.parent == '/' ? '网盘根目录' : item.parent.split('/').last;
    final isLong = item.name.length > 22;
    final fmt = mediaFormatBadge(item.name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isLong ? 19 : 23,
            fontWeight: isLong ? FontWeight.w600 : FontWeight.w700,
            height: 1.28,
            letterSpacing: -0.4,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
            if (fmt.isNotEmpty) ...[
              const SizedBox(width: 8),
              ToneBadge(
                label: isLosslessAudio(item.name) ? '$fmt 无损' : fmt,
                accent: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ---------- 按压增粗进度条（M4） ----------

  Widget _progress(PlaybackController playback) {
    final accent = AppPalette.accentOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);
    final surface = AppPalette.surfaceOf(context);
    final muted = AppPalette.mutedOf(context);
    final isDragging = _dragMs != null;

    return StreamBuilder<Duration>(
      stream: playback.positionStream,
      builder: (context, snap) {
        final streamPos = snap.data ?? playback.currentPosition;
        final dur = playback.currentDuration;
        final effectiveMs = _dragMs ??
            (dur.inMilliseconds > 0
                ? streamPos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble()
                : 0.0);
        final pos = Duration(milliseconds: effectiveMs.toInt());
        final remaining = dur > pos ? dur - pos : Duration.zero;
        final rightTime = dur.inMilliseconds <= 0
            ? '--:--'
            : (_showRemaining ? '-${formatDuration(remaining)}' : formatDuration(dur));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isDragging ? 8.0 : 4.0),
              duration: Duration(milliseconds: isDragging ? 160 : 180),
              curve: Curves.easeOutCubic,
              builder: (context, trackH, _) {
                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: trackH,
                    activeTrackColor: accent,
                    inactiveTrackColor: sandDeep,
                    thumbColor: accent,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    thumbShape: _RingThumbShape(
                      accent: accent,
                      ring: surface,
                      radius: isDragging ? 10.5 : 8.5,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: dur.inMilliseconds > 0
                        ? effectiveMs.clamp(0.0, dur.inMilliseconds.toDouble())
                        : 0,
                    max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                    onChangeStart: dur.inMilliseconds > 0
                        ? (v) => setState(() => _dragMs = v)
                        : null,
                    onChanged: dur.inMilliseconds > 0
                        ? (v) => setState(() => _dragMs = v)
                        : null,
                    onChangeEnd: dur.inMilliseconds > 0
                        ? (v) {
                            if (_dragMs == null) return;
                            setState(() => _dragMs = null);
                            playback.seek(Duration(milliseconds: v.toInt()));
                          }
                        : null,
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: TextStyle(
                      fontSize: isDragging ? 13.5 : 12,
                      fontWeight: isDragging ? FontWeight.w700 : FontWeight.w500,
                      color: accent,
                      fontFeatures: kTabularFigures,
                    ),
                    child: Text(formatDuration(pos)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showRemaining = !_showRemaining),
                    child: Text(
                      rightTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- 五键对称主控行 ----------

  Widget _controls(PlaybackController playback, {required Color ink}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: '上一个',
          iconSize: 30,
          icon: Icon(AppIcons.prev, color: ink),
          onPressed: () {
            HapticFeedback.selectionClick();
            unawaited(playback.previous());
          },
        ),
        _Step15Button(
          forward: false,
          color: ink,
          onTap: () => _triggerStep(playback, -15),
        ),
        _SpringPlayButton(playback: playback),
        _Step15Button(
          forward: true,
          color: ink,
          onTap: () => _triggerStep(playback, 15),
        ),
        IconButton(
          tooltip: '下一个',
          iconSize: 30,
          icon: Icon(AppIcons.next, color: ink),
          onPressed: () {
            HapticFeedback.selectionClick();
            unawaited(playback.next());
          },
        ),
      ],
    );
  }

  // ---------- 四键胶囊工具栏：倍速 / 睡眠定时 / 循环模式 / 队列抽屉 ----------

  Widget _utilityRow(PlaybackController playback) {
    final accent = AppPalette.accentOf(context);
    final ink = AppPalette.inkOf(context);
    final sand = AppPalette.sandOf(context);

    final speedModified = (playback.speed - 1.0).abs() > 0.01;
    final sleepActive = playback.hasSleepTimer;
    final modeIcon = switch (playback.mode) {
      PlayMode.sequentialLoop => AppIcons.repeat,
      PlayMode.repeatOne => AppIcons.repeatOne,
      PlayMode.shuffle => AppIcons.shuffle,
    };
    final modeLabel = switch (playback.mode) {
      PlayMode.sequentialLoop => '列表',
      PlayMode.repeatOne => '单曲',
      PlayMode.shuffle => '随机',
    };
    final queueLabel = playback.queue.isEmpty
        ? '队列'
        : '${playback.index + 1}/${playback.queue.length}';

    return Row(
      children: [
        Expanded(
          child: _toolCapsule(
            label: formatSpeed(playback.speed),
            active: speedModified,
            sand: sand,
            accent: accent,
            ink: ink,
            tooltip: '播放速度 ${formatSpeed(playback.speed)}',
            onTap: () => showSpeedPanel(context, playback),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _toolCapsule(
            icon: sleepActive ? AppIcons.sleepActive : AppIcons.sleep,
            label: playback.sleepTimerShortLabel,
            active: sleepActive,
            sand: sand,
            accent: accent,
            ink: ink,
            tooltip: '睡眠定时',
            onTap: () => showSleepTimerPanel(context, playback),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _toolCapsule(
            icon: modeIcon,
            label: modeLabel,
            active: playback.mode != PlayMode.sequentialLoop,
            sand: sand,
            accent: accent,
            ink: ink,
            tooltip: switch (playback.mode) {
              PlayMode.sequentialLoop => '列表循环',
              PlayMode.repeatOne => '单曲循环',
              PlayMode.shuffle => '随机',
            },
            onTap: () {
              HapticFeedback.selectionClick();
              playback.cycleMode();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _toolCapsule(
            icon: AppIcons.queue,
            label: queueLabel,
            active: false,
            sand: sand,
            accent: accent,
            ink: ink,
            tooltip: '播放队列',
            onTap: () => _openQueueDrawer(playback),
          ),
        ),
      ],
    );
  }

  Widget _toolCapsule({
    IconData? icon,
    required String label,
    required bool active,
    required Color sand,
    required Color accent,
    required Color ink,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final fg = active ? accent : ink;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? accent.withValues(alpha: 0.14) : sand,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard(PlaybackController playback) {
    final surface = AppPalette.surfaceOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);
    final ink = AppPalette.inkOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sandDeep),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              playback.errorText ?? '播放失败',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: ink),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => playback.retryNow(),
            child: const Text('重试'),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => playback.skipAfterError(),
            child: const Text('跳过'),
          ),
        ],
      ),
    );
  }
}

/// M2：主播放键弹簧按压回弹 + AnimatedIcon 丝滑变形 + 缓冲外圈旋转光弧
class _SpringPlayButton extends StatefulWidget {
  const _SpringPlayButton({required this.playback});
  final PlaybackController playback;

  @override
  State<_SpringPlayButton> createState() => _SpringPlayButtonState();
}

class _SpringPlayButtonState extends State<_SpringPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final initPlaying = widget.playback.isPlaying &&
        widget.playback.status != PlaybackStatus.error &&
        widget.playback.status != PlaybackStatus.idle;
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: initPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.accentOf(context);
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return StreamBuilder<bool>(
      stream: widget.playback.playingStream,
      builder: (context, snap) {
        final rawPlaying = snap.data ?? widget.playback.isPlaying;
        final playing = rawPlaying &&
            widget.playback.status != PlaybackStatus.error &&
            widget.playback.status != PlaybackStatus.idle;
        final busy = widget.playback.status == PlaybackStatus.buffering ||
            widget.playback.status == PlaybackStatus.opening;

        if (playing && _iconCtrl.status != AnimationStatus.completed && _iconCtrl.status != AnimationStatus.forward) {
          _iconCtrl.forward();
        } else if (!playing && _iconCtrl.status != AnimationStatus.dismissed && _iconCtrl.status != AnimationStatus.reverse) {
          _iconCtrl.reverse();
        }

        return Semantics(
          button: true,
          label: busy ? '缓冲中' : (playing ? '暂停' : '播放'),
          child: Tooltip(
            message: busy ? '缓冲中' : (playing ? '暂停' : '播放'),
            child: GestureDetector(
              onTapDown: busy ? null : (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: busy
                  ? null
                  : (_) {
                      setState(() => _pressed = false);
                      HapticFeedback.lightImpact();
                      widget.playback.togglePlay();
                    },
              child: AnimatedScale(
                scale: _pressed ? 0.92 : 1.0,
                duration: Duration(milliseconds: _pressed ? 90 : 220),
                curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Material(
                        color: accent,
                        shape: const CircleBorder(),
                        elevation: 6,
                        shadowColor: accent.withValues(alpha: 0.42),
                        child: SizedBox(
                          width: 76,
                          height: 76,
                          child: Center(
                            child: busy
                                ? SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: onAccent,
                                      strokeWidth: 2.6,
                                    ),
                                  )
                                : AnimatedIcon(
                                    icon: AnimatedIcons.play_pause,
                                    progress: _iconCtrl,
                                    size: 36,
                                    color: onAccent,
                                  ),
                          ),
                        ),
                      ),
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
}

/// M5：±15s 步进键（点击时环形箭头沿方向轻转 35° 回弹）
class _Step15Button extends StatefulWidget {
  const _Step15Button({
    required this.forward,
    required this.color,
    required this.onTap,
  });

  final bool forward;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_Step15Button> createState() => _Step15ButtonState();
}

class _Step15ButtonState extends State<_Step15Button> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final dir = widget.forward ? 1.0 : -1.0;
    _turns = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: dir * 0.095).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: dir * 0.095, end: 0.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.forward ? '快进 15 秒' : '快退 15 秒',
      child: InkResponse(
        radius: 26,
        onTap: () {
          _ctrl.forward(from: 0);
          widget.onTap();
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _turns,
                child: CustomPaint(
                  size: const Size(30, 30),
                  painter: _ArcStepPainter(forward: widget.forward, color: widget.color),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '15',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcStepPainter extends CustomPainter {
  const _ArcStepPainter({required this.forward, required this.color});
  final bool forward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2 + 1);
    final r = size.width * 0.38;
    if (forward) {
      // 顺时针缺口圆弧 + 右上箭头
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi * 0.3,
        math.pi * 1.65,
        false,
        paint,
      );
      final tip = Offset(center.dx + r * math.cos(-math.pi * 0.3), center.dy + r * math.sin(-math.pi * 0.3));
      final arrow = Path()
        ..moveTo(tip.dx - 5, tip.dy - 1)
        ..lineTo(tip.dx + 1, tip.dy + 1)
        ..lineTo(tip.dx - 1, tip.dy - 5);
      canvas.drawPath(arrow, paint);
    } else {
      // 逆时针缺口圆弧 + 左上箭头
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi * 0.7,
        -math.pi * 1.65,
        false,
        paint,
      );
      final tip = Offset(center.dx + r * math.cos(-math.pi * 0.7), center.dy + r * math.sin(-math.pi * 0.7));
      final arrow = Path()
        ..moveTo(tip.dx + 5, tip.dy - 1)
        ..lineTo(tip.dx - 1, tip.dy + 1)
        ..lineTo(tip.dx + 1, tip.dy - 5);
      canvas.drawPath(arrow, paint);
    }
  }

  @override
  bool shouldRepaint(_ArcStepPainter old) => old.forward != forward || old.color != color;
}

/// M3：暖陶留声机唱片卡（24 秒/圈匀速微旋 + 暂停 600ms 阻尼平滑停稳 + 右上唱臂 12° 抬落）
class _TurntableCard extends StatefulWidget {
  const _TurntableCard({
    required this.item,
    required this.playing,
    required this.isDark,
  });

  final QueueItem item;
  final bool playing;
  final bool isDark;

  @override
  State<_TurntableCard> createState() => _TurntableCardState();
}

class _TurntableCardState extends State<_TurntableCard> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _angleRad = 0;
  double _angularVelocity = 0; // rad/s
  Duration _lastElapsed = Duration.zero;
  bool _disableAnimations = false;

  static const double _targetVel = (2 * math.pi) / 24.0; // 24 秒一圈

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations) {
      _angularVelocity = 0;
      if (_ticker.isActive) _ticker.stop();
    } else if (widget.playing && !_ticker.isActive) {
      _angularVelocity = _targetVel;
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(_TurntableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_disableAnimations) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (widget.playing && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;

    final target = widget.playing ? _targetVel : 0.0;
    // 阻尼系数 4.5：播放约 0.5s 匀加速至稳态，暂停约 600ms 平滑停稳不回弹
    _angularVelocity += (target - _angularVelocity) * math.min(1.0, dt * 4.5);
    if (!widget.playing && _angularVelocity < 0.002) {
      _angularVelocity = 0;
      _ticker.stop();
      return;
    }
    setState(() {
      _angleRad = (_angleRad + _angularVelocity * dt) % (2 * math.pi);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThumb = widget.item.thumb.isNotEmpty;
    final coverFill = AppPalette.coverFillOf(context);
    final accent = AppPalette.accentOf(context);
    final surface = AppPalette.surfaceOf(context);
    final taupe = AppPalette.taupeOf(context);
    final ink = AppPalette.inkOf(context);
    final fmt = mediaFormatBadge(widget.item.name);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: coverFill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppPalette.sandDeepOf(context), width: 0.9),
        ),
        child: hasThumb
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.item.thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _turntableSurface(accent, surface, taupe, ink),
                  ),
                  if (fmt.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: ToneBadge(
                        label: isLosslessAudio(widget.item.name) ? '$fmt 无损' : fmt,
                        accent: true,
                      ),
                    ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: GridBackdrop(isDark: widget.isDark)),
                  _turntableSurface(accent, surface, taupe, ink),
                  if (fmt.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: surface.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          isLosslessAudio(widget.item.name) ? '$fmt 无损' : fmt,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _turntableSurface(Color accent, Color surface, Color taupe, Color ink) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final discSize = (math.min(constraints.maxWidth, constraints.maxHeight) * 0.72)
            .clamp(120.0, 224.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _angleRad,
              child: CustomPaint(
                size: Size.square(discSize),
                painter: _VinylDiscPainter(
                  isDark: widget.isDark,
                  accent: accent,
                  surface: surface,
                  ink: ink,
                ),
              ),
            ),
            // 右上极简几何唱臂：播放轻搭，暂停微抬 12°
            Positioned(
              top: 20,
              right: 22,
              child: AnimatedRotation(
                turns: widget.playing ? 0.036 : 0.095,
                alignment: const Alignment(0, -0.82),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                child: SizedBox(
                  width: 18,
                  height: 76,
                  child: CustomPaint(
                    painter: _TonearmPainter(taupe: taupe, ink: ink, surface: surface),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VinylDiscPainter extends CustomPainter {
  const _VinylDiscPainter({
    required this.isDark,
    required this.accent,
    required this.surface,
    required this.ink,
  });

  final bool isDark;
  final Color accent;
  final Color surface;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // 柔和底层投影
    canvas.drawCircle(
      center.translate(0, 6),
      r * 0.96,
      Paint()..color = ink.withValues(alpha: isDark ? 0.28 : 0.08),
    );

    // 纸感唱盘主体
    canvas.drawCircle(
      center,
      r * 0.96,
      Paint()..color = isDark ? AppPalette.darkSurface : AudioTone.surface,
    );

    // 外缘细描边 + 5 道等距唱纹同心圆
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = ink.withValues(alpha: isDark ? 0.16 : 0.11);
    for (final factor in const [0.95, 0.84, 0.76, 0.68, 0.60, 0.52]) {
      canvas.drawCircle(center, r * factor, groove);
    }

    // 极轻扇形高光（旋转时提供优雅视觉锚点）
    final sheen = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: r * 0.92),
        -math.pi / 2,
        math.pi / 5,
        false,
      )
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = (isDark ? Colors.white : accent).withValues(alpha: 0.06),
    );

    // 中央陶土唱片标芯
    canvas.drawCircle(center, r * 0.34, Paint()..color = accent);
    canvas.drawCircle(
      center,
      r * 0.20,
      Paint()..color = surface.withValues(alpha: 0.22),
    );
    canvas.drawCircle(center, r * 0.045, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(_VinylDiscPainter old) =>
      old.isDark != isDark || old.accent != accent || old.surface != surface;
}

class _TonearmPainter extends CustomPainter {
  const _TonearmPainter({required this.taupe, required this.ink, required this.surface});
  final Color taupe;
  final Color ink;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // 唱臂杆
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 2.2, 8, 4.4, size.height - 16),
        const Radius.circular(3),
      ),
      Paint()..color = taupe,
    );
    // 顶部转轴圆盘
    canvas.drawCircle(Offset(cx, 9), 7, Paint()..color = taupe);
    canvas.drawCircle(Offset(cx, 9), 3, Paint()..color = surface);
    // 底部唱头
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 6.5, size.height - 12, 13, 6.5),
        const Radius.circular(3),
      ),
      Paint()..color = ink.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_TonearmPainter old) => old.taupe != taupe || old.ink != ink;
}

/// 同目录 .lrc 居中高亮滚动歌词舞台（支持点击某句歌词直接跳转）
class _LyricsStage extends StatefulWidget {
  const _LyricsStage({super.key, required this.playback});
  final PlaybackController playback;

  @override
  State<_LyricsStage> createState() => _LyricsStageState();
}

class _LyricsStageState extends State<_LyricsStage> {
  final _scroll = ScrollController();
  int _lastActiveIndex = -1;
  static const double _itemExtent = 44.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(int index, double viewportHeight) {
    if (!_scroll.hasClients || index < 0) return;
    final target = (index * _itemExtent - viewportHeight / 2 + _itemExtent / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppPalette.surfaceOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);
    final accent = AppPalette.accentOf(context);
    final muted = AppPalette.mutedOf(context);
    final lines = widget.playback.lyrics;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sandDeep, width: 0.9),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return StreamBuilder<Duration>(
            stream: widget.playback.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? widget.playback.currentPosition;
              final active = findActiveLrcIndex(lines, pos);
              if (active != _lastActiveIndex) {
                _lastActiveIndex = active;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _scrollTo(active, constraints.maxHeight);
                });
              }
              return ListView.builder(
                controller: _scroll,
                itemExtent: _itemExtent,
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: (constraints.maxHeight * 0.28).clamp(24.0, 96.0),
                ),
                itemCount: lines.length,
                itemBuilder: (context, i) {
                  final line = lines[i];
                  final isCurrent = i == active;
                  final isNear = active >= 0 && (i - active).abs() == 1;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      unawaited(widget.playback.seek(line.time));
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: isCurrent ? 16 : 13.5,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                          color: isCurrent
                              ? accent
                              : muted.withValues(alpha: isNear ? 0.85 : 0.5),
                        ),
                        child: Text(
                          line.text,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 底部弹出队列抽屉（自动将当前播放项滚至可视区中央）
class _QueueDrawer extends StatefulWidget {
  const _QueueDrawer({required this.playback});
  final PlaybackController playback;

  @override
  State<_QueueDrawer> createState() => _QueueDrawerState();
}

class _QueueDrawerState extends State<_QueueDrawer> {
  final _scroll = ScrollController();
  static const double _rowExtent = 58.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent(animated: false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToCurrent({required bool animated}) {
    if (!_scroll.hasClients) return;
    final idx = widget.playback.index;
    if (idx < 0) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (idx * _rowExtent - viewport / 2 + _rowExtent / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.accentOf(context);
    final ink = AppPalette.inkOf(context);
    final muted = AppPalette.mutedOf(context);
    final sand = AppPalette.sandOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);

    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.playback,
        builder: (context, _) {
          final queue = widget.playback.queue;
          final curIndex = widget.playback.index;
          final isPlaying = widget.playback.status == PlaybackStatus.playing;
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sandDeep,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Text(
                      '播放队列',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
                    ),
                    const SizedBox(width: 8),
                    ToneBadge(label: '共 ${queue.length} 集'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _jumpToCurrent(animated: true),
                      icon: Icon(Icons.my_location_rounded, size: 15, color: accent),
                      label: Text('定位当前', style: TextStyle(fontSize: 12.5, color: accent)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: sandDeep),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: _rowExtent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: queue.length,
                  itemBuilder: (context, i) {
                    final item = queue[i];
                    final isCurrent = i == curIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrent ? sand : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (isCurrent) {
                            if (widget.playback.status == PlaybackStatus.idle) {
                              unawaited(widget.playback.resumeSession());
                            }
                          } else {
                            unawaited(widget.playback.jumpTo(i));
                          }
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${i + 1}'.padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    color: isCurrent ? accent : muted,
                                    fontFeatures: kTabularFigures,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                    color: isCurrent ? accent : ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isCurrent)
                                PlayingWaveBars(playing: isPlaying, color: accent, size: 15)
                              else
                                Text(
                                  formatFileSize(item.size),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                    fontFeatures: kTabularFigures,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 进度滑块拇指：陶土实心 + 暖白圆环（按压拖拽时轻微放大）
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({
    required this.accent,
    required this.ring,
    required this.radius,
  });

  final Color accent;
  final Color ring;
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(radius * 2, radius * 2);

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
    canvas.drawCircle(center, radius, Paint()..color = ring);
    canvas.drawCircle(center, radius * 0.72, Paint()..color = accent);
  }
}
