/// drift 数据库：手动播单 / 播放进度 / 播放历史 / 轨道偏好 / 会话恢复。
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/models.dart';

part 'app_database.g.dart';

/// 手动播单
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 播单条目（手动排序序号 position）
@TableIndex(name: 'idx_playlist_items_pid_pos', columns: {#playlistId, #position})
class PlaylistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get name => text()();
  BoolColumn get isVideo => boolean()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  TextColumn get thumb => text().withDefault(const Constant(''))();
  IntColumn get position => integer()();
}

/// 播放进度（按文件路径，全局默认）。看完（≥95%）即删行 → 下次从头播。
@DataClassName('PlayProgress')
class PlayProgresses extends Table {
  TextColumn get path => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {path};
}

/// 播单独立进度：同一文件在不同播单各自记录断点，互不影响。
/// 与全局进度不同：看完不删行，置 [finished] 保留——详情页据此显示"已看完"，续播时跳过。
@DataClassName('PlaylistProgress')
class PlaylistProgresses extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  /// 已看完：下次在本播单内从头播
  BoolColumn get finished => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId, path};
}

/// 播单续播指针（每播单一行）：上次在这个播单里播到哪个文件。
/// 只记"播到哪一个"，"播到哪一秒"按文件查 [PlaylistProgresses]。
@DataClassName('PlaylistState')
class PlaylistStates extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {playlistId};
}

/// 播放历史（最近播放，保留最近 20 条）
class PlayHistories extends Table {
  TextColumn get path => text()();
  TextColumn get name => text()();
  BoolColumn get isVideo => boolean()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {path};
}

/// 按文件记忆的轨道偏好（字幕轨/音轨选择、字幕延迟）
@DataClassName('TrackPrefs')
class TrackPrefsTable extends Table {
  TextColumn get path => text()();
  TextColumn get audioTrack => text().nullable()(); // 轨道标识（title||lang||id）
  TextColumn get subtitleTrack => text().nullable()();
  IntColumn get subDelayMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {path};
}

