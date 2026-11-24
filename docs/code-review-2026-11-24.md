# OpenListPlayer（云序）全仓 Code Review 报告

- **审查日期**：2026-11-24
- **审查基准**：`main` 分支（commit `555407e`）
- **静态分析基线**：`flutter analyze --no-pub` 0 error / 0 warning（4 条既有 info）
- **单元测试基线**：`flutter test` 32 项全部通过
- **审查范围**：`lib/` 全部 29 个 Dart 源码文件、`android/`、`ios/`、`test/`、`integration_test/` 及项目文档

---

## 一、整体评价与架构亮点

作为一款聚焦解决云盘音视频播放核心痛点（自然排序、倍速、弱网续播、播单独立进度）的移动端播放器，项目整体工程结构清晰、分层克制，具备以下值得肯定的设计亮点：

1. **领域层纯净、可测试性高**：`lib/core/` 下自然排序（`natural_sort.dart`，采用 `BigInt` 防止超长数字段溢出）、外挂字幕同前缀匹配（`subtitle_match.dart`）、进度阈值规则（`ProgressRules`）以及播单续播定位（`locatePlaylistResume`）全部抽离为无副作用纯函数，零 Flutter 依赖，严格遵循 `ui → player → data → core` 单向依赖。
2. **克制的单例与惰性依赖注入**：`PlaybackController` 作为 App 级单例，通过回调 getter（`() => ref.read(apiProvider)` / `() => ref.read(settingsProvider)`）惰性获取最新配置，避免了设置变化时重建底层 `mpv` `Player` 带来的黑屏与高昂资源开销。
3. **贴合真机的容错与迁移实践**：
   - `AppDatabase` 的 `v1 → v2 → v3` 迁移正确规避了 `createTable`（使用最新表定义）与 `addColumn` 叠加的经典陷阱，并在 `beforeOpen` 中显式执行 `PRAGMA foreign_keys = ON` 使外键级联删除真正生效；
   - `PlaybackController._writePlaylist` 捕获外键异常，保证播放途中删除来源播单不会打断当前播放；
   - `main.dart` 为 `AudioService.init`（8s）和 `restoreSession`（5s）均设置了超时兜底，防止原生服务异常卡死首屏。
   - `PlaylistDetailPage` 在 `initState` 中缓存 drift `watch()` 流，避免嵌套 `StreamBuilder` 重复重订阅查库。

---

## 二、高严重度问题（High — 直接导致播放失败、闪退或核心状态错乱）

### H-1. OpenList 直链 `header` 数组被直接 `toString()` 套上方括号，导致需鉴权头驱动 100% 403 失败
- **位置**：`lib/core/openlist_client.dart:109-113`
- **触发条件 / 复现路径**：
  OpenList（AList 系，Go 语言实现）的 `/api/fs/get` 接口返回的 `data.header` 对应 Go 标准库 `http.Header`（即 `map[string][]string`），JSON 结构为：
  ```json
  {
    "Referer": ["https://..."],
    "User-Agent": ["..."]
  }
  ```
  第 112 行直接执行 `headerRaw.forEach((k, v) => headers[k] = v.toString());`。当 `v` 为 `List<dynamic>` 时，Dart 的 `List.toString()` 会生成带方括号的字符串 `"[https://...]"` 并透传给 `mpv`。
- **具体影响**：凡是返回防盗链/鉴权 `header`（`User-Agent`、`Referer`、`Cookie`、`Authorization`）的网盘挂载驱动，`mpv` 发出的 HTTP 请求头均变成非法格式（如 `Referer: [https://...]`），被云盘 CDN 直接拦截返回 `403 Forbidden`。
- **修复建议**：
  区分 `v` 的运行时类型处理：
  ```dart
  headerRaw.forEach((k, v) {
    if (v is List) {
      if (v.isNotEmpty) {
        headers[k] = k.toLowerCase() == 'cookie'
            ? v.map((e) => e.toString()).join('; ')
            : v.map((e) => e.toString()).join(', ');
      }
    } else if (v != null) {
      headers[k] = v.toString();
    }
  });
  ```

---

