/// PlaybackController 单元测试：切歌流隔离、800ms 重试串歌防护、播单/全局进度双写与重播保留 finished、关闭字幕记忆、会话恢复。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';
import 'package:openlistplayer/data/app_database.dart';
import 'package:openlistplayer/data/settings_service.dart';
import 'package:openlistplayer/player/playback_controller.dart';
import 'package:openlistplayer/player/player_backend.dart';

class FakePlayerBackend implements PlayerBackend {
  final playingCtrl = StreamController<bool>.broadcast();
  final bufferingCtrl = StreamController<bool>.broadcast();
  final completedCtrl = StreamController<bool>.broadcast();
  final errorCtrl = StreamController<String>.broadcast();
  final positionCtrl = StreamController<Duration>.broadcast();
  final durationCtrl = StreamController<Duration>.broadcast();
  final tracksCtrl = StreamController<Tracks>.broadcast();
  final trackCtrl = StreamController<Track>.broadcast();
  final bufferCtrl = StreamController<Duration>.broadcast();

  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final Duration _buf = Duration.zero;
  double _vol = 100;
  double rate = 1.0;
  Tracks _tracks = const Tracks();
  Track _track = const Track();

  final List<({String url, Duration? start, Map<String, String> headers})> openCalls = [];
  final List<({String url, String flag, String title, Map<String, String> headers})> externalSubCalls = [];
  SubtitleTrack? lastSubtitleSelected;
  AudioTrack? lastAudioSelected;
  bool pausedCalled = false;
  bool stoppedCalled = false;

  @override
  Player? get rawPlayer => null;

  @override
  VideoController? get rawVideoController => null;

  @override
  Stream<bool> get playingStream => playingCtrl.stream;
  @override
  Stream<bool> get bufferingStream => bufferingCtrl.stream;
  @override
  Stream<bool> get completedStream => completedCtrl.stream;
  @override
  Stream<String> get errorStream => errorCtrl.stream;
  @override
  Stream<Duration> get positionStream => positionCtrl.stream;
  @override
  Stream<Duration> get durationStream => durationCtrl.stream;
  @override
  Stream<Tracks> get tracksStream => tracksCtrl.stream;
  @override
  Stream<Track> get trackStream => trackCtrl.stream;
  @override
  Stream<Duration> get bufferStream => bufferCtrl.stream;

  @override
  bool get isPlaying => _playing;
  @override
  Duration get currentPosition => _pos;
  @override
  Duration get currentDuration => _dur;
  @override
  Duration get currentBuffer => _buf;
  @override
  double get currentVolume => _vol;
  @override
  Tracks get currentTracks => _tracks;
  @override
  Track get currentTrack => _track;

  void emitPosition(Duration p) {
    _pos = p;
    positionCtrl.add(p);
  }

  void emitDuration(Duration d) {
    _dur = d;
    durationCtrl.add(d);
  }

  void emitPlaying(bool p) {
    _playing = p;
    playingCtrl.add(p);
  }

  void emitCompleted() {
    completedCtrl.add(true);
  }

  void emitError(String e) {
    errorCtrl.add(e);
  }

  void emitTracks(Tracks t, {Track? selected}) {
    _tracks = t;
    if (selected != null) _track = selected;
    tracksCtrl.add(t);
  }

  @override
  Future<void> applyBufferProfile({required int readaheadSecs, required int bufferBytes}) async {}

  @override
  Future<void> openMedia(
    String url, {
    Map<String, String> headers = const {},
    Duration? start,
    bool play = true,
  }) async {
    openCalls.add((url: url, start: start, headers: headers));
    _pos = start ?? Duration.zero;
    _playing = play;
    playingCtrl.add(play);
  }

  @override
  Future<void> play() async {
    _playing = true;
    playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    pausedCalled = true;
    _playing = false;
    playingCtrl.add(false);
  }

  @override
  Future<void> stop() async {
    stoppedCalled = true;
    _playing = false;
  }

  @override
  Future<void> seek(Duration position) async {
    _pos = position;
    positionCtrl.add(position);
  }

