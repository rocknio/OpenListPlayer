/// 领域模型：站点配置、网盘条目、队列条目、播放进度规则。
library;

/// 服务器站点配置。v1 单站点无认证；预留 token 扩展位。
class SiteConfig {
  const SiteConfig({required this.baseUrl, this.name, this.token});

  /// 站点根地址，如 http://192.168.2.29:5244 （末尾不带 /）
  final String baseUrl;
  final String? name;
  // ignore: unused_field —— 预留 OpenList 登录认证扩展
  final String? token;

  String get display => name?.isNotEmpty == true ? name! : baseUrl;

  SiteConfig copyWith({String? baseUrl, String? name, String? token}) => SiteConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        name: name ?? this.name,
        token: token ?? this.token,
      );

  /// 拼接 OpenList REST API 地址
  Uri apiUri(String path) => Uri.parse('$baseUrl$path');
}

/// 网盘目录条目（fs/list 返回的单条）
class FsEntry {
  const FsEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
    this.thumb = '',
  });

  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  /// OpenList 提供的缩略图地址（部分驱动/文件类型为空）
  final String thumb;
}

/// "正在播放"队列 / 手动播单共用的条目
class QueueItem {
  const QueueItem({
    required this.path,
    required this.name,
    required this.isVideo,
    this.size = 0,
    this.thumb = '',
  });

  /// 网盘内绝对路径，如 /天翼云盘/我的视频/movie.mkv
  final String path;
  final String name;
  final bool isVideo;
  final int size;

  /// 封面缩略图地址（可能为空，UI 需回退到占位图标）
  final String thumb;

  /// 父目录路径
  String get parent {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  QueueItem copyWith({String? path, String? name, bool? isVideo, int? size, String? thumb}) =>
      QueueItem(
        path: path ?? this.path,
        name: name ?? this.name,
        isVideo: isVideo ?? this.isVideo,
        size: size ?? this.size,
        thumb: thumb ?? this.thumb,
      );
}

enum PlayMode { sequentialLoop, repeatOne, shuffle }

enum SortMode { natural, name, modified }

enum BufferProfile { smooth, balanced, aggressive }

extension BufferProfileSeconds on BufferProfile {
  int get seconds => switch (this) {
        BufferProfile.smooth => 30,
        BufferProfile.balanced => 60,
        BufferProfile.aggressive => 120,
      };

  String get label => switch (this) {
        BufferProfile.smooth => '流畅 (30s)',
        BufferProfile.balanced => '稳健 (60s)',
        BufferProfile.aggressive => '激进 (120s)',
      };
}

/// 播放进度规则（纯函数，便于单测）
class ProgressRules {
  static const finishedThreshold = 0.95; // ≥95% 视为看完
  static const minRecordDuration = Duration(seconds: 10); // <10s 不记进度

  static bool shouldRecord(Duration duration) =>
      duration >= minRecordDuration && duration.inMilliseconds > 0;

  /// 返回 true 表示该进度已"看完"，应清除进度（下次从头播）
  static bool isFinished(Duration position, Duration duration) {
    if (duration.inMilliseconds <= 0) return false;
    return position.inMilliseconds / duration.inMilliseconds >= finishedThreshold;
  }
}