### H-2. 代理下载兜底地址使用 `Uri.encodeFull(path)`，文件名含 `#`、`?`、`%` 时必断链
- **位置**：`lib/core/openlist_client.dart:104-108`
- **触发条件 / 复现路径**：
  当驱动未返回 `raw_url` 回退到 OpenList 本机代理地址 `/d/...` 时：
  ```dart
  rawUrl = '${_dio.options.baseUrl}/d${Uri.encodeFull(path)}${sign.isEmpty ? '' : '?sign=$sign'}';
  ```
  `Uri.encodeFull` 保留 URI 分隔符 `#`、`?`、`&`、`+`、`=` 不编码，且遇到裸 `%`（如 `100%纯享.flac`）会产生非法百分号编码：
  - 文件名含 `#`（如 `C#教程 #01.mp4`）：`#` 及其后的文件名与整个 `?sign=xxx` 会被 HTTP 客户端当作 URI Fragment 直接截断丢弃；
  - 文件名含 `?`：截断路径并产生双问号破坏 `sign` 参数。
- **具体影响**：代理模式下任何含 `#`、`?`、`%` 的音视频或外挂字幕文件 100% 返回 404/400/签名错误无法播放。
- **修复建议**：按路径段逐段调用 `Uri.encodeComponent`，并对 `sign` 使用 `Uri.encodeQueryComponent`：
  ```dart
  final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
  final query = sign.isEmpty ? '' : '?sign=${Uri.encodeQueryComponent(sign)}';
  rawUrl = '${_dio.options.baseUrl}/d$encodedPath$query';
  ```

---

### H-3. iOS `Info.plist` 同时声明 `NSAllowsLocalNetworking` 与 `NSAllowsArbitraryLoads`，触发 ATS 忽略规则导致非局域网 HTTP 请求被拦截
- **位置**：`ios/Runner/Info.plist:17-23`
- **触发条件 / 复现路径**：
  在 iOS 真机上通过 `openp2p` / Tailscale 虚拟网段（如 `100.64.0.0/10` CGNAT 地址）、公网 HTTP 地址连接 OpenList，或播放返回公网 `http://` 直链的媒体。
- **具体影响**：
  根据 Apple 官方 ATS 文档（iOS 10+），只要 `NSAppTransportSecurity` 字典中同时包含 `NSAllowsLocalNetworking`（或 `NSAllowsArbitraryLoadsForMedia` 等细粒度键），**顶层的 `NSAllowsArbitraryLoads = true` 会被系统直接忽略并强制回退为 `false`**。
  开发期使用 `localhost` 或 `192.168.x.x`（RFC 1918 私有地址）因命中 `NSAllowsLocalNetworking` 而看似正常；一旦进入 `openp2p` 非 RFC 1918 网段或公网 HTTP 直链，iOS 真机所有明文 HTTP 请求将被 ATS 直接拦截失败。此外缺少 `NSLocalNetworkUsageDescription`（iOS 14+ 本地网络权限说明）。
- **修复建议**：从 `Info.plist` 中删除 `NSAllowsLocalNetworking`，仅保留 `NSAllowsArbitraryLoads = true`（已涵盖本地与任意 HTTP），并补充 `NSLocalNetworkUsageDescription`。

---

### H-4. iOS `AppDelegate.swift` 在 `UIScene` 架构下 `window` 恒为 `nil`，`olp/device` 通道从未注册成功
- **位置**：`ios/Runner/AppDelegate.swift:10-26`、`ios/Runner/Info.plist:42-62`、`ios/Runner/SceneDelegate.swift:4-6`
- **触发条件 / 复现路径**：在 iOS 模拟器或真机启动 App，`PlaybackController._isSimulator()` 调用 `olp/device` 通道。
- **具体影响**：项目配置了 `UIApplicationSceneManifest`（`SceneDelegate`）及 `FlutterImplicitEngineDelegate`。在此生命周期下，`didFinishLaunchingWithOptions` 执行时 `AppDelegate.window` 恒为 `nil`，`if let controller = window?.rootViewController as? FlutterViewController` 永远不进入，`olp/device` 通道从未注册。Dart 侧捕获 `MissingPluginException` 静默返回 `false`，导致 iOS 模拟器的 `ao=null` / `cache-on-disk=no` 规避逻辑彻底失效。
- **修复建议**：将 `FlutterMethodChannel` 注册移入 `didInitializeImplicitFlutterEngine`，通过 `engineBridge.applicationRegistrar.messenger()` 获取 `binaryMessenger`；并在 `PlaybackController` 中确保首次 `_player.open` 前已 `await` 完模拟器检测。

