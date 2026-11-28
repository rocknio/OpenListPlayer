# 启动时检测并一键拉起 OpenP2P Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Android 端云序冷启动时自动检测 OpenP2P 端口映射 / OpenList 连通性，未运行时弹窗提示并支持一键拉起 `cn.openp2p`，同时在首页保留顶部提醒横幅与前后台切回自动复检闭环。

**Architecture:** 将纯 Dart 探测策略放在 `lib/core/openp2p_probe.dart`（含 TCP 端口探测与 `/ping` 联合判定，无 Flutter 依赖），Android 原生包检测与拉起通过现有 `olp/device` `MethodChannel` 封装在 `lib/data/openp2p_service.dart` 并由 Riverpod `Notifier`（`OpenP2pMonitor`）管理状态与并发序号守卫；UI 层在 `lib/app.dart` 挂接冷启动弹窗与 `resumed` 静默复检，在 `lib/ui/home/home_page.dart` 展示顶部提醒横幅并联动站点状态胶囊，在 `lib/ui/settings/settings_page.dart` 提供开关持久化。

**Tech Stack:** Flutter / Dart (`dart:io` Socket), Riverpod 3 (手写 `Notifier`), Dio (`OpenListClient`), SharedPreferences (`SettingsService`), Android Kotlin `MethodChannel`, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-11-28-openp2p-startup-check-design.md`

## Global Constraints

- 依赖只能向下：`ui → player → data → core`；`lib/core/` 禁止 import `package:flutter/...`。
- 每个新增 Dart 文件以 `/// 职责说明` 开头，紧接 `library;`；项目内 import 一律使用相对路径。
- 代码注释、UI 文案、commit message 一律中文；严禁对整仓运行 `dart format`。
- 配色唯一来源：`AppPalette` / `AudioTone` / `Theme.of(context).colorScheme`，不引入新的硬编码 `Color(...)`；图标从 `AppIcons` 取用。
- 仅在 Android 平台生效（包名 `cn.openp2p`，零高危系统权限）；iOS 与测试宿主默认跳过，不得触发 `MissingPluginException` 或破坏既有测试。
- 最终验证须满足 `flutter analyze --no-pub` 零 error / 零 warning，全量单元测试通过。

## Review Focus

- **并发检测与站点/开关变更竞态**：冷启动探测尚未返回时用户修改/清空站点或关闭开关，迟到的旧结果不得覆盖新状态或误弹窗（`OpenP2pMonitor` 递增 `_serial` 守卫，覆盖于 Task 2 测试）。
- **原生拉起失败处理**：点击「启动 OpenP2P」但 `launchApp` 返回 `false`（被系统拦截或刚被卸载）时给出 SnackBar 提示而非静默无响应（覆盖于 Task 3 测试）。
- **非 Android 宿主静默跳过**：`OpenP2pBridge.isSupported == false` 时不调用 `MethodChannel`，确保 iOS 真机与既有 `flutter_test` 套件零影响（覆盖于 Task 2 测试）。
- **重复弹窗防重入**：冷启动已弹过一次（无论点「暂不启动」还是「启动 OpenP2P」）后，切后台再回前台 `resumed` 仅静默复检，绝不二次弹窗（覆盖于 Task 2 & Task 3 测试）。
- **缺省端口与异常 `/ping` 响应**：`http://127.0.0.1` / `https://localhost/alist` 正确回退到 80 / 443 端口；`/ping` 返回非 200、非 `pong` 或抛出网络异常时返回 `false` 而不抛未捕获异常（覆盖于 Task 1 测试）。

---

### Task 1: 纯 Dart OpenP2P 探测逻辑与 `OpenListClient.ping`

**Files:**
- Create: `lib/core/openp2p_probe.dart`
- Modify: `lib/core/openlist_client.dart:83-95`
- Test: `test/openp2p_probe_test.dart`