  @override
  Future<void> setRate(double r) async {
    rate = r;
  }

  @override
  Future<void> setVolume(double volume) async {
    _vol = volume;
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    lastAudioSelected = track;
    _track = Track(audio: track, subtitle: _track.subtitle, video: _track.video);
    trackCtrl.add(_track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    lastSubtitleSelected = track;
    _track = Track(audio: _track.audio, subtitle: track, video: _track.video);
    trackCtrl.add(_track);
  }

  @override
  Future<void> setSubDelaySeconds(double seconds) async {}

  @override
  Future<void> addExternalSub(
    String url,
    String flag,
    String title, {
    Map<String, String> headers = const {},
  }) async {
    externalSubCalls.add((url: url, flag: flag, title: title, headers: headers));
  }

  @override
  Future<void> dispose() async {
    await playingCtrl.close();
    await bufferingCtrl.close();
    await completedCtrl.close();
    await errorCtrl.close();
    await positionCtrl.close();
    await durationCtrl.close();
    await tracksCtrl.close();
    await trackCtrl.close();
    await bufferCtrl.close();
  }
}

class _ControlledAdapter implements HttpClientAdapter {
  _ControlledAdapter(this.onFetch);

  final Future<Map<String, dynamic>> Function(String endpoint, Map<String, dynamic> body) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reqBody = (options.data as Map<String, dynamic>?) ?? const {};
    final resp = await onFetch(options.path, reqBody);
    return ResponseBody.fromString(
      jsonEncode(resp),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late FakePlayerBackend backend;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakePlayerBackend();
  });

  tearDown(() async {
    await db.close();
  });

  OpenListClient buildClient(
    Future<Map<String, dynamic>> Function(String endpoint, Map<String, dynamic> body) handler,
  ) {
    final dio = Dio();
    dio.httpClientAdapter = _ControlledAdapter(handler);
    return OpenListClient(
      site: const SiteConfig(baseUrl: 'http://localhost:5244'),
      dio: dio,
    );
  }

  const defaultSettings = AppSettings(site: SiteConfig(baseUrl: 'http://localhost:5244'));

