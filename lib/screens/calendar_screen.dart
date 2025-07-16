import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Hiveを使うために必要
import 'package:hive/hive.dart'; // Hiveを使うために必要

import '../models/menu_data.dart'; // DailyRecordも含まれる
import 'record_screen.dart';
import 'settings_screen.dart'; // settings_screenをインポート

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Hive Boxのインスタンス
  late final Box<DailyRecord> recordsBox;

  // 各部位に対応する色を定義
  final Map<String, Color> partColors = {
    '腕': Colors.red,
    '胸': Colors.purple,
    '肩': Colors.blue,
    '背中': Colors.green,
    '足': Colors.yellow,
    '全体': Colors.orange,
    'その他': Colors.pink,
  };

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox'); // Boxを初期化
  }

  // 日付キーを生成するヘルパー関数 (RecordScreenと合わせる)
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 指定された日付に記録されたすべての部位を取得するヘルパー関数
  // この関数は、その日付に記録がある全ての部位のリストを返します。
  List<String> _getRecordedPartsForDate(DateTime date) {
    final String dateKey = _getDateKey(date);
    final DailyRecord? dailyRecord = recordsBox.get(dateKey);

    if (dailyRecord != null && dailyRecord.menus.isNotEmpty) {
      // 記録がある部位のリストを返す (メニューリストが空でないもののみ)
      return dailyRecord.menus.keys.where((part) => dailyRecord.menus[part]!.isNotEmpty).toList();
    }
    return []; // 記録がなければ空のリストを返す
  }

  void navigateToRecord(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordScreen(selectedDate: date),
      ),
    ).then((_) {
      // RecordScreen から戻ってきたときにカレンダーを更新
      setState(() {
        _selectedDay = date; // 戻ってきた日付が選択された状態を維持
        _focusedDay = date;
      });
    });
  }

  void navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングカレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => navigateToSettings(context), // 設定画面へ遷移
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              navigateToRecord(context, selectedDay);
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              // 各日付の下にマーカーを表示
              markerBuilder: (context, date, events) {
                final recordedParts = _getRecordedPartsForDate(date);

                if (recordedParts.isEmpty) {
                  return null; // 記録がなければマーカーを表示しない
                }

                // 記録がある場合、複数のマーカーを表示できるようにStackを使用
                return Positioned(
                  bottom: 1, // 日付の下に表示
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: recordedParts.map((part) {
                      return Container(
                        width: 6, // マーカーのサイズ
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5), // マーカー間のスペース
                        decoration: BoxDecoration(
                          color: partColors[part] ?? Colors.grey, // 部位に対応する色、なければ灰色
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
