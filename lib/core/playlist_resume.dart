/// 播单续播定位：按"上次播到哪个文件"的指针和各文件的看完状态，算出"继续播放"从哪一条开始。
/// 纯函数，不依赖数据库；进度行到入参的映射由调用方完成。
library;

/// 续播定位结果。
///
/// [index]："继续播放 / 播放全部"的起始条目（[paths] 为空时为 0）。
/// [hasProgress]：是否有可继续的进度；false 表示从未在本播单播过或没有未看完的断点，按"播放全部"展示。
typedef PlaylistResume = ({int index, bool hasProgress});

/// [paths]：播单条目路径，按播单顺序。
/// [lastPlayedPath]：续播指针，本播单上次播到的文件；为空或已不在播单里时退化为"从头找第一个播过且没看完的"。
/// [playedPaths]：在本播单里有过播放记录的文件。
/// [finishedPaths]：其中已看完的文件（应是 [playedPaths] 的子集）。
PlaylistResume locatePlaylistResume({
  required List<String> paths,
  required String? lastPlayedPath,
  required Set<String> playedPaths,
  required Set<String> finishedPaths,
}) {
  if (paths.isEmpty) return (index: 0, hasProgress: false);
  final last = lastPlayedPath == null ? -1 : paths.indexOf(lastPlayedPath);
  // 上次播到的条目还没看完（含刚打开、进度尚未落盘）→ 就从它续播
  if (last >= 0 && !finishedPaths.contains(paths[last])) return (index: last, hasProgress: true);
  // 上次播到的条目已看完，或没有指针（旧数据 / 指针指向的文件已被移出播单）：
  // 从它之后依次往后找"播过且没看完"的条目，到末尾再绕回开头；没有指针则从第一条开始
  for (var k = 0; k < paths.length; k++) {
    final i = last < 0 ? k : (last + k) % paths.length;
    final path = paths[i];
    if (playedPaths.contains(path) && !finishedPaths.contains(path)) return (index: i, hasProgress: true);
  }
  return (index: 0, hasProgress: false); // 没有可续播的断点（从未播过 / 已全部看完）
}
