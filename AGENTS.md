# AGENTS.md — OpenListPlayer（云序）

面向 coding agent 的项目须知。上手前先读 `README.md`（项目简介 / 架构 / 功能）；架构审查与 UI 改版方案归档在 `docs/` 下（`docs/iterative-review-2026-11-25.md`、`docs/ui-optimization-plan.md`、`docs/ui-prototype.html`）。

## 项目是什么

- **云序（YUNXU）**：Flutter 手机端（Android / iOS）音视频播放器，是 [openlist](https://github.com/OpenListTeam/OpenList) 的前端。App 只通过 openlist REST API（`/ping`、`/api/fs/list`、`/api/fs/get`）列目录、取直链与拉取文本（同目录 `.lrc` 歌词），交给 media_kit（mpv）解码；**不直接对接天翼云盘**。
- v1 范围：单站点、guest 免认证。`SiteConfig.token` 只是预留扩展位，登录鉴权并未实现。
- **命名分离**：「云序」只用于显示层（AppBar、通知渠道、Android `label`、iOS `CFBundleDisplayName`）。技术标识符保持不动——pubspec 包名 `openlistplayer`（Dart 导入 `package:openlistplayer/...`）与 applicationId `com.songyaning.openlistplayer`、iOS `CFBundleName`；改了会破坏导入 / 编译 / 签名。

## 目录与分层

```
lib/
├── main.dart        启动顺序：锁竖屏 → MediaKit → prefs/db → ProviderContainer → AudioService.init → restoreSession → runApp
├── app.dart         MaterialApp（浅色/深色/跟随系统三态主题）+ 底部 4 tab 外壳（IndexedStack 常驻）+ 生命周期钩子
├── providers.dart   全部 Riverpod provider（集中在这一个文件）
├── core/            纯 Dart 领域逻辑，无 Flutter 依赖 → 单测对象（models/media_types/natural_sort/openlist_client/playlist_resume/queue_builder/subtitle_match/lrc_parser）
├── data/            drift 数据库（app_database.dart + 生成的 .g.dart，schemaVersion = 4）、SharedPreferences 设置（settings_service.dart）
├── player/          PlayerBackend（media_kit 引擎抽象，便于单测注入假驱动）、PlaybackController（ChangeNotifier，播放内核）、PlayerAudioHandler（audio_service）
└── ui/              按页面分目录（home/browser/player/playlist/settings）；app_theme / icons / widgets / mini_player_bar / tab_index 在根
```

- 依赖只能向下：`ui → player → data → core`（UI 也会直接读 data / core）；`core/` 不 import 任何上层。
- 新增纯逻辑（排序、匹配、解析、规则）放 `core/`，并在 `test/` 对应测试文件补单测。
- `design_output/` 是「声环留声 · 实心芯」logo（主标 / 紧凑标 / 单色标 / 字标）与音视频占位图的 SVG 源文件和出图脚本，不是 App 代码；`render_png.py` 出图，应用图标由 `design_output/logo/deploy_icons.py` 覆盖写入 android / ios 图标资源。
- `docs/` 存放审查与设计文档（`code-review-2026-11-24.md`、`fix-plan-2026-11-24.md`、`iterative-review-2026-11-25.md`、`ui-optimization-plan.md`、`ui-prototype.html`）。

## 命令

```bash
flutter pub get
flutter analyze --no-pub                                   # 基线 25 条 info，无 error/warning
flutter test                                               # 90 项（8 个测试文件，涵盖纯逻辑 / LRC / OpenListClient / drift 迁移 / PlaybackController / 组件回归）
dart run build_runner build --delete-conflicting-outputs   # 改 app_database.dart 后必跑
flutter run
flutter build apk --release --target-platform android-arm64   # → build/app/outputs/flutter-apk/app-release.apk
flutter test integration_test/app_test.dart                # 需设备 + 本机 localhost:5244 的 OpenList（含测试用目录数据）
```

> 代理环境提醒：若本机终端设置了 `http_proxy` / `https_proxy` 且未将 `127.0.0.1,localhost` 加入 `NO_PROXY`，`flutter test` 与 `flutter run` 连接本地 Dart VM Service WebSocket 会报 `WebSocketException: Invalid WebSocket upgrade request`。运行前请设置 `NO_PROXY=127.0.0.1,localhost` 或 `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY`。

## 架构要点

- **DI**：Riverpod 3（手写 `Notifier`，无代码生成）。`settingsServiceProvider` / `dbProvider` / `sharedPreferencesProvider` 默认 `throw UnimplementedError()`，只在 `main.dart` 用 `overrides` 注入。设置变更（如 `setDefaultPlayMode`、`setBufferProfile`、`setGlobalSpeed`、`setSite`）由 `AppSettingsNotifier` 实时同步通知 `PlaybackController`。
- **`PlaybackController` 是 App 级单例**，不随设置或站点变化重建；它通过回调 getter（`() => ref.read(apiProvider)`）读最新依赖，所以站点地址变了只需让 `apiProvider` 重建。不要另建实例——每个实例都会创建自己的 mpv `Player`。底层通过 `PlayerBackend` 抽象隔离 `MediaKitBackend`，单元测试直接注入 `FakePlayerBackend`。
- **并发时序守卫**：`PlaybackController` 使用递增 `_openSerial` / `_loadedSerial` 防止异步乱序——`replaceQueue` / `jumpTo` / `next` / `previous` / `skipAfterError` / `resumeSession` 入口同步递增 `_openSerial` 并快照旧曲目进度，消除快速切歌或切歌后立即 `stop()` 导致的旧流污染与幽灵复播；轨道切换、外挂字幕加载与 `.lrc` 歌词拉取同样受 `_openSerial` 守卫。
- **UI 读播放状态必须包 `ListenableBuilder(listenable: playback, ...)`**：`ref.watch(playbackProvider)` 只拿到实例，`notifyListeners()` 不会触发 Riverpod 重建。
- **队列语义**：点网盘文件 = 同目录全部音视频整体替换队列，并从所点项开播（`playFromDirectory`）；播单播放 = 整张播单复制为队列（`playQueue(..., playlistId:)`），点击只决定起点，不截断队列。音视频混合队列跨类型切歌时，`AudioPage` 与 `PlayerScreen` 自动 `pushReplacement` 互切。
- **进度规则**（`ProgressRules` 纯函数）：时长 <10s 不记录；进度 ≥95% 视为看完，全局进度删行（下次从头播；播单进度见下）；每 5 秒落盘，暂停、切歌、退后台时立即记录，拖动进度条立即保存会话位置。`idle` / `error` / `opening` 态下的 `seek` 同步更新待恢复 / 重试断点。
- **弱网与重连**：buffering 无限等待，绝不自动跳曲；失败自动重试最多 2 次（间隔 800ms），一律从最近位置重取直链重连，**绝不回片头**；若底层流发出 `playing=true` 自行恢复，立即取消挂起的 `_retryTimer`。
- **轨道记忆与外挂字幕**：内置音轨 / 字幕轨使用 `title||language||id` 复合键（`trackPrefKey`）记忆偏好，消除同语言无标题轨道碰撞并兼容旧单键；外挂字幕通过 `runSubAddWithHeaderGuard` 隔离并恢复主媒体 HTTP 请求头、逐条独立容错，手动加载对已挂载同名外挂字幕直接复用；字幕延迟限幅在 ±60s。
- **歌词与睡眠定时**：音频开播自动匹配并拉取同目录 `.lrc` 文件（`core/lrc_parser.dart` 纯 Dart 解析 + 二分查找当前行），切歌 / 停止自动重置；睡眠定时支持倒计时（15/30/45/60m 等）与「播完本集停」（`SleepTimerMode`）。
- **进度双写与目录透出**：全局 `playProgresses`（按 path）始终写；队列来源是播单时（`_sourcePlaylistId != null`）额外写 `playlistProgresses`（playlistId + path），并在 `_openCurrent` 里更新续播指针 `playlistStates`（每播单一行，记"上次播到哪个文件"）。`replaceQueue` 里必须先给旧队列记进度、再切换 `_sourcePlaylistId`。网盘文件页通过 `directoryProgressesStream` / `directoryHistoryPathsStream` 透出目录直属子项进度条与「已播」徽章。
- **播单续播**："播到哪一秒"查 `playlistProgresses`，"播到哪一个"查 `playlistStates`，起点由 `core/playlist_resume.dart` 的 `locatePlaylistResume`（纯函数，有单测）算出。播单进度看完不删行、置 `finished`（全局进度才是看完即删）。所有播单相关写入都走 `PlaybackController._writePlaylist` 容错——播单在播放途中被删除时外键会拒绝写入，不能让它打断播放。
- **会话与历史**：`restoreSession()` 只装载队列不开播，首页常驻英雄卡与 `MiniPlayerBar` 均可触发 `resumeSession()`；`playHistories` 裁剪保留最近 20 条（`touchHistory`），并由首页「最近播放」区块实时订阅 `historyStream` 展示且支持弹窗清空。
- **OpenList 客户端容错**：`SiteConfig.tryNormalizeUrl` 规范协议大小写、剥离 `#fragment` 与末尾斜杠并拦截非法地址；`OpenListClient` 设 15s `sendTimeout`、拦截非 JSON 网关错误页、自动补全站内相对路径与 `//` 协议相对 URL（兼容子路径反代去重），并在 guest 刷新报 403 时静默降级为 `refresh=false`。
- **drift 迁移**：当前 `schemaVersion = 4`。改表 → 升 `schemaVersion` → 在 `migration.onUpgrade` 加 `if (from < N)` 分支 → 重跑 build_runner。`app_database.g.dart` 已入库，必须与 `.dart` 一起提交。（Flutter 3.50 会提示 `--delete-conflicting-outputs` 已弃用，可忽略。）两个坑：`createTable` 用的是**当前**表定义，跨版本建表后不能再对同一张表 `addColumn`；SQLite 和 drift 都默认不开外键，`ON DELETE CASCADE` 靠 `migration.beforeOpen` 里的 `PRAGMA foreign_keys = ON` 才生效。`test/app_database_test.dart` 已覆盖真实版本迁移（v1→v4、v3→v4）与外键级联。组件测试里用 drift 的 `watch()` 流时，用例结束前必须先 `pumpWidget` 卸载页面再 `pump` 一次：drift 在订阅取消时会排一个零时长 Timer，不跑掉的话 flutter_test 报"残留 Timer"失败，`db.close()` 还会一直卡住；同时在 `FakeAsync` 中与 `runAsync` 交叉写库触发 drift 流重查时需交替 `pump` 避免死锁（见 `test/widget_regression_test.dart` 注释）。

## 编码约定

- 代码注释、UI 文案、文档、commit message 一律中文；commit 用 `feat:` / `fix:` / `docs:` / `style:` 前缀 + 中文描述。
- 每个 dart 文件以一行 `/// 职责说明` 开头，随后 `library;`。
- 项目内 import 用相对路径（`import '../core/models.dart';`），外部包用 `package:`。
- **不要整仓跑 `dart format`**：仓库未按 Dart 3.14 格式化器统一过，整仓格式化会制造大量无关 diff。手工跟随所在文件的风格。
- 日志用 `debugPrint('[OLP] ...')`（mpv 日志前缀 `[mpv]`），不用 `print`。
- **配色与图标唯一来源**：
  - 配色统一来自 `lib/ui/player/audio_theme.dart` 的 `AudioTone`（浅色纸感暖陶：陶土 `#B85C38` 主色、米白 `#F5F2EC` 底、墨色 `#21201D` 文字、鼠尾草绿 `#4E7A5B` 完成态…）与 `lib/ui/app_theme.dart` 的 `AppTheme.light/dark` 与 `AppPalette`（深色夜读暖曜 `#181614` / `#24211E` / `#D97752` 及 `bgOf/surfaceOf/inkOf/...` 语义取色器、视频遮罩 `scrim`）。新 UI 从 `Theme.of(context).colorScheme` 或 `AppPalette.*Of(context)` 取色，**不引入新的硬编码色值**。
  - 图标与品牌微标集中于 `lib/ui/icons.dart`（`AppIcons`、`YunxuLogoMark`、`PlayingWaveBars`），业务代码优先使用 `AppIcons.xxx`，避免散落原始 `Icons.*`。
  - 主题模式由 `settingsProvider.themePreference` 驱动（`AppThemePreference.light / dark / system`，默认浅色），持久化到 SharedPreferences（`ui.theme_mode`），`app.dart` 实时绑定 `themeMode`。
- 全 App 锁竖屏；只有视频页全屏时临时横屏（`player_screen.dart` 的 `_enterFullscreen` / `_exitFullscreen`），退出全屏与 `dispose` 都要恢复 `portraitUp`。
- `WakelockPlus.enable/disable` 调用必须捕获异步异常（避免无权限或测试环境抛 `PlatformException`）。
- 倍速 / 时长显示统一用 `widgets.dart` 的 `formatSpeed` / `formatDuration`；列表底部防悬浮条遮挡统一使用 `kMiniPlayerReservedPadding`；音频无封面回退 `AudioPlaceholderArt`，远程缩略图必须带 `errorBuilder`。
- 关闭 Impeller 约束下，UI 动效避免大面积 `BackdropFilter` 高斯模糊，坚持 `Transform` / `Opacity` / 轻量 `CustomPainter`。

## 平台与构建陷阱

以下配置都是真机实测后的规避方案，代码注释里带日期和原因，改动前先读注释。

- **Android 视频输出**固定 `vo=mediacodec_embed` + `hwdec=mediacodec`，音频 `ao=audiotrack`（`MediaKitBackend._videoConfig` / `applyBufferProfile`，见 `lib/player/player_backend.dart`）：部分 Android 16 / Mali 机型上 `vo=gpu` 不出帧、`ao=opensles` SIGSEGV。**iOS 不能用 `mediacodec_embed`**（不存在，会永远黑屏 + 缓冲中），保持 media_kit 默认。
- **Impeller 已关闭**：`AndroidManifest.xml` 里 `EnableImpeller=false`（HyperOS/mt6878 上 Impeller 遇到 media_kit 视频纹理后 raster 线程停摆）。
- **依赖钉死，不要升级**：`dependency_overrides: path_provider_android: 2.2.12`（纯 JNI 版在部分 Android 16/MIUI 上 `findClass` 失败导致黑屏）；`media_kit_video` 保持 2.x（1.2.5 在 Flutter 3.38+ 上永远黑屏）。
- `android/build.gradle.kts` 把所有子模块统一到 Java 17 / compileSdk 36，用于兼容 media_kit 系老插件与 Gradle 9 的校验。
- Release 包目前用 **debug 签名**（`android/app/build.gradle.kts`），没有正式 keystore。
- iOS 模拟器上 mpv 无法初始化音频设备：检测到模拟器（MethodChannel `olp/device` 的 `isSimulator`，实现于 `AppDelegate.swift`）后设 `ao=null` 无声播放；真机正常。
- 集成测试播放后 position 流持续刷帧，**不能用 `pumpAndSettle`**，只能定时 `pump`。

## 开发机环境参考

- **Windows / Git Bash 机器**：Flutter 3.50.1 stable（Dart 3.14.0，`C:\flutter-sdk\flutter`），Android SDK `C:\Android\Sdk`，JDK 17 在 `C:\Android\jdk-17`（构建前需 `export JAVA_HOME=C:/Android/jdk-17`）；`~/.gradle/init.gradle` 配置阿里云镜像；Git / `gh` 代理 `http://127.0.0.1:10800`。
- **macOS 机器**：JDK 17（`JAVA_HOME=/Users/rocknio/development/jdk-17.jdk/Contents/Home`）；代理 `http://127.0.0.1:1080`（跑 `flutter run` / `flutter test` 需对 `127.0.0.1,localhost` 绕过代理）。
- **常用真机**：小米 24090RA29C（Android 16 / API 36），ADB 序列号 `9PH67DKVXKJRFEMN`。

## 验证基线

- `flutter analyze --no-pub`：25 条 info，0 error / 0 warning——均为既有项：`package:flutter/material.dart` 弃用提示 21 条（含 `integration_test/` 与 `test/`）、`prefer_initializing_formals` 3 条、`onReorder` 弃用 1 条。lint 规则是 `flutter_lints` 默认集，无自定义。不要顺手修它们，只需保证不新增 error / warning（新文件 import `material.dart` 会多一条同类 info）。
- `flutter test`：8 个测试文件共 90 项用例：
  - `test/core_logic_test.dart`（34）：自然排序、媒体扩展名、字幕匹配、进度规则、队列构建、播单续播定位、`SiteConfig.tryNormalizeUrl`
  - `test/playback_controller_test.dart`（16）：并发切歌与重试时序、复合键轨道记忆、外挂字幕透传与容错、睡眠定时、同目录 `.lrc` 歌词加载
  - `test/openlist_client_test.dart`（10）：`Go http.Header` 格式化、`/d` 代理编码、403 静默降级、非 JSON 拦截、相对/协议相对 URL 解析
  - `test/widget_regression_test.dart`（9）：首页英雄卡、网盘多选与 `PopScope`、播单弹窗、音频进度拖动等回归用例
  - `test/app_database_test.dart`（7）：真实 v1→v4 / v3→v4 迁移、播单事务/级联、历史裁剪、会话脏数据过滤、目录级进度/历史查询
  - `test/lrc_parser_test.dart`（6）：LRC 时间戳/多标签/offset 解析、二分查找与 `.lrc` 文件匹配
  - `test/playlist_detail_page_test.dart`（4）：播单详情页续播提示卡与"已看完"状态
  - `test/ui_redesign_test.dart`（4）：三态主题切换持久化、首页最近播放与清空、网盘进度透出与筛选、音频页一屏主控与 LRC/定时/倍速/队列抽屉
