/// audio_service 集成：锁屏/通知栏控件、耳机拔出暂停、来电中断。
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../core/models.dart';
import '../data/settings_service.dart';
import 'playback_controller.dart';

class PlayerAudioHandler extends BaseAudioHandler {
  PlayerAudioHandler(this._c, {required AppSettings Function() settings})
      : _settings = settings {
    _c.addListener(_onControllerChanged);
    _subs.add(_c.playingStream.listen((_) => _pushPlaybackState()));
    _subs.add(_c.bufferingStream.listen((_) => _pushPlaybackState()));
    _subs.add(_c.durationStream.listen(_onDurationChanged));
    _initSession();
  }

  final PlaybackController _c;
  final AppSettings Function() _settings;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _disposed = false;
  bool _wasPlayingBeforeInterruption = false;
  String? _lastMediaItemId;

  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;
      await session.configure(const AudioSessionConfiguration.music());
      if (_disposed) return;
      // 耳机/蓝牙拔出：自动暂停
      _subs.add(session.becomingNoisyEventStream.listen((_) async {
        if (_c.isPlaying) await pause();
      }));
      // 来电等中断：暂停（结束后不自动恢复，避免打扰）
      _subs.add(session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          _wasPlayingBeforeInterruption = _c.isPlaying;
          if (_wasPlayingBeforeInterruption) await pause();
        } else {
          _wasPlayingBeforeInterruption = false;
        }
      }));
    } catch (_) {
      // 测试环境无原生插件时忽略
    }
  }

  void dispose() {
    _disposed = true;
    _c.removeListener(_onControllerChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _onControllerChanged() {
    if (_disposed) return;
    final item = _c.current;
    if (item == null) {
      if (_lastMediaItemId != null || mediaItem.value != null) {
        _lastMediaItemId = null;
        mediaItem.add(null);
      }
      _pushPlaybackState();
      return;
    }
    final dur = _c.currentDuration;
    if (_lastMediaItemId != item.path) {
      _lastMediaItemId = item.path;
      mediaItem.add(_buildMediaItem(item, dur));
    } else if (dur > Duration.zero && mediaItem.value?.duration != dur) {
      mediaItem.add(_buildMediaItem(item, dur));
    }
    _pushPlaybackState();
  }

  void _onDurationChanged(Duration dur) {
    if (_disposed || dur <= Duration.zero) return;
    final item = _c.current;
    if (item == null || _lastMediaItemId != item.path) return;
    if (mediaItem.value?.duration != dur) {
      mediaItem.add(_buildMediaItem(item, dur));
    }
  }

  MediaItem _buildMediaItem(QueueItem item, Duration dur) {
    final art = item.thumb.isNotEmpty ? Uri.tryParse(item.thumb) : null;
    return MediaItem(
      id: item.path,
      title: item.name,
      duration: dur > Duration.zero ? dur : null,
      artUri: (art != null && art.hasScheme) ? art : null,
      playable: true,
    );
  }

  void _pushPlaybackState() {
    if (_disposed) return;
    final playing = _c.isPlaying;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.fastForward,
        MediaAction.rewind,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(),
      playing: playing,
      updatePosition: _c.currentPosition,
      bufferedPosition: _c.currentBuffer,
      speed: _c.effectiveSpeed,
    ));
  }

  AudioProcessingState _mapProcessingState() {
    switch (_c.status) {
      case PlaybackStatus.idle:
        return AudioProcessingState.idle;
      case PlaybackStatus.opening:
      case PlaybackStatus.buffering:
        return AudioProcessingState.buffering;
      case PlaybackStatus.playing:
      case PlaybackStatus.paused:
        return AudioProcessingState.ready;
      case PlaybackStatus.error:
        return AudioProcessingState.error;
    }
  }

  @override
  Future<void> play() async {
    if (_c.status == PlaybackStatus.idle && _c.current != null) {
      await _c.resumeSession();
      return;
    }
    if (_c.status == PlaybackStatus.error) {
      await _c.retryNow();
      return;
    }
    await _c.togglePlay();
  }

  @override
  Future<void> pause() async {
    if (_c.isPlaying) {
      await _c.togglePlay();
    }
  }

  @override
  Future<void> seek(Duration position) => _c.seek(position);

  @override
  Future<void> fastForward() => _c.seekRelative(10);

  @override
  Future<void> rewind() => _c.seekRelative(-10);

  @override
  Future<void> seekForward(bool begin) async {
    if (begin) await _c.seekRelative(10);
  }

  @override
  Future<void> seekBackward(bool begin) async {
    if (begin) await _c.seekRelative(-10);
  }

  @override
  Future<void> skipToNext() => _c.next();

  @override
  Future<void> skipToPrevious() => _c.previous();

  @override
  Future<void> stop() async {
    await _c.stop();
    await super.stop();
  }

  /// App 退后台钩子：视频且设置"后台不放声音"时暂停
  Future<void> onAppBackgrounded() async {
    final item = _c.current;
    if (item != null && item.isVideo && !_settings().videoBackgroundAudio && _c.isPlaying) {
      await _c.togglePlay();
    }
  }
}