**Interfaces:**
- Consumes: `SiteConfig` (`lib/core/models.dart`), `OpenListClient` (`lib/core/openlist_client.dart`)
- Produces:
  - `OpenListClient.ping({Duration timeout = const Duration(milliseconds: 2500)}) -> Future<bool>`
  - `const String kOpenP2pPackageName = 'cn.openp2p';`
  - `enum OpenP2pStatus { idle, checking, connected, notRunning, unreachable, notInstalled }`
  - `bool isLoopbackHost(String host)`
  - `int resolveUriPort(Uri uri)`
  - `typedef TcpProbe = Future<bool> Function(String host, int port, Duration timeout);`
  - `typedef PingProbe = Future<bool> Function(SiteConfig site, Duration timeout);`
  - `typedef AppInstalledChecker = Future<bool> Function(String packageName);`
  - `Future<bool> defaultTcpProbe(String host, int port, Duration timeout)`
  - `Future<OpenP2pStatus> probeOpenP2p({required SiteConfig site, required TcpProbe tcpProbe, required PingProbe pingProbe, required AppInstalledChecker isAppInstalled, Duration tcpTimeout = const Duration(milliseconds: 1500), Duration pingTimeout = const Duration(milliseconds: 2500)})`

- [ ] **Step 1: 编写失败单测 `test/openp2p_probe_test.dart`**

覆盖以下断言：
1. `isLoopbackHost`：`127.0.0.1`、`localhost`、`LOCALHOST`、`::1`、`[::1]` 为 `true`；`192.168.2.29`、`example.com`、空串为 `false`。
2. `resolveUriPort`：`http://127.0.0.1` → `80`、`https://localhost/alist` → `443`、`http://127.0.0.1:5244` → `5244`。
3. `probeOpenP2p` 本机映射场景（`http://127.0.0.1:5244`）：
   - TCP 失败 + 已安装 `cn.openp2p` → `OpenP2pStatus.notRunning`（不调用 `pingProbe`）。
   - TCP 失败 + 未安装 `cn.openp2p` → `OpenP2pStatus.notInstalled`。
   - TCP 成功 + `pingProbe` 返回 `true` → `OpenP2pStatus.connected`。
   - TCP 成功 + `pingProbe` 返回 `false` → `OpenP2pStatus.unreachable`。
4. `probeOpenP2p` 非本机场景（`http://192.168.2.29:5244`）：
   - 直接调 `pingProbe`（不调 `tcpProbe`），返回 `true` → `OpenP2pStatus.connected`。
   - `pingProbe` 返回 `false` + 已安装 `cn.openp2p` → `OpenP2pStatus.notRunning`。
   - `pingProbe` 返回 `false` + 未安装 `cn.openp2p` → `OpenP2pStatus.idle`（不误报）。
5. `OpenListClient.ping`（用自定义 `HttpClientAdapter` 模拟）：
   - 返回 `200` + `"pong\n"` → `true`。
   - 返回 `200` + `"<html>502</html>"` → `false`。
   - 抛出 `DioException` 或未配置 `baseUrl` → 返回 `false`（不抛异常）。

- [ ] **Step 2: 运行测试确认失败**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_probe_test.dart`
Expected: FAIL（`openp2p_probe.dart` 与 `OpenListClient.ping` 尚未定义）

- [ ] **Step 3: 实现 `OpenListClient.ping` 与 `lib/core/openp2p_probe.dart`**

1. 在 `lib/core/openlist_client.dart` 新增 `Future<bool> ping({Duration timeout = const Duration(milliseconds: 2500)})`：未配置 `baseUrl` 返回 `false`；使用 `Options(sendTimeout: timeout, receiveTimeout: timeout)` 发起 `GET /ping`（同时给单次请求加 `.timeout(timeout)` 防 connectTimeout 过长），仅当 `statusCode == 200 && data?.trim() == 'pong'` 返回 `true`，任何异常捕获并返回 `false`。
2. 新建 `lib/core/openp2p_probe.dart`：实现 `kOpenP2pPackageName`、`OpenP2pStatus`、`isLoopbackHost`、`resolveUriPort`、`defaultTcpProbe`（`Socket.connect` 成功后立即 `destroy()`，异常返回 `false`）及 `probeOpenP2p`。

- [ ] **Step 4: 运行测试确认通过**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_probe_test.dart`
Expected: All tests passed!

- [ ] **Step 5: 提交**

```bash
git add lib/core/openp2p_probe.dart lib/core/openlist_client.dart test/openp2p_probe_test.dart
git commit -m "feat: 新增 OpenP2P 端口与服务连通性纯 Dart 探测逻辑"
```

---

