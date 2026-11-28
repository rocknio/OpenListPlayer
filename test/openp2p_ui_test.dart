/// OpenP2P 启动弹窗、首页提醒横幅、前后台复检与设置页开关组件测试。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/app.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';
import 'package:openlistplayer/core/openp2p_probe.dart';
import 'package:openlistplayer/data/app_database.dart';
import 'package:openlistplayer/data/settings_service.dart';
import 'package:openlistplayer/player/playback_controller.dart';
import 'package:openlistplayer/providers.dart';
import 'package:openlistplayer/ui/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'openp2p_monitor_test.dart' show FakeOpenP2pBridge;
import 'playback_controller_test.dart' show FakePlayerBackend;

class _FakeOpenListAdapter implements HttpClientAdapter {
  _FakeOpenListAdapter({required this.pingOk});
  bool Function() pingOk;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/ping') {
      if (pingOk()) return ResponseBody.fromString('pong', 200);
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': 200,
        'message': 'success',
        'data': {'content': []},
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
  late bool serviceReady;

  Future<void> initEnv({Map<String, Object>? initialPrefs}) async {
    serviceReady = false;
    SharedPreferences.setMockInitialValues(
      initialPrefs ??
          {
            'site.url': 'http://127.0.0.1:5244',
            'site.name': '家里NAS',
          },
    );
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio()..httpClientAdapter = _FakeOpenListAdapter(pingOk: () => serviceReady);
    client = OpenListClient(
      site: const SiteConfig(baseUrl: 'http://127.0.0.1:5244'),
      dio: dio,
    );
    backend = FakePlayerBackend();
    playback = PlaybackController(
      api: () => client,
      db: db,
      settings: () => SettingsService(prefs).load(),
      backend: backend,
    );
  }

  Future<void> tearDownEnv(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    playback.dispose();
    client.close();
    await db.close();
  }

  testWidgets('启动检测到 OpenP2P 未运行时弹窗，暂不启动后首页保留提醒横幅，连通复检后横幅消失',
      (tester) async {
    await initEnv();
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true, launchResult: true);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
            dbProvider.overrideWithValue(db),
            apiProvider.overrideWithValue(client),
            playbackProvider.overrideWithValue(playback),
            openP2pBridgeProvider.overrideWithValue(bridge),
            openP2pTcpProbeProvider.overrideWithValue((_, __, ___) async => serviceReady),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 自动弹出提示框
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('OpenP2P 似乎未运行'), findsOneWidget);
      expect(find.text('暂不启动'), findsOneWidget);
      expect(find.text('启动 OpenP2P'), findsWidgets);

      // 点击「暂不启动」收起弹窗，首页顶部仍显示横幅
      await tester.tap(find.text('暂不启动'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('OpenP2P 未运行'), findsOneWidget);
      expect(find.text('重新检测'), findsOneWidget);

      // 模拟 OpenP2P 已启动并点击「重新检测」→ 横幅消失且不再二次弹窗
      serviceReady = true;
      await tester.tap(find.text('重新检测'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('OpenP2P 未运行'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    } finally {
      await tearDownEnv(tester);
    }
  });

  testWidgets('点击启动 OpenP2P 调用原生拉起；拉起失败时弹出 SnackBar 提示', (tester) async {
    await initEnv();
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true, launchResult: false);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
            dbProvider.overrideWithValue(db),
            apiProvider.overrideWithValue(client),
            playbackProvider.overrideWithValue(playback),
            openP2pBridgeProvider.overrideWithValue(bridge),
            openP2pTcpProbeProvider.overrideWithValue((_, __, ___) async => false),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final dialogLaunchBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('启动 OpenP2P'),
      );
      expect(dialogLaunchBtn, findsOneWidget);

      await tester.tap(dialogLaunchBtn);
      await tester.pumpAndSettle();

      expect(bridge.launchedPackages, [kOpenP2pPackageName]);
      expect(find.text('未能拉起 OpenP2P，请手动打开'), findsOneWidget);
    } finally {
      await tearDownEnv(tester);
    }
  });

  testWidgets('SettingsPage 启动时检测 OpenP2P 开关默认开启，关闭后持久化至 SharedPreferences',
      (tester) async {
    await initEnv();
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
            dbProvider.overrideWithValue(db),
            apiProvider.overrideWithValue(client),
            playbackProvider.overrideWithValue(playback),
            openP2pBridgeProvider.overrideWithValue(bridge),
            openP2pTcpProbeProvider.overrideWithValue((_, __, ___) async => true),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );

      await tester.pump();
      final tileFinder = find.widgetWithText(SwitchListTile, '启动时检测 OpenP2P');
      expect(tileFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tileFinder).value, isTrue);

      await tester.tap(tileFinder);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(tileFinder).value, isFalse);
      expect(prefs.getBool('network.check_openp2p'), isFalse);
    } finally {
      await tearDownEnv(tester);
    }
  });
}
