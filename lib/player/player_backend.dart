/// 播放器内核底层驱动抽象：生产环境由 media_kit (mpv) 实现，单元测试可注入轻量假驱动。
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show mapEquals, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 将 HTTP 请求头格式化为 mpv `http-header-fields` 属性字符串（CRLF 分隔，过滤非法控制字符）。
/// 请求头为空时返回空串，用于清空旧残留请求头。
String formatMpvHttpHeaders(Map<String, String> headers) {
  if (headers.isEmpty) return '';
  return headers.entries
      .map((e) {
        final k = e.key.replaceAll(RegExp(r'[\r\n]'), '').trim();
        final v = e.value.replaceAll(RegExp(r'[\r\n]'), '').trim();
        return (k.isEmpty || v.isEmpty) ? '' : '$k: $v';
      })
      .where((line) => line.isNotEmpty)
      .join('\r\n');
}

/// 编排 mpv 外挂字幕加载时的 `http-header-fields` 切换与恢复：
/// 1. 无论字幕自身的 [subHeaders] 是否为空，都先写入 [subHeaders]，防止主媒体的鉴权/Cookie 泄露给异源或无头字幕；
/// 2. 执行 `sub-add` 命令后，在 `finally` 中若 [subHeaders] 与 [mediaHeaders] 不同，立即恢复为主媒体的 [mediaHeaders]，
///    确保主媒体后续拖动进度发起 HTTP `Range` 重连时仍携带正确的鉴权头。
@visibleForTesting
Future<void> runSubAddWithHeaderGuard({
  required Map<String, String> mediaHeaders,
  required Map<String, String> subHeaders,
  required Future<void> Function(Map<String, String> headers) applyHeaders,
  required Future<void> Function() runSubAdd,
}) async {
  await applyHeaders(subHeaders);
  try {
    await runSubAdd();
  } finally {
    if (!mapEquals(subHeaders, mediaHeaders)) {
      await applyHeaders(mediaHeaders);
    }
  }
}

/// 面向 [PlaybackController] 的底层播放引擎接口
abstract class PlayerBackend {
  Player? get rawPlayer;
  VideoController? get rawVideoController;

  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<Tracks> get tracksStream;
  Stream<Track> get trackStream;
  Stream<Duration> get bufferStream;

  bool get isPlaying;
  Duration get currentPosition;
  Duration get currentDuration;
  Duration get currentBuffer;
  double get currentVolume;
  Tracks get currentTracks;
  Track get currentTrack;

