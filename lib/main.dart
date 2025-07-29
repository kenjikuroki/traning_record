import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart'; // SystemChrome を使用するためにインポート
import 'package:intl/date_symbol_data_local.dart'; // ロケールデータ初期化のためにインポート

import 'models/menu_data.dart'; // MenuDataとDailyRecordのHiveAdapterをインポート
import 'screens/calendar_screen.dart'; // CalendarScreenをインポート
import 'screens/record_screen.dart'; // RecordScreenをインポート
import 'screens/settings_screen.dart'; // SettingsScreenをインポート (もしCalendarScreenから直接遷移する場合)


// 現在のテーマモードを管理するValueNotifier
final ValueNotifier<ThemeMode> currentThemeMode = ValueNotifier(ThemeMode.system);

void main() async {
  // Flutterエンジンの初期化を保証
  WidgetsFlutterBinding.ensureInitialized();

  // ロケールデータ初期化
  await initializeDateFormatting('ja_JP', null); // 日本語ロケールを初期化

  // Hiveの初期化
  await Hive.initFlutter();

  // Hiveアダプターの登録
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MenuDataAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyRecordAdapter());
  }

  // ボックスを開く
  final recordsBox = await Hive.openBox<DailyRecord>('dailyRecords');
  final lastUsedMenusBox = await Hive.openBox<dynamic>('lastUsedMenus');
  // 修正: settingsBoxをdynamic型で開くことで、既存のデータ型との不一致を防ぐ
  final settingsBox = await Hive.openBox<dynamic>('settings');
  final setCountBox = await Hive.openBox<int>('setCount');
  final themeModeBox = await Hive.openBox<int>('themeMode');

  // 保存されているテーマモードをロード
  int? savedThemeModeIndex = themeModeBox.get('themeMode');
  if (savedThemeModeIndex != null) {
    currentThemeMode.value = ThemeMode.values[savedThemeModeIndex];
  }

  // アプリの向きを縦向きに固定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(MyApp(
      recordsBox: recordsBox,
      lastUsedMenusBox: lastUsedMenusBox,
      settingsBox: settingsBox,
      setCountBox: setCountBox,
      themeModeBox: themeModeBox,
    ));
  });
}

class MyApp extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox; // 修正: Boxの型をdynamicに合わせる
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
    // テーマモードの変更をリッスン
    currentThemeMode.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    currentThemeMode.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    if (mounted) {
      setState(() {}); // テーマモードが変更されたらUIを再構築
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: currentThemeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'トレーニング記録アプリ',
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Inter', // フォント設定
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Inter', // フォント設定
          ),
          home: CalendarScreen(
            recordsBox: widget.recordsBox,
            lastUsedMenusBox: widget.lastUsedMenusBox,
            settingsBox: widget.settingsBox,
            setCountBox: widget.setCountBox,
            themeModeBox: widget.themeModeBox,
          ),
          debugShowCheckedModeBanner: false, // デバッグバナーを非表示
        );
      },
    );
  }
}
