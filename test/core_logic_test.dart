/// 领域逻辑单测：自然排序 / 字幕前缀匹配 / 进度规则 / 队列构建（同目录替换语义）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/media_types.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/natural_sort.dart';
import 'package:openlistplayer/core/queue_builder.dart';
import 'package:openlistplayer/core/subtitle_match.dart';

void main() {
  group('自然排序', () {
    test('数字按数值比较：2 < 10 < 100', () {
      final names = ['ep10', 'ep2', 'ep100', 'ep1'];
      names.sort(compareNatural);
      expect(names, ['ep1', 'ep2', 'ep10', 'ep100']);
    });

    test('多位数字段混合：track12 < track100', () {
      final names = ['track100', 'track12'];
      names.sort(compareNatural);
      expect(names, ['track12', 'track100']);
    });

    test('前导零数值相等保持稳定', () {
      expect(compareNatural('007', '7'), 0);
    });

    test('中文名正常参与排序', () {
      final names = ['第2集', '第10集', '第1集'];
      names.sort(compareNatural);
      expect(names, ['第1集', '第2集', '第10集']);
    });

    test('忽略大小写', () {
      expect(compareNatural('ABC', 'abc'), 0);
    });
  });

  group('媒体扩展名判定', () {
    test('大小写不敏感', () {
      expect(isVideoFile('A.MKV'), isTrue);
      expect(isAudioFile('Song.Flac'), isTrue);
    });

    test('无扩展名视为非媒体', () {
      expect(isMediaFile('noext'), isFalse);
      expect(isMediaFile('.hidden'), isFalse);
    });

    test('非白名单扩展名', () {
      expect(isMediaFile('doc.pdf'), isFalse);
      expect(isSubtitleFile('sub.srt'), isTrue);
      expect(isSubtitleFile('sub.idx'), isFalse);
    });
  });

  group('字幕前缀匹配', () {
    test('同名匹配', () {
      expect(matchSubtitleFiles('movie.mkv', ['movie.srt', 'other.srt']), ['movie.srt']);
    });

    test('多级后缀匹配：movie.chs.srt / movie.zh.ass', () {
      final m = matchSubtitleFiles('movie.mkv', ['movie.srt', 'movie.chs.srt', 'movie.zh.ass', 'movie2.srt']);
      expect(m, ['movie.srt', 'movie.chs.srt', 'movie.zh.ass']);
    });

    test('不匹配相邻剧集', () {
      expect(matchSubtitleFiles('Show.S01E02.mkv', ['Show.S01E03.srt']), isEmpty);
    });

    test('vtt 与 ass 均支持', () {
      expect(matchSubtitleFiles('a.mp4', ['a.ass', 'a.vtt']), ['a.ass', 'a.vtt']);
    });
  });

  group('进度规则', () {
    test('短于 10 秒不记录', () {
      expect(ProgressRules.shouldRecord(const Duration(seconds: 9)), isFalse);
      expect(ProgressRules.shouldRecord(const Duration(seconds: 10)), isTrue);
    });

    test('≥95% 视为看完', () {
      expect(ProgressRules.isFinished(const Duration(minutes: 95), const Duration(minutes: 100)), isTrue);
      expect(ProgressRules.isFinished(const Duration(minutes: 94), const Duration(minutes: 100)), isFalse);
    });

    test('零时长不算看完', () {
      expect(ProgressRules.isFinished(Duration.zero, Duration.zero), isFalse);
    });
  });

  group('队列构建（同目录整体替换）', () {
    final entries = [
      FsEntry(name: 'dir1', isDirectory: true, size: 0, modified: null),
      FsEntry(name: 'b.mp3', isDirectory: false, size: 100, modified: null),
      FsEntry(name: 'a.mp4', isDirectory: false, size: 200, modified: null),
      FsEntry(name: 'ep10.mkv', isDirectory: false, size: 300, modified: null),
      FsEntry(name: 'ep2.mkv', isDirectory: false, size: 300, modified: null),
      FsEntry(name: 'doc.pdf', isDirectory: false, size: 50, modified: null),
      FsEntry(name: 'c.flac', isDirectory: false, size: 400, modified: null),
    ];

    test('只含音视频、目录排除、自然排序、路径正确', () {
      final q = buildQueueFromDir('/天翼云盘/我的视频', entries, SortMode.natural);
      expect(q.map((e) => e.name).toList(), ['a.mp4', 'b.mp3', 'c.flac', 'ep2.mkv', 'ep10.mkv']);
      expect(q.first.path, '/天翼云盘/我的视频/a.mp4');
      expect(q.first.isVideo, isTrue);
      expect(q[1].isVideo, isFalse);
    });

    test('根目录路径拼接', () {
      final q = buildQueueFromDir('/', entries, SortMode.natural);
      expect(q.first.path, '/a.mp4');
    });

    test('目录排序：目录在前', () {
      final sorted = sortEntries(entries, SortMode.natural);
      expect(sorted.first.isDirectory, isTrue);
    });
  });
}
