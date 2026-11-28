/// Riverpod providers：设置、数据库、OpenList 客户端、播放控制器。
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models.dart';
import 'core/openlist_client.dart';
import 'core/openp2p_probe.dart';
import 'data/app_database.dart';
import 'data/openp2p_service.dart';
import 'data/settings_service.dart';
import 'player/audio_handler.dart';
import 'player/playback_controller.dart';

/// 在 main() 中覆盖注入
final settingsServiceProvider = Provider<SettingsService>((ref) => throw UnimplementedError());

/// 在 main() 中覆盖注入
final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsServiceProvider).load();

  SettingsService get _svc => ref.read(settingsServiceProvider);

  Future<void> setSite(SiteConfig? site) async {
    final prevUrl = state.site?.baseUrl;
    await _svc.saveSite(site);
    final s = _svc.load();
    state = s;
    final nextUrl = s.site?.baseUrl;
    final playback = ref.read(playbackProvider);
    if (prevUrl != nextUrl) {
      final monitor = ref.read(openP2pMonitorProvider.notifier);
      monitor.reset();
      if (nextUrl != null) {
        unawaited(monitor.check(allowPrompt: false));
      }
      await playback.onSiteChanged();
    } else {
      playback.onSettingsChanged();
    }
  }

  Future<void> setSortMode(SortMode mode) async {
    await _svc.saveSortMode(mode);
    state = _svc.load();
  }

  Future<void> setDefaultPlayMode(PlayMode mode) async {
    await _svc.saveDefaultPlayMode(mode);
    state = _svc.load();
    ref.read(playbackProvider).onSettingsChanged();
  }

  Future<void> setVideoBackgroundAudio(bool v) async {
    await _svc.saveVideoBackgroundAudio(v);
    state = _svc.load();
  }

  Future<void> setBufferProfile(BufferProfile p) async {
    await _svc.saveBufferProfile(p);
    state = _svc.load();
    ref.read(playbackProvider).onSettingsChanged();
  }

  Future<void> setGlobalSpeed(double s) async {
    await _svc.saveGlobalSpeed(s);
    state = _svc.load();
    await ref.read(playbackProvider).setSpeed(state.globalSpeed);
  }

  Future<void> setThemePreference(AppThemePreference pref) async {
    await _svc.saveThemePreference(pref);
    state = _svc.load();
  }

  Future<void> setCheckOpenP2pOnStart(bool v) async {
    await _svc.saveCheckOpenP2pOnStart(v);
    state = _svc.load();
    final monitor = ref.read(openP2pMonitorProvider.notifier);
    if (!v) {
      monitor.reset();
    } else if (state.site != null) {
      unawaited(monitor.check(allowPrompt: false));
    }
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

/// OpenList 客户端（随站点地址变化重建）
final apiProvider = Provider<OpenListClient>((ref) {
  final site = ref.watch(settingsProvider.select((s) => s.site));
  final client = OpenListClient(site: site ?? const SiteConfig(baseUrl: ''));
  ref.onDispose(client.close);
  return client;
});

/// 是否已配置站点
final hasSiteProvider = Provider<bool>((ref) => ref.watch(settingsProvider).site != null);

final playbackProvider = Provider<PlaybackController>((ref) {
  final c = PlaybackController(
    api: () => ref.read(apiProvider),
    db: ref.read(dbProvider),
    settings: () => ref.read(settingsProvider),
    onPersistSpeed: (s) async {
      await ref.read(settingsServiceProvider).saveGlobalSpeed(s);
      ref.invalidate(settingsProvider);
    },
  );
  ref.onDispose(c.dispose);
  return c;
});

final audioHandlerProvider = Provider<PlayerAudioHandler>((ref) {
  final h = PlayerAudioHandler(
    ref.read(playbackProvider),
    settings: () => ref.read(settingsProvider),
  );
  ref.onDispose(h.dispose);
  return h;
});

/// SharedPreferences 原始实例（settingsServiceProvider 内部也需要）
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// OpenP2P 原生平台桥接（测试可 override 为假实现）
final openP2pBridgeProvider = Provider<OpenP2pBridge>((ref) => const PlatformOpenP2pBridge());

/// OpenP2P 本地映射端口 TCP 探测函数（测试可 override）
final openP2pTcpProbeProvider = Provider<TcpProbe>((ref) => defaultTcpProbe);

/// 拉起 OpenP2P 切回前台后的隧道轮询间隔（测试可 override 缩短耗时）
final openP2pPollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 2));

/// 拉起 OpenP2P 切回前台后的最大轮询次数（2s × 15 ≈ 30s，覆盖冷启动打洞耗时）
final openP2pMaxPollAttemptsProvider = Provider<int>((ref) => 15);

/// OpenP2P 连通性监控 Notifier：管理探测序号守卫、会话内单次弹窗与切回隧道轮询。
class OpenP2pMonitor extends Notifier<OpenP2pState> {
  int _serial = 0;
  Future<OpenP2pStatus>? _inFlight;
  Timer? _pollTimer;
  int _pollRemaining = 0;

  @override
  OpenP2pState build() {
    ref.onDispose(_cancelPoll);
    return const OpenP2pState();
  }

