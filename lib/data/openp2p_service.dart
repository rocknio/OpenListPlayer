/// OpenP2P 原生拉起桥接与启动/前后台连通性监控状态。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/openp2p_probe.dart';
import '../providers.dart';

/// 面向 Android 原生包检测与拉起的桥接接口（测试可注入假实现）。
abstract class OpenP2pBridge {
  bool get isSupported;
  Future<bool> isAppInstalled(String packageName);
  Future<bool> launchApp(String packageName);
}

/// 基于 `olp/device` MethodChannel 的真实平台桥接实现（仅 Android 生效）。
class PlatformOpenP2pBridge implements OpenP2pBridge {
  const PlatformOpenP2pBridge();

  static const _channel = MethodChannel('olp/device');

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> isAppInstalled(String packageName) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isAppInstalled',
            {'packageName': packageName},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> launchApp(String packageName) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'launchApp',
            {'packageName': packageName},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// OpenP2P 检测与弹窗提示状态快照。
class OpenP2pState {
  const OpenP2pState({
    this.status = OpenP2pStatus.idle,
    this.hasPromptedThisSession = false,
    this.shouldPrompt = false,
    this.launchedThisSession = false,
  });

  final OpenP2pStatus status;
  final bool hasPromptedThisSession;
  final bool shouldPrompt;
  final bool launchedThisSession;

  bool get needsAttention =>
      status == OpenP2pStatus.notRunning ||
      status == OpenP2pStatus.unreachable ||
      status == OpenP2pStatus.notInstalled;

  OpenP2pState copyWith({
    OpenP2pStatus? status,
    bool? hasPromptedThisSession,
    bool? shouldPrompt,
    bool? launchedThisSession,
  }) =>
      OpenP2pState(
        status: status ?? this.status,
        hasPromptedThisSession: hasPromptedThisSession ?? this.hasPromptedThisSession,
        shouldPrompt: shouldPrompt ?? this.shouldPrompt,
        launchedThisSession: launchedThisSession ?? this.launchedThisSession,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenP2pState &&
          other.status == status &&
          other.hasPromptedThisSession == hasPromptedThisSession &&
          other.shouldPrompt == shouldPrompt &&
          other.launchedThisSession == launchedThisSession;

  @override
  int get hashCode =>
      Object.hash(status, hasPromptedThisSession, shouldPrompt, launchedThisSession);
}

/// OpenP2P 连通性监控 Notifier：管理探测序号守卫、会话内单次弹窗与拉起状态。
class OpenP2pMonitor extends Notifier<OpenP2pState> {
  int _serial = 0;
  Future<OpenP2pStatus>? _inFlight;

  @override
  OpenP2pState build() => const OpenP2pState();

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
    state = state.copyWith(status: OpenP2pStatus.checking, shouldPrompt: false);

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

  Future<OpenP2pStatus> _runCheck({
    required int serial,
    required bool allowPrompt,
    required OpenP2pBridge bridge,
  }) async {
    final site = ref.read(settingsProvider).site;
    if (site == null) return OpenP2pStatus.idle;
    final tcpProbe = ref.read(openP2pTcpProbeProvider);
    final api = ref.read(apiProvider);

    final result = await probeOpenP2p(
      site: site,
      tcpProbe: tcpProbe,
      pingProbe: (_, timeout) => api.ping(timeout: timeout),
      isAppInstalled: bridge.isAppInstalled,
    );

    if (!ref.mounted || serial != _serial) {
      return ref.mounted ? state.status : OpenP2pStatus.idle;
    }

    final needsAttention = result == OpenP2pStatus.notRunning ||
        result == OpenP2pStatus.unreachable ||
        result == OpenP2pStatus.notInstalled;
    final prompt = allowPrompt && needsAttention && !state.hasPromptedThisSession;
    state = state.copyWith(
      status: result,
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
    if (!ref.mounted) return ok;
    if (ok) {
      state = state.copyWith(launchedThisSession: true);
    }
    return ok;
  }

  /// 重置状态并使在途探测结果失效（站点变更或关闭检测开关时调用）。
  void reset() {
    _serial++;
    _inFlight = null;
    state = const OpenP2pState();
  }
}
