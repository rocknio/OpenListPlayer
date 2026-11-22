/// OpenList (AList 系) REST API 客户端。
/// v1 无认证（guest）；预留 token 头扩展位。
library;

import 'package:dio/dio.dart';

import 'models.dart';

class OpenListApiException implements Exception {
  const OpenListApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : '[$statusCode] $message';
}

class OpenListClient {
  OpenListClient({required this.site, Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30))) {
    _dio.options.baseUrl = _normalizeBase(site.baseUrl);
  }

  final SiteConfig site;
  final Dio _dio;

  static String _normalizeBase(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Map<String, String> get _authHeaders => {
        if (site.token != null && site.token!.isNotEmpty) 'Authorization': site.token!,
      };

  /// 连接测试：/ping + 拉根目录。返回根目录条目数，失败抛异常。
  Future<int> testConnection() async {
    final pong = await _dio.get<String>('/ping');
    if (pong.statusCode != 200 || pong.data != 'pong') {
      throw OpenListApiException('服务响应异常: ${pong.data}');
    }
    final entries = await listDir('/');
    return entries.length;
  }

  /// 列目录。[refresh]=true 时让 OpenList 强制从驱动刷新（下拉刷新用）。
  /// guest 账户无刷新权限时自动降级为读缓存重试（静默降级，用户无感）。
  Future<List<FsEntry>> listDir(String path, {bool refresh = false}) async {
    try {
      return await _listDir(path, refresh: refresh);
    } on OpenListApiException catch (e) {
      final isRefreshDenied = e.statusCode == 403 && e.message.toLowerCase().contains('refresh');
      if (refresh && isRefreshDenied) {
        return await _listDir(path, refresh: false);
      }
      rethrow;
    }
  }

  Future<List<FsEntry>> _listDir(String path, {required bool refresh}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/fs/list',
      data: {
        'path': path,
        'password': '',
        'page': 1,
        'per_page': 0,
        'refresh': refresh,
      },
      options: Options(headers: _authHeaders),
    );
    final body = _unwrap(resp.data);
    final content = (body['content'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .map(_toEntry)
        .toList();
    return content;
  }

  FsEntry _toEntry(Map<String, dynamic> e) => FsEntry(
        name: e['name'] as String,
        isDirectory: (e['is_dir'] as bool? ?? false) || (e['type'] == 1),
        size: (e['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.tryParse(e['modified'] as String? ?? ''),
        thumb: e['thumb'] as String? ?? '',
      );

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) throw const OpenListApiException('空响应');
    final code = body['code'] as int? ?? -1;
    if (code != 200) {
      throw OpenListApiException(body['message'] as String? ?? '未知错误', statusCode: code);
    }
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  /// 取文件直链信息（raw_url 可能带签名；header 为部分驱动要求的请求头）。
  Future<FileLink> getFileLink(String path) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/fs/get',
      data: {'path': path, 'password': ''},
      options: Options(headers: _authHeaders),
    );
    final body = _unwrap(resp.data);
    var rawUrl = body['raw_url'] as String? ?? '';
    if (rawUrl.isEmpty) {
      // 兜底：走 OpenList 代理下载地址
      final sign = body['sign'] as String? ?? '';
      rawUrl = '${_dio.options.baseUrl}/d${Uri.encodeFull(path)}${sign.isEmpty ? '' : '?sign=$sign'}';
    }
    final headerRaw = body['header'];
    final headers = <String, String>{};
    if (headerRaw is Map<String, dynamic>) {
      headerRaw.forEach((k, v) => headers[k] = v.toString());
    }
    return FileLink(
      url: rawUrl,
      headers: headers,
      name: body['name'] as String? ?? path.split('/').last,
      size: (body['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 文件直链信息
class FileLink {
  const FileLink({required this.url, this.headers = const {}, this.name = '', this.size = 0});
  final String url;
  final Map<String, String> headers;
  final String name;
  final int size;
}