  test('H-5: 切歌等待 getFileLink 期间，旧曲目的 position / completed 事件不会污染新曲目', () async {
    final linkCompleterB = Completer<Map<String, dynamic>>();
    final client = buildClient((endpoint, body) async {
      if (endpoint == '/api/fs/list') {
        return {'code': 200, 'data': {'content': <dynamic>[]}};
      }
      final path = body['path'] as String;
      if (path == '/b.mp3') {
        return linkCompleterB.future;
      }
      return {
        'code': 200,
        'data': {'name': path.substring(1), 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    final pid = await db.createPlaylist('测试');
    const items = [
      QueueItem(path: '/a.mp3', name: 'a.mp3', isVideo: false),
      QueueItem(path: '/b.mp3', name: 'b.mp3', isVideo: false),
      QueueItem(path: '/c.mp3', name: 'c.mp3', isVideo: false),
    ];
    await db.addItemsToPlaylist(pid, items);

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.playQueue(items, 0, playlistId: pid);
    backend.emitDuration(const Duration(seconds: 600));
    backend.emitPosition(const Duration(seconds: 120));
    await Future<void>.delayed(Duration.zero);

    // 用户切到 /b.mp3，此时 /b.mp3 的 getFileLink 正在挂起
    final jumpFuture = c.jumpTo(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // 确认 /a.mp3 的 120s 进度已准确落盘到 /a.mp3
    final progA = await db.getPlaylistProgress(pid, '/a.mp3');
    expect(progA?.positionMs, 120000);

    // 模拟底层旧媒体在等待期间继续吐出旧位置甚至 completed 事件
    backend.emitPosition(const Duration(seconds: 599));
    backend.emitCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // 放行 /b.mp3 直链
    linkCompleterB.complete({
      'code': 200,
      'data': {'name': 'b.mp3', 'raw_url': 'http://cdn/b.mp3', 'size': 100},
    });
    await jumpFuture;

    // /b.mp3 必须从片头（start: null）打开，绝不能串为 /a.mp3 的 599s，也不能被跳过到 /c.mp3
    expect(c.index, 1);
    expect(c.current?.path, '/b.mp3');
    expect(backend.openCalls.last.url, 'http://cdn/b.mp3');
    expect(backend.openCalls.last.start, isNull);
    final progB = await db.getPlaylistProgress(pid, '/b.mp3');
    expect(progB, isNull);
  });

  test('H-5: 曲目 A 报错进入 800ms 重试等待期间用户切到曲目 B，旧重试被取消不会覆盖曲目 B', () async {
    final client = buildClient((endpoint, body) async {
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    const items = [
      QueueItem(path: '/a.mp3', name: 'a.mp3', isVideo: false),
      QueueItem(path: '/b.mp3', name: 'b.mp3', isVideo: false),
    ];
    await c.replaceQueue(items, 0);
    backend.emitDuration(const Duration(seconds: 300));
    backend.emitPosition(const Duration(seconds: 180));

    // A 在 180s 处出错，启动 800ms 重试倒计时
    backend.emitError('network reset');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.status, PlaybackStatus.buffering);

    // 200ms 时用户手动切到 B
    await c.jumpTo(1);
    expect(c.current?.path, '/b.mp3');
    final openCountAfterJump = backend.openCalls.length;

    // 等过 800ms 窗口，确认旧重试没有触发，B 未被 A 的 180s 断点重开
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(backend.openCalls.length, openCountAfterJump);
    expect(c.current?.path, '/b.mp3');
  });

  test('M-3: 播单中已看完的条目重播时若直链获取失败，保留原有的"已看完"标记不丢失', () async {
    var failGetLink = false;
    final client = buildClient((endpoint, body) async {
      if (failGetLink) {
        throw DioException(
          requestOptions: RequestOptions(path: endpoint),
          error: 'offline',
        );
      }
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    final pid = await db.createPlaylist('追剧播单');
    const item = QueueItem(path: '/ep1.mp4', name: 'ep1.mp4', isVideo: true);
    await db.addItemsToPlaylist(pid, const [item]);
    await db.markPlaylistProgressFinished(pid, item.path, const Duration(seconds: 120));

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    // 断网状态下点击重播已看完的 ep1
    failGetLink = true;
    await c.playQueue(const [item], 0, playlistId: pid);

    final p = await db.getPlaylistProgress(pid, item.path);
    expect(p, isNotNull);
    expect(p!.finished, isTrue);

    // 停止清理重试定时器
    await c.stop();
  });

  test('M-1: 关闭字幕偏好（空串）在下次打开带内置字幕的视频时主动调用 SubtitleTrack.no()', () async {
    final client = buildClient((endpoint, body) async {
      if (endpoint == '/api/fs/list') {
        return {'code': 200, 'data': {'content': <dynamic>[]}};
      }
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const item = QueueItem(path: '/movie.mkv', name: 'movie.mkv', isVideo: true);
    // 模拟上次用户显式关闭了字幕（存储为空字符串 ''）
    await db.saveTrackPrefs(item.path, subtitleTrack: '');

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.replaceQueue(const [item], 0);
    final embeddedSub = SubtitleTrack('1', '简体中文', 'chi');
    backend.emitTracks(
      Tracks(subtitle: [SubtitleTrack.auto(), SubtitleTrack.no(), embeddedSub]),
      selected: Track(subtitle: embeddedSub),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(backend.lastSubtitleSelected?.id, SubtitleTrack.no().id);
    expect(c.currentSubtitle, isNull);
  });

  test('M-4: 首播未满 5 秒即拖动进度条退出，restoreSession + resumeSession 仍能恢复到拖动位置', () async {
    final client = buildClient((endpoint, body) async {
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const item = QueueItem(path: '/book.mp3', name: 'book.mp3', isVideo: false);
    final c1 = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );

    await c1.replaceQueue(const [item], 0);
    backend.emitDuration(const Duration(minutes: 30));
    // 未等 5s 进度落盘，直接 seek 到 10 分钟处
    await c1.seek(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    c1.dispose();

    // 确认此时进度表里还没有记录，但会话表已有记录
    expect(await db.getProgress(item.path), isNull);

    final backend2 = FakePlayerBackend();
    final c2 = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend2,
    );
    addTearDown(c2.dispose);

    await c2.restoreSession();
    expect(c2.status, PlaybackStatus.idle);
    expect(c2.current?.path, item.path);

    await c2.resumeSession();
    expect(backend2.openCalls.single.start, const Duration(minutes: 10));
  });

  test('M-1: 自动与手动挂载外挂字幕均透传直链 headers，手动挂载后立即设置选中态', () async {
    final client = buildClient((endpoint, body) async {
      if (endpoint == '/api/fs/list') {
        return {
          'code': 200,
          'data': {
            'content': [
              {'name': 'ep1.mkv', 'is_dir': false, 'size': 1000},
              {'name': 'ep1.chs.srt', 'is_dir': false, 'size': 10},
              {'name': 'manual.ass', 'is_dir': false, 'size': 12},
            ],
          },
        };
      }
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {
          'name': path.split('/').last,
          'raw_url': 'http://cdn$path',
          'size': 100,
          'header': {
            'Referer': ['https://cloud.189.cn/'],
            'Cookie': ['u=1', 's=2'],
          },
        },
      };
    });

    const item = QueueItem(path: '/dir/ep1.mkv', name: 'ep1.mkv', isVideo: true);
    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.replaceQueue(const [item], 0);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // 自动挂载 ep1.chs.srt 透传了直链 headers
    expect(backend.externalSubCalls, hasLength(1));
    expect(backend.externalSubCalls.single.title, 'ep1.chs.srt');
    expect(backend.externalSubCalls.single.flag, 'select');
    expect(backend.externalSubCalls.single.headers, {
      'Referer': 'https://cloud.189.cn/',
      'Cookie': 'u=1; s=2',
    });

    // 手动挂载 manual.ass 同样透传 headers，并立即更新 currentSubtitle 与偏好记录
    await c.addExternalSubtitle('manual.ass');
    expect(backend.externalSubCalls, hasLength(2));
    expect(backend.externalSubCalls.last.title, 'manual.ass');
    expect(backend.externalSubCalls.last.flag, 'select');
    expect(backend.externalSubCalls.last.headers['Referer'], 'https://cloud.189.cn/');
    expect(c.currentSubtitle?.title, 'manual.ass');
    final savedPrefs = await db.getTrackPrefs(item.path);
    expect(savedPrefs?.subtitleTrack, 'manual.ass');
  });

  test('Minor-1: 外挂字幕请求头与主媒体不同（或为空）时先切换字幕头，sub-add 后在 finally 恢复主媒体请求头',
      () async {
    final appliedLog = <String>[];
    const mediaHeaders = {
      'Referer': 'https://cloud.189.cn/',
      'Cookie': 'media_token=secret',
    };

    // 场景 A：字幕走无 header 的本地 /d 代理 → 先清空避免泄露主媒体 Cookie，sub-add 后恢复主媒体头
    await runSubAddWithHeaderGuard(
      mediaHeaders: mediaHeaders,
      subHeaders: const {},
      applyHeaders: (h) async => appliedLog.add(formatMpvHttpHeaders(h)),
      runSubAdd: () async => appliedLog.add('CMD:sub-add-proxy'),
    );
    expect(appliedLog, [
      '', // 先清空请求头，不向无头字幕源泄露 Cookie
      'CMD:sub-add-proxy',
      'Referer: https://cloud.189.cn/\r\nCookie: media_token=secret', // finally 恢复主媒体请求头
    ]);

    // 场景 B：字幕带异源请求头且 sub-add 抛错 → finally 依然可靠恢复主媒体头
    appliedLog.clear();
    await expectLater(
      runSubAddWithHeaderGuard(
        mediaHeaders: mediaHeaders,
        subHeaders: const {'Authorization': 'Bearer sub_only'},
        applyHeaders: (h) async => appliedLog.add(formatMpvHttpHeaders(h)),
        runSubAdd: () async {
          appliedLog.add('CMD:sub-add-fail');
          throw StateError('sub-add failed');
        },
      ),
      throwsStateError,
    );
    expect(appliedLog, [
      'Authorization: Bearer sub_only',
      'CMD:sub-add-fail',
      'Referer: https://cloud.189.cn/\r\nCookie: media_token=secret',
    ]);

    // 场景 C：字幕头与主媒体头完全一致 → 无需在 finally 重复写回
    appliedLog.clear();
    await runSubAddWithHeaderGuard(
      mediaHeaders: mediaHeaders,
      subHeaders: const {
        'Referer': 'https://cloud.189.cn/',
        'Cookie': 'media_token=secret',
      },
      applyHeaders: (h) async => appliedLog.add(formatMpvHttpHeaders(h)),
      runSubAdd: () async => appliedLog.add('CMD:sub-add-same'),
    );
    expect(appliedLog, [
      'Referer: https://cloud.189.cn/\r\nCookie: media_token=secret',
      'CMD:sub-add-same',
    ]);
  });

  test('R1-H3: 同语言无标题多条内置音轨/字幕轨使用复合键记忆，重开时不串轨', () async {
    final client = buildClient((endpoint, body) async {
      if (endpoint == '/api/fs/list') {
        return {'code': 200, 'data': {'content': <dynamic>[]}};
      }
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path.split('/').last, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const item = QueueItem(path: '/anime/ep01.mkv', name: 'ep01.mkv', isVideo: true);
    final c1 = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c1.dispose);

    await c1.replaceQueue(const [item], 0);
    // 模拟两条 title 均为空、language 均为 chi 的内置字幕轨（id 分别为 1 和 2）
    final sub1 = SubtitleTrack('1', null, 'chi');
    final sub2 = SubtitleTrack('2', null, 'chi');
    final aud1 = AudioTrack('1', null, 'jpn');
    final aud2 = AudioTrack('2', null, 'jpn');
    backend.emitTracks(
      Tracks(
        audio: [AudioTrack.auto(), aud1, aud2],
        subtitle: [SubtitleTrack.auto(), SubtitleTrack.no(), sub1, sub2],
      ),
      selected: Track(audio: aud1, subtitle: sub1),
    );
    await Future<void>.delayed(Duration.zero);

    // 用户手动切到第 2 条同语言轨道
    await c1.selectAudioTrack(c1.audioTracks[1]);
    await c1.selectSubtitleTrack(c1.subtitleTracks[1]);
    expect(backend.lastAudioSelected?.id, '2');
    expect(backend.lastSubtitleSelected?.id, '2');

    // 重新打开同一视频：应精确恢复到 id='2' 的轨道，而非被第一条同语言 chi/jpn 截胡
    final backend2 = FakePlayerBackend();
    final c2 = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend2,
    );
    addTearDown(c2.dispose);

    await c2.replaceQueue(const [item], 0);
    backend2.emitTracks(
      Tracks(
        audio: [AudioTrack.auto(), aud1, aud2],
        subtitle: [SubtitleTrack.auto(), SubtitleTrack.no(), sub1, sub2],
      ),
      selected: Track(audio: aud1, subtitle: sub1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(backend2.lastAudioSelected?.id, '2');
    expect(backend2.lastSubtitleSelected?.id, '2');
  });

  test('R1-M3: 第一个外挂字幕获取直链失败时，后续完好的外挂字幕仍能正常挂载并自动选中', () async {
    final client = buildClient((endpoint, body) async {
      if (endpoint == '/api/fs/list') {
        return {
          'code': 200,
          'data': {
            'content': [
              {'name': 'ep1.mkv', 'is_dir': false, 'size': 1000},
              {'name': 'ep1.srt', 'is_dir': false, 'size': 10}, // 第一个字幕将报错
              {'name': 'ep1.chs.ass', 'is_dir': false, 'size': 12}, // 第二个字幕正常
            ],
          },
        };
      }
      final path = body['path'] as String? ?? '';
      if (path.endsWith('ep1.srt')) {
        throw const OpenListApiException('字幕文件已损坏', statusCode: 500);
      }
      return {
        'code': 200,
        'data': {'name': path.split('/').last, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const item = QueueItem(path: '/dir/ep1.mkv', name: 'ep1.mkv', isVideo: true);
    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.replaceQueue(const [item], 0);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(backend.externalSubCalls, hasLength(1));
    expect(backend.externalSubCalls.single.title, 'ep1.chs.ass');
    expect(backend.externalSubCalls.single.flag, 'select');
  });

  test('R1-M3: 会话恢复 idle 态下外部 seek 同步更新待恢复断点，resumeSession 从新位置开播', () async {
    final client = buildClient((endpoint, body) async {
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const item = QueueItem(path: '/podcast.mp3', name: 'podcast.mp3', isVideo: false);
    await db.saveSession(
      const [item],
      0,
      const Duration(seconds: 60),
      duration: const Duration(seconds: 600),
    );

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.restoreSession();
    expect(c.status, PlaybackStatus.idle);

    // 在尚未开播的 idle 态拖动进度到 180 秒（同时测试越界 clamp）
    await c.seek(const Duration(seconds: 180));
    expect(c.currentPosition, const Duration(seconds: 180));
    expect(backend.openCalls, isEmpty);

    await c.resumeSession();
    expect(backend.openCalls.single.start, const Duration(seconds: 180));
  });

  test('R2-H1: 快速连续 jumpTo 多首曲目或切歌后立即 stop()，不会被旧异步写库乱序覆盖或幽灵复播', () async {
    final client = buildClient((endpoint, body) async {
      final path = body['path'] as String? ?? '';
      await Future<void>.delayed(const Duration(milliseconds: 25));
      return {
        'code': 200,
        'data': {'name': path.split('/').last, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    const items = [
      QueueItem(path: '/ep1.mp3', name: 'ep1.mp3', isVideo: false),
      QueueItem(path: '/ep2.mp3', name: 'ep2.mp3', isVideo: false),
      QueueItem(path: '/ep3.mp3', name: 'ep3.mp3', isVideo: false),
    ];
    await c.replaceQueue(items, 0);
    backend.emitDuration(const Duration(seconds: 120));
    backend.emitPosition(const Duration(seconds: 45));
    await Future<void>.delayed(Duration.zero);

    // 用户快速连点跳到 ep2 再跳到 ep3（不等待前一次完成）
    final f1 = c.jumpTo(1);
    final f2 = c.jumpTo(2);
    await Future.wait([f1, f2]);

    // 最终必须停留在 ep3，且 ep1 的 45s 断点已准确落盘，ep2 未被污染为 45s
    expect(c.current?.path, '/ep3.mp3');
    expect(backend.openCalls.last.url, 'http://cdn/ep3.mp3');
    expect((await db.getProgress('/ep1.mp3'))?.positionMs, 45000);
    expect(await db.getProgress('/ep2.mp3'), isNull);

    // 发起切歌后立即调用 stop()：绝不能在写库返回后幽灵复播
    final fNext = c.next();
    await c.stop();
    await fNext;
    expect(c.status, PlaybackStatus.idle);
  });

  test('R2-H2: 播放瞬断启动 800ms _retryTimer 后若底层流自行恢复 playing=true，立即取消重连定时器防误打断',
      () async {
    final client = buildClient((endpoint, body) async {
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    const item = QueueItem(path: '/live.mp3', name: 'live.mp3', isVideo: false);
    await c.replaceQueue(const [item], 0);
    expect(backend.openCalls, hasLength(1));

    // 瞬断报错：进入 buffering 并启动 800ms _retryTimer
    backend.emitError('transient socket glitch');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.status, PlaybackStatus.buffering);

    // 100ms 后底层 mpv 缓冲自行恢复并发出 playingStream(true)
    backend.emitPlaying(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.status, PlaybackStatus.playing);

    // 等过 800ms 重试窗口：openMedia 调用次数仍为 1，正常播放未被重连打断
    await Future<void>.delayed(const Duration(milliseconds: 850));
    expect(backend.openCalls, hasLength(1));
  });

  test('R2-M3: addExternalSubtitle 对已挂载外挂字幕直接复用选中不重复 sub-add，且字幕延迟限幅 ±60s',
      () async {
    final client = buildClient((endpoint, body) async {
      if (endpoint == '/api/fs/list') {
        return {
          'code': 200,
          'data': {
            'content': [
              {'name': 'ep1.mkv', 'is_dir': false, 'size': 1000},
              {'name': 'ep1.chs.srt', 'is_dir': false, 'size': 10},
            ],
          },
        };
      }
      final path = body['path'] as String? ?? '';
      return {
        'code': 200,
        'data': {'name': path.split('/').last, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const item = QueueItem(path: '/dir/ep1.mkv', name: 'ep1.mkv', isVideo: true);
    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.replaceQueue(const [item], 0);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(backend.externalSubCalls, hasLength(1));

    // 模拟 mpv 已将自动挂载的外挂字幕加入轨道列表
    final extTrack = SubtitleTrack('3', 'ep1.chs.srt', null, uri: true);
    backend.emitTracks(
      Tracks(subtitle: [SubtitleTrack.auto(), SubtitleTrack.no(), extTrack]),
      selected: Track(subtitle: SubtitleTrack.no()),
    );
    await Future<void>.delayed(Duration.zero);

    // 再次请求手动加载同名外挂字幕：应直接调用 setSubtitleTrack 选中而非重复 sub-add
    await c.addExternalSubtitle('ep1.chs.srt');
    expect(backend.externalSubCalls, hasLength(1));
    expect(backend.lastSubtitleSelected?.id, '3');
    expect(c.currentSubtitle?.id, '3');

    // 字幕延迟限幅在 [-60000, 60000]ms
    await c.adjustSubDelay(999999);
    expect(c.subDelayMs, 60000);
    await c.adjustSubDelay(-999999);
    expect(c.subDelayMs, -60000);
  });

  test('R3-M1: resumeSession 期间并发 replaceQueue 不会覆盖新曲目；error 态 seek 同步更新 retryPosition',
      () async {
    var failOpen = false;
    final client = buildClient((endpoint, body) async {
      final path = body['path'] as String? ?? '';
      if (failOpen) {
        throw const OpenListApiException('网络不可达', statusCode: 502);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return {
        'code': 200,
        'data': {'name': path.split('/').last, 'raw_url': 'http://cdn$path', 'size': 100},
      };
    });

    const saved = QueueItem(path: '/old.mp3', name: 'old.mp3', isVideo: false);
    const fresh = QueueItem(path: '/fresh.mp3', name: 'fresh.mp3', isVideo: false);
    await db.saveSession(
      const [saved],
      0,
      const Duration(seconds: 40),
      duration: const Duration(seconds: 200),
    );

    final c = PlaybackController(
      api: () => client,
      db: db,
      settings: () => defaultSettings,
      backend: backend,
    );
    addTearDown(c.dispose);

    await c.restoreSession();
    // 并发调用 resumeSession 与 replaceQueue：最终必须稳定停留在 fresh.mp3
    final fResume = c.resumeSession();
    final fReplace = c.replaceQueue(const [fresh], 0);
    await Future.wait([fResume, fReplace]);
    expect(c.current?.path, '/fresh.mp3');
    expect(backend.openCalls.last.url, 'http://cdn/fresh.mp3');

    // 模拟播放报错耗尽自动重试进入 error 态，在 error 态下外部 seek 更新断点后 retryNow
    failOpen = true;
    await c.replaceQueue(const [fresh], 0);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    expect(c.status, PlaybackStatus.error);

    await c.seek(const Duration(seconds: 90));
    expect(c.currentPosition, const Duration(seconds: 90));

    failOpen = false;
    await c.retryNow();
    expect(backend.openCalls.last.start, const Duration(seconds: 90));
  });
}
