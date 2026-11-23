/// 应用入口：初始化 media_kit / drift / audio_service，恢复会话。
library;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/settings_service.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 全 App 默认锁竖屏；仅视频播放页在全屏时临时切横屏，退出即恢复
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  debugPrint('[OLP] main: start');
  MediaKit.ensureInitialized();
  debugPrint('[OLP] main: mediakit ok');

  final prefs = await SharedPreferences.getInstance();
  debugPrint('[OLP] main: prefs ok');
  final settingsSvc = SettingsService(prefs);
  final db = AppDatabase();
  debugPrint('[OLP] main: db constructed');

  final container = ProviderContainer(
    overrides: [
      settingsServiceProvider.overrideWithValue(settingsSvc),
      dbProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // audio_service 前台服务（锁屏/通知栏控制）
  debugPrint('[OLP] main: before AudioService.init');
  await AudioService.init(
    builder: () => container.read(audioHandlerProvider),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'playback',
      androidNotificationChannelName: '播放控制',
      androidNotificationChannelDescription: '云序 播放控制与进度',
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: false,
    ),
  ).timeout(const Duration(seconds: 8), onTimeout: () {
    debugPrint('[OLP] main: AudioService.init 超时（8s），继续启动（音频后台控制可能不可用）');
    return container.read(audioHandlerProvider);
  });
  debugPrint('[OLP] main: audio_service ok');

  // 恢复上次会话（不开播，首页显示"继续播放"）
  await container.read(playbackProvider).restoreSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () => debugPrint('[OLP] main: restoreSession 超时'),
      );
  debugPrint('[OLP] main: session restored, runApp');

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
