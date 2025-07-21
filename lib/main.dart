import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart'; // Hive.box()のために必要

import 'models/menu_data.dart';       // MenuData と DailyRecord モデル (DailyRecordもこのファイルに統合)
import 'screens/calendar_screen.dart'; // カレンダー画面

// アプリのテーマモードを管理するためのValueNotifier
final ValueNotifier<ThemeMode> currentThemeMode = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // アダプター登録
  Hive.registerAdapter(MenuDataAdapter());
  Hive.registerAdapter(DailyRecordAdapter()); // DailyRecordAdapterもmenu_data.dartから

  // Boxを開く（保存先の箱）
  final recordsBox = await Hive.openBox<DailyRecord>('recordsBox');
  final lastUsedMenusBox = await Hive.openBox<List<MenuData>>('lastUsedMenusBox');
  final settingsBox = await Hive.openBox<Map<String, bool>>('settingsBox'); // 部位選択の設定用Box (型はMap<String, bool>のまま)
  final setCountBox = await Hive.openBox<int>('setCountBox'); // セット数を保存するためのBox
  final themeModeBox = await Hive.openBox<int>('themeModeBox'); // ★テーマモードをint型で保存するための新しいBox

  // 保存されたテーマモードをロード
  // themeModeBoxはint型なので、defaultValueもint型
  final savedThemeModeIndex = themeModeBox.get('themeMode', defaultValue: ThemeMode.system.index);
  currentThemeMode.value = ThemeMode.values[savedThemeModeIndex!]; // ★null assertion operatorを追加


  runApp(TrainingRecordApp(
    recordsBox: recordsBox,
    lastUsedMenusBox: lastUsedMenusBox,
    settingsBox: settingsBox,
    setCountBox: setCountBox,
    themeModeBox: themeModeBox, // ★新しいBoxを渡す
  ));
}

class TrainingRecordApp extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List<MenuData>> lastUsedMenusBox;
  final Box<Map<String, bool>> settingsBox; // 型はMap<String, bool>のまま
  final Box<int> setCountBox;
  final Box<int> themeModeBox; // ★新しいBoxを受け取る

  const TrainingRecordApp({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox, // ★新しいBoxを受け取る
  });

  @override
  State<TrainingRecordApp> createState() => _TrainingRecordAppState();
}

class _TrainingRecordAppState extends State<TrainingRecordApp> {
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
    setState(() {
      // currentThemeMode.value が変更されたらUIを再構築
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: currentThemeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'Training Record',
          theme: ThemeData( // ライトテーマの定義
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFE0F2F7), // Light blue background
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black54),
              titleTextStyle: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF5B86E5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              hintStyle: const TextStyle(color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
          darkTheme: ThemeData( // ダークテーマの定義
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900],
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white70),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.grey[850],
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
              ),
              hintStyle: const TextStyle(color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
          themeMode: mode, // ValueNotifierから取得したテーマモードを適用
          home: CalendarScreen(
            recordsBox: widget.recordsBox,
            lastUsedMenusBox: widget.lastUsedMenusBox,
            settingsBox: widget.settingsBox,
            setCountBox: widget.setCountBox,
            themeModeBox: widget.themeModeBox, // ★新しいBoxを渡す
          ),
        );
      },
    );
  }
}
