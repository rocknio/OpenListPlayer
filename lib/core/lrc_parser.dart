/// 纯 Dart LRC 歌词解析器与同目录 .lrc 匹配：
/// 支持标准 [mm:ss.xx] / [mm:ss.xxx] / [mm:ss] 与同行多时间戳，提供二分查找当前歌词行。
library;

import 'media_types.dart';
import 'natural_sort.dart';

/// 单条歌词行
class LrcLine {
  const LrcLine({required this.time, required this.text});

  final Duration time;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LrcLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);
}

final _tagRe = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// 解析标准 LRC 文本，返回按时间升序排列的非空歌词行列表。
List<LrcLine> parseLrc(String raw) {
  if (raw.isEmpty) return const [];
  final lines = <LrcLine>[];
  var offsetMs = 0;

  // 先扫 offset 标签（如 [offset:500]，单位 ms）
  final offsetMatch = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false).firstMatch(raw);
  if (offsetMatch != null) {
    offsetMs = int.tryParse(offsetMatch.group(1) ?? '') ?? 0;
  }

  for (final rawLine in raw.split(RegExp(r'\r\n|\r|\n'))) {
    final matches = _tagRe.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;
    final text = rawLine.replaceAll(_tagRe, '').trim();
    if (text.isEmpty) continue;
    for (final m in matches) {
      final min = int.tryParse(m.group(1) ?? '') ?? 0;
      final sec = int.tryParse(m.group(2) ?? '') ?? 0;
      final fracStr = m.group(3);
      var ms = 0;
      if (fracStr != null) {
        if (fracStr.length == 1) {
          ms = int.parse(fracStr) * 100;
        } else if (fracStr.length == 2) {
          ms = int.parse(fracStr) * 10;
        } else {
          ms = int.parse(fracStr.substring(0, 3));
        }
      }
      final totalMs = (min * 60 + sec) * 1000 + ms + offsetMs;
      lines.add(LrcLine(
        time: Duration(milliseconds: totalMs < 0 ? 0 : totalMs),
        text: text,
      ));
    }
  }

  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

/// 二分查找当前播放位置对应的歌词行索引；尚未到达第一句或列表为空返回 -1。
int findActiveLrcIndex(List<LrcLine> lines, Duration position) {
  if (lines.isEmpty || position < lines.first.time) return -1;
  var lo = 0;
  var hi = lines.length - 1;
  var ans = 0;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}

/// 判断是否为 LRC 歌词文件
bool isLrcFile(String name) => fileExtension(name) == 'lrc';

/// 从同目录文件名中匹配与音频 [audioName] 对应的 `.lrc` 文件：
/// 精确同名（`song.lrc`）优先，其次同前缀带后缀（`song.chs.lrc`），无匹配返回 null。
String? matchLrcFile(String audioName, Iterable<String> siblingNames) {
  final audioLower = audioName.toLowerCase();
  final baseLower = basenameWithoutExt(audioName).toLowerCase();
  final prefixDot = '$baseLower.';
  final exact = <String>[];
  final suffixed = <String>[];
  for (final name in siblingNames) {
    if (name.toLowerCase() == audioLower) continue;
    if (!isLrcFile(name)) continue;
    final lrcBase = basenameWithoutExt(name).toLowerCase();
    if (lrcBase == baseLower) {
      exact.add(name);
    } else if (lrcBase.startsWith(prefixDot)) {
      suffixed.add(name);
    }
  }
  if (exact.isNotEmpty) {
    if (exact.length > 1) exact.sort(compareNatural);
    return exact.first;
  }
  if (suffixed.isNotEmpty) {
    if (suffixed.length > 1) suffixed.sort(compareNatural);
    return suffixed.first;
  }
  return null;
}
