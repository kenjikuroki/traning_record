// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTokens {
  // Instagram系アクセント（グラデに使う）
  static const gradient = [
    Color(0xFFF58529), // orange
    Color(0xFFDD2A7B), // pink
    Color(0xFF8134AF), // purple
    Color(0xFF515BD4), // blue
  ];

  static const gradientMuted = [
     Color(0xFFC77FA1), // muted rose
      Color(0xFF9D7BB0), // mauve
      Color(0xFF7B78B8), // soft periwinkle
    ];

  // ベースカラー（ライト／ダーク）
  static const bgLight = Color(0xFFFAFAFA);
  static const bgDark  = Color(0xFF0F0F10);

  // テキスト
  static const textPrimaryLight   = Color(0xFF262626);
  static const textSecondaryLight = Color(0xFF8E8E8E);
  static const textPrimaryDark    = Color(0xFFEDEDED);
  static const textSecondaryDark  = Color(0xFF9A9A9A);

  // 枠線・面
  static const strokeLight = Color(0xFFDBDBDB);
  static const surfaceLight = Color(0xFFF4F4F4);
  static const surfaceDark  = Color(0xFF1A1B1E);

  // 角丸と影
  static const radiusL = 20.0;
  static const radiusM = 14.0;

  // スペーシング（余白スケール）
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
}

TextTheme _jpTextTheme(BuildContext context) {
  // 日本語でも崩れにくい Noto Sans JP を採用（英字も綺麗）
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

ThemeData appThemeLight(BuildContext context) {
  final cs = ColorScheme.fromSeed(
    seedColor: AppTokens.gradient[1], // ピンクを基準色に
    brightness: Brightness.light,
    background: AppTokens.bgLight,
  );

  final tt = _jpTextTheme(context).apply(
    bodyColor: AppTokens.textPrimaryLight,
    displayColor: AppTokens.textPrimaryLight,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: AppTokens.bgLight,
    textTheme: tt,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: AppTokens.bgLight,
      foregroundColor: AppTokens.textPrimaryLight,
      titleTextStyle: tt.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppTokens.surfaceLight,
      elevation: 0,
      margin: const EdgeInsets.all(AppTokens.s16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        side: const BorderSide(color: AppTokens.strokeLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s12),
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
      backgroundColor: AppTokens.bgLight,
      selectedItemColor: cs.primary,
      unselectedItemColor: AppTokens.textSecondaryLight,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: AppTokens.strokeLight)),
      labelStyle: tt.labelLarge!,
      selectedColor: cs.primary.withOpacity(0.12),
      side: BorderSide(color: AppTokens.strokeLight),
    ),
    dividerColor: AppTokens.strokeLight,
    iconTheme: IconThemeData(color: AppTokens.textPrimaryLight),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 0, // グラデはカスタムFABで付与
      backgroundColor: Colors.transparent, // カスタムで上書き
      foregroundColor: Colors.white,
    ),
  );
}

ThemeData appThemeDark(BuildContext context) {
  final cs = ColorScheme.fromSeed(
    seedColor: AppTokens.gradient[2],
    brightness: Brightness.dark,
    background: AppTokens.bgDark,
  );
  final tt = _jpTextTheme(context).apply(
    bodyColor: AppTokens.textPrimaryDark,
    displayColor: AppTokens.textPrimaryDark,
  );
  return appThemeLight(context).copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: AppTokens.bgDark,
    textTheme: tt,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: AppTokens.bgDark,
      foregroundColor: AppTokens.textPrimaryDark,
      titleTextStyle: tt.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppTokens.surfaceDark,
      elevation: 0,
      margin: const EdgeInsets.all(AppTokens.s16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusL),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTokens.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s12),
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
      backgroundColor: AppTokens.bgDark,
      selectedItemColor: cs.primary,
      unselectedItemColor: AppTokens.textSecondaryDark,
    ),
    dividerColor: Colors.white.withOpacity(0.08),
    iconTheme: IconThemeData(color: AppTokens.textPrimaryDark),
  );
}
