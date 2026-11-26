/// 视频播放页：竖屏内嵌 16:9 + 信息 + 队列；横屏全屏；手势（快进/亮度/音量/双击/长按3x）；
/// 控制条（倍速/字幕/音轨/播放模式）；缓冲等待与错误重试覆盖层。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models.dart';
import '../../player/playback_controller.dart';
import '../../providers.dart';
import '../app_theme.dart';
import '../browser/add_to_playlist_sheet.dart';
import '../icons.dart';
import '../widgets.dart';
import 'audio_page.dart';
import 'panels.dart';

/// 左右各让出的边缘宽度：水平拖动 seek 不在此区域起手，保留给 iOS 系统返回手势
const double kEdgeGestureGuard = 24;

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double _volume = 100;
  double _brightness = 0.5;
  bool _brightnessReady = false;
  bool _brightnessModified = false;
  bool _wakelockActive = false;
  bool _switchingRoute = false;
  double? _dragMs;

  // 手势状态
  double? _dragStartX; // 垂直手势起点的本地 x（判断左/右半屏）
  double _seekAccumSeconds = 0; // 水平手势累计的秒数

  PlaybackController? _playback;
  String? _lastItemPath;

  @override
  void initState() {
    super.initState();
    _volume = ref.read(playbackProvider).volume;
    _resetHideTimer();
    _loadBrightness();
  }

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

  /// 出错时自动唤出控制层，否则错误与"重试/跳过"藏在被自动隐藏的控制层里。
  /// notifyListeners 可能发生在 build/layout 阶段（如 replaceQueue 内部），
  /// 直接 setState 会触发 markNeedsLayout during layout 断言，故推迟到帧后。
  void _onPlaybackChanged() {
    if (!mounted) return;
    _syncWakelock();
    final cur = _playback?.current;
    final curPath = cur?.path;
    final switched = curPath != _lastItemPath;
    if (switched) _lastItemPath = curPath;
    if (!_switchingRoute && cur != null && !cur.isVideo) {
      _switchingRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == true && _playback?.current?.isVideo == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const AudioPage()),
          );
        } else {
          _switchingRoute = false;
        }
      });
      return;
    }
    var needRebuild = false;
    if (switched || _playback?.status == PlaybackStatus.opening) {
      if (_dragMs != null) {
        _dragMs = null;
        needRebuild = true;
      }
      if (_seekAccumSeconds != 0) {
        _seekAccumSeconds = 0;
        needRebuild = true;
      }
    }
    if (_playback?.status == PlaybackStatus.error && !_controlsVisible) {
      _hideTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controlsVisible) return;
        setState(() => _controlsVisible = true);
      });
      return;
    }
    if (needRebuild) {
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

  Future<void> _loadBrightness() async {
    try {
      _brightness = await ScreenBrightness().application;
      _brightnessReady = true;
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playback?.restoreSpeed();
    _playback?.removeListener(_onPlaybackChanged);
    if (_wakelockActive) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
    }
    if (_brightnessModified) {
      unawaited(ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {}));
    }
    // 若用户横屏全屏状态下直接返回/被弹出，确保恢复竖屏锁，避免后续页面卡在横向
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (_dragMs != null) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _dragMs == null && ref.read(playbackProvider).isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _resetHideTimer();
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullscreen() async {
    // 退出全屏即回到全 App 的竖屏锁定，不让其它页面跟着转横
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    // PlaybackController 是 ChangeNotifier，Provider 本身不会因 notifyListeners 重建，
    // 必须显式订阅，否则状态/队列/倍速变化不会反映到界面。
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final item = playback.current;
        final bg = AppPalette.bgOf(context);
        final muted = AppPalette.mutedOf(context);
        if (item == null) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(title: const Text('播放'), backgroundColor: Colors.transparent),
            body: Center(child: Text('没有正在播放的内容', style: TextStyle(color: muted))),
          );
        }
        return OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            return PopScope(
              // 横屏全屏按系统返回优先退回竖屏，避免直接退出播放页造成页面跳变
              canPop: !isLandscape,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && isLandscape) {
                  _exitFullscreen();
                }
              },
              child: Scaffold(
                backgroundColor: isLandscape ? AppPalette.videoBackdrop : bg,
                body: isLandscape ? _buildFullscreen(playback) : _buildPortrait(playback),
              ),
            );
          },
        );
      },
    );
  }

  // ---------- 竖屏：内嵌 16:9 + 标题卡 + 外置快捷胶囊 + 选集卡片 ----------

  Widget _buildPortrait(PlaybackController playback) {
    final cur = playback.current;
    final ink = AppPalette.inkOf(context);
    final muted = AppPalette.mutedOf(context);
    final accent = AppPalette.accentOf(context);
    final sand = AppPalette.sandOf(context);
    final surface = AppPalette.surfaceOf(context);
    final sandDeep = AppPalette.sandDeepOf(context);
    final isPlaying = playback.status == PlaybackStatus.playing;
    final hasSubs =
        playback.subtitleTracks.isNotEmpty || playback.availableExternalSubs.isNotEmpty;
    final hasAudio = playback.audioTracks.length > 1;
    final fmt = cur == null ? '' : mediaFormatBadge(cur.name);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _videoArea(playback, fullscreen: false),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 剧集标题卡
                        InsetSectionCard(
                          padding: const EdgeInsets.all(14),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    cur?.name ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                if (fmt.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  ToneBadge(label: fmt, accent: true),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${cur?.isVideo == true ? '视频' : '音频'} · ${cur?.parent ?? ''}',
                              style: TextStyle(color: muted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            // 外置快捷胶囊行：倍速 / 字幕 / 音轨 / 定时 / 加入播单
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _portraitActionChip(
                                    icon: AppIcons.speed,
                                    label: formatSpeed(playback.effectiveSpeed),
                                    active: (playback.speed - 1.0).abs() > 0.01,
                                    sand: sand,
                                    accent: accent,
                                    ink: ink,
                                    onTap: () => showSpeedPanel(context, playback),
                                  ),
                                  const SizedBox(width: 8),
                                  _portraitActionChip(
                                    icon: AppIcons.subtitles,
                                    label: playback.currentSubtitle != null ? '字幕开' : '字幕',
                                    active: playback.currentSubtitle != null,
                                    enabled: hasSubs,
                                    sand: sand,
                                    accent: accent,
                                    ink: ink,
                                    onTap: () => showSubtitlePanel(context, playback),
                                  ),
                                  const SizedBox(width: 8),
                                  _portraitActionChip(
                                    icon: AppIcons.audioTrack,
                                    label: '音轨',
                                    active: false,
                                    enabled: hasAudio,
                                    sand: sand,
                                    accent: accent,
                                    ink: ink,
                                    onTap: () => showAudioTrackPanel(context, playback),
                                  ),
                                  const SizedBox(width: 8),
                                  _portraitActionChip(
                                    icon: playback.hasSleepTimer
                                        ? AppIcons.sleepActive
                                        : AppIcons.sleep,
                                    label: playback.sleepTimerShortLabel,
                                    active: playback.hasSleepTimer,
                                    sand: sand,
                                    accent: accent,
                                    ink: ink,
                                    onTap: () => showSleepTimerPanel(context, playback),
                                  ),
                                  if (cur != null) ...[
                                    const SizedBox(width: 8),
                                    _portraitActionChip(
                                      icon: Icons.playlist_add_rounded,
                                      label: '加入播单',
                                      active: false,
                                      sand: sand,
                                      accent: accent,
                                      ink: ink,
                                      onTap: () async {
                                        final db = ref.read(dbProvider);
                                        final added =
                                            await showAddToPlaylistSheet(context, db, [cur]);
                                        if (added != null && mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                added > 0 ? '已添加到播单' : '该文件已在播单中',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              '选集队列',
                              style: TextStyle(
                                color: muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ToneBadge(label: '共 ${playback.queue.length} 集'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: playback.queue.length,
                    itemBuilder: (context, i) {
                      final qItem = playback.queue[i];
                      final isCur = i == playback.index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: isCur ? sand : surface,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () {
                              if (isCur && playback.status == PlaybackStatus.idle) {
                                playback.resumeSession();
                              } else if (!isCur) {
                                playback.jumpTo(i);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isCur ? accent.withValues(alpha: 0.4) : sandDeep,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${i + 1}'.padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isCur ? FontWeight.w700 : FontWeight.w500,
                                        color: isCur ? accent : muted,
                                        fontFeatures: kTabularFigures,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    qItem.isVideo ? AppIcons.movie : AppIcons.musicNote,
                                    size: 18,
                                    color: isCur ? accent : muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      qItem.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isCur ? FontWeight.w600 : FontWeight.w400,
                                        color: isCur ? accent : ink,
                                      ),
                                    ),
                                  ),
                                  if (isCur) ...[
                                    const SizedBox(width: 8),
                                    PlayingWaveBars(playing: isPlaying, color: accent, size: 15),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portraitActionChip({
    required IconData icon,
    required String label,
    required bool active,
    bool enabled = true,
    required Color sand,
    required Color accent,
    required Color ink,
    required VoidCallback onTap,
  }) {
    final fg = !enabled ? ink.withValues(alpha: 0.35) : (active ? accent : ink);
    return Material(
      color: active ? accent.withValues(alpha: 0.14) : sand,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 横屏全屏 ----------

  Widget _buildFullscreen(PlaybackController playback) {
    return _videoArea(playback, fullscreen: true);
  }

  // ---------- 视频区域（含手势与控制层） ----------

  Widget _videoArea(PlaybackController playback, {required bool fullscreen}) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Video(
            controller: playback.videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
        // 缓冲/重连覆盖层
        _statusOverlay(playback),
        // 长按临时倍速激活提示（不受控制层显隐限制）
        if ((playback.effectiveSpeed - playback.speed).abs() > 0.01)
          Positioned(
            top: fullscreen ? MediaQuery.paddingOf(context).top + 14 : 12,
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
                      const Icon(Icons.fast_forward, size: 16, color: AppPalette.darkAccent),
                      const SizedBox(width: 6),
                      Text(
                        '${formatSpeed(playback.effectiveSpeed)} 快进中',
                        style: const TextStyle(color: AppPalette.darkInk, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // 快进预览
        if (_seekAccumSeconds != 0) _seekPreview(playback),
        // 水平拖动 seek：左右各让出 kEdgeGestureGuard 给系统边缘返回手势
        Positioned(
          left: kEdgeGestureGuard,
          right: kEdgeGestureGuard,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) {
              // 1 像素 = 0.5 秒（横向累计，松手提交）
              setState(() => _seekAccumSeconds += d.delta.dx * 0.5);
            },
            onHorizontalDragEnd: (_) {
              final secs = _seekAccumSeconds.round();
              _seekAccumSeconds = 0;
              if (secs != 0) playback.seekRelative(secs);
              setState(() {});
            },
            onHorizontalDragCancel: () {
              if (_seekAccumSeconds != 0) {
                setState(() => _seekAccumSeconds = 0);
              }
            },
          ),
        ),
        // 控制层（在 seek 手势层之上，保证进度条拖动优先）
        if (_controlsVisible) _controlsOverlay(playback, fullscreen: fullscreen),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onDoubleTap: () => playback.togglePlay(),
      onLongPressStart: (_) => playback.setTemporarySpeed(3.0),
      onLongPressEnd: (_) => playback.restoreSpeed(),
      onLongPressCancel: () => playback.restoreSpeed(),
      onVerticalDragStart: (d) => _dragStartX = d.localPosition.dx,
      onVerticalDragUpdate: (d) => _verticalDrag(playback, d),
      onVerticalDragEnd: (_) => _dragStartX = null,
      onVerticalDragCancel: () => _dragStartX = null,
      // 竖屏必须给视频区一个有限高度：Stack(fit: expand) 在 Column 的非 flex
      // 子项里会拿到 h=∞ 约束，触发 "BoxConstraints forces an infinite height"。
      child: fullscreen ? SizedBox.expand(child: content) : AspectRatio(aspectRatio: 16 / 9, child: content),
    );
  }

  Widget _seekPreview(PlaybackController playback) {
    final secs = _seekAccumSeconds.round();
    final base = playback.currentPosition;
    final target = secs >= 0
        ? base + Duration(seconds: secs)
        : (base.inSeconds + secs < 0 ? Duration.zero : base + Duration(seconds: secs));
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: AppPalette.scrimStrong, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(secs > 0 ? Icons.fast_forward : Icons.fast_rewind, color: AppPalette.darkInk),
              const SizedBox(width: 10),
              Text(
                formatDuration(target),
                style: const TextStyle(color: AppPalette.darkInk, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 10),
              Text(
                '${secs > 0 ? '+' : ''}$secs 秒',
                style: const TextStyle(color: AppPalette.darkMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 缓冲/打开提示：加半透明底板，避免落在亮画面上不可读
  Widget _loadingPill(String label, {double? progress}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.scrimStrong,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(color: AppPalette.darkAccent, strokeWidth: 3),
          ),
          const SizedBox(height: 10),
          Text(
            progress == null ? label : '$label ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: AppPalette.darkInk, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 已缓冲比例（无时长信息时返回 null）
  double? _bufferedRatio(PlaybackController playback) {
    final dur = playback.currentDuration;
    if (dur.inMilliseconds <= 0) return null;
    final buffered = playback.currentBuffer;
    if (buffered.inMilliseconds <= 0) return null;
    return (buffered.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
  }

  Widget _statusOverlay(PlaybackController playback) {
    return IgnorePointer(
      child: Center(
        child: switch (playback.status) {
          PlaybackStatus.opening => _loadingPill('打开中…'),
          PlaybackStatus.buffering => _loadingPill('缓冲中…', progress: _bufferedRatio(playback)),
          PlaybackStatus.error => const SizedBox.shrink(),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _controlsOverlay(PlaybackController playback, {required bool fullscreen}) {
    // 横屏全屏时控制层是唯一的安全区来源，需要自己避让刘海与 Home 指示条。
    // 竖屏分支外层已有 SafeArea（padding 已被消耗），这里不能再加，否则重复内缩。
    final pad = fullscreen ? MediaQuery.paddingOf(context) : EdgeInsets.zero;
    // 竖屏内嵌 16:9 只有 ~226pt 高：顶栏 + 进度条 + 两行按钮放不下。
    // 用 LayoutBuilder 依据实际高度决定按钮行是否精简。
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        // 竖屏内嵌区只有 ~226pt：出错时进度条与按钮行已无意义，
        // 让错误卡独占剩余空间，否则顶栏+错误卡+底栏必然溢出。
        final errorOnly = compact && playback.status == PlaybackStatus.error;
        return AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: Column(
              children: [
                // 顶栏
                Container(
                  padding: EdgeInsets.fromLTRB(pad.left + 4, pad.top + 2, pad.right + 4, 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppPalette.scrim, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        icon: const Icon(Icons.arrow_back, color: AppPalette.darkInk),
                        onPressed: () async {
                          if (fullscreen) {
                            await _exitFullscreen();
                            return;
                          }
                          if (mounted) Navigator.of(context).maybePop();
                        },
                      ),
                      Expanded(
                        child: Text(
                          playback.current?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppPalette.darkInk, fontSize: 14),
                        ),
                      ),
                      if (!fullscreen)
                        IconButton(
                          tooltip: '全屏',
                          icon: const Icon(Icons.fullscreen, color: AppPalette.darkInk),
                          onPressed: _enterFullscreen,
                        )
                      else
                        IconButton(
                          tooltip: '退出全屏',
                          icon: const Icon(Icons.fullscreen_exit, color: AppPalette.darkInk),
                          onPressed: _exitFullscreen,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // 错误操作按钮（居中）
                if (playback.status == PlaybackStatus.error) _errorActions(playback, compact: compact),
                const Spacer(),
                // 底栏（错误态在竖屏小区域内隐藏，把空间留给错误卡）
                if (!errorOnly)
                  Container(
                    padding: EdgeInsets.fromLTRB(pad.left + 8, 2, pad.right + 8, pad.bottom + 2),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppPalette.scrim, Colors.transparent],
                      ),
                    ),
                    child: _bottomControls(playback, compact: compact || !fullscreen),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _errorActions(PlaybackController playback, {bool compact = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 0 : 8),
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: compact ? 10 : 16),
      decoration: BoxDecoration(
        color: AppPalette.scrimStrong,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: AppPalette.darkMuted, size: compact ? 28 : 40),
          SizedBox(height: compact ? 6 : 8),
          Text(
            playback.errorText ?? '播放失败',
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppPalette.darkInk, fontSize: compact ? 12 : 13),
          ),
          SizedBox(height: compact ? 8 : 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                style: compact
                    ? FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      )
                    : null,
                onPressed: () => playback.retryNow(),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.skip_next, color: AppPalette.darkInk),
                label: const Text('跳过', style: TextStyle(color: AppPalette.darkInk)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppPalette.darkTaupe),
                  foregroundColor: AppPalette.darkInk,
                  visualDensity: compact ? VisualDensity.compact : null,
                  padding: compact ? const EdgeInsets.symmetric(horizontal: 14) : null,
                ),
                onPressed: () => playback.skipAfterError(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomControls(PlaybackController playback, {required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
        StreamBuilder<Duration>(
          stream: playback.positionStream,
          builder: (context, snap) {
            final streamPos = snap.data ?? playback.currentPosition;
            final dur = playback.currentDuration;
            final effectiveMs = _dragMs ??
                (dur.inMilliseconds > 0
                    ? streamPos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble()
                    : 0.0);
            final displayPos = Duration(milliseconds: effectiveMs.toInt());
            return Row(
              children: [
                Text(
                  formatDuration(displayPos),
                  style: const TextStyle(color: AppPalette.darkMuted, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      activeTrackColor: AppPalette.darkAccent,
                      inactiveTrackColor: AppPalette.darkSandDeep,
                      thumbColor: AppPalette.darkAccent,
                      overlayColor: AppPalette.darkAccent.withValues(alpha: 0.16),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                    ),
                    child: Slider(
                      value: dur.inMilliseconds > 0
                          ? effectiveMs.clamp(0.0, dur.inMilliseconds.toDouble())
                          : 0,
                      max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                      onChangeStart: dur.inMilliseconds > 0
                          ? (v) {
                              _hideTimer?.cancel();
                              setState(() => _dragMs = v);
                            }
                          : null,
                      onChanged: dur.inMilliseconds > 0
                          ? (v) => setState(() => _dragMs = v)
                          : null,
                      onChangeEnd: dur.inMilliseconds > 0
                          ? (v) {
                              if (_dragMs == null) {
                                _resetHideTimer();
                                return; // 拖动中途已切歌重置，忽略松手旧位置
                              }
                              setState(() => _dragMs = null);
                              playback.seek(Duration(milliseconds: v.toInt()));
                              _resetHideTimer();
                            }
                          : null,
                    ),
                  ),
                ),
                Text(
                  formatDuration(dur),
                  style: const TextStyle(color: AppPalette.darkMuted, fontSize: 12),
                ),
              ],
            );
          },
        ),
        // 按钮行：竖屏内嵌区只有 ~226pt 高，必须单行；横屏窄窗口才拆两行。
        _buttonRow(playback, compact: compact),
      ],
    );
  }

  Widget _buttonRow(PlaybackController playback, {required bool compact}) {
    final primary = <Widget>[
      IconButton(
        tooltip: '上一个',
        icon: const Icon(Icons.skip_previous, color: AppPalette.darkInk),
        onPressed: () {
          _resetHideTimer();
          playback.previous();
        },
      ),
      _playPause(playback),
      IconButton(
        tooltip: '下一个',
        icon: const Icon(Icons.skip_next, color: AppPalette.darkInk),
        onPressed: () {
          _resetHideTimer();
          playback.next();
        },
      ),
    ];
    final secondary = <Widget>[
      _speedButton(playback),
      _subtitleButton(playback),
      _audioButton(playback),
      _modeButton(playback),
    ];

    if (compact) {
      // 单行放全部控件；横向空间不足（窄机 / 大字号）时按比例缩小而不是溢出
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [...primary, ...secondary]),
      );
    }
    if (MediaQuery.sizeOf(context).width < 560) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: primary),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: secondary),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [...primary, ...secondary],
    );
  }

  Widget _playPause(PlaybackController playback) {
    return StreamBuilder<bool>(
      stream: playback.playingStream,
      builder: (context, snap) {
        final rawPlaying = snap.data ?? playback.isPlaying;
        final playing = rawPlaying &&
            playback.status != PlaybackStatus.error &&
            playback.status != PlaybackStatus.idle;
        return IconButton(
          tooltip: playing ? '暂停' : '播放',
          iconSize: 36,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: AppPalette.darkAccent),
          onPressed: () {
            _resetHideTimer();
            playback.togglePlay();
          },
        );
      },
    );
  }

  Widget _speedButton(PlaybackController playback) {
    return TextButton(
      onPressed: () {
        _resetHideTimer();
        showSpeedPanel(context, playback);
      },
      child: Text(
        formatSpeed(playback.effectiveSpeed),
        style: const TextStyle(color: AppPalette.darkAccent, fontSize: 13),
      ),
    );
  }

  Widget _subtitleButton(PlaybackController playback) {
    return IconButton(
      tooltip: '字幕',
      icon: Icon(
        playback.currentSubtitle != null ? Icons.subtitles : Icons.subtitles_outlined,
        color: AppPalette.darkInk,
      ),
      onPressed: () {
        _resetHideTimer();
        showSubtitlePanel(context, playback);
      },
    );
  }

  Widget _audioButton(PlaybackController playback) {
    return IconButton(
      tooltip: '音轨',
      icon: Icon(
        playback.audioTracks.length > 1 ? Icons.graphic_eq : Icons.graphic_eq_outlined,
        color: AppPalette.darkInk,
      ),
      onPressed: playback.audioTracks.length > 1
          ? () {
              _resetHideTimer();
              showAudioTrackPanel(context, playback);
            }
          : null,
    );
  }

  Widget _modeButton(PlaybackController playback) {
    final (icon, tip) = switch (playback.mode) {
      PlayMode.sequentialLoop => (Icons.repeat, '列表循环'),
      PlayMode.repeatOne => (Icons.repeat_one, '单曲循环'),
      PlayMode.shuffle => (Icons.shuffle, '随机'),
    };
    return IconButton(
      tooltip: tip,
      icon: Icon(icon, color: AppPalette.darkInk),
      onPressed: () {
        _resetHideTimer();
        playback.cycleMode();
      },
    );
  }

  // ---------- 手势 ----------

  void _verticalDrag(PlaybackController playback, DragUpdateDetails d) {
    final startX = _dragStartX;
    if (startX == null) return;
    final isLeft = startX < MediaQuery.of(context).size.width / 2;
    if (isLeft) {
      // 左半屏上下滑：亮度
      if (!_brightnessReady) return;
      _brightness = (_brightness - d.delta.dy / 400).clamp(0.05, 1.0);
      _brightnessModified = true;
      unawaited(ScreenBrightness().setApplicationScreenBrightness(_brightness).catchError((_) {}));
    } else {
      // 右半屏上下滑：音量
      _volume = (_volume - d.delta.dy / 3).clamp(0, 100);
      playback.setVolume(_volume);
    }
  }
}
