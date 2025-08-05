// lib/main.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'models/menu_data.dart';
import 'models/record_models.dart';
import 'screens/calendar_screen.dart';
import 'package:ttraining_record/settings_manager.dart';

final ValueNotifier<ThemeMode> currentThemeMode = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hiveの初期化
  await Hive.initFlutter();

  // Hiveアダプターの登録
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MenuDataAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyRecordAdapter());
  }

  // ★修正: 設定マネージャーの初期化を呼び出し
  await SettingsManager.initialize();

  // アプリの向きを縦向きに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final recordsBox = await Hive.openBox<DailyRecord>('dailyRecords');
  final lastUsedMenusBox = await Hive.openBox<dynamic>('lastUsedMenus');
  final settingsBox = await Hive.openBox<dynamic>('settings');
  final setCountBox = await Hive.openBox<int>('setCount');
  final themeModeBox = await Hive.openBox<int>('themeMode');

  final savedThemeModeIndex = themeModeBox.get('themeMode');
  if (savedThemeModeIndex != null) {
    currentThemeMode.value = ThemeMode.values[savedThemeModeIndex];
  }

  runApp(MyApp(
    recordsBox: recordsBox,
    lastUsedMenusBox: lastUsedMenusBox,
    settingsBox: settingsBox,
    setCountBox: setCountBox,
    themeModeBox: themeModeBox,
  ));
}

class MyApp extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;
  final Box<int> themeModeBox;

  const MyApp({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    currentThemeMode.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    currentThemeMode.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: currentThemeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Training Record', // ここは固定値でも良いですが、多言語化する場合は変更
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Inter',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Inter',
          ),
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
          home: CalendarScreen(
            recordsBox: widget.recordsBox,
            lastUsedMenusBox: widget.lastUsedMenusBox,
            settingsBox: widget.settingsBox,
            setCountBox: widget.setCountBox,
            themeModeBox: widget.themeModeBox,
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}