/// 会话恢复（单行，id=1）：队列 + 当前进度
class SessionState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get queueJson => text()();
  IntColumn get currentIndex => integer()();
  IntColumn get positionMs => integer()();
  /// 当前曲目已知总时长（毫秒），用于首次未满 5s 即拖动进度条退出后的恢复判定
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  /// 会话来源播单 id，用于恢复后继续写入该播单的独立进度
  IntColumn get sourcePlaylistId => integer().nullable()();
  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Playlists,
  PlaylistItems,
  PlayProgresses,
  PlaylistProgresses,
  PlaylistStates,
  PlayHistories,
  TrackPrefsTable,
  SessionState
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'openlist_player',
              // drift_flutter 默认存应用文档目录
            ));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // 新装：建全部表
        onCreate: (m) => m.createAll(),
        // 老用户逐级升级：
        // v1 → v2：播单进度表 + 会话表加来源播单列
        // v2 → v3：进度表加 finished 列 + 续播指针表
        // v3 → v4：播单条目加 thumb 列与 (playlistId, position) 索引 + 会话表加 durationMs 列
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // createTable 用的是当前表定义（已含 finished 列），不能再 addColumn
            await m.createTable(playlistProgresses);
            await m.addColumn(sessionState, sessionState.sourcePlaylistId);
          } else if (from < 3) {
            await m.addColumn(playlistProgresses, playlistProgresses.finished);
          }
          if (from < 3) {
            await m.createTable(playlistStates);
          }
          if (from < 4) {
            await m.addColumn(playlistItems, playlistItems.thumb);
            await m.addColumn(sessionState, sessionState.durationMs);
            await m.createIndex(idxPlaylistItemsPidPos);
          }
        },
        // SQLite 默认不检查外键，表上的 ON DELETE CASCADE（删播单连带清条目 / 进度 / 续播指针）要显式开启才生效
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---------- 播单 ----------

  Stream<List<Playlist>> playlistsStream() => select(playlists).watch();

  Future<bool> playlistExists(int id) async {
    final row = await (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null;
  }

  Stream<List<PlaylistItem>> playlistItemsStream(int playlistId) {
    return (select(playlistItems)..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<int> createPlaylist(String name) => into(playlists).insert(PlaylistsCompanion.insert(name: name));

  Future<void> renamePlaylist(int id, String name) =>
      (update(playlists)..where((t) => t.id.equals(id))).write(PlaylistsCompanion(name: Value(name)));

  Future<void> deletePlaylist(int id) => transaction(() async {
        // 清理会话中可能残留的已删除播单指针
        await (update(sessionState)..where((t) => t.sourcePlaylistId.equals(id)))
            .write(const SessionStateCompanion(sourcePlaylistId: Value(null)));
        await (delete(playlists)..where((t) => t.id.equals(id))).go();
      });

  /// 向播单批量追加条目（同路径自动去重），返回实际新增的条目数。
  Future<int> addItemsToPlaylist(int playlistId, List<QueueItem> items) {
    if (items.isEmpty) return Future.value(0);
    return transaction(() async {
      // 当前最大 position
      final last = await ((select(playlistItems)
            ..where((t) => t.playlistId.equals(playlistId)))
            ..orderBy([(t) => OrderingTerm.desc(t.position)])
            ..limit(1))
          .get();
      var pos = last.isEmpty ? -1 : last.first.position;
      // 同路径去重：分批查询已存在的 path，避免大目录超过 SQLite 变量上限
      final existingPaths = <String>{};
      const chunkSize = 500;
      for (var start = 0; start < items.length; start += chunkSize) {
        final chunk = items.skip(start).take(chunkSize).map((i) => i.path).toList();
        final rows = await (select(playlistItems)
              ..where((t) => t.playlistId.equals(playlistId) & t.path.isIn(chunk)))
            .get();
        for (final r in rows) {
          existingPaths.add(r.path);
        }
      }
      final batchItems = <PlaylistItemsCompanion>[];
      for (final it in items) {
        if (!existingPaths.add(it.path)) continue;
        batchItems.add(PlaylistItemsCompanion.insert(
          playlistId: playlistId,
          path: it.path,
          name: it.name,
          isVideo: it.isVideo,
          size: Value(it.size),
          thumb: Value(it.thumb),
          position: ++pos,
        ));
      }
      if (batchItems.isNotEmpty) {
        await batch((b) => b.insertAll(playlistItems, batchItems));
      }
      return batchItems.length;
    });
  }

  Future<void> removePlaylistItem(int itemId) => transaction(() async {
        // 用 path 精确清理该条目在所属播单里的进度（避免残留脏数据）
        final row =
            await (select(playlistItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (row != null) {
          await (delete(playlistProgresses)
                ..where((t) => t.playlistId.equals(row.playlistId) & t.path.equals(row.path)))
              .go();
          // 续播指针正指向这个文件 → 一并清掉，续播退化为"第一个没看完的条目"
          await (delete(playlistStates)
                ..where((t) => t.playlistId.equals(row.playlistId) & t.path.equals(row.path)))
              .go();
        }
        await (delete(playlistItems)..where((t) => t.id.equals(itemId))).go();
      });

  Future<void> reorderPlaylistItems(int playlistId, List<PlaylistItem> ordered) =>
      transaction(() async {
        await batch((b) {
          for (var i = 0; i < ordered.length; i++) {
            b.update(
              playlistItems,
              PlaylistItemsCompanion(position: Value(i)),
              where: (t) => t.id.equals(ordered[i].id) & t.playlistId.equals(playlistId),
            );
          }
        });
      });

  // ---------- 进度 ----------

  Future<void> upsertProgress(String path, Duration position, Duration duration) =>
      into(playProgresses).insertOnConflictUpdate(PlayProgressesCompanion.insert(
        path: path,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        updatedAt: DateTime.now(),
      ));

  Future<void> clearProgress(String path) =>
      (delete(playProgresses)..where((t) => t.path.equals(path))).go();

  Future<PlayProgress?> getProgress(String path) =>
      (select(playProgresses)..where((t) => t.path.equals(path))).getSingleOrNull();

  Stream<PlayProgress?> progressStream(String path) =>
      (select(playProgresses)..where((t) => t.path.equals(path))).watchSingleOrNull();

  // ---------- 播单独立进度 ----------

  /// 整个播单的进度流（详情页一次性拿到，按 path 建索引）
  Stream<List<PlaylistProgress>> playlistProgressesStream(int playlistId) =>
      (select(playlistProgresses)..where((t) => t.playlistId.equals(playlistId))).watch();

  Future<PlaylistProgress?> getPlaylistProgress(int playlistId, String path) =>
      (select(playlistProgresses)
            ..where((t) => t.playlistId.equals(playlistId) & t.path.equals(path)))
          .getSingleOrNull();

  /// 写入断点；[finished] 为 true 表示已看完（行保留，位置记为整段时长）。
  /// 同一行的 finished 每次都会被覆盖，所以重新播放后"已看完"会自动变回未看完。
  Future<void> upsertPlaylistProgress(
    int playlistId, String path, Duration position, Duration duration, {
    bool finished = false,
  }) =>
      into(playlistProgresses).insertOnConflictUpdate(PlaylistProgressesCompanion.insert(
        playlistId: playlistId,
        path: path,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        finished: Value(finished),
        updatedAt: DateTime.now(),
      ));

  /// 标记在该播单内已看完（下次从头播）
  Future<void> markPlaylistProgressFinished(int playlistId, String path, Duration duration) =>
      upsertPlaylistProgress(playlistId, path, duration, duration, finished: true);

  Future<void> clearPlaylistProgress(int playlistId, String path) =>
      (delete(playlistProgresses)
            ..where((t) => t.playlistId.equals(playlistId) & t.path.equals(path)))
          .go();

  // ---------- 播单续播指针 ----------

  /// 记录"本播单上次播到哪个文件"（每播单一行，覆盖写）
  Future<void> setPlaylistLastPlayed(int playlistId, String path) =>
      into(playlistStates).insertOnConflictUpdate(PlaylistStatesCompanion.insert(
        playlistId: Value(playlistId),
        path: path,
        updatedAt: Value(DateTime.now()),
      ));

  Stream<PlaylistState?> playlistStateStream(int playlistId) =>
      (select(playlistStates)..where((t) => t.playlistId.equals(playlistId))).watchSingleOrNull();

  // ---------- 历史 ----------

  Future<void> touchHistory(QueueItem item) => transaction(() async {
        await into(playHistories).insertOnConflictUpdate(
          PlayHistoriesCompanion.insert(
            path: item.path,
            name: item.name,
            isVideo: item.isVideo,
            playedAt: DateTime.now(),
          ),
        );
        // 保留最近 20 条：仅在存在第 21 条及以后的旧记录时才触发删除，避免未超限时多余写通知
        final stale = await (select(playHistories)
              ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
              ..limit(1000, offset: 20))
            .get();
        if (stale.isNotEmpty) {
          final stalePaths = stale.map((e) => e.path).toList();
          await (delete(playHistories)..where((t) => t.path.isIn(stalePaths))).go();
        }
      });

  Stream<List<PlayHistory>> historyStream({int limit = 20}) {
    final q = select(playHistories)..orderBy([(t) => OrderingTerm.desc(t.playedAt)])..limit(limit);
    return q.watch();
  }

  Future<void> clearHistory() => delete(playHistories).go();

  // ---------- 轨道偏好 ----------

  Future<void> saveTrackPrefs(String path,
          {String? audioTrack, String? subtitleTrack, int? subDelayMs}) =>
      transaction(() async {
        final old =
            await (select(trackPrefsTable)..where((t) => t.path.equals(path))).getSingleOrNull();
        await into(trackPrefsTable).insertOnConflictUpdate(TrackPrefsTableCompanion.insert(
          path: path,
          audioTrack: Value(audioTrack ?? old?.audioTrack),
          subtitleTrack: Value(subtitleTrack ?? old?.subtitleTrack),
          subDelayMs: Value(subDelayMs ?? old?.subDelayMs ?? 0),
        ));
      });

  Future<TrackPrefs?> getTrackPrefs(String path) =>
      (select(trackPrefsTable)..where((t) => t.path.equals(path))).getSingleOrNull();

  // ---------- 会话 ----------

  Future<void> saveSession(List<QueueItem> queue, int index, Duration position,
      {Duration duration = Duration.zero, int? sourcePlaylistId}) async {
    final json = jsonEncode(queue.map(queueItemToJson).toList());
    await into(sessionState).insertOnConflictUpdate(SessionStateCompanion.insert(
      id: const Value(1),
      queueJson: json,
      currentIndex: index,
      positionMs: position.inMilliseconds,
      durationMs: Value(duration.inMilliseconds),
      sourcePlaylistId: Value(sourcePlaylistId),
      savedAt: Value(DateTime.now()),
    ));
  }

  Future<
      ({
        List<QueueItem> queue,
        int index,
        Duration position,
        Duration duration,
        int? sourcePlaylistId,
      })?> loadSession() async {
    final row = await (select(sessionState)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    try {
      final raw = jsonDecode(row.queueJson);
      if (raw is! List) return null;
      final list = raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => queueItemFromJson(Map<String, dynamic>.from(e)))
          .where((q) => q.path.isNotEmpty)
          .toList();
      if (list.isEmpty) return null;
      return (
        queue: list,
        index: row.currentIndex.clamp(0, list.length - 1),
        position: Duration(milliseconds: row.positionMs < 0 ? 0 : row.positionMs),
        duration: Duration(milliseconds: row.durationMs < 0 ? 0 : row.durationMs),
        sourcePlaylistId: row.sourcePlaylistId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() => (delete(sessionState)..where((t) => t.id.equals(1))).go();
}

/// QueueItem 的 JSON 编码（会话持久化用）
Map<String, dynamic> queueItemToJson(QueueItem q) =>
    {'path': q.path, 'name': q.name, 'isVideo': q.isVideo, 'size': q.size, 'thumb': q.thumb};

/// QueueItem 的 JSON 解码
QueueItem queueItemFromJson(Map<String, dynamic> j) => QueueItem(
      path: j['path']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      isVideo: (j['isVideo'] as bool?) ?? false,
      size: (j['size'] as num?)?.toInt() ?? 0,
      // 旧会话没有 thumb 字段，缺省空字符串
      thumb: j['thumb']?.toString() ?? '',
    );
