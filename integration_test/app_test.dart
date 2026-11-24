/// 端到端集成测试（iOS 模拟器 / 真机运行）：
/// 首启引导 → 配置站点 → 浏览目录 → 点击音频文件 → 队列替换 → 播放状态。
/// 依赖本机 OpenList 服务（模拟器内 localhost 即宿主机）。
/// 注意：播放后 position 流持续刷新帧，不能用 pumpAndSettle，只用定时 pump。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openlistplayer/main.dart' as app;

/// 定时泵帧（不要求 settle）
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首启引导 → 配置站点 → 浏览 → 点击播放 → 队列替换', (tester) async {
    // 预置站点地址（模拟器内 localhost = 宿主机 OpenList）
    SharedPreferences.setMockInitialValues({
      'site.url': 'http://localhost:5244',
      'site.name': '本机测试',
    });
    await app.main();
    await pumpFor(tester, const Duration(seconds: 3));

    // 1. 首页应出现（不再显示无站点引导）
    expect(find.text('云序'), findsOneWidget);
    expect(find.textContaining('还未配置网盘地址'), findsNothing);

    // 2. 切到"文件" tab，应列出两个挂载目录
    await tester.tap(find.text('文件'));
    await pumpFor(tester, const Duration(seconds: 4));
    expect(find.text('天翼云盘'), findsOneWidget);
    expect(find.text('天翼云盘-家庭'), findsOneWidget);

    // 3. 进入 我的音乐 → 经典音乐（在列表下方，滚动到可见）
    await tester.tap(find.text('天翼云盘'));
    await pumpFor(tester, const Duration(seconds: 4));
    await tester.tap(find.text('我的音乐'));
    await pumpFor(tester, const Duration(seconds: 4));
    await tester.scrollUntilVisible(
      find.text('经典音乐'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('经典音乐'));
    await pumpFor(tester, const Duration(seconds: 4));

    // 4. 目录内应有 mp3 且 readme.txt 置灰存在
    expect(find.textContaining('.mp3'), findsWidgets);
    expect(find.text('readme.txt'), findsOneWidget);

    // 5. 点击一个 mp3 → 进入音频页，队列应为同目录全部 5 个 mp3（不含 txt）
    await tester.tap(find.textContaining('心淡-容祖儿').first);
    await pumpFor(tester, const Duration(seconds: 8));
    expect(find.text('正在播放'), findsWidgets);
    expect(find.text('共 5 集'), findsOneWidget);

    // 6. 队列内应包含其余 mp3（同目录替换语义；下方条目滚动到可见）
    expect(find.textContaining('大开眼戒-陈奕迅'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('活着多好-陈奕迅'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('活着多好-陈奕迅'), findsWidgets);

    // 7. 等待真实开播（直链 + libmpv）
    await pumpFor(tester, const Duration(seconds: 10));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
