/// OpenP2pMonitor 状态管理、设置持久化与并发守卫单测。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';
import 'package:openlistplayer/core/openp2p_probe.dart';
import 'package:openlistplayer/data/openp2p_service.dart';
import 'package:openlistplayer/data/settings_service.dart';
import 'package:openlistplayer/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final dio = Dio()..httpClientAdapter = _PingAdapter(pingOk ?? () => true);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsServiceProvider.overrideWithValue(svc),
        apiProvider.overrideWith((ref) {
          final site = ref.watch(settingsProvider.select((s) => s.site));
          return OpenListClient(
            site: site ?? const SiteConfig(baseUrl: ''),
            dio: dio,
          );
        }),
        openP2pBridgeProvider.overrideWithValue(bridge),
        openP2pTcpProbeProvider.overrideWithValue(tcpProbe),
      ],
    );
    addTearDown(container.dispose);
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
      tcpProbe: (_, __, ___) async {
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
      tcpProbe: (_, __, ___) async => false,
    );
    expect(
      await c1.read(openP2pMonitorProvider.notifier).check(allowPrompt: true),
      OpenP2pStatus.idle,
    );
    expect(c1.read(openP2pMonitorProvider).shouldPrompt, isFalse);

    final c2 = await createContainer(
      initialPrefs: {},
      bridge: bridge,
      tcpProbe: (_, __, ___) async => false,
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
      tcpProbe: (_, __, ___) async => false,
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
      tcpProbe: (_, __, ___) async => tcpReady,
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
      tcpProbe: (_, __, ___) => completer.future,
    );
    final monitor = container.read(openP2pMonitorProvider.notifier);

    final pending = monitor.check(allowPrompt: true);
    expect(container.read(openP2pMonitorProvider).status, OpenP2pStatus.checking);

    monitor.reset();
    expect(container.read(openP2pMonitorProvider).status, OpenP2pStatus.idle);

    completer.complete(false);
    await pending;

    final state = container.read(openP2pMonitorProvider);
    expect(state.status, OpenP2pStatus.idle);
    expect(state.shouldPrompt, isFalse);
  });
}