  Future<void> applyBufferProfile({required int readaheadSecs, required int bufferBytes});
  Future<void> openMedia(
    String url, {
    Map<String, String> headers = const {},
    Duration? start,
    bool play = true,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setAudioTrack(AudioTrack track);
  Future<void> setSubtitleTrack(SubtitleTrack track);
  Future<void> setSubDelaySeconds(double seconds);
  Future<void> addExternalSub(
    String url,
    String flag,
    String title, {
    Map<String, String> headers = const {},
  });
  Future<void> dispose();
}

/// 基于 media_kit / mpv 的真实播放引擎实现
class MediaKitBackend implements PlayerBackend {
  MediaKitBackend({required int initialBufferBytes}) {
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: initialBufferBytes,
        osc: false,
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(_player, configuration: _videoConfig());
  }

  late final Player _player;
  late final VideoController _videoController;

  static const _deviceChannel = MethodChannel('olp/device');
  bool? _isSimulatorCache;

  /// 当前主媒体的 HTTP 请求头快照，供加载外挂字幕后恢复 `http-header-fields`。
  Map<String, String> _mediaHeaders = const {};

  /// 平台相关的视频输出配置。
  ///
  /// Android：HyperOS/Android 16 + mt6878(Mali) 上 vo=gpu 不出帧——mpv 自建 EGL
  /// 上下文渲染到 SurfaceTexture 在该设备静默失败。mediacodec_embed 让 MediaCodec
  /// 硬解直接渲染进 Surface，mpv 完全不碰 GL。
  ///
  /// iOS：不存在 mediacodec_embed，保持 media_kit 默认（videotoolbox 硬解 + gpu 输出）。
  static VideoControllerConfiguration _videoConfig() {
    if (Platform.isAndroid) {
      return const VideoControllerConfiguration(
        vo: 'mediacodec_embed',
        hwdec: 'mediacodec',
      );
    }
    return const VideoControllerConfiguration();
  }

  /// iOS 模拟器检测（原生 targetEnvironment(simulator)，Platform.environment 在 iOS 恒空）
  Future<bool> _isSimulator() async {
    final cached = _isSimulatorCache;
    if (cached != null) return cached;
    if (!Platform.isIOS) return _isSimulatorCache = false;
    try {
      return _isSimulatorCache = await _deviceChannel.invokeMethod<bool>('isSimulator') ?? false;
    } catch (_) {
      return _isSimulatorCache = false;
    }
  }

  @override
  Player get rawPlayer => _player;

  @override
  VideoController get rawVideoController => _videoController;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<Tracks> get tracksStream => _player.stream.tracks;

  @override
  Stream<Track> get trackStream => _player.stream.track;

  @override
  Stream<Duration> get bufferStream => _player.stream.buffer;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  Duration get currentPosition => _player.state.position;

  @override
  Duration get currentDuration => _player.state.duration;

  @override
  Duration get currentBuffer => _player.state.buffer;

  @override
  double get currentVolume => _player.state.volume;

  @override
  Tracks get currentTracks => _player.state.tracks;

  @override
  Track get currentTrack => _player.state.track;

  @override
  Future<void> applyBufferProfile({required int readaheadSecs, required int bufferBytes}) async {
    final np = _player.platform;
    if (np is! NativePlayer) return;
    await np.setProperty('demuxer-readahead-secs', '$readaheadSecs');
    await np.setProperty('demuxer-max-bytes', '$bufferBytes');
    if (Platform.isAndroid) {
      // media_kit 默认 ao=opensles 在部分 Android 16/新设备上 SIGSEGV（mpv core 线程崩溃，
      // 2026-11-20 真机实测），改用 Android 原生 AudioTrack 输出
      await np.setProperty('ao', 'audiotrack');
    }
    // iOS 模拟器上 libmpv 音频设备无法初始化（media_kit 已知限制，真机正常）：
    // ao=null 允许无声播放；模拟器磁盘缓存目录也建不了，一并关闭
    if (await _isSimulator()) {
      await np.setProperty('ao', 'null');
      await np.setProperty('cache-on-disk', 'no');
    }
  }

  /// 将指定的 HTTP 请求头写入 mpv `http-header-fields`，确保 Range 重连与外挂字幕携带匹配的请求头。
  Future<void> _applyHttpHeaders(Map<String, String> headers) async {
    final np = _player.platform;
    if (np is! NativePlayer) return;
    await np.setProperty('http-header-fields', formatMpvHttpHeaders(headers));
  }

  @override
  Future<void> openMedia(
    String url, {
    Map<String, String> headers = const {},
    Duration? start,
    bool play = true,
  }) async {
    _mediaHeaders = Map.unmodifiable(headers);
    await _applyHttpHeaders(_mediaHeaders);
    await _player.open(
      Media(
        url,
        httpHeaders: _mediaHeaders,
        start: start,
      ),
      play: play,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _mediaHeaders = const {};
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setAudioTrack(AudioTrack track) => _player.setAudioTrack(track);

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) => _player.setSubtitleTrack(track);

  @override
  Future<void> setSubDelaySeconds(double seconds) async {
    final np = _player.platform;
    if (np is! NativePlayer) return;
    await np.setProperty('sub-delay', '$seconds');
  }

  @override
  Future<void> addExternalSub(
    String url,
    String flag,
    String title, {
    Map<String, String> headers = const {},
  }) async {
    final np = _player.platform;
    if (np is! NativePlayer) return;
    await runSubAddWithHeaderGuard(
      mediaHeaders: _mediaHeaders,
      subHeaders: headers,
      applyHeaders: _applyHttpHeaders,
      runSubAdd: () => np.command(['sub-add', url, flag, title]),
    );
  }

  @override
  Future<void> dispose() => _player.dispose();
}
