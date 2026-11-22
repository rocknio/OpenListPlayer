/// 媒体文件类型判定：扩展名白名单，大小写不敏感，无扩展名视为非媒体。
library;

const Set<String> kVideoExtensions = {
  'mkv', 'mp4', 'avi', 'mov', 'webm', 'ts', 'm2ts', 'flv', 'wmv', 'm4v', '3gp',
};

const Set<String> kAudioExtensions = {
  'mp3', 'flac', 'aac', 'm4a', 'wav', 'ogg', 'opus', 'ape', 'wma',
};

const Set<String> kSubtitleExtensions = {'srt', 'ass', 'vtt'};

String? fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null; // 无扩展名或以 . 开头/结尾
  return name.substring(dot + 1).toLowerCase();
}

/// 去掉最后一个扩展名后的主名（含次级扩展名，如 "movie.chs"）。
String basenameWithoutExt(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

bool isVideoFile(String name) => kVideoExtensions.contains(fileExtension(name));

bool isAudioFile(String name) => kAudioExtensions.contains(fileExtension(name));

bool isMediaFile(String name) => isVideoFile(name) || isAudioFile(name);

bool isSubtitleFile(String name) => kSubtitleExtensions.contains(fileExtension(name));
