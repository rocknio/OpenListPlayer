/// 播放器内核：media_kit 封装。
/// 职责：队列管理、直链获取、外挂字幕、轨道记忆、倍速、弱网重连、进度记录、会话持久化。
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
import 'player_backend.dart';

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
    PlayerBackend? backend,
  })  : _api = api,
        _db = db,
        _settings = settings,
        _persistSpeedCb = onPersistSpeed {
    _backend = backend ?? MediaKitBackend(initialBufferBytes: _bufferBytes);
    _bufferProfileInit = _applyBufferProfile();
    _bindStreams();
    _speed = settings().globalSpeed;
    mode = settings().defaultPlayMode;
  }

  final OpenListClient Function() _api;
  final AppDatabase _db;
  final AppSettings Function() _settings;
  final Future<void> Function(double speed)? _persistSpeedCb;

  late final PlayerBackend _backend;
  Future<void>? _bufferProfileInit;

  Player get player => _backend.rawPlayer!;
  VideoController get videoController => _backend.rawVideoController!;

  // ---------- 播放引擎流与瞬时状态转发（兼容真机与单测） ----------
  Stream<Duration> get positionStream => _backend.positionStream;
  Stream<Duration> get durationStream => _backend.durationStream;
  Stream<bool> get playingStream => _backend.playingStream;
  Stream<bool> get bufferingStream => _backend.bufferingStream;
  Stream<Duration> get bufferStream => _backend.bufferStream;

  bool get isPlaying => _backend.isPlaying;
  Duration get currentPosition => _lastPosition;
  Duration get currentDuration => _lastDuration;
  Duration get currentBuffer => _backend.currentBuffer;

  // ---------- 对外状态 ----------
  List<QueueItem> queue = [];
  int index = -1;
  PlaybackStatus status = PlaybackStatus.idle;
  String? errorText;
  PlayMode mode = PlayMode.sequentialLoop;
  double _speed = 1.0;
  double? _tempSpeed;
  double get speed => _speed;
  double get effectiveSpeed => _tempSpeed ?? _speed;

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

  /// 当前队列来源的播单 id：播单播放时为对应 id，目录/会话播放为 null。
  /// 用于把进度写入对应播单，实现"每个播单独立进度"。
  int? _sourcePlaylistId;

  int _retryCount = 0;
  Timer? _retryTimer;
  bool _handlingError = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  Timer? _progressTimer;
  int _openSerial = 0; // 当前目标打开序号（防过期异步操作）
  int _loadedSerial = -1; // 已调用底层 openMedia 的序号（过滤旧曲目残余流事件）
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

  bool get _isStreamActive => _loadedSerial == _openSerial && !_disposed;

  // ---------- 生命周期 ----------

  void _bindStreams() {
    _playingSub = _backend.playingStream.listen((playing) {
      if (!_isStreamActive) return;
      if (playing) {
        _retryCount = 0; // 恢复成功，重置重试计数
        _handlingError = false;
        if (status == PlaybackStatus.buffering ||
            status == PlaybackStatus.opening ||
            status == PlaybackStatus.paused) {
          status = PlaybackStatus.playing;
        }
      } else {
        if (status == PlaybackStatus.playing) {
          status = PlaybackStatus.paused;
          unawaited(_recordProgressNow());
        }
      }
      _notify();
    });
    _bufferingSub = _backend.bufferingStream.listen((b) {
      if (!_isStreamActive) return;
      if (b) {
        if (status == PlaybackStatus.playing || status == PlaybackStatus.paused) {
          status = PlaybackStatus.buffering; // 弱网：无限等待，绝不自动跳曲
        }
      } else {
        if (status == PlaybackStatus.buffering && _backend.isPlaying) {
          status = PlaybackStatus.playing;
        }
      }
      _notify();
    });
    _completedSub = _backend.completedStream.listen((completed) {
      if (!completed || !_isStreamActive) return;
      unawaited(_onCompleted());
    });
    _errorSub = _backend.errorStream.listen((e) {
      if (!_isStreamActive) return;
      unawaited(_onPlayerError(e));
    });
    _positionSub = _backend.positionStream.listen((p) {
      if (!_isStreamActive) return;
      _lastPosition = p;
    });
    _durationSub = _backend.durationStream.listen((d) {
      if (!_isStreamActive) return;
      _lastDuration = d;
      _maybeApplyTrackPrefs();
      _notify();
    });
    _tracksSub = _backend.tracksStream.listen((tracks) {
      if (!_isStreamActive) return;
      _updateTracks(tracks);
      _maybeApplyTrackPrefs();
    });
    _trackSub = _backend.trackStream.listen((_) {
      if (!_isStreamActive) return;
      _syncCurrentTracks();
      _notify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _progressTimer?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _tracksSub?.cancel();
    _trackSub?.cancel();
    unawaited(_backend.dispose());
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------- 缓冲档位与站点变更 ----------

  Future<void> _applyBufferProfile() async {
    try {
      await _backend.applyBufferProfile(
        readaheadSecs: _readaheadSecs,
        bufferBytes: _bufferBytes,
      );
    } catch (e) {
      debugPrint('[OLP] applyBufferProfile failed: $e');
    }
  }

  /// 设置变更后调用
  void onSettingsChanged() {
    _bufferProfileInit = _applyBufferProfile();
    if (_settings().defaultPlayMode != mode && queue.isEmpty) {
      mode = _settings().defaultPlayMode;
    }
    _notify();
  }

  /// 站点切换或清空时停止旧站点的播放队列与会话
  Future<void> onSiteChanged() async {
    _openSerial++;
    _loadedSerial = -1;
    _retryTimer?.cancel();
    _progressTimer?.cancel();
    _restoredPosition = null;
    _restoredDuration = null;
    await _backend.stop();
    queue = [];
    index = -1;
    _sourcePlaylistId = null;
    _lastPosition = Duration.zero;
    _lastDuration = Duration.zero;
    errorText = null;
    status = PlaybackStatus.idle;
    await _db.clearSession();
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

  /// 播放手动播单：复制为"正在播放"队列，并记录来源播单用于独立进度
  Future<void> playQueue(List<QueueItem> items, int startIndex, {int? playlistId}) =>
      replaceQueue(List.of(items), startIndex, sourcePlaylistId: playlistId);

  Future<void> replaceQueue(List<QueueItem> items, int startIndex, {int? sourcePlaylistId}) async {
    if (items.isEmpty) {
      await stop();
      queue = [];
      index = -1;
      _sourcePlaylistId = null;
      _notify();
      return;
    }
    // 先停掉定时器并等待旧队列进度落盘（不写旧会话），避免读写竞态与新会话被覆盖
    _progressTimer?.cancel();
    _retryTimer?.cancel();
    await _recordProgressNow(saveSession: false);
    _restoredPosition = null;
    _restoredDuration = null;
    _sourcePlaylistId = sourcePlaylistId;
    queue = items;
    index = startIndex.clamp(0, items.length - 1);
    _notify();
    await _openCurrent();
  }

  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= queue.length) return;
    _progressTimer?.cancel();
    _retryTimer?.cancel();
    await _recordProgressNow(saveSession: false);
    _restoredPosition = null;
    _restoredDuration = null;
    index = i;
    _notify();
    await _openCurrent();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    _progressTimer?.cancel();
    _retryTimer?.cancel();
    await _recordProgressNow(saveSession: false);
    _restoredPosition = null;
    _restoredDuration = null;
    index = _nextIndex();
    _notify();
    await _openCurrent();
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    _progressTimer?.cancel();
    _retryTimer?.cancel();
    await _recordProgressNow(saveSession: false);
    _restoredPosition = null;
    _restoredDuration = null;
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
    if (item == null || _disposed) return;
    final serial = ++_openSerial;
    _loadedSerial = -1; // 屏蔽旧媒体的残余流事件，直到新媒体调用 openMedia
    _retryTimer?.cancel();
    _progressTimer?.cancel();
    _handlingError = false;
    _tempSpeed = null;
    _lastPosition = isRetry ? _retryPosition : Duration.zero;
    _lastDuration = Duration.zero;
    _retryCount = isRetry ? _retryCount : 0;
    audioTracks = [];
    subtitleTracks = [];
    availableExternalSubs = [];
    currentAudio = null;
    currentSubtitle = null;
    errorText = null;
    if (!isRetry) status = PlaybackStatus.opening;
    _notify();

    // 先暂停旧媒体流，避免异步查库与请求直链期间旧流继续推进或触发 completed
    try {
      await _backend.pause();
    } catch (_) {}
    if (serial != _openSerial || _disposed) return;

    await (_bufferProfileInit ?? Future<void>.value());
    if (serial != _openSerial || _disposed) return;

    _pendingPrefs = await _db.getTrackPrefs(item.path);
    if (serial != _openSerial || _disposed) return;
    _audioPrefApplied = false;
    _subPrefApplied = false;
    subDelayMs = _pendingPrefs?.subDelayMs ?? 0;

    // 校验来源播单是否仍存在：若已被删除则回退到全局进度模式
    var playlistId = _sourcePlaylistId;
    if (playlistId != null && !await _db.playlistExists(playlistId)) {
      _sourcePlaylistId = null;
      playlistId = null;
    }
    if (serial != _openSerial || _disposed) return;

    // 起始位置：重试→最近位置（绝不回片头）；会话恢复→forceStart；
    // 否则读进度续播（播单播放读该播单的独立进度，其它读全局；已看完/≥95% 视为看完从头播）
    Duration? start;
    if (isRetry) {
      start = _retryPosition > Duration.zero ? _retryPosition : null;
    } else if (forceStart != null) {
      start = forceStart;
    } else {
      if (playlistId != null) {
        final p = await _db.getPlaylistProgress(playlistId, item.path);
        if (p != null) {
          final pos = Duration(milliseconds: p.positionMs);
          final dur = Duration(milliseconds: p.durationMs);
          // 已看完时从头播（start = null），不提前删行，以免打开失败或误触退出丢失"已看完"标记
          if (!p.finished && !ProgressRules.isFinished(pos, dur) && pos > Duration.zero) {
            start = pos;
          }
        }
      } else {
        final p = await _db.getProgress(item.path);
        if (p != null) {
          final pos = Duration(milliseconds: p.positionMs);
          final dur = Duration(milliseconds: p.durationMs);
          if (!ProgressRules.isFinished(pos, dur) && pos > Duration.zero) {
            start = pos;
          }
        }
      }
    }

    try {
      if (serial != _openSerial || _disposed) return;
      // 播单来源：更新续播指针（"本播单上次播到这个文件"），详情页"继续播放"据此定位到具体条目
      if (playlistId != null) {
        await _writePlaylist(() => _db.setPlaylistLastPlayed(playlistId!, item.path));
        if (serial != _openSerial || _disposed) return;
      }
      final link = await _api().getFileLink(item.path);
      if (serial != _openSerial || _disposed) return;
      if (kDebugMode) {
        final safeUri = Uri.tryParse(link.url);
        final hostInfo = safeUri != null ? '${safeUri.scheme}://${safeUri.authority}${safeUri.path}' : item.name;
        debugPrint('[OLP] open: $hostInfo headerKeys=${link.headers.keys.toList()} start=$start');
      }
      if (start != null && start > Duration.zero) {
        _lastPosition = start;
      }
      _loadedSerial = serial;
      await _backend.openMedia(
        link.url,
        headers: link.headers,
        start: start,
        play: true,
      );
      if (serial != _openSerial || _disposed) return;
      await _backend.setRate(_speed);
      await _applySubDelay();
      unawaited(_attachExternalSubs(serial, item)); // 不阻塞开播
      _startProgressTimer();
      await _db.touchHistory(item);
      await _saveSessionNow();
    } catch (e) {
      if (serial != _openSerial || _disposed) return;
      // 打开失败（直链获取失败等）走同一重试策略
      _onOpenFailure(serial, e);
    }
  }

  Duration _retryPosition = Duration.zero;

  void _onOpenFailure(int serial, Object e) {
    _retryPosition = _lastPosition;
    unawaited(_onPlayerError('打开失败: $e', serial: serial));
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
      final hasEmbedded = _backend.currentTracks.subtitle
          .any((t) => t.id != 'auto' && t.id != 'no' && !t.uri);
      final noSubPref = _pendingPrefs?.subtitleTrack == null;
      for (var i = 0; i < matches.length; i++) {
        final subName = matches[i];
        final link = await _api().getFileLink(joinPath(item.parent, subName));
        if (serial != _openSerial || _disposed) return;
        // 第一个匹配：无内置字幕且无记忆选择时直接选中
        final flag = (i == 0 && !hasEmbedded && noSubPref && !_subPrefApplied) ? 'select' : 'auto';
        await _backend.addExternalSub(link.url, flag, subName, headers: link.headers);
      }
      if (serial != _openSerial || _disposed) return;
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
    final sel = _backend.currentTrack;
    currentAudio = audioTracks.where((t) => t.id == sel.audio.id).firstOrNull;
    currentSubtitle = subtitleTracks.where((t) => t.id == sel.subtitle.id).firstOrNull ??
        (sel.subtitle.title != null
            ? subtitleTracks.where((t) => t.title == sel.subtitle.title).firstOrNull
            : null);
  }

  void _maybeApplyTrackPrefs() {
    final item = current;
    final prefs = _pendingPrefs;
    if (item == null || prefs == null) return;
    final tracks = _backend.currentTracks;
    if (!_audioPrefApplied && prefs.audioTrack != null) {
      final match = tracks.audio
          .where((x) => (x.title ?? x.language ?? x.id) == prefs.audioTrack)
          .firstOrNull;
      if (match != null) {
        _audioPrefApplied = true;
        unawaited(_backend.setAudioTrack(match));
      }
    }
    if (!_subPrefApplied && prefs.subtitleTrack != null) {
      if (prefs.subtitleTrack!.isEmpty) {
        // 用户上次显式关闭了字幕：强制关闭以压制内置默认字幕
        _subPrefApplied = true;
        currentSubtitle = null;
        unawaited(_backend.setSubtitleTrack(SubtitleTrack.no()));
      } else {
        final match = tracks.subtitle
            .where((x) => (x.title ?? x.language ?? x.id) == prefs.subtitleTrack)
            .firstOrNull;
        if (match != null) {
          _subPrefApplied = true;
          unawaited(_backend.setSubtitleTrack(match));
        }
      }
    }
    // 无任何字幕偏好且无内置字幕时，外挂加载完后选第一个（_attachExternalSubs 已处理 select）
    if (prefs.audioTrack == null) _audioPrefApplied = true;
    if (prefs.subtitleTrack == null) _subPrefApplied = true;
  }

  Future<void> selectAudioTrack(TrackDesc t) async {
    final match = _backend.currentTracks.audio.where((x) => x.id == t.id).firstOrNull;
    if (match == null) return;
    await _backend.setAudioTrack(match);
    currentAudio = audioTracks.where((x) => x.id == t.id).firstOrNull ?? t;
    final item = current;
    if (item != null) {
      await _db.saveTrackPrefs(item.path, audioTrack: _trackKeyOfDesc(t));
    }
    _notify();
  }

  Future<void> selectSubtitleTrack(TrackDesc? t) async {
    if (t == null) {
      await _backend.setSubtitleTrack(SubtitleTrack.no());
      currentSubtitle = null;
    } else {
      final match = _backend.currentTracks.subtitle.where((x) => x.id == t.id).firstOrNull;
      if (match == null) return;
      await _backend.setSubtitleTrack(match);
      currentSubtitle = subtitleTracks.where((x) => x.id == t.id).firstOrNull ?? t;
    }
    final item = current;
    if (item != null) {
      await _db.saveTrackPrefs(item.path, subtitleTrack: t == null ? '' : _trackKeyOfDesc(t));
    }
    _notify();
  }

  String _trackKeyOfDesc(TrackDesc t) => t.title ?? t.language ?? t.id;

  /// 手动加载同目录某字幕文件（携带直链 headers 选中并记忆）
  Future<void> addExternalSubtitle(String fileName) async {
    final item = current;
    if (item == null) return;
    final serial = _openSerial;
    final link = await _api().getFileLink(joinPath(item.parent, fileName));
    if (serial != _openSerial || _disposed || current?.path != item.path) return;
    await _backend.addExternalSub(link.url, 'select', fileName, headers: link.headers);
    await _db.saveTrackPrefs(item.path, subtitleTrack: fileName);
    // 先乐观展示选中态，待 mpv 解析完 track-list / sid 后由 _updateTracks 自动对齐真实轨道 id
    currentSubtitle = subtitleTracks.where((t) => t.title == fileName).firstOrNull ??
        TrackDesc(id: link.url, title: fileName, language: null, isExternal: true);
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

  Future<void> _applySubDelay() => _backend.setSubDelaySeconds(subDelayMs / 1000.0);

  // ---------- 倍速 ----------

  Future<void> setSpeed(double s) async {
    _speed = s;
    _tempSpeed = null;
    await _backend.setRate(s);
    _notify();
  }

  /// 长按临时 3x：松开后恢复
  Future<void> setTemporarySpeed(double s) async {
    _tempSpeed = s;
    await _backend.setRate(s);
    _notify();
  }

  Future<void> restoreSpeed() async {
    if (_tempSpeed == null) return;
    _tempSpeed = null;
    await _backend.setRate(_speed);
    _notify();
  }

  Future<void> persistSpeed(double s) async {
    _speed = s;
    _tempSpeed = null;
    await _backend.setRate(s);
    await _persistSpeedCb?.call(s);
    _notify();
  }

  // ---------- 播放控制 ----------

  Future<void> togglePlay() async {
    if (status == PlaybackStatus.error) {
      await retryNow();
      return;
    }
    if (status == PlaybackStatus.idle && current != null) {
      await resumeSession();
      return;
    }
    if (_backend.isPlaying) {
      await _backend.pause();
    } else {
      await _backend.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _backend.seek(position);
    _lastPosition = position;
    unawaited(_saveSessionNow());
    _notify();
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
    await _backend.setVolume(v.clamp(0, 100));
    _notify();
  }

  double get volume => _backend.currentVolume;

  // ---------- 完成与错误 ----------

  Future<void> _onCompleted() async {
    final serial = _openSerial;
    final item = current;
    if (item == null || serial != _loadedSerial) return;
    _progressTimer?.cancel();
    // 看完：清全局进度（下次从头）+ 播单标已看完 + 记历史
    await _db.clearProgress(item.path);
    final playlistId = _sourcePlaylistId;
    if (playlistId != null && _lastDuration > Duration.zero) {
      await _writePlaylist(() => _db.markPlaylistProgressFinished(playlistId, item.path, _lastDuration));
    }
    await _db.touchHistory(item);
    if (serial != _openSerial || _disposed) return;
    if (mode == PlayMode.repeatOne) {
      _lastPosition = Duration.zero;
      await _backend.seek(Duration.zero);
      await _backend.play();
      _startProgressTimer();
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
      _lastPosition = Duration.zero;
      await _backend.seek(Duration.zero);
      await _backend.pause();
      unawaited(_saveSessionNow());
    }
  }

  Future<void> _onPlayerError(String e, {int? serial}) async {
    final activeSerial = serial ?? _openSerial;
    if (current == null || _disposed || activeSerial != _openSerial) return;
    if (_handlingError) return; // 避免 open 抛错与 stream.error 双通道重复计数
    if (status != PlaybackStatus.playing &&
        status != PlaybackStatus.buffering &&
        status != PlaybackStatus.paused &&
        status != PlaybackStatus.opening) {
      return;
    }
    _handlingError = true;
    _retryPosition = _lastPosition;
    if (_retryCount < 2) {
      _retryCount++;
      status = PlaybackStatus.buffering; // UI 显示"重连中"
      errorText = null;
      _notify();
      // 从最近位置重取直链断点重连（可取消 Timer，切歌/停止/销毁时立即终止）
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 800), () {
        _handlingError = false;
        if (_disposed || activeSerial != _openSerial || status == PlaybackStatus.idle) return;
        unawaited(_openCurrent(isRetry: true));
      });
    } else {
      _handlingError = false;
      _progressTimer?.cancel();
      status = PlaybackStatus.error;
      errorText = '播放失败：$e';
      _notify();
    }
  }

  /// 用户手动重试（错误页按钮）
  Future<void> retryNow() async {
    _retryTimer?.cancel();
    _handlingError = false;
    _retryCount = 0;
    _retryPosition = _lastPosition;
    await _openCurrent(isRetry: true);
  }

  /// 用户手动跳过（错误页按钮）：跳下一曲
  Future<void> skipAfterError() async {
    _retryTimer?.cancel();
    _handlingError = false;
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
    _loadedSerial = -1;
    _retryTimer?.cancel();
    _progressTimer?.cancel();
    _handlingError = false;
    _tempSpeed = null;
    await _recordProgressNow();
    await _backend.stop();
    status = PlaybackStatus.idle;
    _notify();
  }

  // ---------- 进度记录 ----------

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _recordProgressNow());
  }

  Future<void> _recordProgressNow({bool saveSession = true}) async {
    final item = current;
    if (item == null) return;
    final pos = _lastPosition;
    final dur = _lastDuration;
    final playlistId = _sourcePlaylistId;
    if (ProgressRules.shouldRecord(dur)) {
      if (ProgressRules.isFinished(pos, dur)) {
        await _db.clearProgress(item.path);
        // 播单进度保留"已看完"行（详情页展示 + 续播时跳过）；全局进度仍是看完即删
        if (playlistId != null) {
          await _writePlaylist(() => _db.markPlaylistProgressFinished(playlistId, item.path, dur));
        }
      } else if (pos > Duration.zero) {
        await _db.upsertProgress(item.path, pos, dur);
        // 播单来源：同一文件在各自播单独立记录断点
        if (playlistId != null) {
          await _writePlaylist(() => _db.upsertPlaylistProgress(playlistId, item.path, pos, dur));
        }
      }
    }
    if (saveSession) {
      await _saveSessionNow();
    }
  }

  Future<void> _saveSessionNow() async {
    final item = current;
    if (item == null) return;
    await _db.saveSession(
      queue,
      index,
      _lastPosition,
      duration: _lastDuration,
      sourcePlaylistId: _sourcePlaylistId,
    );
  }

  /// 播单进度 / 续播指针是附属记录：写失败不能影响播放和全局进度。
  /// 例如播单在播放途中被删除，外键约束会拒绝后续写入，此时自动回退为全局进度模式。
  Future<void> _writePlaylist(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('[OLP] playlist write skipped: $e');
      final pid = _sourcePlaylistId;
      if (pid != null && !await _db.playlistExists(pid)) {
        _sourcePlaylistId = null;
      }
    }
  }

  // ---------- 会话恢复 ----------

  /// 启动时恢复会话：装载队列但不开播，首页"继续播放"卡片触发 resumeSession
  Future<void> restoreSession() async {
    final s = await _db.loadSession();
    if (s == null) return;
    var playlistId = s.sourcePlaylistId;
    if (playlistId != null && !await _db.playlistExists(playlistId)) {
      playlistId = null;
    }
    queue = s.queue;
    index = s.index;
    _sourcePlaylistId = playlistId;
    _restoredPosition = s.position;
    _restoredDuration = s.duration;
    _lastPosition = s.position;
    _lastDuration = s.duration;
    _notify();
  }

  Duration? _restoredPosition;
  Duration? _restoredDuration;

  /// 继续/开始播放恢复的会话
  Future<void> resumeSession() async {
    final item = current;
    if (item == null) return;
    final pos = _restoredPosition;
    final savedDur = _restoredDuration ?? Duration.zero;
    _restoredPosition = null;
    _restoredDuration = null;
    if (pos != null && pos > Duration.zero && status == PlaybackStatus.idle) {
      var playlistId = _sourcePlaylistId;
      if (playlistId != null && !await _db.playlistExists(playlistId)) {
        _sourcePlaylistId = null;
        playlistId = null;
      }
      var durMs = playlistId != null
          ? (await _db.getPlaylistProgress(playlistId, item.path))?.durationMs ?? 0
          : (await _db.getProgress(item.path))?.durationMs ?? 0;
      if (durMs <= 0 && savedDur > Duration.zero) {
        durMs = savedDur.inMilliseconds;
      }
      if (durMs > 0 && pos.inMilliseconds / durMs < ProgressRules.finishedThreshold) {
        await _openCurrent(forceStart: pos);
        return;
      }
      if (durMs <= 0) {
        // 首次打开尚未解析出总时长就拖动保存了断点：直接信任会话保存的位置续播
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
