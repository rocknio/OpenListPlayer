/// 外挂字幕匹配：同前缀规则。
/// movie.mkv 匹配 movie.srt、movie.chs.srt、movie.zh.ass（多级后缀均匹配）。
library;

import 'media_types.dart';
import 'natural_sort.dart';

/// 从同目录文件名列表中找出可作为 [videoName] 外挂字幕的文件（按自然序）。
/// 匹配规则：字幕扩展名 && (字幕主名 == 视频主名 || 字幕主名以 "视频主名." 开头)。
/// 例：视频 "Show.S01E02.mkv"（主名 Show.S01E02）匹配 "Show.S01E02.srt"
///     与 "Show.S01E02.chs.srt"，但不匹配 "Show.S01E03.srt"。
/// [siblingNames] 为同目录的兄弟文件名（不含路径）。
List<String> matchSubtitleFiles(String videoName, Iterable<String> siblingNames) {
  final videoBase = basenameWithoutExt(videoName);
  final matches = <String>[];
  for (final name in siblingNames) {
    if (name == videoName) continue;
    if (!isSubtitleFile(name)) continue;
    final subBase = basenameWithoutExt(name);
    if (subBase == videoBase || subBase.startsWith('$videoBase.')) {
      matches.add(name);
    }
  }
  // 排序：精确同名（movie.srt）排最前，其余按自然序
  matches.sort((a, b) {
    final aExact = basenameWithoutExt(a) == videoBase;
    final bExact = basenameWithoutExt(b) == videoBase;
    if (aExact != bExact) return aExact ? -1 : 1;
    return compareNatural(a, b);
  });
  return matches;
}
