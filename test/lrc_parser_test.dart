/// LRC 歌词解析器与同目录 .lrc 文件匹配纯逻辑单测。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/lrc_parser.dart';

void main() {
  group('parseLrc', () {
    test('解析标准厘秒、毫秒、无小数时间戳并按时间升序排列', () {
      const raw = '''
[ti:测试曲目]
[ar:云序]
[00:12.34]第二句
[00:05.5]第一句
[01:02.345]第三句
[01:10]第四句
[00:20.00]
''';
      final lines = parseLrc(raw);
      expect(lines, hasLength(4));
      expect(lines[0], const LrcLine(time: Duration(seconds: 5, milliseconds: 500), text: '第一句'));
      expect(lines[1], const LrcLine(time: Duration(seconds: 12, milliseconds: 340), text: '第二句'));
      expect(lines[2], const LrcLine(time: Duration(minutes: 1, seconds: 2, milliseconds: 345), text: '第三句'));
      expect(lines[3], const LrcLine(time: Duration(minutes: 1, seconds: 10), text: '第四句'));
    });

    test('支持同行多时间戳展开与重复副歌排序', () {
      const raw = '''
[00:10.00][00:40.50]副歌一句
[00:25.00]间奏过门
''';
      final lines = parseLrc(raw);
      expect(lines, hasLength(3));
      expect(lines.map((e) => e.text).toList(), ['副歌一句', '间奏过门', '副歌一句']);
      expect(lines[0].time, const Duration(seconds: 10));
      expect(lines[1].time, const Duration(seconds: 25));
      expect(lines[2].time, const Duration(seconds: 40, milliseconds: 500));
    });

    test('支持 [offset] 正负偏移并对负结果钳位至 0', () {
      const raw = '''
[offset:-2000]
[00:01.00]开头提早
[00:05.50]正常偏移
''';
      final lines = parseLrc(raw);
      expect(lines, hasLength(2));
      expect(lines[0].time, Duration.zero);
      expect(lines[1].time, const Duration(seconds: 3, milliseconds: 500));
    });

    test('空文本或纯元信息返回空列表', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('[ti:只有标题]\n[al:专辑]'), isEmpty);
    });
  });

  group('findActiveLrcIndex', () {
    const lines = [
      LrcLine(time: Duration(seconds: 5), text: 'A'),
      LrcLine(time: Duration(seconds: 10), text: 'B'),
      LrcLine(time: Duration(seconds: 20), text: 'C'),
    ];

    test('边界与二分查找准确', () {
      expect(findActiveLrcIndex(const [], const Duration(seconds: 5)), -1);
      expect(findActiveLrcIndex(lines, const Duration(seconds: 4, milliseconds: 999)), -1);
      expect(findActiveLrcIndex(lines, const Duration(seconds: 5)), 0);
      expect(findActiveLrcIndex(lines, const Duration(seconds: 9, milliseconds: 999)), 0);
      expect(findActiveLrcIndex(lines, const Duration(seconds: 10)), 1);
      expect(findActiveLrcIndex(lines, const Duration(seconds: 15)), 1);
      expect(findActiveLrcIndex(lines, const Duration(seconds: 20)), 2);
      expect(findActiveLrcIndex(lines, const Duration(minutes: 5)), 2);
    });
  });

  group('isLrcFile / matchLrcFile', () {
    test('精确同名优先于同前缀带后缀，忽略大小写且不匹配自身', () {
      expect(isLrcFile('song.lrc'), isTrue);
      expect(isLrcFile('song.LRC'), isTrue);
      expect(isLrcFile('song.srt'), isFalse);

      expect(
        matchLrcFile('ep01.flac', ['ep01.flac', 'ep01.chs.lrc', 'ep01.lrc', 'ep02.lrc']),
        'ep01.lrc',
      );
      expect(
        matchLrcFile('EP01.MP3', ['EP01.MP3', 'ep01.zh.lrc', 'ep01.en.lrc']),
        'ep01.en.lrc',
      );
      expect(
        matchLrcFile('ep01.mp3', ['ep01.mp3', 'ep010.lrc', 'other.lrc']),
        isNull,
      );
    });
  });
}
