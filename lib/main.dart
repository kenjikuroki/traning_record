// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'l10n/app_localizations.dart';
import 'models/menu_data.dart';
import 'screens/home_screen.dart';
import 'settings_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await MobileAds.instance.initialize();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MenuDataAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyRecordAdapter());
  }

  await SettingsManager.initialize();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final recordsBox = await Hive.openBox<DailyRecord>('dailyRecords');
  // 型安全化：List<MenuData> 保持用
  final lastUsedMenusBox = await Hive.openBox<List>('lastUsedMenus');
  final settingsBox = await Hive.openBox<dynamic>('settings');
  final setCountBox = await Hive.openBox<int>('setCount');

  runApp(MyApp(
    recordsBox: recordsBox,
    lastUsedMenusBox: lastUsedMenusBox,
    settingsBox: settingsBox,
    setCountBox: setCountBox,
  ));
}

class MyApp extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const MyApp({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    // 未定義エラー回避のためここでテーマを定義
    final ThemeData lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,   // ← 透過
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,         // ← 白字で潰れ防止
      ),
    );
    final ThemeData darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      useMaterial3: true,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
    );


    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsManager.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'TrainingRecord',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,

          // l10n
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('ja', ''),
          ],

          // 壁紙の即時反映（背景が変わるたびに再ビルド）
          builder: (context, child) {
            return ValueListenableBuilder<String>(
              valueListenable: SettingsManager.backgroundAssetNotifier,
              builder: (context, bg, __) {
                if (bg.isEmpty) {
                  return child ?? const SizedBox.shrink();
                }
                return Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(bg),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // ← ここを強化：各所の背景を全面的に透過
                      scaffoldBackgroundColor: Colors.transparent,
                      canvasColor: Colors.transparent,
                      cardColor: Colors.transparent,
                      dialogBackgroundColor: Colors.transparent,
                      bottomSheetTheme: const BottomSheetThemeData(
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                      ),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
            );
          },


          // ルート画面（戻るで最小化をブロック）
          home: PopScope(
            canPop: false,
            child: HomeScreen(
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
              settingsBox: widget.settingsBox,
              setCountBox: widget.setCountBox,
            ),
          ),
        );
      },
    );
  }
}
