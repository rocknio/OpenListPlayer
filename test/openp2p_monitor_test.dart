/// OpenP2pMonitor 状态管理、设置持久化与并发守卫单测。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';
import 'package:openlistplayer/core/openp2p_probe.dart';
import 'package:openlistplayer/data/app_database.dart';
import 'package:openlistplayer/data/openp2p_service.dart';
import 'package:openlistplayer/data/settings_service.dart';
import 'package:openlistplayer/player/playback_controller.dart';
import 'package:openlistplayer/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playback_controller_test.dart' show FakePlayerBackend;

class FakeOpenP2pBridge implements OpenP2pBridge {
  FakeOpenP2pBridge({
    this.isSupported = true,
    this.installed = true,
    this.launchResult = true,
  });

  @override
  bool isSupported;
  bool installed;
  bool launchResult;
  int installCheckCount = 0;
  final List<String> launchedPackages = [];

  @override
  Future<bool> isAppInstalled(String packageName) async {
    installCheckCount++;
    return installed;
  }

  @override
  Future<bool> launchApp(String packageName) async {
    launchedPackages.add(packageName);
    return launchResult;
  }
}

class _PingAdapter implements HttpClientAdapter {
  _PingAdapter(this.respondOk);
  bool Function() respondOk;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (respondOk()) {
      return ResponseBody.fromString('pong', 200);
    }
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<ProviderContainer> createContainer({
    required Map<String, Object> initialPrefs,
    required FakeOpenP2pBridge bridge,
    required TcpProbe tcpProbe,
    bool Function()? pingOk,
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    final svc = SettingsService(prefs);
    final db = AppDatabase(NativeDatabase.memory());
    final dio = Dio()..httpClientAdapter = _PingAdapter(pingOk ?? () => true);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(svc),
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWith((ref) {
          final site = ref.watch(settingsProvider.select((s) => s.site));
          return OpenListClient(
            site: site ?? const SiteConfig(baseUrl: ''),
            dio: dio,
          );
        }),
        playbackProvider.overrideWith((ref) {
          final c = PlaybackController(
            api: () => ref.read(apiProvider),
            db: db,
            settings: () => ref.read(settingsProvider),
            backend: FakePlayerBackend(),
          );
          ref.onDispose(c.dispose);
          return c;
        }),
        openP2pBridgeProvider.overrideWithValue(bridge),
        openP2pTcpProbeProvider.overrideWithValue(tcpProbe),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return container;
  }

  test('SettingsService 默认开启 checkOpenP2pOnStart 且支持持久化关闭', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = SettingsService(prefs);

    expect(svc.load().checkOpenP2pOnStart, isTrue);
    await svc.saveCheckOpenP2pOnStart(false);
    expect(svc.load().checkOpenP2pOnStart, isFalse);
    expect(prefs.getBool('network.check_openp2p'), isFalse);
  });

  test('非 Android 平台（isSupported == false）静默跳过，不触发原生和网络探测', () async {
    var tcpCalled = false;
    final bridge = FakeOpenP2pBridge(isSupported: false);
    final container = await createContainer(
      initialPrefs: {'site.url': 'http://127.0.0.1:5244'},
      bridge: bridge,
      tcpProbe: (_, _, _) async {
        tcpCalled = true;
        return false;
      },
    );

    final status = await container.read(openP2pMonitorProvider.notifier).check(allowPrompt: true);
    final state = container.read(openP2pMonitorProvider);
    expect(status, OpenP2pStatus.idle);
    expect(state.status, OpenP2pStatus.idle);
    expect(state.shouldPrompt, isFalse);
    expect(tcpCalled, isFalse);
    expect(bridge.installCheckCount, 0);
  });

  test('关闭检测开关或未配置站点时直接跳过并返回 idle', () async {
    final bridge = FakeOpenP2pBridge(isSupported: true);
    final c1 = await createContainer(
      initialPrefs: {
        'site.url': 'http://127.0.0.1:5244',
        'network.check_openp2p': false,
      },
      bridge: bridge,
      tcpProbe: (_, _, _) async => false,
    );
    expect(
      await c1.read(openP2pMonitorProvider.notifier).check(allowPrompt: true),
      OpenP2pStatus.idle,
    );
    expect(c1.read(openP2pMonitorProvider).shouldPrompt, isFalse);

    final c2 = await createContainer(
      initialPrefs: {},
      bridge: bridge,
      tcpProbe: (_, _, _) async => false,
    );
    expect(
      await c2.read(openP2pMonitorProvider.notifier).check(allowPrompt: true),
      OpenP2pStatus.idle,
    );
    expect(c2.read(openP2pMonitorProvider).shouldPrompt, isFalse);
  });

