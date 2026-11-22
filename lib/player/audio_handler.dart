/// audio_service 集成：锁屏/通知栏控件、耳机拔出暂停、来电中断。
library;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../data/settings_service.dart';
import 'playback_controller.dart';

class PlayerAudioHandler extends BaseAudioHandler {
  PlayerAudioHandler(this._c, {required AppSettings Function() settings})
      : _settings = settings {
    _c.addListener(_onControllerChanged);
    _c.player.stream.playing.listen((_) => _pushPlaybackState());
    _c.player.stream.buffering.listen((_) => _pushPlaybackState());
    _initSession();
  }

  final PlaybackController _c;
  final AppSettings Function() _settings;
  bool _wasPlayingBeforeInterruption = false;
  String? _lastMediaItemId;

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // 耳机/蓝牙拔出：自动暂停
    session.becomingNoisyEventStream.listen((_) async {
      if (_c.player.state.playing) await _c.player.pause();
    });
    // 来电等中断：暂停（结束后不自动恢复，避免打扰）
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _wasPlayingBeforeInterruption = _c.player.state.playing;
        if (_wasPlayingBeforeInterruption) await _c.player.pause();
      } else {
        _wasPlayingBeforeInterruption = false;
      }
    });
  }

  void _onControllerChanged() {
    final item = _c.current;
    if (item == null) return;
    if (_lastMediaItemId != item.path) {
      _lastMediaItemId = item.path;
      final dur = _c.player.state.duration;
      mediaItem.add(MediaItem(
        id: item.path,
        title: item.name,
        duration: dur > Duration.zero ? dur : null,
        playable: true,
      ));
    }
    _pushPlaybackState();
  }

  void _pushPlaybackState() {
    final s = _c.player.state;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        s.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(),
      playing: s.playing,
      updatePosition: s.position,
      bufferedPosition: s.buffer,
      speed: _c.speed,
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
  Future<void> play() => _c.player.play();

  @override
  Future<void> pause() => _c.player.pause();

  @override
  Future<void> seek(Duration position) => _c.seek(position);

  @override
  Future<void> skipToNext() => _c.next();

  @override
  Future<void> skipToPrevious() => _c.previous();

  @override
  Future<void> stop() async {
    await _c.onAppPaused();
    await _c.player.pause();
  }

  /// App 退后台钩子：视频且设置"后台不放声音"时暂停
  Future<void> onAppBackgrounded() async {
    final item = _c.current;
    if (item != null && item.isVideo && !_settings().videoBackgroundAudio) {
      await _c.player.pause();
    }
  }
}
