import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart'; // path_provider をインポート
import 'package:intl/date_symbol_data_local.dart'; // ★ 追加: initializeDateFormatting のためにインポート

import 'screens/calendar_screen.dart';
import 'models/menu_data.dart'; // MenuData と DailyRecord をインポート

// テーマモードを管理するためのValueNotifier
final ValueNotifier<ThemeMode> currentThemeMode = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ 追加: ロケールデータを初期化 ★
  // 日本語ロケールデータをロードします。
  // TableCalendar が 'ja_JP' を使用しているため、ここで初期化が必要です。
  await initializeDateFormatting('ja_JP', null);

  // アプリケーションのドキュメントディレクトリのパスを取得
  final appDocumentDir = await getApplicationDocumentsDirectory();
  // Hiveを初期化し、パスを指定
  await Hive.initFlutter(appDocumentDir.path);

  // Hiveアダプターの登録
  // MenuDataAdapter と DailyRecordAdapter を登録
  // アダプターIDはユニークである必要があります
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MenuDataAdapter()); // MenuData のアダプターIDを 0 とする
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DailyRecordAdapter()); // DailyRecord のアダプターIDを 1 とする
  }

  // Boxを開く (型を指定)
  await Hive.openBox<DailyRecord>('dailyRecords');
  await Hive.openBox<dynamic>('lastUsedMenus');
  await Hive.openBox<Map<String, bool>>('settings');
  await Hive.openBox<int>('setCount');
  await Hive.openBox<int>('themeMode');

  // 保存されているテーマモードを読み込み
  final themeModeBox = Hive.box<int>('themeMode');
  int? savedThemeModeIndex = themeModeBox.get('themeMode');
  if (savedThemeModeIndex != null) {
    currentThemeMode.value = ThemeMode.values[savedThemeModeIndex];
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // テーマモード変更をリッスン
    currentThemeMode.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    currentThemeMode.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    setState(() {
      // テーマモードが変更されたらUIを再ビルド
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: currentThemeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'トレーニング記録',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: CalendarScreen(
            recordsBox: Hive.box<DailyRecord>('dailyRecords'),
            lastUsedMenusBox: Hive.box<dynamic>('lastUsedMenus'),
            settingsBox: Hive.box<Map<String, bool>>('settings'),
            setCountBox: Hive.box<int>('setCount'),
            themeModeBox: Hive.box<int>('themeMode'),
          ),
        );
      },
    );
  }
}