---

### H-5. `PlaybackController` 切歌异步等待期间未先停旧流，导致跨曲目串进度、误标“已看完”及 800ms 重试串歌
- **位置**：`lib/player/playback_controller.dart:175-184`、`274-309`、`356-426`、`447-450`、`664-715`、`752-779`
- **触发条件与三条具体竞态链**：
  1. **旧媒体流事件张冠李戴（第 `356-419`、`448`、`665` 行）**：
     `replaceQueue` / `jumpTo` / `next` 先同步将 `index`（即 `current`）改为新曲目 B，随后进入 `_openCurrent()`。在执行第 419 行 `_player.open` 之前隔着最多 4 个 `await`（查偏好、查进度、写续播指针、`getFileLink` 网络请求），期间底层 `_player` **仍在播放旧曲目 A** 且 `_progressTimer` 未取消：
     - A 的 `position` 流持续把 A 的播放位置（如 `20:00`）写进 `_lastPosition`；若 `getFileLink(B)` 超时报错进入 `_onOpenFailure`（`_retryPosition = _lastPosition`），800ms 后重试从未播过的曲目 B 时，会直接跳到 **曲目 A 的 20:00 处** 开播；
     - 若切歌时曲目 A 恰剩最后几百毫秒自然播完触发 `completed = true`，`_onCompleted()` 读到的 `current` 已是曲目 B，会把还没开播的曲目 B 清空全局进度、标为播单 `finished = true`，并自动跳到曲目 C。
  2. **`_onPlayerError` 800ms 延迟重试未校验 `_openSerial` / `idle` 状态且可能双倍计数（第 `692-715` 行）**：
     曲目 A 报错进入 `await Future.delayed(800ms)` 等待窗口内，若用户切到曲目 B 或调用 `stop()`，800ms 后仅检查了 `if (_disposed) return;`，未校验 `_openSerial` 是否已变或 `status == idle`，会强行打断曲目 B 并用曲目 A 的报错位置重开曲目 B，或使已 `stop()` 的播放器幽灵自启。此外 `_player.open` 抛错与 `stream.error` 可能同时触发两次 `_onPlayerError`。
  3. **切歌时 `_recordProgressNow()` 未 `await` 引发读写竞态与脏会话覆盖（第 `274-309`、`752-779` 行）**：
     切歌调用 `_recordProgressNow()` 未 `await`，当其内部第一个 DB `await` 返回执行第 772 行 `unawaited(_saveSessionNow())` 时，`queue`、`index`、`_sourcePlaylistId`、`_lastPosition` 早已被新队列改写；若同文件跨来源切换或重播，还会出现 `_openCurrent` 读进度早于旧队列 `upsertPlaylistProgress` 写进度的竞态。
- **修复建议**：
  - 在 `replaceQueue` / `jumpTo` / `next` / `previous` 中先 `await _recordProgressNow(saveSession: false)` 再切换 `queue` / `index` / `_sourcePlaylistId`；
  - `_openCurrent` 递增 `_openSerial` 后立即取消 `_progressTimer` 与可取消的 `Timer? _retryTimer`，并先 `await _player.pause()`（或 `stop()`）停掉旧流；
  - 维护 `_loadedSerial` 记录已调用 `_player.open` 的序号，在 `_positionSub` / `_durationSub` / `_onCompleted` / `_onPlayerError` 中忽略 `_loadedSerial != _openSerial` 的旧事件。

---

### H-6. `BrowserPage` 普通多选态取消最后一项时误调 `Navigator.maybePop()`，导致直接退回上级目录甚至退出应用
- **位置**：`lib/ui/browser/browser_page.dart:110-116`（联动 `175-190`）
- **触发条件 / 复现路径**：在「文件」Tab（`_pickMode == false`）长按选中 1 个文件进入多选态，再次点击该文件取消选中。
- **具体影响**：
  多选 AppBar 并非独立路由，而是本地状态 `_selecting`（`_selected.isNotEmpty`）。取消最后一项后 `_selected` 已空（`_selecting == false`），第 114 行调用 `Navigator.of(context).maybePop()` 会触发第 175 行 `PopScope.onPopInvokedWithResult`。因 `_selecting` 已为 `false`，直接穿透第 180 行：
  - 在子目录时：用户仅取消选中，却被强制退回上一级父目录；
  - 在根目录 `/` 时：直接执行第 189 行 `SystemNavigator.pop()`，**App 当场退出回系统桌面**。
