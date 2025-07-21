import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:hive/hive.dart'; // Unnecessary import, removed

import '../models/menu_data.dart'; // DailyRecordもこのファイルに統合
// import '../models/daily_record.dart'; // DailyRecordモデルはmenu_data.dartに統合されているため削除
import 'record_screen.dart';
import 'settings_screen.dart';
import '../main.dart'; // currentThemeMode を使用するためにインポート

class CalendarScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List<MenuData>> lastUsedMenusBox;
  final Box<Map<String, bool>> settingsBox; // 型はMap<String, bool>のまま
  final Box<int> setCountBox;
  final Box<int> themeModeBox; // ★新しいBoxを受け取る

  const CalendarScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox, // ★新しいBoxを受け取る
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 各部位に対応する色を定義 (機能の一部として維持)
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
  }

  // 日付キーを生成するヘルパー関数 (RecordScreenと共通)
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 指定された日付に記録されたすべての部位を取得するヘルパー関数
  List<String> _getRecordedPartsForDate(DateTime date) {
    final String dateKey = _getDateKey(date);
    final DailyRecord? dailyRecord = widget.recordsBox.get(dateKey);

    if (dailyRecord != null && dailyRecord.menus.isNotEmpty) {
      return dailyRecord.menus.keys.where((part) => dailyRecord.menus[part]!.isNotEmpty).toList();
    }
    return [];
  }

  void navigateToRecord(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => RecordScreen(
          selectedDate: date,
          recordsBox: widget.recordsBox, // Boxインスタンスを渡す
          lastUsedMenusBox: widget.lastUsedMenusBox, // Boxインスタンスを渡す
          settingsBox: widget.settingsBox, // Boxインスタンスを渡す
          setCountBox: widget.setCountBox, // Boxインスタンスを渡す
          themeModeBox: widget.themeModeBox, // ★themeModeBoxを渡す
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      setState(() {
        _selectedDay = date;
        _focusedDay = date;
      });
    });
  }

  void navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
          settingsBox: widget.settingsBox, // settingsBoxを渡す
          setCountBox: widget.setCountBox, // setCountBoxを渡す
          themeModeBox: widget.themeModeBox, // ★themeModeBoxを渡す
          onThemeModeChanged: (newMode) {
            currentThemeMode.value = newMode; // main.dartのValueNotifierを更新
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background, // 背景色をテーマから取得
      appBar: AppBar(
        title: Text(
          'トレーニングカレンダー',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0), // タイトル色をテーマから取得
        ),
        backgroundColor: colorScheme.surface, // AppBar背景色をテーマから取得
        elevation: 0.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface), // アイコン色をテーマから取得
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface), // アイコン色をテーマから取得
            onPressed: () => navigateToSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<Box<DailyRecord>>(
            valueListenable: widget.recordsBox.listenable(),
            builder: (context, box, child) {
              return TableCalendar(
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
                headerStyle: HeaderStyle( // HeaderStyleもColorSchemeを使用
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18.0, fontWeight: FontWeight.bold),
                  leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
                  rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
                ),
                calendarStyle: CalendarStyle( // CalendarStyleもColorSchemeを使用
                  todayDecoration: BoxDecoration(
                    color: colorScheme.secondary, // 今日の日付の色をsecondaryに
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colorScheme.primary, // 選択された日付の色をprimaryに
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: colorScheme.onSurface), // デフォルトのテキスト色
                  weekendTextStyle: TextStyle(color: colorScheme.onSurfaceVariant), // 週末のテキスト色
                  outsideTextStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)), // 範囲外のテキスト色
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final recordedParts = _getRecordedPartsForDate(date);

                    if (recordedParts.isEmpty) {
                      return null;
                    }

                    return Positioned(
                      bottom: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: recordedParts.map((part) {
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(
                              color: partColors[part] ?? colorScheme.onSurfaceVariant, // 部位の色、なければonSurfaceVariant
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
