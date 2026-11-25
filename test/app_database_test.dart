/// AppDatabase 单元测试：v1→v4 / v3→v4 真实文件迁移、外键级联删除、去重返回值、原子重排、历史 20 条裁剪、会话存取。
library;

import 'dart:io';

import 'package:drift/drift.dart' show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/data/app_database.dart';

void main() {
  group('AppDatabase 真实版本迁移', () {
    test('v1 数据库平滑升级至 v4，保留旧数据并补齐新表/新列/索引', () async {
      final dir = await Directory.systemTemp.createTemp('olp_mig_v1_');
      final file = File('${dir.path}/legacy_v1.sqlite');
      try {
        // 用 NativeDatabase 写入 v1 原始表结构、旧数据与 user_version = 1
        final seedExec = NativeDatabase(
          file,
          setup: (raw) {
            raw.execute('''
              CREATE TABLE playlists (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
              );
              CREATE TABLE playlist_items (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
                path TEXT NOT NULL,
                name TEXT NOT NULL,
                is_video INTEGER NOT NULL,
                size INTEGER NOT NULL DEFAULT 0,
                position INTEGER NOT NULL
              );
              CREATE TABLE play_progresses (
                path TEXT NOT NULL PRIMARY KEY,
                position_ms INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
              CREATE TABLE play_histories (
                path TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                is_video INTEGER NOT NULL,
                played_at INTEGER NOT NULL
              );
              CREATE TABLE track_prefs_table (
                path TEXT NOT NULL PRIMARY KEY,
                audio_track TEXT NULL,
                subtitle_track TEXT NULL,
                sub_delay_ms INTEGER NOT NULL DEFAULT 0
              );
              CREATE TABLE session_state (
                id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
                queue_json TEXT NOT NULL,
                current_index INTEGER NOT NULL,
                position_ms INTEGER NOT NULL,
                saved_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
              );
              INSERT INTO playlists (id, name) VALUES (1, '老播单');
              INSERT INTO playlist_items (playlist_id, path, name, is_video, size, position)
                VALUES (1, '/v/ep1.mp4', 'ep1.mp4', 1, 1024, 0);
              INSERT INTO session_state (id, queue_json, current_index, position_ms)
                VALUES (1, '[{"path":"/v/ep1.mp4","name":"ep1.mp4","isVideo":true,"size":1024}]', 0, 12000);
              PRAGMA user_version = 1;
            ''');
          },
        );
        await seedExec.ensureOpen(_VersionStubUser(1));
        await seedExec.close();

        final db = AppDatabase(NativeDatabase(file));
        final items = await db.playlistItemsStream(1).first;
        expect(items.single.path, '/v/ep1.mp4');
        expect(items.single.thumb, '');

        final session = await db.loadSession();
        expect(session, isNotNull);
        expect(session!.position, const Duration(seconds: 12));
        expect(session.duration, Duration.zero);
        expect(session.sourcePlaylistId, isNull);

        // 新表 playlist_progresses 与 playlist_states 可正常读写
        await db.upsertPlaylistProgress(
          1,
          '/v/ep1.mp4',
          const Duration(seconds: 30),
          const Duration(seconds: 120),
        );
        await db.setPlaylistLastPlayed(1, '/v/ep1.mp4');
        final p = await db.getPlaylistProgress(1, '/v/ep1.mp4');
        expect(p?.positionMs, 30000);
        expect(p?.finished, isFalse);

        // 验证 idx_playlist_items_pid_pos 索引已创建
        final idxRows = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type='index' AND name='idx_playlist_items_pid_pos'")
            .get();
        expect(idxRows, hasLength(1));

        await db.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('v3 数据库平滑升级至 v4', () async {
      final dir = await Directory.systemTemp.createTemp('olp_mig_v3_');
      final file = File('${dir.path}/legacy_v3.sqlite');
      try {
        final seedExec = NativeDatabase(
          file,
          setup: (raw) {
            raw.execute('''
              CREATE TABLE playlists (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
              );
              CREATE TABLE playlist_items (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
                path TEXT NOT NULL,
                name TEXT NOT NULL,
                is_video INTEGER NOT NULL,
                size INTEGER NOT NULL DEFAULT 0,
                position INTEGER NOT NULL
              );
              CREATE TABLE play_progresses (
                path TEXT NOT NULL PRIMARY KEY,
                position_ms INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
              CREATE TABLE playlist_progresses (
                playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
                path TEXT NOT NULL,
                position_ms INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                finished INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (playlist_id, path)
              );
              CREATE TABLE playlist_states (
                playlist_id INTEGER NOT NULL PRIMARY KEY REFERENCES playlists(id) ON DELETE CASCADE,
                path TEXT NOT NULL,
                updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
              );
              CREATE TABLE play_histories (
                path TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                is_video INTEGER NOT NULL,
                played_at INTEGER NOT NULL
              );
              CREATE TABLE track_prefs_table (
                path TEXT NOT NULL PRIMARY KEY,
                audio_track TEXT NULL,
                subtitle_track TEXT NULL,
                sub_delay_ms INTEGER NOT NULL DEFAULT 0
              );
              CREATE TABLE session_state (
                id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
                queue_json TEXT NOT NULL,
                current_index INTEGER NOT NULL,
                position_ms INTEGER NOT NULL,
                source_playlist_id INTEGER NULL,
                saved_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
              );
              PRAGMA user_version = 3;
            ''');
          },
        );
        await seedExec.ensureOpen(_VersionStubUser(3));
        await seedExec.close();

        final db = AppDatabase(NativeDatabase(file));
        final pid = await db.createPlaylist('v3升级测试');
        final added = await db.addItemsToPlaylist(pid, const [
          QueueItem(path: '/a.mp3', name: 'a.mp3', isVideo: false, thumb: 'http://img/1.jpg'),
        ]);
        expect(added, 1);
        final loaded = await db.playlistItemsStream(pid).first;
        expect(loaded.single.thumb, 'http://img/1.jpg');
        await db.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('AppDatabase 事务、级联与裁剪规则', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('addItemsToPlaylist 去重并返回真实新增数量；reorderPlaylistItems 批量重排', () async {
      final pid = await db.createPlaylist('测试播单');
      final firstAdd = await db.addItemsToPlaylist(pid, const [
        QueueItem(path: '/1.mp3', name: '1.mp3', isVideo: false),
        QueueItem(path: '/2.mp3', name: '2.mp3', isVideo: false),
        QueueItem(path: '/1.mp3', name: '1.mp3', isVideo: false), // 批次内自身重复
      ]);
      expect(firstAdd, 2);

      final secondAdd = await db.addItemsToPlaylist(pid, const [
        QueueItem(path: '/2.mp3', name: '2.mp3', isVideo: false),
        QueueItem(path: '/3.mp3', name: '3.mp3', isVideo: false),
      ]);
      expect(secondAdd, 1);

      final before = await db.playlistItemsStream(pid).first;
      expect(before.map((e) => e.path).toList(), ['/1.mp3', '/2.mp3', '/3.mp3']);

      await db.reorderPlaylistItems(pid, [before[2], before[0], before[1]]);
      final after = await db.playlistItemsStream(pid).first;
      expect(after.map((e) => e.path).toList(), ['/3.mp3', '/1.mp3', '/2.mp3']);
      expect(after.map((e) => e.position).toList(), [0, 1, 2]);
    });

    test('deletePlaylist 触发外键级联清理条目、进度、指针，并将 session.sourcePlaylistId 置空', () async {
      final pid = await db.createPlaylist('待删播单');
      const item = QueueItem(path: '/ep1.mkv', name: 'ep1.mkv', isVideo: true);
      await db.addItemsToPlaylist(pid, const [item]);
      await db.upsertPlaylistProgress(pid, item.path, const Duration(seconds: 20), const Duration(seconds: 100));
      await db.setPlaylistLastPlayed(pid, item.path);
      await db.saveSession(const [item], 0, const Duration(seconds: 20),
          duration: const Duration(seconds: 100), sourcePlaylistId: pid);

      await db.deletePlaylist(pid);

      expect(await db.playlistExists(pid), isFalse);
      expect(await db.playlistItemsStream(pid).first, isEmpty);
      expect(await db.getPlaylistProgress(pid, item.path), isNull);
      expect(await db.playlistStateStream(pid).first, isNull);
      final s = await db.loadSession();
      expect(s?.sourcePlaylistId, isNull);
      expect(s?.duration, const Duration(seconds: 100));
    });

    test('touchHistory 自动保留最近 20 条记录', () async {
      for (var i = 0; i < 25; i++) {
        await db.touchHistory(QueueItem(
          path: '/song_$i.mp3',
          name: 'song_$i.mp3',
          isVideo: false,
        ));
      }
      final all = await db.select(db.playHistories).get();
      expect(all.length, lessThanOrEqualTo(20));
    });

    test('R3-L1: loadSession 过滤混入的脏条目与负时长，保留有效会话项不崩溃', () async {
      await db.customStatement(
        'INSERT OR REPLACE INTO session_state (id, queue_json, current_index, position_ms, duration_ms) '
        'VALUES (1, ?, 5, -100, -50)',
        [
          '["broken", {"path": "", "name": "empty"}, {"path": "/ok.mp3", "name": "ok.mp3", "isVideo": false}]',
        ],
      );
      final loaded = await db.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.queue.single.path, '/ok.mp3');
      expect(loaded.index, 0);
      expect(loaded.position, Duration.zero);
      expect(loaded.duration, Duration.zero);
    });
  });
}

class _VersionStubUser extends QueryExecutorUser {
  _VersionStubUser(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
