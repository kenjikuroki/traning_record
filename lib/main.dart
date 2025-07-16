import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'model/menu_data.dart';
import 'screens/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(MenuDataAdapter());
  Hive.registerAdapter(DailyRecordAdapter());

  await Hive.openBox<DailyRecord>('recordsBox');
  await Hive.openBox<List<MenuData>>('lastUsedMenusBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CalendarScreen(),
    );
  }
}
