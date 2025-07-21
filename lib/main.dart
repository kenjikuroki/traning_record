import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

import 'models/menu_data.dart';       // MenuData と DailyRecord モデル
import 'screens/calendar_screen.dart'; // カレンダー画面

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // アダプター登録
  Hive.registerAdapter(MenuDataAdapter());
  Hive.registerAdapter(DailyRecordAdapter());

  // Boxを開く（保存先の箱）
  final recordsBox = await Hive.openBox<DailyRecord>('recordsBox');
  final lastUsedMenusBox = await Hive.openBox<List<MenuData>>('lastUsedMenusBox');
  final settingsBox = await Hive.openBox<Map<String, bool>>('settingsBox'); // 部位選択の設定用Box
  final setCountBox = await Hive.openBox<int>('setCountBox'); // セット数を保存するための新しいBoxを開きます

  runApp(TrainingRecordApp(
    recordsBox: recordsBox,
    lastUsedMenusBox: lastUsedMenusBox,
    settingsBox: settingsBox,
    setCountBox: setCountBox,
  ));
}

class TrainingRecordApp extends StatelessWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List<MenuData>> lastUsedMenusBox;
  final Box<Map<String, bool>> settingsBox;
  final Box<int> setCountBox;

  const TrainingRecordApp({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Record',
      theme: ThemeData(
        useMaterial3: true, // Material 3 を有効にする
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, // 基調色
          brightness: Brightness.dark, // ダークテーマ
        ),
        scaffoldBackgroundColor: const Color(0xFF121212), // ダークモードの背景色
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900], // ダークモードのAppBar背景色
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
          color: Colors.grey[850], // ダークモードのカード背景色
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue[700], // ダークモードのボタン背景色
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
          fillColor: Colors.grey[800], // ダークモードのTextField塗りつぶし色
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
      themeMode: ThemeMode.dark, // 常にダークモードを強制
      home: CalendarScreen( // CalendarScreenにBoxインスタンスを渡す
        recordsBox: recordsBox,
        lastUsedMenusBox: lastUsedMenusBox,
        settingsBox: settingsBox,
        setCountBox: setCountBox,
      ),
    );
  }
}
