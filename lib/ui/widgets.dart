/// 通用小组件与格式化工具。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/media_types.dart';
import 'app_theme.dart';
import 'player/audio_theme.dart';

/// 全局悬浮 MiniPlayerBar 的统一底部留白常量，防止列表末项被遮挡。
const double kMiniPlayerReservedPadding = 84.0;

/// 等宽数字样式列表，避免读秒与进度百分比左右抖动。
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// 从文件名提取简明格式徽章文案（如 `FLAC` / `MP3` / `MKV`），无扩展名返回空串。
String mediaFormatBadge(String fileName) {
  final ext = fileExtension(fileName);
  if (ext == null || ext.isEmpty) return '';
  return ext.toUpperCase();
}

/// 判断格式是否为无损音频，供音频页展示「FLAC 无损」等标识。
bool isLosslessAudio(String fileName) {
  final ext = fileExtension(fileName);
  return ext == 'flac' || ext == 'wav' || ext == 'ape';
}

/// 自底向上模态转场路由（M1）：用于从 MiniPlayerBar 或首页平滑展开全屏播放器。
Route<T> buildPlayerSheetRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.14),
        end: Offset.zero,
      ).animate(curved);
      final radius = Tween<double>(begin: 24, end: 0).animate(curved);
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
        ),
        child: SlideTransition(
          position: slide,
          child: AnimatedBuilder(
            animation: radius,
            builder: (_, c) => radius.value > 0.5
                ? ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(radius.value)), child: c)
                : c!,
            child: child,
          ),
        ),
      );
    },
  );
}

/// 精简胶囊徽章（用于格式、已完成、状态提示）
class ToneBadge extends StatelessWidget {
  const ToneBadge({
    super.key,
    required this.label,
    this.accent = false,
    this.success = false,
    this.icon,
  });

  final String label;
  final bool accent;
  final bool success;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppPalette.accentOf(context);
    final successColor = AppPalette.successOf(context);
    final mutedColor = AppPalette.mutedOf(context);
    final sand = AppPalette.sandOf(context);
    final Color fg;
    final Color bg;
    if (success) {
      fg = successColor;
      bg = successColor.withValues(alpha: 0.14);
    } else if (accent) {
      fg = accentColor;
      bg = accentColor.withValues(alpha: 0.13);
    } else {
      fg = mutedColor;
      bg = sand;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.3,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inset Grouped 分组白卡（设置页 / 首页区块复用）
class InsetSectionCard extends StatelessWidget {
  const InsetSectionCard({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AudioTone.cardShadow, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: AppPalette.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppPalette.sandDeepOf(context), width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// 播放倍速统一显示：整数不带小数（1x / 2x），其余保留两位有效位（1.25x）。
/// 播放页、音频页与倍速面板共用同一格式，避免 1.0x 与 1x 混用。
String formatSpeed(double speed) {
  if (speed == speed.roundToDouble()) return '${speed.toInt()}x';
  final fixed = speed.toStringAsFixed(2);
  return fixed.endsWith('0') ? '${fixed.substring(0, fixed.length - 1)}x' : '${fixed}x';
}

/// 封面圆角：按边长比例计算，大图（音频页 220）与小图（mini bar 40）观感一致
double coverRadius(double size) => size * 0.1;

/// 封面：有 OpenList 缩略图时显示图片，否则回退到占位图标。
/// 远程图可能 404 / 需要鉴权失败，必须带 errorBuilder 回退。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.size,
    required this.thumbUrl,
    required this.fallbackIcon,
    this.radius,
  });

  final double size;
  final String thumbUrl;
  final IconData fallbackIcon;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = radius ?? coverRadius(size);
    final placeholder = Container(
      width: size,
      height: size,
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, size: size * 0.44, color: cs.onPrimaryContainer),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: thumbUrl.isEmpty
          ? placeholder
          : Image.network(
              thumbUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

/// 音频占位封面图路径（浅色 / 深色），无缩略图时统一回退到矢量占位图。
/// 深色版由同一矢量母版导出，仅提亮主色以适配暗背景。
class AudioPlaceholderArt extends StatelessWidget {
  const AudioPlaceholderArt({super.key, required this.isDark, this.size});

  /// 深色模式用提亮版（#D2704A），浅色用陶土母版（#B85C38）。
  final bool isDark;

  /// 缩略图场景传入边长；大封面留空由父级 Stack 撑满。
  final double? size;

  static const lightAsset = 'assets/images/audio_placeholder.png';
  static const darkAsset = 'assets/images/audio_placeholder_dark.png';

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      isDark ? darkAsset : lightAsset,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (size == null) return image;
    return SizedBox(width: size, height: size, child: image);
  }
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  var v = bytes.toDouble();
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return v >= 100 || i == 0 ? '${v.round()}${units[i]}' : '${v.toStringAsFixed(1)}${units[i]}';
}

/// 无站点时的引导卡片
class NoSiteHint extends StatelessWidget {
  const NoSiteHint({super.key, this.onGoSettings});
  final VoidCallback? onGoSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('还未配置网盘地址', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('前往设置添加 OpenList 服务地址', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGoSettings,
              icon: const Icon(Icons.settings),
              label: const Text('去设置'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一错误重试视图
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 平台判断（避免到处 import dart:io）
bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
