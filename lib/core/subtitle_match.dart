/// 外挂字幕匹配：同前缀规则（忽略大小写）。
/// movie.mkv 匹配 movie.srt、Movie.chs.srt、MOVIE.zh.ass（多级后缀均匹配）。
library;

import 'media_types.dart';
import 'natural_sort.dart';

/// 从同目录文件名列表中找出可作为 [videoName] 外挂字幕的文件（按自然序）。
/// 匹配规则：字幕扩展名 && 忽略大小写后 (字幕主名 == 视频主名 || 字幕主名以 "视频主名." 开头)。
/// 例：视频 "Show.S01E02.mkv"（主名 Show.S01E02）匹配 "Show.S01E02.srt"
///     与 "show.s01e02.chs.srt"，但不匹配 "Show.S01E03.srt"。
/// [siblingNames] 为同目录的兄弟文件名（不含路径）。
List<String> matchSubtitleFiles(String videoName, Iterable<String> siblingNames) {
  final videoNameLower = videoName.toLowerCase();
  final videoBaseLower = basenameWithoutExt(videoName).toLowerCase();
  final prefixWithDot = '$videoBaseLower.';
  final exactMatches = <String>[];
  final suffixMatches = <String>[];

  for (final name in siblingNames) {
    if (name.toLowerCase() == videoNameLower) continue;
    if (!isSubtitleFile(name)) continue;
    final subBaseLower = basenameWithoutExt(name).toLowerCase();
    if (subBaseLower == videoBaseLower) {
      exactMatches.add(name);
    } else if (subBaseLower.startsWith(prefixWithDot)) {
      suffixMatches.add(name);
    }
  }

  // 排序：精确同名（movie.srt）排最前，其余按自然序；分桶各自排序避免比较器内重复截取主名
  if (exactMatches.length > 1) exactMatches.sort(compareNatural);
  if (suffixMatches.length > 1) suffixMatches.sort(compareNatural);
  return [...exactMatches, ...suffixMatches];
}