### Task 2: Android 原生桥接、设置开关与 `OpenP2pMonitor` 状态管理

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:73-78`
- Modify: `android/app/src/main/kotlin/com/songyaning/openlistplayer/MainActivity.kt:1-7`
- Modify: `lib/data/settings_service.dart:8-133`
- Create: `lib/data/openp2p_service.dart`
- Modify: `lib/providers.dart:1-112`
- Test: `test/openp2p_monitor_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `OpenP2pStatus`, `kOpenP2pPackageName`, `probeOpenP2p`, `defaultTcpProbe`, `OpenListClient.ping`
- Produces:
  - `AppSettings.checkOpenP2pOnStart` (`bool`, default `true`) 与 `SettingsService.saveCheckOpenP2pOnStart(bool v)`（SharedPreferences 键 `network.check_openp2p`）
  - `AppSettingsNotifier.setCheckOpenP2pOnStart(bool v)`
  - `abstract class OpenP2pBridge { bool get isSupported; Future<bool> isAppInstalled(String packageName); Future<bool> launchApp(String packageName); }`
  - `class PlatformOpenP2pBridge implements OpenP2pBridge`（基于 `MethodChannel('olp/device')`，仅 `Platform.isAndroid` 时 `isSupported == true`）
  - `class OpenP2pState { final OpenP2pStatus status; final bool hasPromptedThisSession; final bool shouldPrompt; final bool launchedThisSession; bool get needsAttention; }`（`needsAttention` 在 `notRunning` / `unreachable` / `notInstalled` 时为 `true`）
  - `class OpenP2pMonitor extends Notifier<OpenP2pState>`：
    - `Future<OpenP2pStatus> check({required bool allowPrompt})`
    - `void markPromptHandled()`（清 `shouldPrompt` 并置 `hasPromptedThisSession = true`）
    - `Future<bool> launchOpenP2p()`（调用 `bridge.launchApp(kOpenP2pPackageName)`，成功时置 `launchedThisSession = true`）
    - `void reset()`（清空状态，供站点清空或关闭检测开关时调用）
  - `openP2pBridgeProvider` / `openP2pTcpProbeProvider` / `openP2pMonitorProvider`（均可在单测中 override）

- [ ] **Step 1: 编写失败单测 `test/openp2p_monitor_test.dart`**

使用 `ProviderContainer` + 假 `OpenP2pBridge` + 假 `TcpProbe` + 假 `OpenListClient` 覆盖：
1. `SettingsService` 默认 `checkOpenP2pOnStart == true`，保存 `false` 后重载为 `false`。
2. `OpenP2pBridge.isSupported == false`（如 iOS / 非 Android）：`check(allowPrompt: true)` 返回 `idle`、`shouldPrompt == false`，且不调用 `isAppInstalled` 或 `tcpProbe`。
3. 开关 `checkOpenP2pOnStart == false` 或 `site == null`：`check(allowPrompt: true)` 返回 `idle`、`shouldPrompt == false`。
4. 启动检测未运行（`notRunning`）且 `allowPrompt: true` → `status == notRunning`、`shouldPrompt == true`、`needsAttention == true`；调用 `markPromptHandled()` 后 `shouldPrompt == false`、`hasPromptedThisSession == true`；随后以 `allowPrompt: true` 或 `false` 再次 `check` 仍返回 `notRunning` 但 `shouldPrompt` 保持 `false`（不二次弹窗）。
5. 拉起 `launchOpenP2p()` 成功返回 `true` 并记 `launchedThisSession == true`；之后复检连通 → `status == connected`、`needsAttention == false`、`launchedThisSession == false`。
6. 并发竞态守卫：第一次 `check(allowPrompt: true)` 挂起在 `Completer` 时调用 `reset()`（模拟用户清空站点或关闭开关），随后旧 `Completer` 完成为 `notRunning` → 状态必须保持 `idle` 且 `shouldPrompt == false`。