  test('启动未运行时置 shouldPrompt=true，处理后本会话不再二次弹窗', () async {
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true);
    final container = await createContainer(
      initialPrefs: {'site.url': 'http://127.0.0.1:5244'},
      bridge: bridge,
      tcpProbe: (_, _, _) async => false,
    );
    final monitor = container.read(openP2pMonitorProvider.notifier);

    final first = await monitor.check(allowPrompt: true);
    expect(first, OpenP2pStatus.notRunning);
    var state = container.read(openP2pMonitorProvider);
    expect(state.shouldPrompt, isTrue);
    expect(state.needsAttention, isTrue);

    monitor.markPromptHandled();
    state = container.read(openP2pMonitorProvider);
    expect(state.shouldPrompt, isFalse);
    expect(state.hasPromptedThisSession, isTrue);

    await monitor.check(allowPrompt: true);
    expect(container.read(openP2pMonitorProvider).shouldPrompt, isFalse);
    await monitor.check(allowPrompt: false);
    expect(container.read(openP2pMonitorProvider).shouldPrompt, isFalse);
  });

  test('launchOpenP2p 标记已拉起，随后复检连通自动清除提醒和拉起标记', () async {
    var tcpReady = false;
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true, launchResult: true);
    final container = await createContainer(
      initialPrefs: {'site.url': 'http://127.0.0.1:5244'},
      bridge: bridge,
      tcpProbe: (_, _, _) async => tcpReady,
      pingOk: () => tcpReady,
    );
    final monitor = container.read(openP2pMonitorProvider.notifier);

    await monitor.check(allowPrompt: true);
    expect(container.read(openP2pMonitorProvider).needsAttention, isTrue);

    final launched = await monitor.launchOpenP2p();
    expect(launched, isTrue);
    expect(bridge.launchedPackages, [kOpenP2pPackageName]);
    expect(container.read(openP2pMonitorProvider).launchedThisSession, isTrue);

    tcpReady = true;
    final next = await monitor.check(allowPrompt: false);
    expect(next, OpenP2pStatus.connected);
    final state = container.read(openP2pMonitorProvider);
    expect(state.needsAttention, isFalse);
    expect(state.launchedThisSession, isFalse);
  });

  test('并发竞态守卫：探测挂起期间调用 reset() 后，迟到的旧结果不会覆盖状态或弹窗', () async {
    final completer = Completer<bool>();
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true);
    final container = await createContainer(
      initialPrefs: {'site.url': 'http://127.0.0.1:5244'},
      bridge: bridge,
      tcpProbe: (_, _, _) => completer.future,
    );
    final monitor = container.read(openP2pMonitorProvider.notifier);

    final pending = monitor.check(allowPrompt: true);
    expect(container.read(openP2pMonitorProvider).isChecking, isTrue);

    monitor.reset();
    expect(container.read(openP2pMonitorProvider).status, OpenP2pStatus.idle);
    expect(container.read(openP2pMonitorProvider).isChecking, isFalse);

    completer.complete(false);
    await pending;

    final state = container.read(openP2pMonitorProvider);
    expect(state.status, OpenP2pStatus.idle);
    expect(state.shouldPrompt, isFalse);
  });

  test('复检期间保留既有异常 status 且置 isChecking=true，不引起横幅闪退', () async {
    var firstDone = false;
    final secondCompleter = Completer<bool>();
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true);
    final container = await createContainer(
      initialPrefs: {'site.url': 'http://127.0.0.1:5244'},
      bridge: bridge,
      tcpProbe: (_, _, _) async {
        if (!firstDone) {
          firstDone = true;
          return false;
        }
        return secondCompleter.future;
      },
    );
    final monitor = container.read(openP2pMonitorProvider.notifier);

    await monitor.check(allowPrompt: true);
    expect(container.read(openP2pMonitorProvider).status, OpenP2pStatus.notRunning);
    expect(container.read(openP2pMonitorProvider).isChecking, isFalse);

    final recheck = monitor.check(allowPrompt: false);
    final during = container.read(openP2pMonitorProvider);
    expect(during.isChecking, isTrue);
    expect(during.status, OpenP2pStatus.notRunning);
    expect(during.needsAttention, isTrue);

    secondCompleter.complete(true);
    await recheck;
    final after = container.read(openP2pMonitorProvider);
    expect(after.isChecking, isFalse);
    expect(after.status, OpenP2pStatus.connected);
    expect(after.needsAttention, isFalse);
  });

  test('保存新站点与重新开启检测开关时自动静默刷新状态，关闭开关取消在途探测', () async {
    final inFlight = Completer<bool>();
    var probeCalls = 0;
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true);
    final container = await createContainer(
      initialPrefs: {'network.check_openp2p': false},
      bridge: bridge,
      tcpProbe: (_, _, _) {
        probeCalls++;
        if (probeCalls == 1) return Future.value(false);
        return inFlight.future;
      },
    );
    final settingsNotifier = container.read(settingsProvider.notifier);

    // 配置新站点（此时开关关闭，不探测）
    await settingsNotifier.setSite(const SiteConfig(baseUrl: 'http://127.0.0.1:5244'));
    await Future<void>.delayed(Duration.zero);
    expect(probeCalls, 0);
    expect(container.read(openP2pMonitorProvider).status, OpenP2pStatus.idle);

    // 打开检测开关 → 自动静默探测（不弹窗）
    await settingsNotifier.setCheckOpenP2pOnStart(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(probeCalls, 1);
    final afterEnable = container.read(openP2pMonitorProvider);
    expect(afterEnable.status, OpenP2pStatus.notRunning);
    expect(afterEnable.shouldPrompt, isFalse);

    // 更换新站点地址 → reset 后自动发起新一轮探测；挂起期间关闭开关应作废旧探测
    await settingsNotifier.setSite(const SiteConfig(baseUrl: 'http://127.0.0.1:5245'));
    await Future<void>.delayed(Duration.zero);
    expect(probeCalls, 2);
    expect(container.read(openP2pMonitorProvider).isChecking, isTrue);

    await settingsNotifier.setCheckOpenP2pOnStart(false);
    inFlight.complete(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(openP2pMonitorProvider).status, OpenP2pStatus.idle);
    expect(container.read(openP2pMonitorProvider).isChecking, isFalse);
  });

  test('拉起 OpenP2P 后切回前台（checkOnResume）：首次未就绪自动轮询，隧道就绪后立即停止并切为 connected',
      () async {
    var attempts = 0;
    final bridge = FakeOpenP2pBridge(isSupported: true, installed: true, launchResult: true);
    SharedPreferences.setMockInitialValues({'site.url': 'http://127.0.0.1:5244'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final dio = Dio()..httpClientAdapter = _PingAdapter(() => attempts >= 3);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
        dbProvider.overrideWithValue(db),
        apiProvider.overrideWith((ref) {
          final site = ref.watch(settingsProvider.select((s) => s.site));
          return OpenListClient(
            site: site ?? const SiteConfig(baseUrl: ''),
            dio: dio,
          );
        }),
        playbackProvider.overrideWith((ref) {
          final c = PlaybackController(
            api: () => ref.read(apiProvider),
            db: db,
            settings: () => ref.read(settingsProvider),
            backend: FakePlayerBackend(),
          );
          ref.onDispose(c.dispose);
          return c;
        }),
        openP2pBridgeProvider.overrideWithValue(bridge),
        openP2pTcpProbeProvider.overrideWithValue((_, _, _) async {
          attempts++;
          return attempts >= 3;
        }),
        openP2pPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 20)),
        openP2pMaxPollAttemptsProvider.overrideWithValue(5),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final monitor = container.read(openP2pMonitorProvider.notifier);
    // 1. 冷启动探测（第 1 次失败）
    expect(await monitor.check(allowPrompt: true), OpenP2pStatus.notRunning);
    monitor.markPromptHandled();

    // 2. 用户点启动 OpenP2P
    expect(await monitor.launchOpenP2p(), isTrue);

    // 3. 切回云序瞬间（第 2 次仍未就绪）→ 进入自动轮询等待状态
    final resumeResult = await monitor.checkOnResume();
    expect(resumeResult, OpenP2pStatus.notRunning);
    expect(container.read(openP2pMonitorProvider).isWaitingForTunnel, isTrue);

    // 4. 等待轮询触发第 3 次探测成功 → 自动变为 connected 并结束轮询
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final finalState = container.read(openP2pMonitorProvider);
    expect(finalState.status, OpenP2pStatus.connected);
    expect(finalState.isWaitingForTunnel, isFalse);
    expect(finalState.needsAttention, isFalse);
    expect(finalState.shouldPrompt, isFalse);
  });
}
