/// 通用小组件与格式化工具。
library;

import 'dart:io';

import 'package:flutter/material.dart';

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