- [ ] **Step 2: 运行测试确认失败**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_monitor_test.dart`
Expected: FAIL（`openp2p_service.dart`、`checkOpenP2pOnStart`、`openP2pMonitorProvider` 尚未定义）

- [ ] **Step 3: 实现 Android 原生桥接、设置项与 `OpenP2pMonitor`**

1. `android/app/src/main/AndroidManifest.xml`：在 `<queries>` 内添加 `<package android:name="cn.openp2p" />`。
2. `android/app/src/main/kotlin/com/songyaning/openlistplayer/MainActivity.kt`：重写 `configureFlutterEngine(flutterEngine: FlutterEngine)`，注册 `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "olp/device")`：
   - `isAppInstalled`：读取 `packageName` 参数，返回 `packageManager.getLaunchIntentForPackage(pkg) != null`。
   - `launchApp`：获取 launch Intent，加上 `Intent.FLAG_ACTIVITY_NEW_TASK` 并 `startActivity(intent)`，成功返回 `true`，空或异常返回 `false`。
3. `lib/data/settings_service.dart`：为 `AppSettings` 补 `checkOpenP2pOnStart = true`（构造、`copyWith`、`==`、`hashCode`），`SettingsService` 补 `_kCheckOpenP2p = 'network.check_openp2p'`、`load()`、`saveCheckOpenP2pOnStart(bool v)`。
4. 新建 `lib/data/openp2p_service.dart`：实现 `OpenP2pBridge`、`PlatformOpenP2pBridge`、`OpenP2pState`、`OpenP2pMonitor`（用递增 `_serial` 防异步乱序，且复用进行中探测防止并发抖动）。
5. `lib/providers.dart`：
   - `AppSettingsNotifier` 新增 `setCheckOpenP2pOnStart(bool v)`，并在 `setSite` 变更或 `setCheckOpenP2pOnStart(false)` 时调用 `ref.read(openP2pMonitorProvider.notifier).reset()`。
   - 注册 `openP2pBridgeProvider`、`openP2pTcpProbeProvider`、`openP2pMonitorProvider`。

- [ ] **Step 4: 运行测试确认通过**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_monitor_test.dart test/openp2p_probe_test.dart`
Expected: All tests passed!

- [ ] **Step 5: 提交**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/songyaning/openlistplayer/MainActivity.kt lib/data/settings_service.dart lib/data/openp2p_service.dart lib/providers.dart test/openp2p_monitor_test.dart
git commit -m "feat: 实现 Android OpenP2P 原生拉起桥接、设置项与状态监控"
```

---

### Task 3: 启动弹窗、前后台自动复检、首页横幅与设置页开关 UI

**Files:**
- Modify: `lib/app.dart:42-131`
- Modify: `lib/ui/home/home_page.dart:78-130,234-276`
- Modify: `lib/ui/settings/settings_page.dart:175-205`
- Test: `test/openp2p_ui_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `openP2pMonitorProvider`, `openP2pBridgeProvider`, `openP2pTcpProbeProvider`, `OpenP2pStatus`, `OpenP2pState`, `AppSettings.checkOpenP2pOnStart`, `AppSettingsNotifier.setCheckOpenP2pOnStart`
- Produces:
  - 启动弹窗（`_AppShellState`）：标题 `OpenP2P 似乎未运行` / `无法连接到 OpenList` / `未检测到 OpenP2P`，按钮 `暂不启动` / `启动 OpenP2P`（未安装为 `知道了`）；`launchOpenP2p()` 返回 `false` 时通过 `ScaffoldMessenger` 显示 `未能拉起 OpenP2P，请手动打开`
  - 首页顶部横幅（`_OpenP2pBanner`）：`status.needsAttention` 为真时显示，含「启动 OpenP2P」（已安装时）与「重新检测」按钮，状态胶囊 `_SiteStatusPill` 圆点同步切为 `error` 色
  - 生命周期复检（`_AppState.didChangeAppLifecycleState`）：`AppLifecycleState.resumed` 且 `state.needsAttention || state.launchedThisSession` 时自动调用 `check(allowPrompt: false)`
  - 设置页开关（`SettingsPage` 服务器卡片内）：`启动时检测 OpenP2P`（副标题：`未连通时提示并一键拉起 OpenP2P`）

- [ ] **Step 1: 编写失败组件测试 `test/openp2p_ui_test.dart`**

用内存 SQLite + `FakePlayerBackend` + `SharedPreferences` + 假 `OpenP2pBridge` / 假 `TcpProbe`（并在每个用例结束按 `AGENTS.md` 规范卸载页面 `pumpWidget(const SizedBox())` + `pump(1ms)` 排空 drift Timer）覆盖：
1. `AppShell` 启动时若 OpenP2P 未运行 → 自动弹出 `OpenP2P 似乎未运行` 对话框；点击「暂不启动」关闭对话框后，首页顶部显示横幅（含「启动 OpenP2P」与「重新检测」）。
2. 在横幅或弹窗点击「启动 OpenP2P」→ 调用 `bridge.launchApp('cn.openp2p')`；当 `launchApp` 返回 `false` 时显示 `SnackBar` 文案 `未能拉起 OpenP2P，请手动打开`。
3. 模拟 OpenP2P 启动成功并点击「重新检测」（或触发复检）→ 横幅自动消失。
4. `SettingsPage` 中「启动时检测 OpenP2P」开关默认开启，点击关闭后写入 `SharedPreferences`（`network.check_openp2p == false`）。

