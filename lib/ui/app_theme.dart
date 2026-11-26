/// 全局主题：以音频播放页的 AudioTone 色板为唯一来源。
/// 浅色直接用设计稿 token；深色使用同一色系的暗色变体（与 mini 播放条一致）。
library;

import 'package:flutter/material.dart';

import 'player/audio_theme.dart';

/// 深色模式的同色系变体（与 AudioTone 一一对应）。
class AppPalette {
  const AppPalette._();

  /// 页面背景（比卡片更暗，深焙暖曜黑）
  static const darkBg = Color(0xFF181614);

  /// 卡片 / AppBar 之下的面板底色（暖炭卡片底）
  static const darkSurface = Color(0xFF24211E);

  /// chip / 选中行底（深暖褐沙）
  static const darkSand = Color(0xFF332E29);

  /// 进度条未播放段 / 分隔线（暗沙灰）
  static const darkSandDeep = Color(0xFF423B35);

  /// 描边 / 禁用
  static const darkTaupe = Color(0xFF6B6055);

  /// 主文字
  static const darkInk = Color(0xFFF2EDE6);

  /// 次文字 / 次级图标
  static const darkMuted = Color(0xFF9E958A);

  /// 主色（深色版提亮，保证在暗底上的对比度 ≥ 5.2:1）
  static const darkAccent = Color(0xFFD97752);

  /// 柔和苔绿完成态语义（深色模式）
  static const darkSuccess = Color(0xFF6FA07E);

  /// 封面占位暗底
  static const darkCoverFill = Color(0xFF2A2622);

  /// 按当前亮度返回对应语义色，方便业务组件统一取色无硬编码
  static Color bgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : AudioTone.bg;
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : AudioTone.surface;
  static Color sandOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSand : AudioTone.sand;
  static Color sandDeepOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSandDeep : AudioTone.sandDeep;
  static Color taupeOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTaupe : AudioTone.taupe;
  static Color inkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkInk : AudioTone.ink;
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkMuted : AudioTone.muted;
  static Color accentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkAccent : AudioTone.accent;
  static Color successOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSuccess : AudioTone.success;
  static Color coverFillOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCoverFill : AudioTone.coverFill;

  /// 暖砖红错误色，避免 Material 默认的冷红破坏色板
  static const error = Color(0xFFB23B2A);
  static const darkError = Color(0xFFE0775C);
  static const errorContainer = Color(0xFFF4DED6);
  static const darkErrorContainer = Color(0xFF5A2A22);
  static const onErrorContainer = Color(0xFF7C2D19);

  /// 视频控制层遮罩：取墨色的半透明，代替纯黑渐变
  static const scrim = Color(0x66211F1C);
  static const scrimStrong = Color(0x9E211F1C);

  /// 略暖的近黑，仅用于视频画面 letterbox 区域
  static const videoBackdrop = Color(0xFF14120F);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppPalette.darkBg : AudioTone.bg;
    final surface = isDark ? AppPalette.darkSurface : AudioTone.surface;
    final ink = isDark ? AppPalette.darkInk : AudioTone.ink;
    final muted = isDark ? AppPalette.darkMuted : AudioTone.muted;
    final accent = isDark ? AppPalette.darkAccent : AudioTone.accent;
    final sand = isDark ? AppPalette.darkSand : AudioTone.sand;
    final sandDeep = isDark ? AppPalette.darkSandDeep : AudioTone.sandDeep;
    final taupe = isDark ? AppPalette.darkTaupe : AudioTone.taupe;
    final onAccent = isDark ? AppPalette.darkBg : Colors.white;

    // 从陶土色派生完整 Material 色阶，再把可见 token 严格覆盖为音频页色板。
    final scheme = ColorScheme.fromSeed(
      seedColor: AudioTone.accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: sand,
      onPrimaryContainer: ink,
      secondary: muted,
      onSecondary: onAccent,
      secondaryContainer: sand,
      onSecondaryContainer: ink,
      tertiary: taupe,
      onTertiary: ink,
      tertiaryContainer: sand,
      onTertiaryContainer: ink,
      surface: surface,
      onSurface: ink,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: sand,
      surfaceContainerHighest: sand,
      onSurfaceVariant: muted,
      outline: taupe,
      outlineVariant: sandDeep,
      error: isDark ? AppPalette.darkError : AppPalette.error,
      onError: isDark ? AppPalette.darkBg : Colors.white,
      errorContainer: isDark ? AppPalette.darkErrorContainer : AppPalette.errorContainer,
      onErrorContainer: isDark ? AppPalette.darkError : AppPalette.onErrorContainer,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface,
      dividerColor: sandDeep,
      disabledColor: taupe,
      hintColor: muted,
      unselectedWidgetColor: taupe,
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.08),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      primaryTextTheme: base.primaryTextTheme.apply(bodyColor: onAccent, displayColor: onAccent),
      iconTheme: IconThemeData(color: muted, size: 24),
      primaryIconTheme: IconThemeData(color: onAccent, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: (base.textTheme.titleLarge ?? const TextStyle(fontSize: 20))
            .copyWith(color: ink, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: AudioTone.barShadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: sandDeep, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        selectedTileColor: sand,
        titleTextStyle: (base.textTheme.bodyLarge ?? const TextStyle()).copyWith(color: ink),
        subtitleTextStyle: (base.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: sandDeep,
          disabledForegroundColor: muted,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          disabledForegroundColor: taupe,
          side: BorderSide(color: taupe),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent, disabledForegroundColor: taupe),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: sand,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? accent : muted,
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              color: states.contains(WidgetState.selected) ? accent : muted,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: surface,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: accent),
        helperStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: taupe),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: taupe),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: (base.textTheme.titleLarge ?? const TextStyle()).copyWith(color: ink),
        contentTextStyle: (base.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surface : ink,
        contentTextStyle: TextStyle(color: isDark ? AppPalette.darkInk : AudioTone.surface, fontSize: 13),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? surface : ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: isDark ? AppPalette.darkInk : Colors.white, fontSize: 12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: sandDeep,
        thumbColor: accent,
        valueIndicatorColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: sandDeep,
        circularTrackColor: sandDeep,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sand,
        selectedColor: accent,
        labelStyle: TextStyle(color: ink, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: onAccent, fontSize: 13),
        side: BorderSide(color: taupe),
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled)
            ? taupe
            : states.contains(WidgetState.selected)
                ? onAccent
                : sand),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? accent
            : sandDeep),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? accent
            : Colors.transparent),
        checkColor: WidgetStatePropertyAll<Color>(onAccent),
        side: BorderSide(color: taupe, width: 1.6),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? accent
            : taupe),
      ),
    );
  }
}

