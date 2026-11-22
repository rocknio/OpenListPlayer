/// 播放面板：倍速、字幕（内置轨/外挂/延迟）、音轨。
library;

import 'package:flutter/material.dart';

import '../../player/playback_controller.dart';
import '../widgets.dart';
import 'audio_theme.dart';

const kSpeedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// 播放器是纯黑背景，面板固定用深色，避免浅色模式下面板跳成白底。
/// [dark] 由调用方决定：播放页传 true，音频页跟随应用主题。
ThemeData _panelTheme(BuildContext context, bool dark) {
  if (!dark) return Theme.of(context);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3F51B5),
    brightness: Brightness.dark,
  );
  return ThemeData(colorScheme: scheme, brightness: Brightness.dark, useMaterial3: true);
}

/// 面板统一骨架：深色 + 可滚动列表 + 高度上限（横屏 402pt 高时不至于顶满）。
/// 字幕轨道可能很多（内置+外挂+同目录可加载），必须可滚动。
Future<void> _showPlayerSheet(
  BuildContext context,
  bool dark, {
  required Widget Function(BuildContext) builder,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: dark ? const Color(0xFF1C1B1F) : null,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (sheetContext) {
      // Builder 保证面板内容拿到的是 _panelTheme 之后（内部）的 context；
      // 直接用 sheetContext 会读到未套主题的外层，深色面板上出现深色标题。
      return Theme(
        data: _panelTheme(context, dark),
        child: SafeArea(
          top: false,
          child: Builder(builder: builder),
        ),
      );
    },
  );
}

Future<void> showSpeedPanel(BuildContext context, PlaybackController playback, {bool dark = false}) {
  // 音频页（dark=false）按设计稿用「标题 + 行式列表 + 勾选」；
  // 视频播放页（dark=true）是纯黑沉浸场景，保留紧凑的 chip 布局。
  if (!dark) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AudioTone.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '播放速度',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AudioTone.ink,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close, size: 20, color: AudioTone.muted),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final s in kSpeedPresets)
                    _speedRow(sheetContext, playback, s,
                        (playback.speed - s).abs() < 0.01),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  return _showPlayerSheet(context, dark, builder: (sheetContext) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('播放速度', style: Theme.of(sheetContext).textTheme.titleMedium),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final s in kSpeedPresets)
              ChoiceChip(
                label: Text(formatSpeed(s)),
                selected: (playback.speed - s).abs() < 0.01,
                onSelected: (_) {
                  playback.persistSpeed(s);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  });
}

/// 设计稿的倍速行：1.0× + 「正常」标签，选中行进显示浅陶土底与勾选圆点
Widget _speedRow(
  BuildContext sheetContext,
  PlaybackController playback,
  double speed,
  bool selected,
) {
  final isNormal = (speed - 1.0).abs() < 0.01;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Material(
      color: selected ? AudioTone.accent.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          playback.persistSpeed(speed);
          Navigator.pop(sheetContext);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Text(
                formatSpeed(speed),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? AudioTone.accent : AudioTone.ink,
                ),
              ),
              if (isNormal) ...[
                const SizedBox(width: 8),
                Text('正常', style: AudioTone.rowMeta),
              ],
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle, size: 20, color: AudioTone.accent)
              else
                const Icon(Icons.circle_outlined, size: 20, color: AudioTone.sandDeep),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showAudioTrackPanel(BuildContext context, PlaybackController playback, {bool dark = true}) {
  return _showPlayerSheet(context, dark, builder: (sheetContext) {
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('音轨', style: Theme.of(sheetContext).textTheme.titleMedium),
        ),
        RadioGroup<String>(
          groupValue: playback.currentAudio?.id,
          onChanged: (id) {
            final t = playback.audioTracks.where((x) => x.id == id).firstOrNull;
            if (t == null) return;
            playback.selectAudioTrack(t);
            Navigator.pop(sheetContext);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in playback.audioTracks)
                RadioListTile<String>(
                  dense: true,
                  value: t.id,
                  title: Text(t.label),
                  subtitle: t.title != null && t.language != null ? Text(t.language!) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  });
}

Future<void> showSubtitlePanel(BuildContext context, PlaybackController playback, {bool dark = true}) {
  final cur = playback.currentSubtitle;
  return _showPlayerSheet(context, dark, builder: (sheetContext) {
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('字幕', style: Theme.of(sheetContext).textTheme.titleMedium),
        ),
        RadioGroup<String>(
          groupValue: cur?.id ?? '__none__',
          onChanged: (id) {
            if (id == '__none__') {
              playback.selectSubtitleTrack(null);
            } else {
              final t = playback.subtitleTracks.where((x) => x.id == id).firstOrNull;
              if (t == null) return;
              playback.selectSubtitleTrack(t);
            }
            Navigator.pop(sheetContext);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RadioListTile<String>(
                dense: true,
                value: '__none__',
                title: Text('关闭字幕'),
              ),
              if (playback.subtitleTracks.any((t) => !t.isExternal)) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('内置字幕轨', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                for (final t in playback.subtitleTracks.where((x) => !x.isExternal))
                  RadioListTile<String>(dense: true, value: t.id, title: Text(t.label)),
              ],
              if (playback.subtitleTracks.any((t) => t.isExternal)) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('已加载外挂字幕', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                for (final t in playback.subtitleTracks.where((x) => x.isExternal))
                  RadioListTile<String>(dense: true, value: t.id, title: Text(t.title ?? t.label)),
              ],
            ],
          ),
        ),
        if (playback.availableExternalSubs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('从同目录加载字幕', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          for (final name in playback.availableExternalSubs)
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              onTap: () {
                playback.addExternalSubtitle(name);
                Navigator.pop(sheetContext);
              },
            ),
        ],
        const Divider(height: 20),
        // 字幕延迟
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('字幕延迟'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: '提前 0.5 秒',
                onPressed: () => playback.adjustSubDelay(-500),
              ),
              SizedBox(
                width: 88,
                child: Center(
                  child: Text(
                    playback.subDelayMs == 0
                        ? '同步'
                        : '${playback.subDelayMs > 0 ? '+' : ''}${(playback.subDelayMs / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '延后 0.5 秒',
                onPressed: () => playback.adjustSubDelay(500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  });
}
