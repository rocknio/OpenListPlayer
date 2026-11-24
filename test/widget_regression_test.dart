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
import 'package:openlistplayer/ui/player/audio_page.dart';
import 'package:openlistplayer/ui/playlist/playlists_page.dart';
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

  testWidgets('H-8: HomePage 继续播放卡片在开播后自动隐藏、停止回到 idle 后重新显示', (tester) async {
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
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );

    // 恢复态 idle：显示继续播放卡片（标题 + 按钮共 2 处"继续播放"，此处校验卡片按钮）
    expect(find.text('第一集.mp3'), findsOneWidget);
    expect(find.text('音频 · /music'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    // 模拟在其它页面开播：status 变为 playing 并 notifyListeners()
    await tester.runAsync(() => playback.replaceQueue(const [item], 0));
    await tester.pump();

    // 首页常驻未重建，但因 ListenableBuilder 包裹，继续播放卡片应立即消失
    expect(find.text('音频 · /music'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    // 停止回到 idle：继续播放卡片重新显示
    await tester.runAsync(() => playback.stop());
    await tester.pump();
    expect(find.text('音频 · /music'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await closePage(tester);
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

    // 长按选中唯一文件进入多选态
    await tester.longPress(find.text('sub_song.mp3'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsOneWidget);

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
}