- **修复建议**：删除 `lib/ui/browser/browser_page.dart:114` 的 `if (_selected.isEmpty && !_pickMode) Navigator.of(context).maybePop();`。

---

### H-7. `BrowserPage` 的 `PopScope(canPop: false)` 跨 Tab 劫持全局返回键，且 `_load` 缺少并发请求序号保护
- **位置**：`lib/ui/browser/browser_page.dart:62-86`、`175-190`、`lib/app.dart:82`
- **触发条件与具体影响**：
  1. **跨 Tab 吞返回键**：`AppShell` 用 `IndexedStack` 常驻挂载 4 个 Tab。用户在「文件」Tab 进入子目录或多选文件后切到「首页/播单/设置」Tab 按返回键，根路由被隐藏的 `BrowserPage` `PopScope(canPop: false)` 拦截，当前页无反应而后台悄悄回退「文件」Tab 目录，且破坏 Android 预测性返回手势。
  2. **目录并发请求错位**：`_load()` 无请求序号保护。进入慢速子目录 `/A` 后立即返回 `/`，`/` 先渲染完成后，慢请求 `/A` 晚到会覆盖 `_entries`；此时 `_path` 为 `'/'` 而列表显示 `/A` 的文件，点播或加播单全部拼出错误路径导致 404。另外 `_tapMedia`（第 96 行）无防重入锁，弱网双击会 push 两个播放页。
- **修复建议**：
  - 订阅 `final isActiveTab = _pickMode || ref.watch(tabIndexProvider) == 1;`，令 `canPop: !(!_pickMode && isActiveTab && (_selecting || _path != '/'))`，根目录无多选时交还系统默认返回；
  - 为 `_load` 增加自增 `_loadSerial`，在 `await` 后的正常、`catch`、`finally` 分支均校验 `serial == _loadSerial`。

---

### H-8. `HomePage._ResumeCard` 与 `panels.dart` 播放面板遗漏 `ListenableBuilder`，导致卡片残留与字幕延迟微调卡死
- **位置**：`lib/ui/home/home_page.dart:79-129`、`lib/ui/player/panels.dart:44-133`、`183-326`
- **触发条件与具体影响**：
  1. `_ResumeCard` 违反 `AGENTS.md` 规范，只调用了 `ref.watch(playbackProvider)` 未包 `ListenableBuilder`。开播后从播放页返回或从其他 Tab 切回首页时，顶部的「继续播放」卡片不会消失（与底部 `MiniPlayerBar` 并存，再次点击会重开当前播放）；若启动时 `restoreSession()` 晚于首帧完成，卡片也无法显示。
  2. `showSubtitlePanel` 等底部面板未包 `ListenableBuilder(listenable: playback, ...)`，且第 220 行将 `cur = playback.currentSubtitle` 写在 `builder` 外。用户连续点击字幕延迟 `-` / `+` 按钮时，面板中间的延迟秒数文案完全冻结不变；面板打开期间异步到达的音轨/外挂字幕列表也不会刷新。
- **修复建议**：在 `_ResumeCard.build` 与 `_showPlayerSheet`（含 `showSpeedPanel` 浅色分支）内部统一包裹 `ListenableBuilder(listenable: playback, ...)`。

---

## 三、中严重度问题（Medium — 状态失步、边界失效或性能/体验缺陷）

