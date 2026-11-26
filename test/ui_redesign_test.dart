/// UI 改版专项组件测试（Phase 1–3）：
/// 1. SettingsPage 三态主题切换与 SharedPreferences 持久化
/// 2. HomePage 最近播放流展示与「清空」弹窗确认
/// 3. BrowserPage 目录内即时筛选 + 媒体级进度条 / 「✓ 已播」徽章展示
/// 4. AudioPage 一屏主控（±15s 步进、0.1x 精细倍速面板、睡眠定时面板、队列抽屉、LRC 歌词切换）
library;

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
import 'package:openlistplayer/ui/app_theme.dart';
import 'package:openlistplayer/ui/browser/browser_page.dart';
import 'package:openlistplayer/ui/home/home_page.dart';
import 'package:openlistplayer/ui/player/audio_page.dart';
import 'package:openlistplayer/ui/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playback_controller_test.dart' show FakePlayerBackend;

class _RedesignFakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/fs/list') {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 200,
          'data': {
            'content': [
              {'name': 'ep01_intro.flac', 'is_dir': false, 'size': 4096},
              {'name': 'ep01_intro.lrc', 'is_dir': false, 'size': 128},
              {'name': 'ep02_story.mp3', 'is_dir': false, 'size': 2048},
              {'name': 'ep03_finale.mp3', 'is_dir': false, 'size': 2048},
            ],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/api/fs/get') {
      final body = (options.data as Map<String, dynamic>?) ?? const {};
      final path = body['path'] as String? ?? '';
      return ResponseBody.fromString(
        jsonEncode({
          'code': 200,
          'data': {
            'name': path.split('/').last,
            'raw_url': 'http://cdn$path',
            'size': path.endsWith('.lrc') ? 128 : 4096,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.uri.toString().endsWith('.lrc')) {
      return ResponseBody.fromString(
        '[00:01.00]云端第一句歌词\n[00:10.00]云端第二句歌词\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      );
    }
    return ResponseBody.fromString('', 404);
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
      'site.name': '家里NAS',
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio()..httpClientAdapter = _RedesignFakeAdapter();
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

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('SettingsPage 三态主题切换并持久化至 SharedPreferences', (tester) async {
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
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).themePreference, AppThemePreference.light);
    expect(find.text('主题模式'), findsOneWidget);

    await tester.tap(find.text('深色'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).themePreference, AppThemePreference.dark);
    expect(SettingsService(prefs).load().themePreference, AppThemePreference.dark);

    await tester.tap(find.text('跟随系统'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).themePreference, AppThemePreference.system);
    expect(SettingsService(prefs).load().themePreference, AppThemePreference.system);

    await closePage(tester);
  });

  testWidgets('HomePage 展示最近播放记录并支持弹窗清空', (tester) async {
    await tester.runAsync(() async {
      await db.touchHistory(const QueueItem(
        path: '/books/ch01.mp3',
        name: '第一章 序幕.mp3',
        isVideo: false,
      ));
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
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    try {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('最近播放'), findsOneWidget);
      expect(find.text('第一章 序幕.mp3'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(find.text('清空最近播放'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '清空'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();

      expect(find.text('第一章 序幕.mp3'), findsNothing);
    } finally {
      await closePage(tester);
    }
  });

  testWidgets('BrowserPage 透出目录级进度条与「已播」徽章，并支持目录内即时筛选', (tester) async {
    await tester.runAsync(() async {
      await db.upsertProgress(
        '/ep01_intro.flac',
        const Duration(seconds: 60),
        const Duration(seconds: 120),
      );
      await db.touchHistory(const QueueItem(
        path: '/ep02_story.mp3',
        name: 'ep02_story.mp3',
        isVideo: false,
      ));
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
        child: MaterialApp(theme: AppTheme.light, home: const BrowserPage()),
      ),
    );
    try {
      await tester.pumpAndSettle();
      // 列表加载完成后挂载目录进度/历史 StreamBuilder，再推进一帧等待 drift 流发出首轮快照
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();

      expect(find.text('ep01_intro.flac'), findsOneWidget);
      expect(find.textContaining('已播 50%'), findsOneWidget);
      expect(find.text('ep02_story.mp3'), findsOneWidget);
      expect(find.text('已播'), findsOneWidget);

      // 打开目录内筛选搜索框并过滤关键字
      await tester.tap(find.byTooltip('目录内筛选'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'finale');
      await tester.pump();

      expect(find.text('ep03_finale.mp3'), findsOneWidget);
      expect(find.text('ep01_intro.flac'), findsNothing);
    } finally {
      await closePage(tester);
    }
  });

  testWidgets('AudioPage 一屏主控：±15s 步进、0.1x 倍速面板、睡眠定时面板、队列抽屉与 LRC 切换',
      (tester) async {
    const items = [
      QueueItem(path: '/ep01_intro.flac', name: 'ep01_intro.flac', isVideo: false),
      QueueItem(path: '/ep02_story.mp3', name: 'ep02_story.mp3', isVideo: false),
    ];
    await tester.runAsync(() async {
      await playback.replaceQueue(items, 0);
      backend.emitDuration(const Duration(seconds: 200));
      backend.emitPosition(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(playback.hasLyrics, isTrue);

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
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(412, 915), disableAnimations: true),
            child: AudioPage(),
          ),
        ),
      ),
    );
    try {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      // 1. 格式徽章（唱片卡角标 + 标题下方元信息）与 LRC 切换按钮可见
      expect(find.text('FLAC 无损'), findsWidgets);
      expect(find.text('词'), findsOneWidget);

      // 2. 点击「词」切换到滚动歌词视图
      await tester.tap(find.text('词'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('云端第一句歌词'), findsOneWidget);

      // 3. 点击快进 15 秒
      await tester.tap(find.byTooltip('快进 15 秒'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(playback.currentPosition, const Duration(seconds: 45));

      // 4. 打开睡眠定时面板并选择「播完本集停」
      await tester.tap(find.text('定时'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('睡眠定时'), findsOneWidget);
      await tester.tap(find.text('播完本集停'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(playback.sleepTimerMode, SleepTimerMode.endOfTrack);
      expect(find.text('本集末'), findsOneWidget);

      // 5. 打开倍速面板并用 +0.1 微调到 1.1x
      await tester.tap(find.text('1x'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('播放速度'), findsOneWidget);
      await tester.tap(find.text('+0.1'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(playback.speed, closeTo(1.1, 0.001));
      await tester.tap(find.byTooltip('关闭'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 6. 打开底部队列抽屉并验证全部曲目可见
      await tester.tap(find.text('1/2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('播放队列'), findsOneWidget);
      expect(find.text('ep02_story.mp3'), findsOneWidget);
      expect(find.text('定位当前'), findsOneWidget);
      Navigator.of(tester.element(find.text('播放队列'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      await tester.runAsync(() => playback.stop());
      await closePage(tester);
    }
  });
}
