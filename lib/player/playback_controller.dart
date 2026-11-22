/// 播放器内核：media_kit 封装。
/// 职责：队列管理、直链获取、外挂字幕、轨道记忆、倍速、弱网重连、进度记录、会话持久化。
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/media_types.dart';
import '../core/models.dart';
import '../core/natural_sort.dart' show compareNatural;
import '../core/openlist_client.dart';
import '../core/queue_builder.dart';
import '../core/subtitle_match.dart';
import '../data/app_database.dart';
import '../data/settings_service.dart';

enum PlaybackStatus { idle, opening, buffering, playing, paused, error }

/// 播放器对外暴露的轨道描述（UI 用）
class TrackDesc {
  TrackDesc({required this.id, required this.title, required this.language, required this.isExternal});
  final String id;
  final String? title;
  final String? language;
  final bool isExternal;

  String get label => title ?? language ?? id;
}

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required OpenListClient Function() api,
    required AppDatabase db,
    required AppSettings Function() settings,
    Future<void> Function(double speed)? onPersistSpeed,
  })  : _api = api,
        _db = db,
        _settings = settings,
        _persistSpeedCb = onPersistSpeed {
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: _bufferBytes,
        osc: false,
        logLevel: MPVLogLevel.info, // TODO(debug): 临时调高日志排查缓冲问题，发布前改回 warn
      ),
    );
    _videoController = VideoController(_player, configuration: _videoConfig());
    _applyBufferProfile();
    _bindStreams();
    // TODO(debug): 临时 mpv 日志订阅，排查缓冲问题，发布前移除
    _player.stream.log.listen((e) => debugPrint('[mpv] ${e.level} ${e.prefix}: ${e.text}'));
    _speed = settings().globalSpeed;
    mode = settings().defaultPlayMode;
  }

  final OpenListClient Function() _api;
  final AppDatabase _db;
  final AppSettings Function() _settings;
  final Future<void> Function(double speed)? _persistSpeedCb;

  /// 平台相关的视频输出配置。
  ///
  /// Android：HyperOS/Android 16 + mt6878(Mali) 上 vo=gpu 不出帧——mpv 自建 EGL
  /// 上下文渲染到 SurfaceTexture 在该设备静默失败（真机实测：解码线程正常、VO
  /// 初始化成功、但 SurfaceFlinger 层永远黑；tombstone 亦为 mpv core SIGSEGV）。
  /// mediacodec_embed 让 MediaCodec 硬解直接渲染进 Surface，mpv 完全不碰 GL。
  ///
  /// iOS：不存在 mediacodec_embed，mpv 会直接 `Video output ... not found!` 并
  /// 判定 `No video or audio streams selected`，表现为永远黑屏 + 缓冲中。iOS 上
  /// 保持 media_kit 默认（videotoolbox 硬解 + gpu 输出）。
  static VideoControllerConfiguration _videoConfig() {
    if (Platform.isAndroid) {
      return const VideoControllerConfiguration(
        vo: 'mediacodec_embed',
        hwdec: 'mediacodec',
      );
    }
    return const VideoControllerConfiguration();
  }

  late final Player _player;
  late final VideoController _videoController;

  Player get player => _player;
  VideoController get videoController => _videoController;

  // ---------- 对外状态 ----------
  List<QueueItem> queue = [];
  int index = -1;
  PlaybackStatus status = PlaybackStatus.idle;
  String? errorText;
  PlayMode mode = PlayMode.sequentialLoop;
  double _speed = 1.0;
  double get speed => _speed;

  List<TrackDesc> audioTracks = [];
  List<TrackDesc> subtitleTracks = [];
  TrackDesc? currentAudio;
  TrackDesc? currentSubtitle;
  int subDelayMs = 0;

  /// 当前同目录可用外挂字幕（含未加载的），供手动选择
  List<String> availableExternalSubs = [];

  QueueItem? get current => (index >= 0 && index < queue.length) ? queue[index] : null;
  bool get hasQueue => queue.isNotEmpty;

  // ---------- 内部状态 ----------
  int _retryCount = 0;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  Timer? _progressTimer;
  int _openSerial = 0; // 防过期 open 结果
  TrackPrefs? _pendingPrefs;
  bool _audioPrefApplied = false;
  bool _subPrefApplied = false;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _tracksSub;
  StreamSubscription? _trackSub;
  bool _disposed = false;

  int get _bufferBytes => switch (_settings().bufferProfile) {
        BufferProfile.smooth => 64 * 1024 * 1024,
        BufferProfile.balanced => 160 * 1024 * 1024,
        BufferProfile.aggressive => 320 * 1024 * 1024,
      };

  int get _readaheadSecs => _settings().bufferProfile.seconds;

  // ---------- 生命周期 ----------

  void _bindStreams() {
    _playingSub = _player.stream.playing.listen((playing) {
      if (playing) {
        _retryCount = 0; // 恢复成功，重置重试计数
        if (status == PlaybackStatus.buffering ||
            status == PlaybackStatus.opening ||
            status == PlaybackStatus.paused) {
          status = PlaybackStatus.playing;
        }
      } else {
        if (status == PlaybackStatus.playing) status = PlaybackStatus.paused;
        _recordProgressNow();
      }
      _notify();
    });
    _bufferingSub = _player.stream.buffering.listen((b) {
      if (b) {
        if (status == PlaybackStatus.playing || status == PlaybackStatus.paused) {
          status = PlaybackStatus.buffering; // 弱网：无限等待，绝不自动跳曲
        }
      } else {
        if (status == PlaybackStatus.buffering && _player.state.playing) {
          status = PlaybackStatus.playing;
        }
      }
      _notify();
    });
    _completedSub = _player.stream.completed.listen((completed) {
      if (!completed) return;
      _onCompleted();
    });
    _errorSub = _player.stream.error.listen((e) {
      _onPlayerError(e);
    });
    _positionSub = _player.stream.position.listen((p) {
      _lastPosition = p;
    });
    _durationSub = _player.stream.duration.listen((d) {
      _lastDuration = d;
      _maybeApplyTrackPrefs();
    });
    _tracksSub = _player.stream.tracks.listen((tracks) {
      _updateTracks(tracks);
      _maybeApplyTrackPrefs();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _progressTimer?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _tracksSub?.cancel();
    _trackSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------- 缓冲档位 ----------

  static const _deviceChannel = MethodChannel('olp/device');
  bool? _isSimulatorCache;

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

  void _applyBufferProfile() {
    final np = _player.platform;
    if (np is! NativePlayer) return;
    np.setProperty('demuxer-readahead-secs', '$_readaheadSecs');
    np.setProperty('demuxer-max-bytes', '$_bufferBytes');
    if (Platform.isAndroid) {
      // media_kit 默认 ao=opensles 在部分 Android 16/新设备上 SIGSEGV（mpv core 线程崩溃，
      // 2026-11-20 真机实测），改用 Android 原生 AudioTrack 输出
      np.setProperty('ao', 'audiotrack');
    }
    // iOS 模拟器上 libmpv 音频设备无法初始化（media_kit 已知限制，真机正常）：
    // ao=null 允许无声播放；模拟器磁盘缓存目录也建不了，一并关闭
    _isSimulator().then((sim) {
      if (!sim || _disposed) return;
      np.setProperty('ao', 'null');
      np.setProperty('cache-on-disk', 'no');
    });
  }

  /// 设置变更后调用
  void onSettingsChanged() {
    _applyBufferProfile();
    if (_settings().defaultPlayMode != mode && queue.isEmpty) {
      mode = _settings().defaultPlayMode;
    }
    _notify();
  }

  // ---------- 队列操作 ----------

  /// 点击网盘文件：同目录音视频整体替换队列，从所点文件开播（有历史则续播）
  Future<void> playFromDirectory(String dirPath, List<FsEntry> entries, String tappedName) async {
    final items = buildQueueFromDir(dirPath, entries, _settings().sortMode);
    if (items.isEmpty) return;
    final i = items.indexWhere((e) => e.name == tappedName);
    await replaceQueue(items, i < 0 ? 0 : i);
  }

  /// 播放手动播单：复制为"正在播放"队列
  Future<void> playQueue(List<QueueItem> items, int startIndex) =>
      replaceQueue(List.of(items), startIndex);

  Future<void> replaceQueue(List<QueueItem> items, int startIndex) async {
    final wasPlayingItem = current;
    if (wasPlayingItem != null) {
      _recordProgressNow();
    }
    queue = items;
    index = startIndex.clamp(0, items.length - 1);
    _notify();
    await _openCurrent();
  }

  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= queue.length) return;
    _recordProgressNow();
    index = i;
    _notify();
    await _openCurrent();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    _recordProgressNow();
    index = _nextIndex();
    _notify();
    await _openCurrent();
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    _recordProgressNow();
    index = _prevIndex();
    _notify();
    await _openCurrent();
  }

  int _nextIndex() {
    if (queue.isEmpty) return -1;
    switch (mode) {
      case PlayMode.repeatOne:
        return index; // 单曲循环：自动播放下一曲时不切歌
      case PlayMode.shuffle:
        if (queue.length == 1) return 0;
        var n = index;
        while (n == index) {
          n = _random.nextInt(queue.length);
        }
        return n;
      case PlayMode.sequentialLoop:
        return (index + 1) % queue.length;
    }
  }

  int _prevIndex() {
    if (queue.isEmpty) return -1;
    switch (mode) {
      case PlayMode.shuffle:
        if (queue.length == 1) return 0;
        var n = index;
        while (n == index) {
          n = _random.nextInt(queue.length);
        }
        return n;
      default:
        return (index - 1 + queue.length) % queue.length;
    }
  }

  final _random = Random();

  void cycleMode() {
    mode = switch (mode) {
      PlayMode.sequentialLoop => PlayMode.repeatOne,
      PlayMode.repeatOne => PlayMode.shuffle,
      PlayMode.shuffle => PlayMode.sequentialLoop,
    };
    _notify();
  }

  // ---------- 打开当前曲目 ----------

  Future<void> _openCurrent({bool isRetry = false, Duration? forceStart}) async {
    final item = current;
    if (item == null) return;
    final serial = ++_openSerial;
    _lastPosition = isRetry ? _retryPosition : Duration.zero;
    _lastDuration = Duration.zero;
    _retryCount = isRetry ? _retryCount : 0;
    _pendingPrefs = await _db.getTrackPrefs(item.path);
    _audioPrefApplied = false;
    _subPrefApplied = false;
    subDelayMs = _pendingPrefs?.subDelayMs ?? 0;
    audioTracks = [];
    subtitleTracks = [];
    availableExternalSubs = [];
    currentAudio = null;
    currentSubtitle = null;
    errorText = null;
    if (!isRetry) status = PlaybackStatus.opening;
    _notify();

    // 起始位置：重试→最近位置（绝不回片头）；会话恢复→forceStart；
    // 否则读历史进度续播（≥95% 视为看完，从头播）
    Duration? start;
    if (isRetry) {
      start = _retryPosition;
    } else if (forceStart != null) {
      start = forceStart;
    } else {
      final prog = await _db.getProgress(item.path);
      if (prog != null) {
        final pos = Duration(milliseconds: prog.positionMs);
        final dur = Duration(milliseconds: prog.durationMs);
        if (!ProgressRules.isFinished(pos, dur)) start = pos;
      }
    }

    try {
      final link = await _api().getFileLink(item.path);
      if (serial != _openSerial || _disposed) return;
      debugPrint('[OLP] open: ${link.url}');
      debugPrint('[OLP] headers: ${link.headers} start: $start');
      await _player.open(
        Media(
          link.url,
          httpHeaders: link.headers,
          start: start,
        ),
        play: true,
      );
      if (serial != _openSerial || _disposed) return;
      await _player.setRate(_speed);
      await _applySubDelay();
      // TODO(debug): 纹理绑定诊断，发布前移除
      Future.delayed(const Duration(seconds: 2), () {
        debugPrint('[OLP] textureId=${_videoController.id.value}');
      });
      unawaited(_attachExternalSubs(serial, item)); // 不阻塞开播
      _startProgressTimer();
      await _db.touchHistory(item);
      unawaited(_saveSessionNow());
    } catch (e) {
      if (serial != _openSerial || _disposed) return;
      // 打开失败（直链获取失败等）走同一重试策略
      _onOpenFailure(e);
    }
  }

  Duration _retryPosition = Duration.zero;

  void _onOpenFailure(Object e) {
    _retryPosition = _lastPosition;
    _onPlayerError('打开失败: $e');
  }

  Future<void> _attachExternalSubs(int serial, QueueItem item) async {
    if (!item.isVideo) return; // 音频不挂字幕
    try {
      final siblings = await _api().listDir(item.parent);
      if (serial != _openSerial || _disposed) return;
      final names = siblings.where((e) => !e.isDirectory).map((e) => e.name).toList();
      final matches = matchSubtitleFiles(item.name, names);
      availableExternalSubs = names.where(isSubtitleFile).toList()..sort(compareNatural);
      _notify();
      if (matches.isEmpty) return;
      final np = _player.platform;
      if (np is! NativePlayer) return;
      final hasEmbedded = _player.state.tracks.subtitle
          .any((t) => t.id != 'auto' && t.id != 'no' && !t.uri);
      final noSubPref = _pendingPrefs?.subtitleTrack == null;
      for (var i = 0; i < matches.length; i++) {
        final subName = matches[i];
        final link = await _api().getFileLink(joinPath(item.parent, subName));
        if (serial != _openSerial || _disposed) return;
        // 第一个匹配：无内置字幕且无记忆选择时直接选中
        final flag = (i == 0 && !hasEmbedded && noSubPref && !_subPrefApplied) ? 'select' : 'auto';
        await np.command(['sub-add', link.url, flag, subName]);
      }
      _maybeApplyTrackPrefs();
    } catch (_) {
      // 外挂字幕失败不影响播放
    }
  }

  // ---------- 轨道 ----------

  void _updateTracks(Tracks tracks) {
    audioTracks = tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .map((t) => TrackDesc(
              id: t.id,
              title: t.title,
              language: t.language,
              isExternal: false,
            ))
        .toList();
    subtitleTracks = tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .map((t) => TrackDesc(
              id: t.id,
              title: t.title,
              language: t.language,
              isExternal: t.uri,
            ))
        .toList();
    _syncCurrentTracks();
    _notify();
  }

  void _syncCurrentTracks() {
    final sel = _player.state.track;
    currentAudio = audioTracks.where((t) => t.id == sel.audio.id).firstOrNull;
    currentSubtitle = subtitleTracks.where((t) => t.id == sel.subtitle.id).firstOrNull;
  }

  void _maybeApplyTrackPrefs() {
    final item = current;
    final prefs = _pendingPrefs;
    if (item == null || prefs == null) return;
    final tracks = _player.state.tracks;
    if (!_audioPrefApplied && prefs.audioTrack != null) {
      final match = tracks.audio
          .where((x) => (x.title ?? x.language ?? x.id) == prefs.audioTrack)
          .firstOrNull;
      if (match != null) {
        _audioPrefApplied = true;
        _player.setAudioTrack(match);
      }
    }
    if (!_subPrefApplied && prefs.subtitleTrack != null) {
      final match = tracks.subtitle
          .where((x) => (x.title ?? x.language ?? x.id) == prefs.subtitleTrack)
          .firstOrNull;
      if (match != null) {
        _subPrefApplied = true;
        _player.setSubtitleTrack(match);
      }
    }
    // 无任何字幕偏好且无内置字幕时，外挂加载完后选第一个（_attachExternalSubs 已处理 select）
    if (prefs.audioTrack == null) _audioPrefApplied = true;
    if (prefs.subtitleTrack == null) _subPrefApplied = true;
  }

  Future<void> selectAudioTrack(TrackDesc t) async {
    final match = _player.state.tracks.audio.where((x) => x.id == t.id).firstOrNull;
    if (match == null) return;
    await _player.setAudioTrack(match);
    final item = current;
    if (item != null) {
      await _db.saveTrackPrefs(item.path, audioTrack: _trackKeyOfDesc(t));
    }
    _notify();
  }

  Future<void> selectSubtitleTrack(TrackDesc? t) async {
    if (t == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      currentSubtitle = null;
    } else {
      final match = _player.state.tracks.subtitle.where((x) => x.id == t.id).firstOrNull;
      if (match == null) return;
      await _player.setSubtitleTrack(match);
    }
    final item = current;
    if (item != null) {
      await _db.saveTrackPrefs(item.path, subtitleTrack: t == null ? '' : _trackKeyOfDesc(t));
    }
    _notify();
  }

  String _trackKeyOfDesc(TrackDesc t) => t.title ?? t.language ?? t.id;

  /// 手动加载同目录某字幕文件（选中并记忆）
  Future<void> addExternalSubtitle(String fileName) async {
    final item = current;
    if (item == null) return;
    final link = await _api().getFileLink(joinPath(item.parent, fileName));
    await _player.setSubtitleTrack(SubtitleTrack.uri(link.url, title: fileName));
    await _db.saveTrackPrefs(item.path, subtitleTrack: fileName);
    _notify();
  }

  // ---------- 字幕延迟 ----------

  Future<void> adjustSubDelay(int deltaMs) async {
    subDelayMs += deltaMs;
    await _applySubDelay();
    final item = current;
    if (item != null) await _db.saveTrackPrefs(item.path, subDelayMs: subDelayMs);
    _notify();
  }

  Future<void> _applySubDelay() async {
    final np = _player.platform;
    if (np is! NativePlayer) return;
    await np.setProperty('sub-delay', '${subDelayMs / 1000.0}');
  }

  // ---------- 倍速 ----------

  Future<void> setSpeed(double s) async {
    _speed = s;
    await _player.setRate(s);
    _notify();
  }

  /// 长按临时 3x：松开后恢复
  Future<void> setTemporarySpeed(double s) async {
    await _player.setRate(s);
    _notify();
  }

  Future<void> restoreSpeed() async {
    await _player.setRate(_speed);
    _notify();
  }

  Future<void> persistSpeed(double s) async {
    _speed = s;
    await _player.setRate(s);
    await _persistSpeedCb?.call(s);
    _notify();
  }

  // ---------- 播放控制 ----------

  Future<void> togglePlay() async {
    if (status == PlaybackStatus.error) {
      await retryNow();
      return;
    }
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _lastPosition = position;
    unawaited(_saveSessionNow());
  }

  Future<void> seekRelative(int seconds) async {
    final target = _lastPosition + Duration(seconds: seconds);
    final dur = _lastDuration;
    late Duration clamped;
    if (target < Duration.zero) {
      clamped = Duration.zero;
    } else if (dur > Duration.zero && target > dur - const Duration(milliseconds: 200)) {
      clamped = dur - const Duration(milliseconds: 200);
    } else {
      clamped = target;
    }
    await seek(clamped);
  }

  Future<void> setVolume(double v) async {
    await _player.setVolume(v.clamp(0, 100));
    _notify();
  }

  double get volume => _player.state.volume;

  // ---------- 完成与错误 ----------

  Future<void> _onCompleted() async {
    final item = current;
    if (item == null) return;
    // 看完：清进度（下次从头）+ 记历史
    await _db.clearProgress(item.path);
    await _db.touchHistory(item);
    if (mode == PlayMode.repeatOne) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    if (queue.length > 1 || (index < queue.length - 1)) {
      final ni = _nextIndex();
      if (ni == index) return;
      index = ni;
      _notify();
      await _openCurrent();
    } else if (queue.length == 1) {
      // 单曲队列播完：停在开头
      await _player.seek(Duration.zero);
      await _player.pause();
    }
  }

  Future<void> _onPlayerError(String e) async {
    if (current == null || _disposed) return;
    if (status != PlaybackStatus.playing &&
        status != PlaybackStatus.buffering &&
        status != PlaybackStatus.paused &&
        status != PlaybackStatus.opening) {
      return;
    }
    _retryPosition = _lastPosition;
    if (_retryCount < 2) {
      _retryCount++;
      status = PlaybackStatus.buffering; // UI 显示"重连中"
      errorText = null;
      _notify();
      // 从最近位置重取直链断点重连
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (_disposed) return;
      await _openCurrent(isRetry: true);
    } else {
      status = PlaybackStatus.error;
      errorText = '播放失败：$e';
      _notify();
    }
  }

  /// 用户手动重试（错误页按钮）
  Future<void> retryNow() async {
    _retryCount = 0;
    _retryPosition = _lastPosition;
    await _openCurrent(isRetry: true);
  }

  /// 用户手动跳过（错误页按钮）：跳下一曲
  Future<void> skipAfterError() async {
    _retryCount = 0;
    if (queue.length <= 1) {
      await stop();
      return;
    }
    index = _nextIndex();
    _notify();
    await _openCurrent();
  }

  Future<void> stop() async {
    _openSerial++;
    _progressTimer?.cancel();
    await _recordProgressNow();
    await _player.stop();
    status = PlaybackStatus.idle;
    _notify();
  }

  // ---------- 进度记录 ----------

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _recordProgressNow());
  }

  Future<void> _recordProgressNow() async {
    final item = current;
    if (item == null) return;
    final pos = _lastPosition;
    final dur = _lastDuration;
    if (!ProgressRules.shouldRecord(dur)) return;
    if (ProgressRules.isFinished(pos, dur)) {
      await _db.clearProgress(item.path);
    } else if (pos > Duration.zero) {
      await _db.upsertProgress(item.path, pos, dur);
    }
    unawaited(_saveSessionNow());
  }

  Future<void> _saveSessionNow() async {
    final item = current;
    if (item == null) return;
    await _db.saveSession(queue, index, _lastPosition);
  }

  // ---------- 会话恢复 ----------

  /// 启动时恢复会话：装载队列但不开播，首页"继续播放"卡片触发 resumeSession
  Future<void> restoreSession() async {
    final s = await _db.loadSession();
    if (s == null) return;
    queue = s.queue;
    index = s.index;
    _restoredPosition = s.position;
    _lastPosition = s.position;
    _notify();
  }

  Duration? _restoredPosition;

  /// 继续/开始播放恢复的会话
  Future<void> resumeSession() async {
    final item = current;
    if (item == null) return;
    final pos = _restoredPosition;
    _restoredPosition = null;
    if (pos != null && pos > Duration.zero && status == PlaybackStatus.idle) {
      final prog = await _db.getProgress(item.path);
      final durMs = prog?.durationMs ?? 0;
      if (durMs > 0 && pos.inMilliseconds / durMs < 0.95) {
        await _openCurrent(forceStart: pos);
        return;
      }
    }
    await _openCurrent();
  }

  /// App 退到后台/被杀前的落盘钩子
  Future<void> onAppPaused() async {
    await _recordProgressNow();
  }
}