### M-1. `_trackSub` 漏绑导致选中音轨/字幕 UI 不更新，且“关闭字幕”无法压制内置默认字幕
- **位置**：`lib/player/playback_controller.dart:135`、`189-193`、`468-475`、`512-577`
- **问题详情**：
  1. 第 135 行声明了 `StreamSubscription? _trackSub;` 并在 `dispose()` 取消，但 `_bindStreams()` 中漏掉了对 `_player.stream.track` 的监听；且 `selectAudioTrack` / `selectSubtitleTrack` 非空分支未调用 `_syncCurrentTracks()`，导致切换已有轨道后 `currentAudio` / `currentSubtitle` 高亮态不更新。
  2. `selectSubtitleTrack(null)` 保存空串 `''` 到数据库；下次打开带内置默认字幕的视频时，`prefs.subtitleTrack` 为 `''`，`_maybeApplyTrackPrefs` 匹配不到名为 `''` 的轨道便跳过，未调用 `_player.setSubtitleTrack(SubtitleTrack.no())`，内置字幕仍被默认展示。
  3. `addExternalSubtitle`（第 570 行）在 `await getFileLink` 后未校验 `current == item`（切歌后会挂到新歌上），且外挂字幕加载未透传 `link.headers`。
- **修复建议**：在 `_bindStreams()` 补绑 `_player.stream.track` 同步调用 `_syncCurrentTracks()`；当 `prefs.subtitleTrack == ''` 时显式调用 `SubtitleTrack.no()`；`addExternalSubtitle` 增加 `_openSerial` 校验。

---

### M-2. `PlayerAudioHandler` 锁屏/通知栏曲目时长恒错位、拖动进度不刷新、前台服务无法停止
- **位置**：`lib/player/audio_handler.dart:42-78`、`95-114`、`lib/player/playback_controller.dart:185-188`、`635-639`
- **问题详情**：
  1. `_onControllerChanged` 仅在切歌瞬间（`_lastMediaItemId != item.path`）推送一次 `MediaItem`，此时新媒体尚未打开，`state.duration` 要么为 `0`（首播推送 `duration: null`），要么**仍是上一首歌的时长**；待真实时长解析出后不再更新 `mediaItem`，导致系统通知栏与锁屏不显示正确总时长或无法拖动进度条。
  2. `PlaybackController.seek()` 未调用 `_notify()`，App 内或通知栏拖动进度条后系统媒体卡片位置不刷新；长按临时 3x 倍速时通知栏仍按原倍速推算。
  3. `PlayerAudioHandler.play()` 直接调 `_c.player.play()`，在冷启动会话恢复态（`idle`）或报错态（`error`）下按蓝牙耳机播放键无响应；`stop()` 未调用 `await super.stop()`，导致 Android 前台服务无法正常退出。
- **修复建议**：监听 `player.stream.duration` 更新当前 `mediaItem` 的 `duration`；`seek()` 末尾调用 `_notify()`；`play()` 在 `idle` 态转调 `resumeSession()`、`error` 态转调 `retryNow()`；`stop()` 补调 `await super.stop()`。

---

### M-3. 播单独立进度在“重播打开失败”与“列表循环播完末曲”两个边界下丢失“已看完”状态
- **位置**：`lib/player/playback_controller.dart:323-324`、`391-394`、`679-685`
- **问题详情**：
  1. `_openCurrent` 第 393 行在请求直链前遇到 `p.finished` 就立即执行 `clearPlaylistProgress`（与 `app_database.dart:258` 注释中“保留行、靠后续 upsert 覆盖 `finished`”的设计冲突）。若直链获取断网失败或用户点错立即退出，文件并未播放，“已看完”记录却已被永久删除。
  2. `PlayMode` 仅有 `sequentialLoop`（默认）、`repeatOne`、`shuffle`，无“顺序播完即停”模式。多曲播单播完最后一集时，`_onCompleted` 刚把末集标为 `finished = true`，紧接着自动绕回第 1 集调用 `_openCurrent` 并立即清掉第 1 集的 `finished`，导致用户自然播完整张播单后永远看不到详情页变为“全部已看完 / 播放全部”。
- **修复建议**：移除 `_openCurrent` 第 393 行的 `clearPlaylistProgress`（`p.finished` 时仅设 `start = null` 从头播，等产生有效未完进度时由 `upsertPlaylistProgress` 自然将 `finished` 置回 `false`）；评估增加顺序播完停机策略。

---

