/// Riverpod providers：设置、数据库、OpenList 客户端、播放控制器。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models.dart';
import 'core/openlist_client.dart';
import 'data/app_database.dart';
import 'data/settings_service.dart';
import 'player/audio_handler.dart';
import 'player/playback_controller.dart';

/// 在 main() 中覆盖注入
final settingsServiceProvider = Provider<SettingsService>((ref) => throw UnimplementedError());

/// 在 main() 中覆盖注入
final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsServiceProvider).load();

  SettingsService get _svc => ref.read(settingsServiceProvider);

  Future<void> setSite(SiteConfig? site) async {
    final prevUrl = state.site?.baseUrl;
    await _svc.saveSite(site);
    final s = _svc.load();
    state = s;
    final nextUrl = s.site?.baseUrl;
    final playback = ref.read(playbackProvider);
    if (prevUrl != nextUrl) {
      await playback.onSiteChanged();
    } else {
      playback.onSettingsChanged();
    }
  }

  Future<void> setSortMode(SortMode mode) async {
    await _svc.saveSortMode(mode);
    state = _svc.load();
  }

  Future<void> setDefaultPlayMode(PlayMode mode) async {
    await _svc.saveDefaultPlayMode(mode);
    state = _svc.load();
    ref.read(playbackProvider).onSettingsChanged();
  }

  Future<void> setVideoBackgroundAudio(bool v) async {
    await _svc.saveVideoBackgroundAudio(v);
    state = _svc.load();
  }

  Future<void> setBufferProfile(BufferProfile p) async {
    await _svc.saveBufferProfile(p);
    state = _svc.load();
    ref.read(playbackProvider).onSettingsChanged();
  }

  Future<void> setGlobalSpeed(double s) async {
    await _svc.saveGlobalSpeed(s);
    state = _svc.load();
    await ref.read(playbackProvider).setSpeed(state.globalSpeed);
  }

  Future<void> setThemePreference(AppThemePreference pref) async {
    await _svc.saveThemePreference(pref);
    state = _svc.load();
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

/// OpenList 客户端（随站点地址变化重建）
final apiProvider = Provider<OpenListClient>((ref) {
  final site = ref.watch(settingsProvider.select((s) => s.site));
  final client = OpenListClient(site: site ?? const SiteConfig(baseUrl: ''));
  ref.onDispose(client.close);
  return client;
});

/// 是否已配置站点
final hasSiteProvider = Provider<bool>((ref) => ref.watch(settingsProvider).site != null);

final playbackProvider = Provider<PlaybackController>((ref) {
  final c = PlaybackController(
    api: () => ref.read(apiProvider),
    db: ref.read(dbProvider),
    settings: () => ref.read(settingsProvider),
    onPersistSpeed: (s) async {
      await ref.read(settingsServiceProvider).saveGlobalSpeed(s);
      ref.invalidate(settingsProvider);
    },
  );
  ref.onDispose(c.dispose);
  return c;
});

final audioHandlerProvider = Provider<PlayerAudioHandler>((ref) {
  final h = PlayerAudioHandler(
    ref.read(playbackProvider),
    settings: () => ref.read(settingsProvider),
  );
  ref.onDispose(h.dispose);
  return h;
});

/// SharedPreferences 原始实例（settingsServiceProvider 内部也需要）
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
