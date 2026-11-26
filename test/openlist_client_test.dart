/// OpenListClient 与 SiteConfig 单元测试：请求头数组解析、代理路径特殊字符编码、403 静默降级、URL 校验与值相等。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/openlist_client.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, Map<String, dynamic>? jsonBody) handler;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic>? body;
    if (options.data is Map<String, dynamic>) {
      body = options.data as Map<String, dynamic>;
    }
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

ResponseBody _jsonResp(Map<String, dynamic> data, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  group('SiteConfig 校验与值相等', () {
    test('tryNormalizeUrl 去除多个末尾斜杠并校验协议与主机', () {
      expect(SiteConfig.tryNormalizeUrl('  http://192.168.2.29:5244/// '), 'http://192.168.2.29:5244');
      expect(SiteConfig.tryNormalizeUrl('https://alist.example.com/sub/'), 'https://alist.example.com/sub');
      expect(SiteConfig.tryNormalizeUrl('192.168.2.29:5244'), isNull);
      expect(SiteConfig.tryNormalizeUrl('http://'), isNull);
      expect(SiteConfig.tryNormalizeUrl('ftp://192.168.1.1'), isNull);
      expect(SiteConfig.tryNormalizeUrl('   '), isNull);
    });

    test('值相等与 hashCode 一致', () {
      const a = SiteConfig(baseUrl: 'http://192.168.2.29:5244', name: '家里');
      const b = SiteConfig(baseUrl: 'http://192.168.2.29:5244', name: '家里');
      const c = SiteConfig(baseUrl: 'http://192.168.2.30:5244', name: '家里');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('OpenListClient 直链与代理编码', () {
    test('H-1: Go http.Header 字符串数组不产生方括号，Cookie 用分号拼接', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((options, _) {
        expect(options.path, '/api/fs/get');
        return _jsonResp({
          'code': 200,
          'message': 'success',
          'data': {
            'name': 'ep01.mp4',
            'size': 1024,
            'raw_url': 'https://cdn.example.com/ep01.mp4',
            'header': {
              'Referer': ['https://cloud.189.cn/'],
              'User-Agent': ['Mozilla/5.0'],
              'Cookie': ['a=1', 'b=2'],
              'X-Custom': 'plain',
              'X-Empty': <String>[],
            },
          },
        });
      });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://192.168.2.29:5244///'),
        dio: dio,
      );

      final link = await client.getFileLink('/视频/ep01.mp4');
      expect(link.url, 'https://cdn.example.com/ep01.mp4');
      expect(link.headers['Referer'], 'https://cloud.189.cn/');
      expect(link.headers['User-Agent'], 'Mozilla/5.0');
      expect(link.headers['Cookie'], 'a=1; b=2');
      expect(link.headers['X-Custom'], 'plain');
      expect(link.headers.containsKey('X-Empty'), isFalse);
    });

    test('H-2: raw_url 为空回退 /d 代理时，正确编码 # / ? / % / 中文及 sign 参数', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((_, _) {
        return _jsonResp({
          'code': 200,
          'message': 'success',
          'data': {
            'name': 'C#教程 #01 100%?.mp4',
            'size': 2048,
            'raw_url': '',
            'sign': 'abc+def/123=456',
          },
        });
      });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://192.168.2.29:5244/'),
        dio: dio,
      );

      final link = await client.getFileLink('/天翼云盘/C#教程 #01 100%?.mp4');
      expect(
        link.url,
        'http://192.168.2.29:5244/d/%E5%A4%A9%E7%BF%BC%E4%BA%91%E7%9B%98/'
        'C%23%E6%95%99%E7%A8%8B%20%2301%20100%25%3F.mp4?sign=abc%2Bdef%2F123%3D456',
      );
      final parsed = Uri.parse(link.url);
      expect(parsed.fragment, isEmpty);
      expect(parsed.queryParameters['sign'], 'abc+def/123=456');
    });
  });

  group('OpenListClient 403 下拉刷新静默降级与连接释放', () {
    test('业务码 403（即使提示为中文不含 refresh）自动降级为 refresh=false', () async {
      final refreshFlags = <bool>[];
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((_, body) {
        final r = body?['refresh'] as bool? ?? false;
        refreshFlags.add(r);
        if (r) {
          return _jsonResp({'code': 403, 'message': '访客无刷新权限'});
        }
        return _jsonResp({
          'code': 200,
          'message': 'success',
          'data': {
            'content': [
              {'name': '01.mp3', 'is_dir': false, 'size': 100},
            ],
          },
        });
      });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://localhost:5244'),
        dio: dio,
      );

      final list = await client.listDir('/music', refresh: true);
      expect(refreshFlags, [true, false]);
      expect(list.single.name, '01.mp3');
    });

    test('HTTP 状态码 403 DioException 同样自动降级为 refresh=false', () async {
      final refreshFlags = <bool>[];
      final dio = Dio();
      final adapter = _MockAdapter((_, body) {
        final r = body?['refresh'] as bool? ?? false;
        refreshFlags.add(r);
        if (r) {
          return _jsonResp({'message': 'Forbidden'}, statusCode: 403);
        }
        return _jsonResp({
          'code': 200,
          'message': 'success',
          'data': {
            'content': [
              {'name': '02.mkv', 'is_dir': false, 'size': 200},
            ],
          },
        });
      });
      dio.httpClientAdapter = adapter;
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://localhost:5244'),
        dio: dio,
      );

      final list = await client.listDir('/video', refresh: true);
      expect(refreshFlags, [true, false]);
      expect(list.single.name, '02.mkv');

      client.close();
      expect(adapter.closed, isTrue);
    });

    test('未配置站点地址时抛出清晰的 OpenListApiException', () async {
      final client = OpenListClient(site: const SiteConfig(baseUrl: ''));
      await expectLater(
        client.getFileLink('/a.mp4'),
        throwsA(isA<OpenListApiException>()),
      );
      client.close();
    });

    test('R1-M1: 网关返回非 JSON 对象时抛出 OpenListApiException 而非 TypeError', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((_, _) {
          return ResponseBody.fromString(
            '<html>502 Bad Gateway</html>',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          );
        });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://localhost:5244'),
        dio: dio,
      );
      await expectLater(
        client.listDir('/'),
        throwsA(isA<OpenListApiException>()),
      );
      client.close();
    });

    test('R1-M1: 站内相对路径 raw_url / thumb 自动补全站点 baseUrl，且 /ping 容忍首尾空白', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options, _) {
          if (options.path == '/ping') {
            return ResponseBody.fromString('pong\n', 200);
          }
          if (options.path == '/api/fs/list') {
            return _jsonResp({
              'code': 200,
              'data': {
                'content': [
                  {'name': 'cover_song.mp3', 'is_dir': false, 'size': 512, 'thumb': '/p/thumb/1.jpg'},
                  'invalid_element_ignored',
                ],
              },
            });
          }
          return _jsonResp({
            'code': 200,
            'data': {
              'name': 'cover_song.mp3',
              'raw_url': '/d/music/cover_song.mp3?sign=xyz',
              'size': 512,
            },
          });
        });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'http://192.168.2.29:5244/'),
        dio: dio,
      );

      final count = await client.testConnection();
      expect(count, 1);
      final entries = await client.listDir('/');
      expect(entries.single.thumb, 'http://192.168.2.29:5244/p/thumb/1.jpg');
      final link = await client.getFileLink('/music/cover_song.mp3');
      expect(link.url, 'http://192.168.2.29:5244/d/music/cover_song.mp3?sign=xyz');
      client.close();
    });

    test('R2-M2: 协议相对 URL (//cdn...) 继承站点协议，子路径反代部署避免重复拼接前缀', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((options, _) {
          if (options.path == '/api/fs/list') {
            return _jsonResp({
              'code': 200,
              'data': {
                'content': [
                  {'name': 'ep1.mkv', 'is_dir': false, 'size': 1024, 'thumb': '//cdn.example.com/t1.jpg'},
                  {'name': 'ep2.mkv', 'is_dir': false, 'size': 1024, 'thumb': 'HTTPS://img.example.com/t2.jpg'},
                ],
              },
            });
          }
          return _jsonResp({
            'code': 200,
            'data': {
              'name': 'ep1.mkv',
              'raw_url': '/alist/d/video/ep1.mkv?sign=123',
              'size': 1024,
            },
          });
        });
      final client = OpenListClient(
        site: const SiteConfig(baseUrl: 'https://nas.example.com/alist'),
        dio: dio,
      );

      final entries = await client.listDir('/');
      expect(entries[0].thumb, 'https://cdn.example.com/t1.jpg');
      expect(entries[1].thumb, 'HTTPS://img.example.com/t2.jpg');

      final link = await client.getFileLink('/video/ep1.mkv');
      expect(link.url, 'https://nas.example.com/alist/d/video/ep1.mkv?sign=123');
      client.close();
    });
  });
}
