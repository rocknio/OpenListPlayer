/// UI 关键回归测试：
/// 1. HomePage._ResumeCard 随 PlaybackController.notifyListeners 实时显隐（H-8）
/// 2. BrowserPage 普通多选态取消最后一项不会退回父目录或退出路由（H-6）
/// 3. BrowserPage 在 IndexedStack 非当前激活 Tab 时不劫持全局 PopScope（H-7）
/// 4. PlaylistsPage 新建弹窗关闭退场动画期间安全持有并释放 TextEditingController（Minor-2）
/// 5. AudioPage 按住进度条拖动期间若发生切歌，自动重置拖拽态且松手不误 seek 新曲目（Minor-3）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';
import 'package:openlistplayer/data/app_database.dart';
import 'package:openlistplayer/data/settings_service.dart';
import 'package:openlistplayer/player/playback_controller.dart';
import 'package:openlistplayer/providers.dart';
import 'package:openlistplayer/ui/browser/browser_page.dart';
import 'package:openlistplayer/ui/home/home_page.dart';
import 'package:openlistplayer/ui/mini_player_bar.dart';
import 'package:openlistplayer/ui/player/audio_page.dart';
import 'package:openlistplayer/ui/playlist/playlists_page.dart';
import 'package:openlistplayer/ui/settings/settings_page.dart';
import 'package:openlistplayer/ui/tab_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playback_controller_test.dart' show FakePlayerBackend;