  void _cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollRemaining = 0;
  }

  /// 探测当前站点的 OpenP2P 端口映射与 `/ping` 状态。
  /// [allowPrompt]=true 且本会话尚未弹窗时，异常态将置 `shouldPrompt=true`。
  Future<OpenP2pStatus> check({required bool allowPrompt}) {
    final bridge = ref.read(openP2pBridgeProvider);
    final settings = ref.read(settingsProvider);
    final site = settings.site;
    if (!bridge.isSupported || !settings.checkOpenP2pOnStart || site == null) {
      reset();
      return Future.value(OpenP2pStatus.idle);
    }
    final existing = _inFlight;
    if (existing != null) return existing;

    final serial = ++_serial;
    state = state.copyWith(isChecking: true, shouldPrompt: false);

    final future = _runCheck(
      serial: serial,
      allowPrompt: allowPrompt,
      bridge: bridge,
    );
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  /// 从后台切回前台时调用：先静默复检一次；若刚拉起过 OpenP2P 且隧道尚未就绪
  /// （OpenP2P Android 冷启动登录+打洞实测需 12~24s），则启动定时轮询直至连通或超时。
  Future<OpenP2pStatus> checkOnResume() async {
    final shouldPoll = state.launchedThisSession;
    final result = await check(allowPrompt: false);
    if (!ref.mounted) return result;
    if (result == OpenP2pStatus.connected || result == OpenP2pStatus.idle) {
      _cancelPoll();
      if (state.isWaitingForTunnel) {
        state = state.copyWith(isWaitingForTunnel: false);
      }
      return result;
    }
    if (shouldPoll && result != OpenP2pStatus.notInstalled) {
      _startTunnelPolling();
    }
    return result;
  }

  void _startTunnelPolling() {
    _cancelPoll();
    final maxAttempts = ref.read(openP2pMaxPollAttemptsProvider);
    final interval = ref.read(openP2pPollIntervalProvider);
    if (maxAttempts <= 0) return;
    _pollRemaining = maxAttempts;
    state = state.copyWith(isWaitingForTunnel: true);
    debugPrint('[OLP] openp2p: waiting for tunnel (max=$maxAttempts, interval=${interval.inMilliseconds}ms)');
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollTick());
    });
  }

  Future<void> _pollTick() async {
    if (!ref.mounted) {
      _cancelPoll();
      return;
    }
    if (_inFlight != null) return;
    if (_pollRemaining <= 0) {
      _cancelPoll();
      state = state.copyWith(isWaitingForTunnel: false);
      return;
    }
    _pollRemaining--;
    final result = await check(allowPrompt: false);
    if (!ref.mounted) {
      _cancelPoll();
      return;
    }
    if (result == OpenP2pStatus.connected ||
        result == OpenP2pStatus.idle ||
        result == OpenP2pStatus.notInstalled ||
        _pollRemaining <= 0) {
      _cancelPoll();
      if (state.isWaitingForTunnel) {
        state = state.copyWith(isWaitingForTunnel: false);
      }
    }
  }

  Future<OpenP2pStatus> _runCheck({
    required int serial,
    required bool allowPrompt,
    required OpenP2pBridge bridge,
  }) async {
    final site = ref.read(settingsProvider).site;
    if (site == null) return OpenP2pStatus.idle;
    final tcpProbe = ref.read(openP2pTcpProbeProvider);
    final api = ref.read(apiProvider);

    final sw = Stopwatch()..start();
    final result = await probeOpenP2p(
      site: site,
      tcpProbe: tcpProbe,
      pingProbe: (_, timeout) => api.ping(timeout: timeout),
      isAppInstalled: bridge.isAppInstalled,
    );
    sw.stop();
    debugPrint('[OLP] openp2p: probe ${site.baseUrl} -> ${result.name} (${sw.elapsedMilliseconds}ms)');

    if (!ref.mounted || serial != _serial) {
      return ref.mounted ? state.status : OpenP2pStatus.idle;
    }

    final needsAttention = result == OpenP2pStatus.notRunning ||
        result == OpenP2pStatus.unreachable ||
        result == OpenP2pStatus.notInstalled;
    final prompt = allowPrompt && needsAttention && !state.hasPromptedThisSession;
    if (result == OpenP2pStatus.connected) {
      _cancelPoll();
    }
    state = state.copyWith(
      status: result,
      isChecking: false,
      isWaitingForTunnel: result == OpenP2pStatus.connected ? false : state.isWaitingForTunnel,
      shouldPrompt: prompt,
      launchedThisSession: result == OpenP2pStatus.connected ? false : state.launchedThisSession,
    );
    return result;
  }

  /// 标记启动弹窗已被展示/处理，避免本会话重复弹窗。
  void markPromptHandled() {
    state = state.copyWith(hasPromptedThisSession: true, shouldPrompt: false);
  }

  /// 拉起手机上的 OpenP2P App。
  Future<bool> launchOpenP2p() async {
    final bridge = ref.read(openP2pBridgeProvider);
    final ok = await bridge.launchApp(kOpenP2pPackageName);
    debugPrint('[OLP] openp2p: launchApp($kOpenP2pPackageName) -> $ok');
    if (!ref.mounted) return ok;
    if (ok) {
      state = state.copyWith(launchedThisSession: true);
    }
    return ok;
  }

  /// 重置状态并使在途探测与轮询失效（站点变更或关闭检测开关时调用）。
  void reset() {
    _serial++;
    _inFlight = null;
    _cancelPoll();
    state = const OpenP2pState();
  }
}

/// OpenP2P 连通性检测与一键拉起状态监控
final openP2pMonitorProvider = NotifierProvider<OpenP2pMonitor, OpenP2pState>(OpenP2pMonitor.new);
