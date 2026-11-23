/// App 根组件：主题（深色跟随系统）+ 底部 4 tab 壳 + 生命周期处理。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'ui/app_theme.dart';
import 'ui/browser/browser_page.dart';
import 'ui/home/home_page.dart';
import 'ui/mini_player_bar.dart';
import 'ui/playlist/playlists_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/tab_index.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final playback = ref.read(playbackProvider);
    final handler = ref.read(audioHandlerProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 视频且设置"后台不放声音"→ 暂停；同时落盘进度/会话
        handler.onAppBackgrounded();
        playback.onAppPaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '云序',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light, // 全 App 统一为音频页的米白浅色色板
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _pages = [HomePage(), BrowserPage(), PlaylistsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(tabIndexProvider);
    return Scaffold(
      body: IndexedStack(index: tabIndex, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          NavigationBar(
            selectedIndex: tabIndex,
            onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).set(i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: '文件'),
              NavigationDestination(icon: Icon(Icons.playlist_play_outlined), selectedIcon: Icon(Icons.playlist_play), label: '播单'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        ],
      ),
    );
  }
}