class _FakeOpenListAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = (options.data as Map<String, dynamic>?) ?? const {};
    final path = body['path'] as String? ?? '/';
    if (options.path == '/api/fs/list') {
      final content = path == '/'
          ? [
              {'name': '子目录', 'is_dir': true, 'size': 0},
              {'name': 'root_song.mp3', 'is_dir': false, 'size': 1024},
            ]
          : [
              {'name': 'sub_song.mp3', 'is_dir': false, 'size': 2048},
            ];
      return ResponseBody.fromString(
        jsonEncode({
          'code': 200,
          'message': 'success',
          'data': {'content': content},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': 200,
        'message': 'success',
        'data': {'name': 'song.mp3', 'raw_url': 'http://cdn/song.mp3', 'size': 1024},
      }),
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
  late SharedPreferences prefs;
  late OpenListClient client;
  late FakePlayerBackend backend;
  late PlaybackController playback;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'site.url': 'http://localhost:5244',
      'site.name': '测试站',
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio()..httpClientAdapter = _FakeOpenListAdapter();
    client = OpenListClient(
      site: const SiteConfig(baseUrl: 'http://localhost:5244'),
      dio: dio,
    );
    backend = FakePlayerBackend();
    playback = PlaybackController(
      api: () => client,
      db: db,
      settings: () => SettingsService(prefs).load(),
      backend: backend,
    );
  });

  tearDown(() async {
    playback.dispose();
    client.close();
    await db.close();
  });

  /// 卸载页面并排空 drift 在流订阅取消时排队的零时长 Timer（参见 AGENTS.md）
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('H-8: HomePage 常驻英雄卡随播放状态在「继续播放 / 正在收听 / 已暂停」间实时切换', (tester) async {
    const item = QueueItem(path: '/music/ep1.mp3', name: '第一集.mp3', isVideo: false);
    await tester.runAsync(() async {
      await db.saveSession(
        const [item],
        0,
        const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
      );
      await playback.restoreSession();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(client),
          playbackProvider.overrideWithValue(playback),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    try {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 恢复态 idle：英雄卡显示「继续播放」与路径信息
      expect(find.text('第一集.mp3'), findsOneWidget);
      expect(find.text('音频 · /music'), findsOneWidget);
      expect(find.text('继续播放'), findsNWidgets(2)); // 顶部状态标 + 主按钮

      // 模拟在其它页面开播：status 变为 playing 并 notifyListeners()，英雄卡实时切为「正在收听 / 进入播放器」
      // 注意：HomePage 在 FakeAsync zone 订阅了 drift 的 historyStream，replaceQueue 在真实 async 中写入
      // playHistories 后，drift 会向 FakeAsync zone 派发一次零时长 Timer 来重查流；若在 runAsync 里持续 await
      // 后续写库（saveSession）就会与等待 FakeAsync 推进的查询串行锁死。交替 pump 即可平滑完成。
      Future<void>? openFuture;
      await tester.runAsync(() async {
        openFuture = playback.replaceQueue(const [item], 0);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(() => openFuture!);
      await tester.pump();
      expect(find.text('正在收听'), findsOneWidget);
      expect(find.text('进入播放器'), findsOneWidget);
      expect(find.text('继续播放'), findsNothing);

      // 停止回到 idle：英雄卡切回「继续播放」
      await tester.runAsync(() => playback.stop());
      await tester.pump();
      expect(find.text('音频 · /music'), findsOneWidget);
      expect(find.text('继续播放'), findsNWidgets(2));
    } finally {
      // 先卸载页面排空 drift 流取消零时长 Timer，避免与 tearDown db.close() 死锁
      await closePage(tester);
    }
  });

  testWidgets('H-6 & H-7: BrowserPage 取消最后一项多选不误退父目录；非当前 Tab 时 canPop 为 true',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(client),
        playbackProvider.overrideWithValue(playback),
      ],
    );
    addTearDown(container.dispose);

    // 切到文件 tab (index = 1)
    container.read(tabIndexProvider.notifier).set(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrowserPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('子目录'), findsOneWidget);
    expect(find.text('root_song.mp3'), findsOneWidget);

    // 进入子目录
    await tester.tap(find.text('子目录'));
    await tester.pumpAndSettle();
    expect(find.text('sub_song.mp3'), findsOneWidget);

    // 长按选中唯一文件进入多选态（顶部 AppBar 与底部浮岛均展示已选计数）
    await tester.longPress(find.text('sub_song.mp3'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsWidgets);

    // 再次点击取消最后一个选中项：应退出多选态，但仍留在"子目录"（绝不能退回根目录！）
    await tester.tap(find.text('sub_song.mp3'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNothing);
    expect(find.text('sub_song.mp3'), findsOneWidget);
    expect(find.text('root_song.mp3'), findsNothing);

    // 此时在文件 tab (index=1) 的子目录下，PopScope.canPop 应为 false（拦截返回以回上级）
    final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
    var popScope = tester.widget<PopScope<dynamic>>(popScopeFinder);
    expect(popScope.canPop, isFalse);

    // 切到首页 tab (index=0)：BrowserPage 在后台不应再拦截返回键（canPop 变为 true）
    container.read(tabIndexProvider.notifier).set(0);
    await tester.pump();
    popScope = tester.widget<PopScope<dynamic>>(popScopeFinder);
    expect(popScope.canPop, isTrue);

    await closePage(tester);
  });

  testWidgets('Minor-2: PlaylistsPage 新建播单弹窗在退场过渡动画逐帧渲染期间不触发已销毁控制器异常',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(client),
          playbackProvider.overrideWithValue(playback),
        ],
        child: const MaterialApp(home: PlaylistsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建播单'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '通勤歌单');
    await tester.tap(find.text('确定'));

    // 模拟真实路由退场动画中间帧（showDialog Future 已完成，但 AlertDialog 尚未卸载）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('通勤歌单'), findsOneWidget);

    await closePage(tester);
  });

  testWidgets('Minor-3: AudioPage 按住进度条拖动期间若切歌，立即重置拖拽态且松手不会误 seek 新曲目',
      (tester) async {
    const items = [
      QueueItem(path: '/music/a.mp3', name: '曲目A.mp3', isVideo: false),
      QueueItem(path: '/music/b.mp3', name: '曲目B.mp3', isVideo: false),
    ];
    await tester.runAsync(() => playback.replaceQueue(items, 0));
    backend.emitDuration(const Duration(seconds: 200));
    backend.emitPosition(const Duration(seconds: 20));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(client),
          playbackProvider.overrideWithValue(playback),
        ],
        child: const MaterialApp(home: AudioPage()),
      ),
    );
    await tester.pump();

    // 按住 Slider 向右拖动但保持手指不松开
    final sliderCenter = tester.getCenter(find.byType(Slider));
    final gesture = await tester.startGesture(sliderCenter);
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    // 拖动尚未松手时，外部触发切到下一首曲目 B
    await tester.runAsync(() => playback.next());
    backend.emitDuration(const Duration(seconds: 300));
    backend.emitPosition(const Duration(seconds: 0));
    await tester.pump();
    await tester.pump();

    expect(playback.current?.path, '/music/b.mp3');

    // 此时用户松开手指：不应将曲目 A 拖动时的位置 seek 到曲目 B 上
    await gesture.up();
    await tester.pump();

    expect(playback.currentPosition, Duration.zero);

    await closePage(tester);
  });

  testWidgets('R1-H2: 音视频混合队列在 AudioPage 切到视频条目时自动 pushReplacement 到视频页',
      (tester) async {
    const items = [
      QueueItem(path: '/mix/a.mp3', name: '纯音频.mp3', isVideo: false),
      QueueItem(path: '/mix/b.mp4', name: 'MV视频.mp4', isVideo: true),
    ];
    await tester.runAsync(() => playback.replaceQueue(items, 0));

    // 用带二级路由栈模拟真实从列表打开 AudioPage，验证同类型切歌不重复替换、跨类型切歌触发路由切换
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(client),
          playbackProvider.overrideWithValue(playback),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute<void>(builder: (_) => const AudioPage()),
                  );
                },
                child: const Text('打开播放器'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开播放器'));
    // AudioPage 播放中含唱片旋转 Ticker，使用定时 pump 推进路由转场动画
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AudioPage), findsOneWidget);

    // 验证当切换到另一首音频时仍停留在 AudioPage
    await tester.runAsync(() => playback.replaceQueue(const [
          QueueItem(path: '/mix/a2.mp3', name: '音频2.mp3', isVideo: false),
        ], 0));
    await tester.pump();
    expect(find.byType(AudioPage), findsOneWidget);

    await closePage(tester);
  });

  testWidgets('R1-L1: PlaylistsPage 新建播单输入超长名称（>100字符）受 maxLength 保护不抛数据库约束异常',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
          dbProvider.overrideWithValue(db),
          apiProvider.overrideWithValue(client),
          playbackProvider.overrideWithValue(playback),
        ],
        child: const MaterialApp(home: PlaylistsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建播单'));
    await tester.pumpAndSettle();

    final longName = '超长播单' * 35; // 140 字符，超过 Playlists.name 的 max=100
    await tester.enterText(find.byType(TextField), longName);
    await tester.tap(find.text('确定'));
    // drift 写库必须在 tester.runAsync 或短暂释放真实异步中完成
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final playlists = await tester.runAsync(() => db.playlistsStream().first);
    expect(playlists, hasLength(1));
    expect(playlists!.single.name.length, lessThanOrEqualTo(100));

    await closePage(tester);
  });

  testWidgets('R2-M1 & R2-M4: setDefaultPlayMode 立即同步空队列播放模式；MiniPlayerBar 在 idle 态点击自动触发 resumeSession',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(client),
        playbackProvider.overrideWithValue(playback),
      ],
    );
    addTearDown(container.dispose);

    // R2-M1：队列为空时通过 AppSettingsNotifier 修改默认播放模式，playback.mode 应立即同步
    expect(playback.mode, PlayMode.sequentialLoop);
    await tester.runAsync(
      () => container.read(settingsProvider.notifier).setDefaultPlayMode(PlayMode.shuffle),
    );
    expect(playback.mode, PlayMode.shuffle);

    // R2-M4：装载恢复态会话（status == idle）后点击 MiniPlayerBar，应自动触发 resumeSession 开播
    const item = QueueItem(path: '/music/idle_song.mp3', name: '待恢复歌曲.mp3', isVideo: false);
    await tester.runAsync(() async {
      await db.saveSession(
        const [item],
        0,
        const Duration(seconds: 25),
        duration: const Duration(seconds: 180),
      );
      await playback.restoreSession();
    });
    expect(playback.status, PlaybackStatus.idle);
    expect(backend.openCalls, isEmpty);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar: MiniPlayerBar(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('待恢复歌曲.mp3'), findsOneWidget);

    await tester.tap(find.text('待恢复歌曲.mp3'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    // AudioPage 播放中含唱片旋转 Ticker，使用定时 pump 完成 Sheet 入场动画
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(backend.openCalls, hasLength(1));
    expect(backend.openCalls.single.start, const Duration(seconds: 25));
    expect(find.byType(AudioPage), findsOneWidget);

    await tester.runAsync(() => playback.stop());
    await closePage(tester);
  });

  testWidgets('R2-M4: BrowserPage 响应 sortMode 设置变更实时重排当前目录条目', (tester) async {
    final multiFileDio = Dio()
      ..httpClientAdapter = _MultiSortAdapter();
    final multiClient = OpenListClient(
      site: const SiteConfig(baseUrl: 'http://localhost:5244'),
      dio: multiFileDio,
    );
    addTearDown(multiClient.close);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(multiClient),
        playbackProvider.overrideWithValue(playback),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrowserPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 默认自然排序：ep2.mp3 在 ep10.mp3 上方
    var yEp2 = tester.getTopLeft(find.text('ep2.mp3')).dy;
    var yEp10 = tester.getTopLeft(find.text('ep10.mp3')).dy;
    expect(yEp2, lessThan(yEp10));

    // 修改排序模式为字典序 SortMode.name：'ep10.mp3' 应立即排到 'ep2.mp3' 上方，无需手动刷新
    await tester.runAsync(
      () => container.read(settingsProvider.notifier).setSortMode(SortMode.name),
    );
    await tester.pump();

    yEp2 = tester.getTopLeft(find.text('ep2.mp3')).dy;
    yEp10 = tester.getTopLeft(find.text('ep10.mp3')).dy;
    expect(yEp10, lessThan(yEp2));

    await closePage(tester);
  });

  testWidgets('R3-M2: setGlobalSpeed 同步更新 PlaybackController；SettingsPage 响应外部站点变更同步输入框',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWithValue(client),
        playbackProvider.overrideWithValue(playback),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://localhost:5244'), findsOneWidget);

    await tester.runAsync(() async {
      await container.read(settingsProvider.notifier).setGlobalSpeed(1.5);
      await container.read(settingsProvider.notifier).setSite(
            const SiteConfig(baseUrl: 'https://nas.example.com:8443', name: '远程NAS'),
          );
    });
    await tester.pump();

    expect(playback.speed, 1.5);
    expect(find.text('https://nas.example.com:8443'), findsWidgets);
    // 顶部连接状态胶囊与备注输入框均同步显示新站点名
    expect(find.text('远程NAS'), findsWidgets);
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller?.text, '远程NAS');

    await closePage(tester);
  });
}

class _MultiSortAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'code': 200,
        'message': 'success',
        'data': {
          'content': [
            {'name': 'ep10.mp3', 'is_dir': false, 'size': 1024},
            {'name': 'ep2.mp3', 'is_dir': false, 'size': 1024},
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
