/// 领域逻辑单测：自然排序 / 字幕前缀匹配 / 进度规则 / 队列构建（同目录替换语义）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/media_types.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/core/natural_sort.dart';
import 'package:openlistplayer/core/playlist_resume.dart';
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

    test('超长数字段（超过 64 位整数上限）与全零块比较准确无溢出', () {
      const a = 'ep0009999999999999999999999999998.mp4';
      const b = 'ep9999999999999999999999999999.mp4';
      const c = 'ep10000000000000000000000000000.mp4';
      expect(compareNatural(a, b), lessThan(0));
      expect(compareNatural(b, c), lessThan(0));
      expect(compareNatural('track000_end', 'track0_end'), 0);
      expect(compareNatural('track000_a', 'track0_b'), lessThan(0));
    });

    test('数字块排在非数字块之前', () {
      final names = ['ep_special.mkv', 'ep1.mkv'];
      names.sort(compareNatural);
      expect(names, ['ep1.mkv', 'ep_special.mkv']);
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

    test('忽略大小写匹配主名，且精确同名始终优先于带后缀字幕', () {
      final m = matchSubtitleFiles(
        'Movie.MKV',
        ['MOVIE.chs.srt', 'movie.srt', 'Movie.eng.ass', 'Movie.MKV'],
      );
      expect(m, ['movie.srt', 'MOVIE.chs.srt', 'Movie.eng.ass']);
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

    test('修改时间排序：队列顺序与文件浏览器列表顺序一致', () {
      final timedEntries = [
        FsEntry(name: 'late.mp3', isDirectory: false, size: 100, modified: DateTime(2026, 5, 3)),
        FsEntry(name: 'early.mp3', isDirectory: false, size: 100, modified: DateTime(2026, 5, 1)),
        FsEntry(name: 'mid.mp4', isDirectory: false, size: 100, modified: DateTime(2026, 5, 2)),
      ];
      final browserOrder = sortEntries(timedEntries, SortMode.modified).map((e) => e.name).toList();
      final queueOrder = buildQueueFromDir('/dir', timedEntries, SortMode.modified).map((e) => e.name).toList();
      expect(queueOrder, ['early.mp3', 'mid.mp4', 'late.mp3']);
      expect(queueOrder, browserOrder);
    });
  });

  group('播单续播定位', () {
    const paths = ['a', 'b', 'c', 'd'];
    PlaylistResume locate({String? last, Set<String> played = const {}, Set<String> finished = const {}}) =>
        locatePlaylistResume(
            paths: paths, lastPlayedPath: last, playedPaths: played, finishedPaths: finished);

    test('从未在本播单播过：播放全部，没有可续播的进度', () {
      expect(locate(), (index: 0, hasProgress: false));
    });

    test('从上次播到的条目续播，即使前面有更早的断点', () {
      expect(locate(last: 'c', played: {'b', 'c'}), (index: 2, hasProgress: true));
    });

    test('上次播到的条目刚打开、进度还没落盘，仍从它开始', () {
      expect(locate(last: 'd'), (index: 3, hasProgress: true));
    });

    test('上次播到的条目已看完：跳到它之后第一个播过且没看完的', () {
      expect(
        locate(last: 'b', played: {'a', 'b', 'c'}, finished: {'a', 'b'}),
        (index: 2, hasProgress: true),
      );
    });

    test('上次播到的条目之后没有未看完的断点：绕回开头', () {
      expect(
        locate(last: 'd', played: {'b', 'c', 'd'}, finished: {'c', 'd'}),
        (index: 1, hasProgress: true),
      );
    });

    test('全部看完：播放全部', () {
      expect(
        locate(last: 'd', played: {'a', 'b', 'c', 'd'}, finished: {'a', 'b', 'c', 'd'}),
        (index: 0, hasProgress: false),
      );
    });

    test('上次播到的条目已看完且没有其它断点：播放全部', () {
      expect(locate(last: 'b', played: {'b'}, finished: {'b'}), (index: 0, hasProgress: false));
    });

    test('没有续播指针（旧数据）：第一个播过且没看完的条目', () {
      // a 没播过、b 已看完、c 有断点 → c
      expect(locate(played: {'b', 'c'}, finished: {'b'}), (index: 2, hasProgress: true));
    });

    test('指针指向的文件已被移出播单：退化为第一个播过且没看完的条目', () {
      expect(locate(last: 'gone', played: {'b', 'c'}, finished: {'b'}), (index: 2, hasProgress: true));
    });

    test('空播单', () {
      expect(
        locatePlaylistResume(paths: [], lastPlayedPath: 'a', playedPaths: {'a'}, finishedPaths: {}),
        (index: 0, hasProgress: false),
      );
    });
  });

  group('R2-M2: SiteConfig.tryNormalizeUrl 边界校验与规整', () {
    test('剥离 Web 端粘贴带入的 #fragment、末尾斜杠并小写化 scheme', () {
      expect(
        SiteConfig.tryNormalizeUrl('  Http://192.168.2.29:5244/#/天翼云盘/视频  '),
        'http://192.168.2.29:5244',
      );
      expect(
        SiteConfig.tryNormalizeUrl('HTTPS://nas.example.com:8443/alist///#/'),
        'https://nas.example.com:8443/alist',
      );
    });

    test('拒绝含 ?query、userInfo、非法协议或越界端口的地址', () {
      expect(SiteConfig.tryNormalizeUrl('http://localhost:5244?token=abc'), isNull);
      expect(SiteConfig.tryNormalizeUrl('http://user:pass@localhost:5244'), isNull);
      expect(SiteConfig.tryNormalizeUrl('ftp://localhost:21'), isNull);
      expect(SiteConfig.tryNormalizeUrl('http://localhost:0'), isNull);
      expect(SiteConfig.tryNormalizeUrl('http://localhost:70000'), isNull);
      expect(SiteConfig.tryNormalizeUrl('   '), isNull);
    });
  });
}