### M-4. 会话恢复、删播单回退、切换站点与「当前播放」页 `idle` 态边界缺陷
- **位置**：`lib/player/playback_controller.dart:635-639`、`794-824`、`lib/ui/playlist/current_queue_page.dart:102-106`、`lib/providers.dart:26-31`、`lib/data/app_database.dart:104`
- **问题详情**：
  1. **首播拖动进度条立即退出丢失位置**：`seek()` 只写 `sessionState` 不写进度表；若首次打开未满 5 秒就拖进度条并退出，下次 `resumeSession()` 因进度表查不到 `durationMs`（为 0）而直接丢弃 `sessionState` 中的断点从头播。
  2. **恢复态点击「当前播放」当前项黑屏**：冷启动恢复会话后（`status == idle`），进入 `CurrentQueuePage` 点击高亮的当前项（`isCurrent == true`），既不调 `jumpTo` 也不调 `resumeSession` 直接进入播放页，底层 `mpv` 未加载任何 URL，无法播放。
  3. **删播单后会话断点失效**：`SessionState.sourcePlaylistId` 无外键置空，删除关联播单后 `_sourcePlaylistId` 仍非空，`resumeSession` 与 `_openCurrent` 查不到播单进度且忽略全局进度；未点继续播放直接切歌也未重置 `_restoredPosition = null`。
  4. **切换或清空站点不断播**：`setSite` 未 `stop()` 旧站点队列，清空站点后以空 `baseUrl` 请求会抛 `ArgumentError`。
- **修复建议**：`SessionState` 同时保存 `durationMs`；`CurrentQueuePage` 在 `isCurrent && playback.status == PlaybackStatus.idle` 时调用 `playback.resumeSession()`；`_writePlaylist` 外键失败或删播单时回退 `_sourcePlaylistId = null`；变更站点时调用 `playback.stop()`。

---

### M-5. 音视频页进度条无本地拖拽态引发滑块抖动与请求风暴，以及亮度/常亮/手势中断泄漏
- **位置**：`lib/ui/player/audio_page.dart:30, 36, 226-253`、`lib/ui/player/player_screen.dart:51, 88, 95-107, 131-148, 244-275, 511-541, 673`
- **问题详情**：
  1. **进度条抖动与 Range/SQLite 风暴**：`Slider.value` 直接绑定 `position` 流且 `onChanged` 每帧直调 `playback.seek()`。手指拖动 1 秒会发起数十次 HTTP Range 重连与 SQLite 会话写入，且网络 seek 完成前滑块在手指与旧播放时间之间剧烈跳动。
  2. **长按 3x 倍速卡死**：`GestureDetector` 绑定了 `onLongPressStart` / `onLongPressEnd`，漏了 `onLongPressCancel`（及 `onHorizontalDragCancel`）。来电、通知栏下拉或手势滑出打断长按时，`restoreSpeed()` 永不触发，播放器一直锁在 `3.0x` 而 UI 仍显示 `1x`。
  3. **3 秒隐藏定时器打断拖动**：拖动进度条或点击控制栏按钮未重置/暂停 `_hideTimer`，唤出后第 3 秒控制栏卸载会直接中断正在进行的拖动手势。
  4. **亮度与屏幕常亮泄漏**：退出 `PlayerScreen` 未调用 `ScreenBrightness().resetApplicationScreenBrightness()` 恢复系统亮度；停留在播放页处于暂停/播完/报错态时 `WakelockPlus` 永不释放屏幕常亮；`OrientationBuilder` 在 `build` 内重复调用 `SystemChrome.setEnabledSystemUIMode`。
- **修复建议**：为 `Slider` 增加本地 `_dragMs` 状态，仅在 `onChangeEnd` 调用一次 `playback.seek()`；补齐 `onLongPressCancel` / `onHorizontalDragCancel`、亮度重置与基于播放状态的常亮管理，并在交互控件上重置 `_hideTimer`。

---

