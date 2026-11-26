/// 云序全局图标与品牌矢量微标集中入口：
/// 1. 优先映射 Material Outlined（24px 网格、圆润描边，零额外字体依赖）；
/// 2. 品牌「声环留声」微标（YunxuLogoMark）与等化器律动指示器（PlayingWaveBars）纯 CustomPainter 绘制。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'player/audio_theme.dart';

/// 全局统一图标语义映射（业务组件优先从此类取图标）
class AppIcons {
  const AppIcons._();

  static const home = Icons.home_outlined;
  static const homeSelected = Icons.home_rounded;
  static const folder = Icons.folder_outlined;
  static const folderSelected = Icons.folder_rounded;
  static const playlist = Icons.queue_music_outlined;
  static const playlistSelected = Icons.queue_music_rounded;
  static const settings = Icons.tune_rounded;
  static const settingsSelected = Icons.tune_rounded;

  static const play = Icons.play_arrow_rounded;
  static const pause = Icons.pause_rounded;
  static const prev = Icons.skip_previous_rounded;
  static const next = Icons.skip_next_rounded;
  static const rewind = Icons.replay_rounded;
  static const forward = Icons.refresh_rounded;

  static const queue = Icons.format_list_bulleted_rounded;
  static const sort = Icons.sort_rounded;
  static const sleep = Icons.bedtime_outlined;
  static const sleepActive = Icons.bedtime_rounded;
  static const speed = Icons.speed_rounded;
  static const repeat = Icons.repeat_rounded;
  static const repeatOne = Icons.repeat_one_rounded;
  static const shuffle = Icons.shuffle_rounded;
  static const search = Icons.search_rounded;
  static const filter = Icons.filter_list_rounded;
  static const more = Icons.more_horiz_rounded;
  static const chevronRight = Icons.chevron_right_rounded;
  static const collapseDown = Icons.keyboard_arrow_down_rounded;
  static const check = Icons.check_rounded;
  static const cloud = Icons.cloud_outlined;
  static const clock = Icons.history_rounded;
  static const subtitles = Icons.subtitles_outlined;
  static const audioTrack = Icons.audiotrack_rounded;
  static const lyrics = Icons.lyrics_outlined;
  static const movie = Icons.movie_outlined;
  static const musicNote = Icons.music_note_rounded;
  static const file = Icons.insert_drive_file_outlined;
}

/// 云序「声环留声」品牌矢量微标（与 design_output/logo/yunxu_logo.svg 同源）。
/// size <= 32 自动切为紧凑单环版，保证在 AppBar / 设置页 / 启动卡片清晰锐利。
class YunxuLogoMark extends StatelessWidget {
  const YunxuLogoMark({
    super.key,
    this.size = 28,
    this.withSurface = true,
  });

  final double size;
  final bool withSurface;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _YunxuLogoPainter(
          isDark: isDark,
          compact: size <= 32,
          withSurface: withSurface,
        ),
      ),
    );
  }
}

class _YunxuLogoPainter extends CustomPainter {
  const _YunxuLogoPainter({
    required this.isDark,
    required this.compact,
    required this.withSurface,
  });

  final bool isDark;
  final bool compact;
  final bool withSurface;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 512.0;
    final accent = isDark ? AppPalette.darkAccent : AudioTone.accent;
    final bgTop = isDark ? AppPalette.darkSurface : AudioTone.surface;
    final bgBot = isDark ? AppPalette.darkBg : AudioTone.bg;
    final border = isDark ? AppPalette.darkSandDeep : AudioTone.sandDeep;

    if (withSurface) {
      final rrect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(114 * s),
      );
      final bgPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBot],
        ).createShader(Offset.zero & size);
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(
        rrect.deflate(2 * s),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 * s).clamp(0.8, 3.0)
          ..color = border,
      );
    }

    final center = Offset(256 * s, 256 * s);

    if (compact) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 138 * s),
        42 * math.pi / 180,
        276 * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 34 * s
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.58),
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 146 * s),
        41 * math.pi / 180,
        278 * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22 * s
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.30),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 94 * s),
        46 * math.pi / 180,
        268 * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22 * s
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.66),
      );
    }

    final path = Path();
    if (compact) {
      path
        ..moveTo(232 * s, 204 * s)
        ..cubicTo(232 * s, 195 * s, 242 * s, 189 * s, 250 * s, 194 * s)
        ..lineTo(320 * s, 244 * s)
        ..cubicTo(328 * s, 249 * s, 328 * s, 263 * s, 320 * s, 268 * s)
        ..lineTo(250 * s, 318 * s)
        ..cubicTo(242 * s, 323 * s, 232 * s, 317 * s, 232 * s, 308 * s)
        ..close();
    } else {
      path
        ..moveTo(239 * s, 218 * s)
        ..cubicTo(239 * s, 210 * s, 248 * s, 205 * s, 255 * s, 209 * s)
        ..lineTo(311 * s, 247 * s)
        ..cubicTo(318 * s, 251 * s, 318 * s, 261 * s, 311 * s, 265 * s)
        ..lineTo(255 * s, 303 * s)
        ..cubicTo(248 * s, 307 * s, 239 * s, 302 * s, 239 * s, 294 * s)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_YunxuLogoPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.compact != compact ||
      oldDelegate.withSurface != withSurface;
}

/// 轻量化三柱播放律动声波（播放时平滑律动，暂停时静立，Skia 零模糊开销）
class PlayingWaveBars extends StatefulWidget {
  const PlayingWaveBars({
    super.key,
    required this.playing,
    this.color,
    this.size = 16,
  });

  final bool playing;
  final Color? color;
  final double size;

  @override
  State<PlayingWaveBars> createState() => _PlayingWaveBarsState();
}

class _PlayingWaveBarsState extends State<PlayingWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PlayingWaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.playing && !_disableAnimations) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else if (_ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? Theme.of(context).colorScheme.primary;
    final animate = widget.playing && !_disableAnimations;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(
          painter: _WaveBarsPainter(
            phase: animate ? _ctrl.value : 0.25,
            playing: animate,
            color: barColor,
          ),
        ),
      ),
    );
  }
}

class _WaveBarsPainter extends CustomPainter {
  const _WaveBarsPainter({
    required this.phase,
    required this.playing,
    required this.color,
  });

  final double phase;
  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barW = size.width * 0.2;
    final gap = (size.width - barW * 3) / 2;
    final heights = playing
        ? [
            0.35 + 0.55 * (0.5 + 0.5 * math.sin((phase * 2 * math.pi) + 0.0)),
            0.40 + 0.55 * (0.5 + 0.5 * math.sin((phase * 2 * math.pi) + 2.1)),
            0.35 + 0.55 * (0.5 + 0.5 * math.sin((phase * 2 * math.pi) + 4.2)),
          ]
        : const [0.42, 0.72, 0.52];

    for (var i = 0; i < 3; i++) {
      final h = size.height * heights[i];
      final x = i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        Radius.circular(barW / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveBarsPainter old) =>
      old.phase != phase || old.playing != playing || old.color != color;
}
