/// 纯 Dart OpenP2P 探测逻辑与 OpenListClient.ping 单测。
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';
import 'package:openlistplayer/core/openp2p_probe.dart';

class _StubPingAdapter implements HttpClientAdapter {
  _StubPingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  group('isLoopbackHost 与 resolveUriPort', () {
    test('准确识别回环地址与非回环地址', () {
      expect(isLoopbackHost('127.0.0.1'), isTrue);
      expect(isLoopbackHost('localhost'), isTrue);
      expect(isLoopbackHost('LOCALHOST'), isTrue);
      expect(isLoopbackHost('::1'), isTrue);
      expect(isLoopbackHost('[::1]'), isTrue);

      expect(isLoopbackHost('192.168.2.29'), isFalse);
      expect(isLoopbackHost('example.com'), isFalse);
      expect(isLoopbackHost(''), isFalse);
    });

    test('正确解析显式与缺省端口', () {
      expect(resolveUriPort(Uri.parse('http://127.0.0.1')), 80);
      expect(resolveUriPort(Uri.parse('https://localhost/alist')), 443);
      expect(resolveUriPort(Uri.parse('http://127.0.0.1:5244')), 5244);
    });
  });

  group('probeOpenP2p 本机映射场景', () {
    const localSite = SiteConfig(baseUrl: 'http://127.0.0.1:5244');

    test('TCP 拒连且已安装 cn.openp2p → notRunning，且不调 pingProbe', () async {
      var pingCalled = false;
      String? checkedPkg;
      final status = await probeOpenP2p(
        site: localSite,
        tcpProbe: (host, port, _) async {
          expect(host, '127.0.0.1');
          expect(port, 5244);
          return false;
        },
        pingProbe: (_, __) async {
          pingCalled = true;
          return true;
        },
        isAppInstalled: (pkg) async {
          checkedPkg = pkg;
          return true;
        },
      );
      expect(status, OpenP2pStatus.notRunning);
      expect(pingCalled, isFalse);
      expect(checkedPkg, kOpenP2pPackageName);
    });

    test('TCP 拒连且未安装 cn.openp2p → notInstalled', () async {
      final status = await probeOpenP2p(
        site: localSite,
        tcpProbe: (_, __, ___) async => false,
        pingProbe: (_, __) async => false,
        isAppInstalled: (_) async => false,
      );
      expect(status, OpenP2pStatus.notInstalled);
    });

    test('TCP 通且 /ping 通 → connected', () async {
      final status = await probeOpenP2p(
        site: localSite,
        tcpProbe: (_, __, ___) async => true,
        pingProbe: (_, __) async => true,
        isAppInstalled: (_) async => true,
      );
      expect(status, OpenP2pStatus.connected);
    });

    test('TCP 通但 /ping 失败 → unreachable', () async {
      final status = await probeOpenP2p(
        site: localSite,
        tcpProbe: (_, __, ___) async => true,
        pingProbe: (_, __) async => false,
        isAppInstalled: (_) async => true,
      );
      expect(status, OpenP2pStatus.unreachable);
    });
  });

  group('probeOpenP2p 非本机场景', () {
    const lanSite = SiteConfig(baseUrl: 'http://192.168.2.29:5244');

    test('直接调 pingProbe 不调 tcpProbe，成功返回 connected', () async {
      var tcpCalled = false;
      final status = await probeOpenP2p(
        site: lanSite,
        tcpProbe: (_, __, ___) async {
          tcpCalled = true;
          return false;
        },
        pingProbe: (_, __) async => true,
        isAppInstalled: (_) async => true,
      );
      expect(status, OpenP2pStatus.connected);
      expect(tcpCalled, isFalse);
    });

    test('ping 失败且已安装 cn.openp2p → notRunning', () async {
      final status = await probeOpenP2p(
        site: lanSite,
        tcpProbe: (_, __, ___) async => false,
        pingProbe: (_, __) async => false,
        isAppInstalled: (_) async => true,
      );
      expect(status, OpenP2pStatus.notRunning);
    });

    test('ping 失败且未安装 cn.openp2p → idle（不误报）', () async {
      final status = await probeOpenP2p(
        site: lanSite,
        tcpProbe: (_, __, ___) async => false,
        pingProbe: (_, __) async => false,
        isAppInstalled: (_) async => false,
      );
      expect(status, OpenP2pStatus.idle);
    });
  });

  group('OpenListClient.ping', () {
    test('200 + pong（含换行）返回 true', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubPingAdapter((options) async {
          expect(options.path, '/ping');
          return ResponseBody.fromString('pong\n', 200);
        });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://127.0.0.1:5244'),
        dio: dio,
      );
      expect(await client.ping(), isTrue);
      client.close();
    });

    test('非 pong 响应返回 false', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubPingAdapter(
          (_) async => ResponseBody.fromString('<html>502</html>', 200),
        );
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://127.0.0.1:5244'),
        dio: dio,
      );
      expect(await client.ping(), isFalse);
      client.close();
    });

    test('网络异常与空地址均安全返回 false', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubPingAdapter((options) async {
          throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
        });
      final errClient = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://127.0.0.1:5244'),
        dio: dio,
      );
      expect(await errClient.ping(), isFalse);
      errClient.close();

      final emptyClient = OpenListClient(site: const SiteConfig(baseUrl: ''));
      expect(await emptyClient.ping(), isFalse);
      emptyClient.close();
    });
  });
}
