import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../settings_manager.dart';

// テーマ選択用のシードカラー（落ち着いたがやや濃い）
Color _seedFromIndex(int idx) {
  switch (idx) {
    case 0: // モノトーン（ニュートラル）
      return const Color(0xFF3F3F3F);
    case 1: // 赤
      return const Color(0xFFD64545); // 落ち着いた濃い赤（Seed）
    case 2: // 青
      return const Color(0xFF2F6AD9);
    case 3: // 緑
      return const Color(0xFF2F7D46);
    case 4: // 黄
      return const Color(0xFFE0A20A);
    default:
      return const Color(0xFF3F3F3F);
  }
}

class AppTokens {
  // くすんだ系グラデ（GradientFABのデフォルトフォールバック用）
  static const gradientMuted = [
    Color(0xFFC77FA1), // muted rose
    Color(0xFF9D7BB0), // mauve
    Color(0xFF7B78B8), // soft periwinkle
  ];

  // アプリの共通トークン
  static const bgLight = Color(0xFFFAFAFA);
  static const bgDark  = Color(0xFF0F0F10);

  static const textPrimaryLight   = Color(0xFF262626);
  static const textSecondaryLight = Color(0xFF8E8E8E);
  static const textPrimaryDark    = Color(0xFFEDEDED);
  static const textSecondaryDark  = Color(0xFF9A9A9A);

  static const strokeLight  = Color(0xFFDBDBDB);
  static const surfaceLight = Color(0xFFF4F4F4); // ← カード色（ライト）
  static const surfaceDark  = Color(0xFF1A1B1E); // ← カード色（ダーク）

  static const radiusL = 20.0;
  static const radiusM = 14.0;

  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
}

