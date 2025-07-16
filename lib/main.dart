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
  await Hive.openBox<DailyRecord>('recordsBox');
  await Hive.openBox<List<MenuData>>('lastUsedMenusBox');
  // ★設定を保存するための新しいBoxを開きます
  await Hive.openBox<Map<String, bool>>('settingsBox');

  runApp(const TrainingRecordApp());
}

class TrainingRecordApp extends StatelessWidget {
  const TrainingRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Record',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CalendarScreen(),
    );
  }
}