### M-6. `AppDatabase` 多处写操作缺少事务保护，`PlaylistItems` 缺少索引，`SiteConfig` 缺少值相等
- **位置**：`lib/data/app_database.dart:21-30, 174-225, 314-323`、`lib/core/models.dart:5-24`、`lib/providers.dart:63-66`、`lib/core/openlist_client.dart:27-28, 46-56`、`lib/data/settings_service.dart:73-86`
- **问题详情**：
  1. `reorderPlaylistItems` 在循环中无事务逐行 `await update`，重排 N 项会提交 N 次事务并触发 N 次 Stream 半成品推送导致列表闪烁；`removePlaylistItem`、`addItemsToPlaylist`、`saveTrackPrefs` 同样未包 `transaction`。
  2. `PlaylistItems` 主键仅为 `id`，缺少 `(playlistId, position)` 索引，查询播单条目及父表 `ON DELETE CASCADE` 均需全表扫描。
  3. `SiteConfig` 未重写 `operator ==` 与 `hashCode`，导致每次修改倍速/排序/缓冲档位时 `settingsProvider.select((s) => s.site)` 均判定变化，反复重建 `OpenListClient` 且旧 `Dio` 未 `close()`。
  4. `OpenListClient.listDir` 仅捕获业务层 403 且强依赖英文 `'refresh'` 字样（未兼容 HTTP 403 `DioException` 或中文错误提示）；`SettingsService.saveSite` 未校验 URL 是否含合法 `http(s)://` scheme 与 host。
- **修复建议**：多语句写入统一用 `transaction` + `batch`；为 `PlaylistItems` 添加 `(playlistId, position)` 索引；为 `SiteConfig` 实现 `==` / `hashCode` 并在 `apiProvider` 注册 `ref.onDispose(client.close)`；补齐 URL 校验与 403 降级兼容。

---

### M-7. 软键盘与底部浮层遮挡交互元素、音频主封面错误回退缺失及左滑误删无保护
- **位置**：
  - `lib/ui/browser/add_to_playlist_sheet.dart:54-56`：未叠加 `MediaQuery.viewInsetsOf(context).bottom`，弹起软键盘时完全遮挡底部的「新播单名称」输入框与提交按钮；`_createAndAdd` 无防连点锁。
  - `lib/ui/browser/browser_page.dart:194, 352` 与 `lib/ui/playlist/playlists_page.dart:39`：`ListView` 缺少底部 `padding`，列表末尾项分别被多选底栏「添加到播单」和右下角「新建播单」FAB 遮挡。
  - `lib/ui/player/audio_page.dart:172`：300pt 主封面当 `item.thumb` 非空但远程加载失败时，`errorBuilder` 返回 `SizedBox.shrink()` 变为空白色块，未按规范回退 `AudioPlaceholderArt(isDark: false)`。
  - `lib/ui/playlist/playlist_detail_page.dart:43, 174-184`：`Dismissible` 左滑无 `confirmDismiss` 二次确认也无 Undo SnackBar，误滑即连带永久清除该条目在本播单的播放进度；且 `PlaylistItems` 表未存 `thumb`，从播单播放会丢失封面缩略图。

---

## 四、低严重度问题、发布阻断清理与测试盲区（Low / Release & Tests）

### L-1. 发布前待清理的调试代码（4 处 `TODO(debug)`）与敏感日志输出
- `lib/player/playback_controller.dart:50`：`logLevel: MPVLogLevel.info` 未改回 `MPVLogLevel.warn`。
- `lib/player/playback_controller.dart:57`：`_player.stream.log.listen(...)` 未保存 `StreamSubscription` 取消，持续跨线程刷屏输出 mpv 日志。
- `lib/player/playback_controller.dart:431-433`：每次开播创建未守卫 `_disposed` 的 `Future.delayed(2s)` 打印 `textureId`（在组件测试提前销毁时会导致残留 Timer 失败）。
- `lib/player/playback_controller.dart:417-418`：非 `kDebugMode` 守卫下直接 `debugPrint` 输出带 `sign` 的完整直链与可能含 `Cookie`/`Authorization` 的 `headers`。
- `android/app/src/main/kotlin/com/songyaning/openlistplayer/MainActivity.kt:5, 9-14`：残留未使用的 `FlutterRenderer` import 与实验注释。
- `android/app/build.gradle.kts:36`：`release` 构建仍使用 debug 签名密钥。

