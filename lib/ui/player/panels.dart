/// 播放面板：精细倍速（0.5x~3.0x 步进 0.1x 滑杆 + 快捷预设）、睡眠定时、字幕（内置/外挂/延迟）、音轨。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../player/playback_controller.dart';
import '../app_theme.dart';
import '../icons.dart';
import '../widgets.dart';

const kSpeedPresets = [0.75, 1.0, 1.25, 1.5, 2.0];

ThemeData _panelTheme(BuildContext context, bool dark) =>
    dark ? AppTheme.dark : Theme.of(context);

/// 面板统一骨架：可滚动列表 + 高度上限（横屏 402pt 高时不至于顶满）。
Future<void> _showPlayerSheet(
  BuildContext context,
  PlaybackController playback,
  bool dark, {
  required Widget Function(BuildContext) builder,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: dark ? AppPalette.darkSurface : null,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (sheetContext) {
      return Theme(
        data: _panelTheme(context, dark),
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: playback,
            builder: (innerContext, _) => builder(innerContext),
          ),
        ),
      );
    },
  );
}

Widget _sheetHandle(BuildContext context) {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppPalette.sandDeepOf(context),
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

/// 倍速调节面板：支持 0.5x ~ 3.0x（0.1x 步进）滑杆、±0.1 微调键与常用快捷预设。
Future<void> showSpeedPanel(
  BuildContext context,
  PlaybackController playback, {
  bool dark = false,
}) {
  return _showPlayerSheet(context, playback, dark, builder: (sheetContext) {
    final accent = AppPalette.accentOf(sheetContext);
    final ink = AppPalette.inkOf(sheetContext);
    final muted = AppPalette.mutedOf(sheetContext);
    final sand = AppPalette.sandOf(sheetContext);
    final currentSpeed = playback.speed.clamp(0.5, 3.0);

    void applySpeed(double v) {
      final rounded = (v.clamp(0.5, 3.0) * 10).round() / 10.0;
      playback.persistSpeed(rounded);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(sheetContext),
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Center(
                  child: Text(
                    '播放速度',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                icon: Icon(Icons.close, size: 20, color: muted),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 中央大号当前倍速读数 + ±0.1x 微调
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepBtn(
                sheetContext,
                label: '-0.1',
                enabled: currentSpeed > 0.51,
                onTap: () {
                  HapticFeedback.selectionClick();
                  applySpeed(currentSpeed - 0.1);
                },
              ),
              SizedBox(
                width: 108,
                child: Center(
                  child: Text(
                    formatSpeed(currentSpeed),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
              ),
              _stepBtn(
                sheetContext,
                label: '+0.1',
                enabled: currentSpeed < 2.99,
                onTap: () {
                  HapticFeedback.selectionClick();
                  applySpeed(currentSpeed + 0.1);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: currentSpeed,
            min: 0.5,
            max: 3.0,
            divisions: 25,
            onChanged: (v) => playback.setSpeed((v * 10).round() / 10.0),
            onChangeEnd: applySpeed,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0.5x', style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures)),
                Text('1.0x', style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures)),
                Text('2.0x', style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures)),
                Text('3.0x', style: TextStyle(fontSize: 11, color: muted, fontFeatures: kTabularFigures)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 常用预设快捷胶囊
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in kSpeedPresets)
                _speedPresetChip(
                  sheetContext,
                  speed: s,
                  selected: (playback.speed - s).abs() < 0.01,
                  sand: sand,
                  accent: accent,
                  ink: ink,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    playback.persistSpeed(s);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  });
}

Widget _stepBtn(
  BuildContext context, {
  required String label,
  required bool enabled,
  required VoidCallback onTap,
}) {
  final sand = AppPalette.sandOf(context);
  final ink = AppPalette.inkOf(context);
  final muted = AppPalette.mutedOf(context);
  return Material(
    color: sand,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? ink : muted.withValues(alpha: 0.4),
            fontFeatures: kTabularFigures,
          ),
        ),
      ),
    ),
  );
}

Widget _speedPresetChip(
  BuildContext context, {
  required double speed,
  required bool selected,
  required Color sand,
  required Color accent,
  required Color ink,
  required VoidCallback onTap,
}) {
  final onAccent = Theme.of(context).colorScheme.onPrimary;
  return Material(
    color: selected ? accent : sand,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          formatSpeed(speed),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? onAccent : ink,
            fontFeatures: kTabularFigures,
          ),
        ),
      ),
    ),
  );
}

/// 睡眠定时选择面板：关闭 / 15m / 30m / 45m / 60m / 播完本集停。
Future<void> showSleepTimerPanel(
  BuildContext context,
  PlaybackController playback, {
  bool dark = false,
}) {
  return _showPlayerSheet(context, playback, dark, builder: (sheetContext) {
    final accent = AppPalette.accentOf(sheetContext);
    final ink = AppPalette.inkOf(sheetContext);
    final muted = AppPalette.mutedOf(sheetContext);
    final mode = playback.sleepTimerMode;
    final rem = playback.sleepRemaining;

    Widget row({
      required String title,
      String? subtitle,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
              Navigator.pop(sheetContext);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? accent : ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, style: TextStyle(fontSize: 11.5, color: muted)),
                        ],
                      ],
                    ),
                  ),
                  if (selected) Icon(AppIcons.check, size: 20, color: accent),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(sheetContext),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              children: [
                Icon(AppIcons.sleep, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  '睡眠定时',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: ink),
                ),
                const Spacer(),
                if (mode == SleepTimerMode.countdown && rem != null)
                  ToneBadge(
                    label: '剩余 ${formatDuration(rem)}',
                    accent: true,
                  )
                else if (mode == SleepTimerMode.endOfTrack)
                  const ToneBadge(label: '播完本集停', accent: true),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                row(
                  title: '关闭',
                  selected: mode == SleepTimerMode.off,
                  onTap: () => playback.cancelSleepTimer(),
                ),
                for (final mins in const [15, 30, 45, 60])
                  row(
                    title: '$mins 分钟后暂停',
                    selected: false,
                    onTap: () => playback.setSleepCountdown(Duration(minutes: mins)),
                  ),
                row(
                  title: '播完本集停',
                  subtitle: '当前单集结束时自动暂停，听有声书/播客推荐',
                  selected: mode == SleepTimerMode.endOfTrack,
                  onTap: () => playback.setSleepEndOfTrack(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });
}

Future<void> showAudioTrackPanel(
  BuildContext context,
  PlaybackController playback, {
  bool dark = false,
}) {
  return _showPlayerSheet(context, playback, dark, builder: (sheetContext) {
    return ListView(
      shrinkWrap: true,
      children: [
        _sheetHandle(sheetContext),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

Future<void> showSubtitlePanel(
  BuildContext context,
  PlaybackController playback, {
  bool dark = false,
}) {
  return _showPlayerSheet(context, playback, dark, builder: (sheetContext) {
    final cur = playback.currentSubtitle;
    final loadedExternalNames = playback.subtitleTracks
        .where((t) => t.isExternal && t.title != null)
        .map((t) => t.title!)
        .toSet();
    final unloadedSubs = playback.availableExternalSubs
        .where((name) => !loadedExternalNames.contains(name))
        .toList();
    return ListView(
      shrinkWrap: true,
      children: [
        _sheetHandle(sheetContext),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
        if (unloadedSubs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('从同目录加载字幕', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          for (final name in unloadedSubs)
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
                    style: const TextStyle(fontSize: 14, fontFeatures: kTabularFigures),
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