// ───────────── ユーティリティ（色調整 & FAB色） ─────────────
Color _slightlyDarker(Color base, [double amount = 0.04]) { // ← デフォルト 4%
  final hsl = HSLColor.fromColor(base);
  final l = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

Color _desaturate(Color base, [double amount = 0.12]) {
  final hsl = HSLColor.fromColor(base);
  final s = (hsl.saturation - amount).clamp(0.0, 1.0);
  return hsl.withSaturation(s).toColor();
}

// くすんだ濃い FAB 色（単色 & グラデ）
List<Color> _fabGradientFromSeed(Color seed, Brightness b) {
  final base  = _desaturate(seed, b == Brightness.light ? 0.16 : 0.12);
  final start = _slightlyDarker(base, 0.08);
  final end   = _slightlyDarker(base, 0.26);
  return [start, end];
}
Color _fabSolidFromSeed(Color seed, Brightness b) => _fabGradientFromSeed(seed, b).last;

// 画面から使える公開関数
List<Color> appFabGradient(BuildContext context) {
  final seed = _seedFromIndex(SettingsManager.currentAppColorThemeIndex);
  final br   = Theme.of(context).brightness;
  return _fabGradientFromSeed(seed, br);
}
Color appFabSolid(BuildContext context) {
  final seed = _seedFromIndex(SettingsManager.currentAppColorThemeIndex);
  final br   = Theme.of(context).brightness;
  return _fabSolidFromSeed(seed, br);
}

// ───────────── タイポグラフィ ─────────────
TextTheme _jpTextTheme(BuildContext context) {
  final base = Theme.of(context).textTheme;
  return GoogleFonts.notoSansJpTextTheme(base).copyWith(
    displayLarge:  GoogleFonts.notoSansJp(fontWeight: FontWeight.w700),
    displayMedium: GoogleFonts.notoSansJp(fontWeight: FontWeight.w700),
    titleLarge:    GoogleFonts.notoSansJp(fontWeight: FontWeight.w600, fontSize: 20),
    titleMedium:   GoogleFonts.notoSansJp(fontWeight: FontWeight.w600, fontSize: 16),
    bodyLarge:     GoogleFonts.notoSansJp(fontWeight: FontWeight.w400, fontSize: 16, height: 1.3),
    bodyMedium:    GoogleFonts.notoSansJp(fontWeight: FontWeight.w400, fontSize: 14, height: 1.35),
    labelLarge:    GoogleFonts.notoSansJp(fontWeight: FontWeight.w600, fontSize: 14),
  );
}

// ───────────── Light ─────────────
ThemeData appThemeLight(BuildContext context) {
  final csRaw = ColorScheme.fromSeed(
    seedColor: _seedFromIndex(SettingsManager.currentAppColorThemeIndex),
    brightness: Brightness.light,
    background: AppTokens.bgLight,
  );

  // モノトーンは完全グレー系で固定（緑み回避）
  final isMono = SettingsManager.currentAppColorThemeIndex == 0;
  final cs = isMono
      ? csRaw.copyWith(
    primary: const Color(0xFF3F3F3F),   onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE0E0E0), onPrimaryContainer: const Color(0xFF1F1F1F),
    secondary: const Color(0xFF5A5A5A), onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF0F0F0), onSecondaryContainer: const Color(0xFF2B2B2B),
    surface: Colors.white, onSurface: AppTokens.textPrimaryLight,
    surfaceVariant: AppTokens.surfaceLight, onSurfaceVariant: AppTokens.textSecondaryLight,
  )
      : csRaw;

  final tt = _jpTextTheme(context).apply(
    bodyColor: AppTokens.textPrimaryLight,
    displayColor: AppTokens.textPrimaryLight,
  );

  // ★ AppBar/BottomBar = 「カード色（surfaceLight）と同じ系の、ほんの少し濃い色」
  final barColor = _slightlyDarker(AppTokens.surfaceLight, 0.04);
  final fabColor = _fabSolidFromSeed(_seedFromIndex(SettingsManager.currentAppColorThemeIndex), Brightness.light);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    applyElevationOverlayColor: false,
    scaffoldBackgroundColor: AppTokens.bgLight,
    textTheme: tt,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: barColor,
      foregroundColor: cs.onSurface,
      titleTextStyle: tt.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // 黒いアイコン
        statusBarBrightness: Brightness.light,    // iOS用の設定
      ),
    ),
    cardTheme: CardThemeData(
      color: AppTokens.surfaceLight,       // ← カード色（基準）
      elevation: 0,
      margin: const EdgeInsets.all(AppTokens.s4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        side: const BorderSide(color: AppTokens.strokeLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: AppTokens.s12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        borderSide: const BorderSide(color: AppTokens.strokeLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        borderSide: const BorderSide(color: AppTokens.strokeLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 0,
      backgroundColor: barColor,           // ← AppBar と同色
      selectedItemColor: cs.primary,       // ← アクセントのみテーマ色
      unselectedItemColor: cs.onSurfaceVariant,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      labelStyle: tt.labelLarge!,
      selectedColor: cs.primary.withOpacity(0.12),
      side: const BorderSide(color: AppTokens.strokeLight),
    ),
    dividerColor: AppTokens.strokeLight,
    iconTheme: const IconThemeData(color: AppTokens.textPrimaryLight),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      backgroundColor: fabColor,           // ← くすんだ濃い単色
      foregroundColor: Colors.white,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((_) => cs.primary),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((_) => cs.primaryContainer),
      thumbColor: WidgetStateProperty.resolveWith((_) => cs.primary),
    ),
  );
}

// ───────────── Dark ─────────────
ThemeData appThemeDark(BuildContext context) {
  final csRaw = ColorScheme.fromSeed(
    seedColor: _seedFromIndex(SettingsManager.currentAppColorThemeIndex),
    brightness: Brightness.dark,
    background: AppTokens.bgDark,
  );

  final isMono = SettingsManager.currentAppColorThemeIndex == 0;
  final cs = isMono
      ? csRaw.copyWith(
    primary: const Color(0xFF5A5A5A),   onPrimary: Colors.white,
    primaryContainer: const Color(0xFF2B2B2B), onPrimaryContainer: Colors.white,
    secondary: const Color(0xFF777777), onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF3A3A3A), onSecondaryContainer: Colors.white,
    surface: AppTokens.bgDark, onSurface: AppTokens.textPrimaryDark,
    surfaceVariant: AppTokens.surfaceDark, onSurfaceVariant: AppTokens.textSecondaryDark,
  )
      : csRaw;

  final tt = _jpTextTheme(context).apply(
    bodyColor: AppTokens.textPrimaryDark,
    displayColor: AppTokens.textPrimaryDark,
  );

  // ★ ダークも「カード色（surfaceDark）より少し濃い」
  final barColor = _slightlyDarker(AppTokens.surfaceDark, 0.03);
  final fabColor = _fabSolidFromSeed(_seedFromIndex(SettingsManager.currentAppColorThemeIndex), Brightness.dark);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    applyElevationOverlayColor: false,
    scaffoldBackgroundColor: AppTokens.bgDark,
    textTheme: tt,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: barColor,
      foregroundColor: cs.onSurface,
      titleTextStyle: tt.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // 白いアイコン
        statusBarBrightness: Brightness.dark,     // iOS用の設定
      ),
    ),
    cardTheme: CardThemeData(
      color: AppTokens.surfaceDark,
      elevation: 0,
      margin: const EdgeInsets.all(AppTokens.s4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTokens.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: AppTokens.s12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 0,
      backgroundColor: barColor,            // ← AppBar と同色
      selectedItemColor: cs.primary,
      unselectedItemColor: cs.onSurfaceVariant,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),
    dividerColor: Colors.white.withOpacity(0.08),
    iconTheme: const IconThemeData(color: AppTokens.textPrimaryDark),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      backgroundColor: fabColor,            // ← くすんだ濃い単色
      foregroundColor: Colors.white,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((_) => cs.primary),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((_) => cs.primaryContainer),
      thumbColor: WidgetStateProperty.resolveWith((_) => cs.primary),
    ),
  );
}
