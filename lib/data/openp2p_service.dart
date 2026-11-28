/// OpenP2P 原生拉起桥接与状态模型（不反向依赖 providers.dart，保持分层单向）。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/openp2p_probe.dart';

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
/// [isChecking] 与 [status] 分离，复检期间保留既有异常 [status] 防止首页横幅闪退跳动。
class OpenP2pState {
  const OpenP2pState({
    this.status = OpenP2pStatus.idle,
    this.isChecking = false,
    this.isWaitingForTunnel = false,
    this.hasPromptedThisSession = false,
    this.shouldPrompt = false,
    this.launchedThisSession = false,
  });

  final OpenP2pStatus status;
  final bool isChecking;
  final bool isWaitingForTunnel;
  final bool hasPromptedThisSession;
  final bool shouldPrompt;
  final bool launchedThisSession;

  bool get needsAttention =>
      status == OpenP2pStatus.notRunning ||
      status == OpenP2pStatus.unreachable ||
      status == OpenP2pStatus.notInstalled;

  OpenP2pState copyWith({
    OpenP2pStatus? status,
    bool? isChecking,
    bool? isWaitingForTunnel,
    bool? hasPromptedThisSession,
    bool? shouldPrompt,
    bool? launchedThisSession,
  }) =>
      OpenP2pState(
        status: status ?? this.status,
        isChecking: isChecking ?? this.isChecking,
        isWaitingForTunnel: isWaitingForTunnel ?? this.isWaitingForTunnel,
        hasPromptedThisSession: hasPromptedThisSession ?? this.hasPromptedThisSession,
        shouldPrompt: shouldPrompt ?? this.shouldPrompt,
        launchedThisSession: launchedThisSession ?? this.launchedThisSession,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenP2pState &&
          other.status == status &&
          other.isChecking == isChecking &&
          other.isWaitingForTunnel == isWaitingForTunnel &&
          other.hasPromptedThisSession == hasPromptedThisSession &&
          other.shouldPrompt == shouldPrompt &&
          other.launchedThisSession == launchedThisSession;

  @override
  int get hashCode => Object.hash(
        status,
        isChecking,
        isWaitingForTunnel,
        hasPromptedThisSession,
        shouldPrompt,
        launchedThisSession,
      );
}
