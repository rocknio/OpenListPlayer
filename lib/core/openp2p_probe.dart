/// 纯 Dart OpenP2P 端口映射与 OpenList 连通性探测逻辑（无 Flutter 依赖）。
library;

import 'dart:io';

import 'models.dart';

/// OpenP2P 官方 Android 客户端包名（github.com/openp2p-cn/openp2p）。
const String kOpenP2pPackageName = 'cn.openp2p';

/// OpenP2P / 站点连通性检测状态。
enum OpenP2pStatus {
  /// 未检测、已跳过或非关注场景
  idle,

  /// 正在探测中
  checking,

  /// 端口映射与 OpenList 服务均已连通
  connected,

  /// OpenP2P 未运行（或服务不通且手机已安装 OpenP2P）
  notRunning,

  /// 本机映射端口已监听，但 `/ping` 失败（隧道未就绪或 OpenList 服务异常）
  unreachable,

  /// 本机映射端口无人监听且手机未安装 OpenP2P
  notInstalled,
}

typedef TcpProbe = Future<bool> Function(String host, int port, Duration timeout);
typedef PingProbe = Future<bool> Function(SiteConfig site, Duration timeout);
typedef AppInstalledChecker = Future<bool> Function(String packageName);

/// 判断主机名是否指向本机回环地址（用于识别 P2P 本地端口映射）。
bool isLoopbackHost(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized == '127.0.0.1' ||
      normalized == 'localhost' ||
      normalized == '::1' ||
      normalized == '[::1]';
}

/// 解析 URI 的目标端口（未显式声明时按 http=80 / https=443 补全）。
int resolveUriPort(Uri uri) {
  if (uri.hasPort && uri.port > 0) return uri.port;
  return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
}

/// 默认 TCP 端口探测：能建立连接即判定端口正在监听并立即释放。
Future<bool> defaultTcpProbe(String host, int port, Duration timeout) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    return true;
  } catch (_) {
    return false;
  } finally {
    socket?.destroy();
  }
}

/// 联合探测 OpenP2P 映射端口与 OpenList `/ping` 连通状态。
Future<OpenP2pStatus> probeOpenP2p({
  required SiteConfig site,
  required TcpProbe tcpProbe,
  required PingProbe pingProbe,
  required AppInstalledChecker isAppInstalled,
  Duration tcpTimeout = const Duration(milliseconds: 1500),
  Duration pingTimeout = const Duration(milliseconds: 2500),
}) async {
  final uri = Uri.tryParse(site.baseUrl);
  if (uri == null || uri.host.isEmpty) {
    return OpenP2pStatus.idle;
  }

  if (isLoopbackHost(uri.host)) {
    final port = resolveUriPort(uri);
    final tcpOk = await tcpProbe(uri.host, port, tcpTimeout);
    if (!tcpOk) {
      final installed = await isAppInstalled(kOpenP2pPackageName);
      return installed ? OpenP2pStatus.notRunning : OpenP2pStatus.notInstalled;
    }
    final pingOk = await pingProbe(site, pingTimeout);
    return pingOk ? OpenP2pStatus.connected : OpenP2pStatus.unreachable;
  }

  // 非本机地址（如局域网直连或 SD-WAN IP）：先 ping，直连能通绝不误报
  final pingOk = await pingProbe(site, pingTimeout);
  if (pingOk) return OpenP2pStatus.connected;
  final installed = await isAppInstalled(kOpenP2pPackageName);
  return installed ? OpenP2pStatus.notRunning : OpenP2pStatus.idle;
}
