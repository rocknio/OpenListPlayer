/// 应用设置（SharedPreferences）：站点地址、排序、播放模式、后台声音、缓冲档、全局倍速。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

class AppSettings {
  const AppSettings({
    required this.site,
    this.sortMode = SortMode.natural,
    this.defaultPlayMode = PlayMode.sequentialLoop,
    this.videoBackgroundAudio = true,
    this.bufferProfile = BufferProfile.balanced,
    this.globalSpeed = 1.0,
  });

  final SiteConfig? site;
  final SortMode sortMode;
  final PlayMode defaultPlayMode;
  final bool videoBackgroundAudio;
  final BufferProfile bufferProfile;
  final double globalSpeed;

  AppSettings copyWith({
    SiteConfig? site,
    bool clearSite = false,
    SortMode? sortMode,
    PlayMode? defaultPlayMode,
    bool? videoBackgroundAudio,
    BufferProfile? bufferProfile,
    double? globalSpeed,
  }) =>
      AppSettings(
        site: clearSite ? null : (site ?? this.site),
        sortMode: sortMode ?? this.sortMode,
        defaultPlayMode: defaultPlayMode ?? this.defaultPlayMode,
        videoBackgroundAudio: videoBackgroundAudio ?? this.videoBackgroundAudio,
        bufferProfile: bufferProfile ?? this.bufferProfile,
        globalSpeed: globalSpeed ?? this.globalSpeed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.site == site &&
          other.sortMode == sortMode &&
          other.defaultPlayMode == defaultPlayMode &&
          other.videoBackgroundAudio == videoBackgroundAudio &&
          other.bufferProfile == bufferProfile &&
          other.globalSpeed == globalSpeed;

  @override
  int get hashCode => Object.hash(
        site,
        sortMode,
        defaultPlayMode,
        videoBackgroundAudio,
        bufferProfile,
        globalSpeed,
      );
}

class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  static const _kSiteName = 'site.name';
  static const _kSiteUrl = 'site.url';
  static const _kSort = 'browser.sort';
  static const _kPlayMode = 'play.mode.default';
  static const _kVideoBgAudio = 'play.video_bg_audio';
  static const _kBuffer = 'play.buffer_profile';
  static const _kSpeed = 'play.global_speed';

  AppSettings load() {
    final rawUrl = _prefs.getString(_kSiteUrl);
    final url = rawUrl == null ? null : SiteConfig.tryNormalizeUrl(rawUrl);
    final site = url == null
        ? null
        : SiteConfig(baseUrl: url, name: _prefs.getString(_kSiteName));
    final rawSpeed = _prefs.getDouble(_kSpeed) ?? 1.0;
    final speed = rawSpeed.isFinite && rawSpeed > 0 ? rawSpeed.clamp(0.25, 4.0) : 1.0;
    return AppSettings(
      site: site,
      sortMode: _enumFromString(SortMode.values, _prefs.getString(_kSort), SortMode.natural),
      defaultPlayMode:
          _enumFromString(PlayMode.values, _prefs.getString(_kPlayMode), PlayMode.sequentialLoop),
      videoBackgroundAudio: _prefs.getBool(_kVideoBgAudio) ?? true,
      bufferProfile:
          _enumFromString(BufferProfile.values, _prefs.getString(_kBuffer), BufferProfile.balanced),
      globalSpeed: speed,
    );
  }

  Future<void> saveSite(SiteConfig? site) async {
    final url = site == null ? null : SiteConfig.tryNormalizeUrl(site.baseUrl);
    if (site == null || url == null) {
      await _prefs.remove(_kSiteUrl);
      await _prefs.remove(_kSiteName);
      return;
    }
    await _prefs.setString(_kSiteUrl, url);
    final name = site.name?.trim() ?? '';
    name.isEmpty ? await _prefs.remove(_kSiteName) : await _prefs.setString(_kSiteName, name);
  }

  Future<void> saveSortMode(SortMode mode) => _prefs.setString(_kSort, mode.name);

  Future<void> saveDefaultPlayMode(PlayMode mode) => _prefs.setString(_kPlayMode, mode.name);

  Future<void> saveVideoBackgroundAudio(bool v) => _prefs.setBool(_kVideoBgAudio, v);

  Future<void> saveBufferProfile(BufferProfile p) => _prefs.setString(_kBuffer, p.name);

  Future<void> saveGlobalSpeed(double s) => _prefs.setDouble(_kSpeed, s);

  T _enumFromString<T extends Enum>(List<T> values, String? s, T fallback) {
    if (s == null) return fallback;
    for (final v in values) {
      if (v.name == s) return v;
    }
    return fallback;
  }
}
