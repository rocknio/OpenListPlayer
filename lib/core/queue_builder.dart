/// 队列构建：目录条目 → "正在播放"队列（同目录非递归、整体替换语义）。
library;

import 'media_types.dart';
import 'models.dart';
import 'natural_sort.dart';

/// 拼接网盘路径（dirPath 以 / 开头，根目录为 /）
String joinPath(String dir, String name) =>
    dir == '/' ? '/$name' : '$dir/$name';

/// 按排序模式排序的目录条目（目录在前，文件在后）
List<FsEntry> sortEntries(List<FsEntry> entries, SortMode mode) {
  final dirs = entries.where((e) => e.isDirectory).toList();
  final files = entries.where((e) => !e.isDirectory).toList();
  int cmp(FsEntry a, FsEntry b) => switch (mode) {
        SortMode.natural => compareNatural(a.name, b.name),
        SortMode.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortMode.modified => (a.modified?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.modified?.millisecondsSinceEpoch ?? 0),
      };
  dirs.sort(cmp);
  files.sort(cmp);
  return [...dirs, ...files];
}

/// 从目录条目构建音视频队列（过滤非媒体，按设置排序）
List<QueueItem> buildQueueFromDir(String dirPath, List<FsEntry> entries, SortMode mode) {
  final items = entries
      .where((e) => !e.isDirectory && isMediaFile(e.name))
      .map((e) => QueueItem(
            path: joinPath(dirPath, e.name),
            name: e.name,
            isVideo: isVideoFile(e.name),
            size: e.size,
            thumb: e.thumb,
          ))
      .toList();
  items.sort((a, b) => switch (mode) {
        SortMode.natural => compareNatural(a.name, b.name),
        SortMode.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortMode.modified => 0, // 修改时间排序对队列意义不大，回退保持 OpenList 返回序
      });
  return items;
}
