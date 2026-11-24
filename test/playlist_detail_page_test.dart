/// 播单详情页组件测试：用内存 SQLite 验证"上次播到"提示、续播按钮与条目进度展示。
library;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlistplayer/core/models.dart';
import 'package:openlistplayer/data/app_database.dart';
import 'package:openlistplayer/providers.dart';
import 'package:openlistplayer/ui/playlist/playlist_detail_page.dart';

void main() {
  late AppDatabase db;
  late int playlistId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    playlistId = await db.createPlaylist('测试播单');
    await db.addItemsToPlaylist(playlistId, const [
      QueueItem(path: '/a.mp3', name: 'a.mp3', isVideo: false, size: 1000),
      QueueItem(path: '/b.mp3', name: 'b.mp3', isVideo: false, size: 1000),
      QueueItem(path: '/c.mp3', name: 'c.mp3', isVideo: false, size: 1000),
      QueueItem(path: '/d.mp3', name: 'd.mp3', isVideo: false, size: 1000),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  /// 渲染详情页并等三个数据库流（指针 / 进度 / 条目）都发出首轮数据
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(home: PlaylistDetailPage(playlistId: playlistId, playlistName: '测试播单')),
    ));
    await tester.pumpAndSettle(
        const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
  }

  /// 每条用例结束前必须调用：卸载页面并跑掉 drift 在流订阅取消时排的零时长 Timer。
  /// 否则 flutter_test 的"不应残留 Timer"检查会失败，teardown 里的 db.close() 也会一直等下去。
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('从未播过：播放全部，没有"上次播到"', (tester) async {
    await pumpPage(tester);
    expect(find.text('播放全部 (4)'), findsOneWidget);
    expect(find.text('上次播到'), findsNothing);
    await closePage(tester);
  });

  testWidgets('上次播到 c 的 45 秒：提示卡 + 行标签，继续播放从 c 开始', (tester) async {
    await db.upsertPlaylistProgress(
        playlistId, '/c.mp3', const Duration(seconds: 45), const Duration(seconds: 100));
    await db.setPlaylistLastPlayed(playlistId, '/c.mp3');
    await pumpPage(tester);
    expect(find.text('继续播放 (4)'), findsOneWidget);
    // 顶部提示卡的标题 + c 这一行的标签
    expect(find.text('上次播到'), findsNWidgets(2));
    // 提示卡：播到哪一秒
    expect(find.text('00:45 / 01:40 · 45%'), findsOneWidget);
    // 列表行：c 显示断点，其余行不显示进度
    expect(find.text('45% · 00:45 / 01:40'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('上次播到的 b 已看完：b 显示"已看完"，继续播放跳到下一个有断点的 c', (tester) async {
    await db.upsertPlaylistProgress(
        playlistId, '/b.mp3', const Duration(seconds: 100), const Duration(seconds: 100),
        finished: true);
    await db.upsertPlaylistProgress(
        playlistId, '/c.mp3', const Duration(seconds: 45), const Duration(seconds: 100));
    await db.setPlaylistLastPlayed(playlistId, '/b.mp3');
    await pumpPage(tester);
    expect(find.text('继续播放 (4)'), findsOneWidget);
    expect(find.text('已看完'), findsOneWidget);
    // 续播起点是 c 而不是上次播到的 b → 没有提示卡，只剩 b 行上的标签；c 行照常显示断点
    expect(find.text('上次播到'), findsOneWidget);
    expect(find.text('45% · 00:45 / 01:40'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('只有看完的记录、没有未看完的断点：播放全部', (tester) async {
    await db.upsertPlaylistProgress(
        playlistId, '/b.mp3', const Duration(seconds: 100), const Duration(seconds: 100),
        finished: true);
    await db.setPlaylistLastPlayed(playlistId, '/b.mp3');
    await pumpPage(tester);
    expect(find.text('播放全部 (4)'), findsOneWidget);
    expect(find.text('已看完'), findsOneWidget);
    expect(find.text('上次播到'), findsOneWidget);
    expect(find.text('01:40 / 01:40 · 100%'), findsNothing);
    await closePage(tester);
  });
}
