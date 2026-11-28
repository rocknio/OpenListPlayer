/// App 根组件：浅色/深色/跟随系统三态主题 + 底部 4 tab 壳 + 生命周期处理。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models.dart';
import 'core/openp2p_probe.dart';
import 'data/openp2p_service.dart';
import 'providers.dart';
import 'ui/app_theme.dart';
import 'ui/browser/browser_page.dart';
import 'ui/home/home_page.dart';
import 'ui/icons.dart';
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
        // 视频且设置"后台不放声音"→ 先串行暂停，随后统一落盘进度/会话，避免并发重复写库
        unawaited(() async {
          await handler.onAppBackgrounded();
          await playback.onAppPaused();
        }());
        break;
      case AppLifecycleState.resumed:
        final p2p = ref.read(openP2pMonitorProvider);
        if (p2p.needsAttention || p2p.launchedThisSession) {
          unawaited(ref.read(openP2pMonitorProvider.notifier).checkOnResume());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePref = ref.watch(settingsProvider.select((s) => s.themePreference));
    final themeMode = switch (themePref) {
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
      AppThemePreference.system => ThemeMode.system,
    };
    return MaterialApp(
      title: '云序',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
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
  bool _p2pDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(openP2pMonitorProvider.notifier).check(allowPrompt: true));
    });
  }

  Future<void> _showOpenP2pDialog(OpenP2pStatus status) async {
    if (_p2pDialogOpen || !mounted) return;
    _p2pDialogOpen = true;
    ref.read(openP2pMonitorProvider.notifier).markPromptHandled();
    final (title, content, canLaunch) = switch (status) {
      OpenP2pStatus.notInstalled => (
          '未检测到 OpenP2P',
          '当前配置的站点使用本机端口映射，需要安装并运行 OpenP2P 客户端才能连接家里的 OpenList。',
          false,
        ),
      OpenP2pStatus.unreachable => (
          '无法连接到 OpenList',
          '本地映射端口已响应，但暂时无法连上家里的 OpenList 服务。请检查 OpenP2P 隧道状态或服务端是否在线。',
          true,
        ),
      _ => (
          'OpenP2P 似乎未运行',
          '云序需要通过手机上的 OpenP2P 端口映射才能连接家里的 OpenList 服务，是否立即启动 OpenP2P？',
          true,
        ),
    };

    try {
      final shouldLaunch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (canLaunch) ...[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('暂不启动'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('启动 OpenP2P'),
              ),
            ] else
              FilledButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('知道了'),
              ),
          ],
        ),
      );
      if (shouldLaunch == true && mounted) {
        final ok = await ref.read(openP2pMonitorProvider.notifier).launchOpenP2p();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未能拉起 OpenP2P，请手动打开')),
          );
        }
      }
    } finally {
      _p2pDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OpenP2pState>(openP2pMonitorProvider, (prev, next) {
      if (next.shouldPrompt && !_p2pDialogOpen) {
        unawaited(_showOpenP2pDialog(next.status));
      }
    });

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
              NavigationDestination(
                icon: Icon(AppIcons.home),
                selectedIcon: Icon(AppIcons.homeSelected),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(AppIcons.folder),
                selectedIcon: Icon(AppIcons.folderSelected),
                label: '文件',
              ),
              NavigationDestination(
                icon: Icon(AppIcons.playlist),
                selectedIcon: Icon(AppIcons.playlistSelected),
                label: '播单',
              ),
              NavigationDestination(
                icon: Icon(AppIcons.settings),
                selectedIcon: Icon(AppIcons.settingsSelected),
                label: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