- [ ] **Step 2: 运行测试确认失败**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_ui_test.dart`
Expected: FAIL（弹窗、横幅与设置页开关尚未实现）

- [ ] **Step 3: 实现 `lib/app.dart`、`lib/ui/home/home_page.dart` 与 `lib/ui/settings/settings_page.dart`**

1. `lib/app.dart`：
   - `_AppState.didChangeAppLifecycleState` 的 `resumed` 分支：读取 `openP2pMonitorProvider`，若 `state.needsAttention || state.launchedThisSession`，异步调用 `ref.read(openP2pMonitorProvider.notifier).check(allowPrompt: false)`。
   - `_AppShellState`：`initState` 中通过 `addPostFrameCallback` 触发 `check(allowPrompt: true)`；在 `build` 内用 `ref.listen<OpenP2pState>(openP2pMonitorProvider, ...)` 监听 `next.shouldPrompt && !_dialogOpen`，调用 `markPromptHandled()` 并弹出 `AlertDialog`。弹窗点击「启动 OpenP2P」调用 `launchOpenP2p()`，若返回 `false` 且 `mounted` 弹 `SnackBar('未能拉起 OpenP2P，请手动打开')`。
2. `lib/ui/home/home_page.dart`：
   - 监听 `openP2pMonitorProvider`：
     - 将 `hasIssue: openP2p.needsAttention` 传给 `_SiteStatusPill`（圆点色用 `Theme.of(context).colorScheme.error` 替代 `success`）。
     - 当 `openP2p.needsAttention` 为真时，在 `_HeroResumeCard` 上方渲染 `_OpenP2pBanner`（圆角卡片，底色 `colorScheme.errorContainer`，文字 `colorScheme.onErrorContainer`，主色按钮「启动 OpenP2P」（`notInstalled` 时隐藏）与次级按钮「重新检测」（检测中显示进度指示器））。
3. `lib/ui/settings/settings_page.dart`：
   - 在「服务器」`InsetSectionCard` 底部加 `Divider` + `SwitchListTile`：`contentPadding: EdgeInsets.zero`，标题 `启动时检测 OpenP2P`，副标题 `未连通时提示并一键拉起 OpenP2P`，值绑定 `settings.checkOpenP2pOnStart`，回调 `ref.read(settingsProvider.notifier).setCheckOpenP2pOnStart`。

- [ ] **Step 4: 运行测试确认通过**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_ui_test.dart`
Expected: All tests passed!

- [ ] **Step 5: 提交**

```bash
git add lib/app.dart lib/ui/home/home_page.dart lib/ui/settings/settings_page.dart test/openp2p_ui_test.dart
git commit -m "feat: 新增 OpenP2P 启动弹窗、首页提醒横幅与设置开关"
```

---

### Task 4: 全量静态检查与回归验证

**Files:**
- Verify only（不新增功能代码，如有分析警告或测试回归则一并修复）

- [ ] **Step 1: 运行 `flutter analyze --no-pub`**

Run: `flutter analyze --no-pub`
Expected: 0 error / 0 warning（仅保留既有 `material.dart` 弃用等 info）

- [ ] **Step 2: 运行全部新增与既有测试**

Run: `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test test/openp2p_probe_test.dart test/openp2p_monitor_test.dart test/openp2p_ui_test.dart test/core_logic_test.dart test/lrc_parser_test.dart test/openlist_client_test.dart test/app_database_test.dart test/playback_controller_test.dart test/playlist_detail_page_test.dart test/ui_redesign_test.dart`
Expected: 全部 PASS（并确认 Android 端 `flutter build apk --debug --target-platform android-arm64` 编译通过，验证 Kotlin 与 Manifest 无语法/类型错误）

- [ ] **Step 3: 确认分支干净并汇报**

Run: `git status -sb`
Expected: 干净无未追踪或脏改文件（`pubspec.lock` 如有镜像 URL 变更需还原）。