### L-2. 细节缺陷、代码卫生与文档同步
- `lib/ui/settings/settings_page.dart:51, 53`：`_testConnection` 在 `await` 之后未检查 `if (!mounted) return;` 直接 `setState`；`_testResult` 与两个按钮挤在同一 `Row` 内，窄屏大字号下易挤压截断。
- `lib/ui/playlist/playlists_page.dart:101`：`_promptName` 弹窗创建的 `TextEditingController` 未 `dispose()`。
- `lib/player/audio_handler.dart:13-16, 28-39`：4 个 `StreamSubscription` 与 `addListener` 未保存释放钩子。
- `lib/core/queue_builder.dart:42`：`SortMode.modified` 下构建播放队列返回 `0` 未按修改时间排序，导致点开后的上下集顺序与文件浏览器列表顺序不一致。
- `lib/data/app_database.dart:74, 296-303`：`PlayHistories` 注释写保留最近 20 条，实际只写不裁且首页已无历史入口。
- `lib/ui/playlist/playlist_detail_page.dart:165`：`ReorderableListView.onReorder` 在 Flutter 3.41+ 已弃用（注：后续迁移至 `onReorderItem` 时框架已自动修正 `newIndex`，届时需同步移除手动 `if (newIndex > oldIndex) newIndex--;`）。
- 少量硬编码色值（`audio_page.dart:164, 449, 492`、`mini_player_bar.dart:40`、`app_theme.dart:99`）与未使用组件（`widgets.dart` 的 `CoverArt`、`audio_theme.dart` 的 `GridBackdrop`）。
- 文档注释滞后：`pubspec.yaml:119`（写要求 `EnableImpeller=true`，与 manifest 相反）、`android/build.gradle.kts:8, 19`（仍写 `media_kit_video 1.2.5`）、`lib/app.dart:1`（写深色跟随系统）、`README.md:68-75, 100, 103`（缺 `playlist_resume.dart`、提及已移除的最近历史与不存在的设置页全局倍速入口）。

### L-3. 测试套件缺陷与覆盖盲区
- **现有集成测试必败**（`integration_test/app_test.dart:31, 64`）：第 31 行未 `await app.main()` 存在启动竞态；第 64 行仍断言旧版文案 `'播放队列 (5)'`（`AudioPage` 重构后实际为 `'共 5 集'` / `'播放列表'`），运行必挂，且强依赖个人云盘真实目录名。
- **核心单测盲区（0 覆盖）**：
  1. `OpenListClient`：Go `http.Header` 数组解析、`/d` 代理路径特殊字符编码、guest `403` 刷新静默降级；
  2. `AppDatabase`：v1→v2→v3 真实 schema 迁移、`PRAGMA foreign_keys = ON` 级联删除、播单去重与重排事务；
  3. `PlaybackController`：切歌/重连状态机竞态、全局与播单进度双写隔离、删播单外键容错、会话恢复分流；
  4. 关键 Widget 测试：`BrowserPage`（多选取消、跨 Tab `PopScope`、并发切目录）、`HomePage`（`_ResumeCard` 状态联动）。

---

## 五、建议修复路线图

| 批次 | 目标范围 | 关联编号 |
| --- | --- | --- |
| **第一批：网络与平台阻断项** | 修复 `OpenListClient` 请求头方括号与 `/d` 路径特殊字符编码；修复 iOS ATS 配置冲突与 `AppDelegate` 通道注册；补充 `OpenListClient` 单测 | H-1, H-2, H-3, H-4 |
| **第二批：播放内核与通知栏** | 修复 `PlaybackController` 切歌停旧流、`_openSerial` 重试守卫、`_recordProgressNow` 等待时序、`_trackSub` 绑定与关闭字幕记忆、播单重播误删 `finished` 及会话恢复边界；修复 `PlayerAudioHandler` 锁屏时长与 `stop()` | H-5, M-1, M-2, M-3, M-4 |
| **第三批：UI 交互与状态同步** | 删除 `BrowserPage` 多选误 `maybePop`、修复跨 Tab `PopScope` 与目录加载序号；为 `_ResumeCard` 与 `panels.dart` 补齐 `ListenableBuilder`；修复进度条拖拽抖动、长按 3x 取消、亮度重置、软键盘与底栏遮挡、主封面回退 | H-6, H-7, H-8, M-5, M-7 |
| **第四批：数据库、测试与发布清理** | 补齐 `AppDatabase` 事务与 `PlaylistItems` 索引、`SiteConfig` 值相等；清理 4 处 `TODO(debug)` 与敏感日志；修复 `integration_test` 并补齐 DB/Controller 单测与文档同步 | M-6, L-1, L-2, L-3 |
