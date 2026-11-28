# 启动时检测并一键拉起 OpenP2P — 设计说明

日期：2026-11-28

## 1. 背景与目标

云序在手机端依赖 [OpenP2P](https://openp2p.cn/) 的 **P2P 端口映射** 才能访问家中部署的 OpenList 服务。若 OpenP2P 未在后台运行，用户打开云序后直到浏览目录或点击播放才会报错，体验割裂。

- **目标**：
  - Android 端冷启动时自动检测 OpenP2P 映射端口 / OpenList 服务是否可用；
  - 未运行时立即给出轻提示弹窗，点击即可自动拉起 OpenP2P App；
  - 关闭弹窗后在首页顶部保留可随时操作的提醒横幅，并同步状态胶囊指示色；
  - 用户从 OpenP2P 切回云序时自动复检，连通后自动收起提示。
- **非目标**：
  - 不在 iOS 启用（iOS 沙盒无法探测或拉起无公开 URL Scheme 的第三方 App，静默跳过）；
  - 不申请高危系统权限（如使用情况统计、无障碍、通知监听）；
  - 不尝试自动操作 OpenP2P 内部界面。
- **反目标**：
  - 不阻塞首帧渲染与本地会话/播单展示；
  - 服务已连通时不弹窗打扰；
  - 从普通后台（如切去回消息）切回时不重复强弹对话框。

## 2. 方案对比与决策

| 方案 | 做法 | 取舍 |
| --- | --- | --- |
| **方案一（选定）** | TCP 端口 + `/ping` 联合探测 + 原生 `MethodChannel` 拉起 + 启动弹窗与首页顶部提醒条联动 | 启动第一时间不漏看；点「暂不启动」后首页仍留一键入口；切回自动复检闭环；零高危权限 |
| 方案二 | 仅首页顶部横幅提醒 | 不打断，但习惯启动后直奔「文件」或点底部迷你条时容易漏看 |
| 方案三 | 仅启动弹窗，无常驻入口 | 改动最小，但关掉后需手动回桌面找 OpenP2P |

## 3. 详细设计

### 3.1 探测策略（纯逻辑 + 平台桥接解耦）

- **触发条件**：仅 Android 平台、已配置 `SiteConfig`、且设置项 `checkOpenP2pOnStart == true`（默认开启）。
- **包名**：`cn.openp2p`（来自 `openp2p-cn/openp2p` 官方 Android 客户端；真机安装测试时通过 `adb` 复核）。
- **探测步骤**：
  1. 解析 `site.baseUrl` 的 `host` 与 `port`（http 默认 80，https 默认 443）。
  2. **本机映射地址**（`127.0.0.1` / `localhost` / `::1`）：
     - 先做 TCP 探测（`Socket.connect`，超时 1.5s）：
       - 失败（如 `Connection refused` / 超时）→ 查询是否安装 `cn.openp2p`：已安装判定 `notRunning`，未安装判定 `notInstalled`。
       - 成功 → 再调短超时（2.5s）`/ping`：返回 `pong` 判定 `connected`；失败判定 `unreachable`（端口已监听但隧道未通或 OpenList 未响应）。
  3. **非本机地址**（如局域网直连或 SD-WAN IP）：
     - 直接发短超时（2.5s）`/ping`：返回 `pong` 判定 `connected`（在家直连不误报）；
     - 失败时仅当手机安装了 `cn.openp2p` 才判定 `notRunning` 并提示，否则保持静默（避免纯直连用户误报）。

### 3.2 Android 原生桥接

- `android/app/src/main/AndroidManifest.xml`：在 `<queries>` 中新增 `<package android:name="cn.openp2p" />`（满足 Android 11+ 包可见性）。
- `android/app/src/main/kotlin/com/songyaning/openlistplayer/MainActivity.kt`：在现有 `olp/device` `MethodChannel` 上新增两个方法：
  - `isAppInstalled(packageName: String): Boolean` — 通过 `packageManager.getLaunchIntentForPackage(pkg) != null` 判断；
  - `launchApp(packageName: String): Boolean` — 给 launch Intent 加上 `FLAG_ACTIVITY_NEW_TASK` 并 `startActivity`，捕获异常返回 `false`。

### 3.3 状态管理与交互流程

- 新增 `OpenP2pMonitor`（Riverpod `Notifier` 或 `ChangeNotifier`），持有当前检测状态（`idle` / `checking` / `connected` / `notRunning` / `unreachable` / `notInstalled`）以及本会话是否已弹过窗（`hasPromptedThisSession`）。
- **冷启动检测**：`AppShell` 首帧后异步触发 `check(allowPrompt: true)`。若返回未连通且本次会话尚未弹窗，则弹出 `AlertDialog`：
  - 标题：`OpenP2P 似乎未运行`（`unreachable` 时为 `无法连接到 OpenList`；`notInstalled` 时为 `未检测到 OpenP2P`）
  - 正文：说明当前依赖 OpenP2P 端口映射才能连接家里的 OpenList
  - 按钮：`暂不启动` / `启动 OpenP2P`（点击后拉起 `cn.openp2p` 并关闭弹窗；未安装时仅显示 `知道了`）
- **首页顶部提醒条（`_OpenP2pBanner`）**：当状态为 `notRunning` / `unreachable` / `notInstalled` 时展示在首页顶部，配色严格取自 `AppPalette` / `colorScheme`，提供「启动 OpenP2P」与「重新检测」操作；同时首页右上角 `_SiteStatusPill` 圆点在未连通时由 `success` 切为 `error`。
- **前后台切回自动复检**：`App.didChangeAppLifecycleState` 收到 `resumed` 且当前状态非 `connected`（或刚拉起过 OpenP2P）时，自动执行 `check(allowPrompt: false)`，不重复弹窗；连通后自动隐藏横幅、绿点恢复。
- **站点变更联动**：设置页保存新站点地址或打开/关闭开关时同步刷新状态。

### 3.4 设置开关（默认决策）

- `AppSettings` 新增 `bool checkOpenP2pOnStart`（默认 `true`，SharedPreferences 键 `network.check_openp2p`）。
- 在设置页「服务器」卡片下方新增 `SwitchListTile`：「启动时检测 OpenP2P」（副标题：「未连通时提示并一键拉起 OpenP2P」），方便后续切直连环境时关闭。

### 3.5 测试覆盖

- 纯逻辑 / 服务层单测：覆盖本机端口映射（TCP 拒连 → `notRunning` / 未安装 → `notInstalled` / TCP 通且 ping 通 → `connected` / TCP 通但 ping 失败 → `unreachable`）、非本机地址直连不误报、开关关闭跳过、重复并发调用防重入。
- 组件回归测试：覆盖启动未连通时弹窗与点击拉起、点「暂不启动」后首页横幅展示、恢复连通后横幅自动消失、设置页开关持久化。
