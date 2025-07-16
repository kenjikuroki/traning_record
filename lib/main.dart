import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

import 'models/menu_data.dart';       // MenuData と DailyRecord モデル
import 'screens/calendar_screen.dart'; // カレンダー画面

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // アダプター登録
  // MenuDataとDailyRecordのアダプターは、menu_data.g.dartに生成されます。
  Hive.registerAdapter(MenuDataAdapter());
  Hive.registerAdapter(DailyRecordAdapter()); // DailyRecordAdapterもmenu_data.dartで定義されたため、ここで登録

  // Boxを開く（保存先の箱）
  await Hive.openBox<DailyRecord>('recordsBox');
  await Hive.openBox<List<MenuData>>('lastUsedMenusBox'); // 前回使用したメニューを保存するBox

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
