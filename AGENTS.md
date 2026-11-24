# AGENTS.md — OpenListPlayer（云序）

面向 ZCode agent 的项目须知。上手前先读 `README.md`（项目简介 / 架构 / 功能）；最近一轮改动的决策与验证记录在 `.workbuddy/memory/<日期>.md` 工作日志里。

## 项目是什么

- **云序（YUNXU）**：Flutter 手机端（Android / iOS）音视频播放器，是 [openlist](https://github.com/OpenListTeam/OpenList) 的前端。App 只通过 openlist REST API（`/ping`、`/api/fs/list`、`/api/fs/get`）列目录、取直链，交给 media_kit（mpv）解码；**不直接对接天翼云盘**。
- v1 范围：单站点、guest 免认证。`SiteConfig.token` 只是预留扩展位，登录鉴权并未实现。
- **命名分离**：「云序」只用于显示层（AppBar、通知渠道、Android `label`、iOS `CFBundleDisplayName`）。技术标识符保持不动——pubspec 包名 `openlistplayer`（Dart 导入 `package:openlistplayer/...`）与 applicationId `com.songyaning.openlistplayer`、iOS `CFBundleName`；改了会破坏导入 / 编译 / 签名。

## 目录与分层

```
lib/
├── main.dart        启动顺序：锁竖屏 → MediaKit → prefs/db → ProviderContainer → AudioService.init → restoreSession → runApp
├── app.dart         MaterialApp + 底部 4 tab 外壳（IndexedStack 常驻）+ 生命周期钩子
├── providers.dart   全部 Riverpod provider（集中在这一个文件）
├── core/            纯 Dart 领域逻辑，无 Flutter 依赖 → 单测对象
├── data/            drift 数据库（app_database.dart + 生成的 .g.dart）、SharedPreferences 设置
├── player/          PlaybackController（ChangeNotifier，播放内核）、PlayerAudioHandler（audio_service）
└── ui/              按页面分目录；app_theme / widgets / mini_player_bar / tab_index 在根
```

- 依赖只能向下：`ui → player → data → core`（UI 也会直接读 data / core）；`core/` 不 import 任何上层。
- 新增纯逻辑（排序、匹配、规则）放 `core/`，并在 `test/core_logic_test.dart` 补单测。
- `design_output/` 是 logo 与占位图的 SVG 源文件和出图脚本，不是 App 代码；应用图标由 `design_output/logo/deploy_icons.py` 覆盖写入 android / ios 的图标资源。

## 命令

```bash
flutter pub get
flutter analyze --no-pub                                   # 基线 22 条 info，无 error/warning
flutter test                                               # 32 项：test/core_logic_test.dart（纯逻辑）+ test/playlist_detail_page_test.dart（组件，用内存 SQLite）
dart run build_runner build --delete-conflicting-outputs   # 改 app_database.dart 后必跑
flutter run
flutter build apk --release --target-platform android-arm64   # → build/app/outputs/flutter-apk/app-release.apk
flutter test integration_test/app_test.dart                # 需设备 + 本机 localhost:5244 的 OpenList（含测试用目录数据）
```

## 架构要点

- **DI**：Riverpod 3（手写 `Notifier`，无代码生成）。`settingsServiceProvider` / `dbProvider` / `sharedPreferencesProvider` 默认 `throw UnimplementedError()`，只在 `main.dart` 用 `overrides` 注入。
- **`PlaybackController` 是 App 级单例**，不随设置或站点变化重建；它通过回调 getter（`() => ref.read(apiProvider)`）读最新依赖，所以站点地址变了只需让 `apiProvider` 重建。不要另建实例——每个实例都会创建自己的 mpv `Player`。
- **UI 读播放状态必须包 `ListenableBuilder(listenable: playback, ...)`**：`ref.watch(playbackProvider)` 只拿到实例，`notifyListeners()` 不会触发 Riverpod 重建。
- **队列语义**：点网盘文件 = 同目录全部音视频整体替换队列，并从所点项开播（`playFromDirectory`）；播单播放 = 整张播单复制为队列（`playQueue(..., playlistId:)`），点击只决定起点，不截断队列。
- **进度规则**（`ProgressRules` 纯函数）：时长 <10s 不记录；进度 ≥95% 视为看完，全局进度删行（下次从头播；播单进度见下）；每 5 秒落盘，暂停、切歌、退后台时立即记录，拖动进度条立即保存会话位置。
- **弱网**：buffering 无限等待，绝不自动跳曲；失败自动重试最多 2 次（间隔 800ms），一律从最近位置重取直链重连，**绝不回片头**。
- **进度双写**：全局 `playProgresses`（按 path）始终写；队列来源是播单时（`_sourcePlaylistId != null`）额外写 `playlistProgresses`（playlistId + path），并在 `_openCurrent` 里更新续播指针 `playlistStates`（每播单一行，记"上次播到哪个文件"）。`replaceQueue` 里必须先给旧队列记进度、再切换 `_sourcePlaylistId`。
- **播单续播**："播到哪一秒"查 `playlistProgresses`，"播到哪一个"查 `playlistStates`，起点由 `core/playlist_resume.dart` 的 `locatePlaylistResume`（纯函数，有单测）算出。播单进度看完不删行、置 `finished`（全局进度才是看完即删）。所有播单相关写入都走 `PlaybackController._writePlaylist` 容错——播单在播放途中被删除时外键会拒绝写入，不能让它打断播放。
- **会话**：`restoreSession()` 只装载队列不开播，首页「继续播放」卡片才触发 `resumeSession()`。
- **drift 迁移**：改表 → 升 `schemaVersion` → 在 `migration.onUpgrade` 加 `if (from < N)` 分支 → 重跑 build_runner。`app_database.g.dart` 已入库，必须与 `.dart` 一起提交。（工作日志记录：Flutter 3.50 会提示 `--delete-conflicting-outputs` 已弃用，可忽略。）两个坑：`createTable` 用的是**当前**表定义，跨版本建表后不能再对同一张表 `addColumn`；SQLite 和 drift 都默认不开外键，`ON DELETE CASCADE` 靠 `migration.beforeOpen` 里的 `PRAGMA foreign_keys = ON` 才生效。迁移可以用临时测试实测：`AppDatabase(NativeDatabase(File(...)))` + 手写旧版 DDL + `PRAGMA user_version`，`flutter test` 在本机能直接加载 SQLite。组件测试里用 drift 的 `watch()` 流时，用例结束前必须先 `pumpWidget` 卸载页面再 `pump` 一次：drift 在订阅取消时会排一个零时长 Timer，不跑掉的话 flutter_test 报"残留 Timer"失败，`db.close()` 还会一直卡住。

## 编码约定

- 代码注释、UI 文案、文档、commit message 一律中文；commit 用 `feat:` / `fix:` / `docs:` / `style:` 前缀 + 中文描述。
- 每个 dart 文件以一行 `/// 职责说明` 开头，随后 `library;`。
- 项目内 import 用相对路径（`import '../core/models.dart';`），外部包用 `package:`。
- **不要整仓跑 `dart format`**：仓库未按 Dart 3.14 格式化器统一过（31 个文件里 28 个会被改写），整仓格式化会制造大量无关 diff。手工跟随所在文件的风格。
- 日志用 `debugPrint('[OLP] ...')`（mpv 日志前缀 `[mpv]`），不用 `print`。
- 配色唯一来源：`lib/ui/player/audio_theme.dart` 的 `AudioTone`（8 色：陶土 `#B85C38` 主色、米白 `#F5F2EC` 底、墨色 `#21201D` 文字…）与 `lib/ui/app_theme.dart`（`AppTheme.light/dark`、深色变体 `AppPalette`、视频遮罩 `scrim`）。新 UI 从 `Theme.of(context).colorScheme` 或这两个类取色，不引入新的硬编码色值。
- `app.dart` 固定 `themeMode: ThemeMode.light`（全 App 米白浅色）；`AppTheme.dark` 虽传给了 `darkTheme`，但不会生效。
- 全 App 锁竖屏；只有视频页全屏时临时横屏（`player_screen.dart` 的 `_enterFullscreen` / `_exitFullscreen`），退出全屏与 `dispose` 都要恢复 `portraitUp`。
- 倍速 / 时长显示统一用 `widgets.dart` 的 `formatSpeed` / `formatDuration`；音频无封面回退 `AudioPlaceholderArt`，远程缩略图必须带 `errorBuilder`。

## 平台与构建陷阱

以下配置都是真机实测后的规避方案，代码注释里带日期和原因，改动前先读注释。

- **Android 视频输出**固定 `vo=mediacodec_embed` + `hwdec=mediacodec`，音频 `ao=audiotrack`（`PlaybackController._videoConfig` / `_applyBufferProfile`）：部分 Android 16 / Mali 机型上 `vo=gpu` 不出帧、`ao=opensles` SIGSEGV。**iOS 不能用 `mediacodec_embed`**（不存在，会永远黑屏 + 缓冲中），保持 media_kit 默认。
- **Impeller 已关闭**：`AndroidManifest.xml` 里 `EnableImpeller=false`（HyperOS/mt6878 上 Impeller 遇到 media_kit 视频纹理后 raster 线程停摆）。`pubspec.yaml` 注释里仍写着"要求 `EnableImpeller=true`"，与 manifest 不一致，以 manifest 为准。
- **依赖钉死，不要升级**：`dependency_overrides: path_provider_android: 2.2.12`（纯 JNI 版在部分 Android 16/MIUI 上 `findClass` 失败导致黑屏）；`media_kit_video` 保持 2.x（1.2.5 在 Flutter 3.38+ 上永远黑屏）。
- `android/build.gradle.kts` 把所有子模块统一到 Java 17 / compileSdk 36，用于兼容 media_kit 系老插件与 Gradle 9 的校验。
- Release 包目前用 **debug 签名**（`android/app/build.gradle.kts`），没有正式 keystore。
- iOS 模拟器上 mpv 无法初始化音频设备：检测到模拟器（MethodChannel `olp/device` 的 `isSimulator`，实现于 `AppDelegate.swift`）后设 `ao=null` 无声播放；真机正常。
- 集成测试播放后 position 流持续刷帧，**不能用 `pumpAndSettle`**，只能定时 `pump`。
- `playback_controller.dart` 里有 3 处 `TODO(debug)`（mpv 日志级别、日志订阅、纹理诊断），发布前需清理。

## 本机环境（Windows / Git Bash，仅适用于这台机器）

- Flutter 3.50.1 stable（Dart 3.14.0），SDK 在 `C:\flutter-sdk\flutter`，已在 PATH。
- Android SDK `C:\Android\Sdk`，JDK 17 在 `C:\Android\jdk-17`。**`JAVA_HOME` 默认未设置**：Android 构建前先 `export JAVA_HOME=C:/Android/jdk-17` 并加入 PATH，否则 Gradle 报 JAVA_HOME 未设置。
- `maven.google.com` 在当前网络不可用，已由 `~/.gradle/init.gradle` 切到阿里云镜像。
- Git push / `gh` 需走本地代理 `http://127.0.0.1:10800`。
- 测试机：小米 24090RA29C（Android 16 / API 36），ADB 序列号 `9PH67DKVXKJRFEMN`。

## 验证基线与文档

- `flutter analyze --no-pub`：22 条 info，全部既有——`package:flutter/material.dart` 弃用提示 18 条（每个 import 该库的文件一条，含组件测试文件）、`prefer_initializing_formals` 3 条、`onReorder` 弃用 1 条。lint 规则是 `flutter_lints` 默认集，无自定义。不要顺手修它们，只需保证不新增 error / warning（新文件 import `material.dart` 会多一条同类 info）。
- `flutter test`：32 项通过（18 项原有 + 10 项播单续播定位 + 4 项播单详情页组件测试）。
- `README.md` 是初稿，部分描述滞后于代码，以代码和工作日志为准。已知出入：首页已无「最近播放」区块（`historyStream` / `clearHistory` 仍在 DB 层但没有 UI 调用）；`app.dart` 头注释写"深色跟随系统"，实际固定浅色。
