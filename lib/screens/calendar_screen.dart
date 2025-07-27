import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // 日付フォーマット用
import 'package:collection/collection.dart'; // firstWhereOrNull を使用するためにインポート

import '../models/menu_data.dart'; // MenuData and DailyRecord models
import 'record_screen.dart'; // RecordScreen import
import 'settings_screen.dart'; // SettingsScreen import
import '../main.dart'; // currentThemeMode を使用するためにインポート

// ignore_for_file: library_private_types_in_public_api

class CalendarScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<Map<String, bool>> settingsBox;
  final Box<int> setCountBox;
  final Box<int> themeModeBox;

  const CalendarScreen({
    Key? key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox,
  }) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 部位ごとの色を定義するマップ
  final Map<String, Color> _bodyPartColors = {
    '有酸素運動': Colors.green.shade400,
    '腕': Colors.blue.shade400,
    '胸': Colors.red.shade400,
    '背中': Colors.purple.shade400,
    '肩': Colors.orange.shade400,
    '足': Colors.teal.shade400,
    '全身': Colors.pink.shade400,
    'その他１': Colors.brown.shade400,
    'その他２': Colors.indigo.shade400,
    'その他３': Colors.lime.shade400,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'GoodTraining',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: 24.0, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    themeModeBox: widget.themeModeBox,
                    onThemeModeChanged: (newMode) {
                      currentThemeMode.value = newMode;
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                locale: 'ja_JP', // 日本語ロケールを設定
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  // 変更点: 同じ日付が2回タップされた場合に記録画面へ遷移
                  if (isSameDay(_selectedDay, selectedDay)) {
                    // 同じ日付が再度タップされたら記録画面へ遷移
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => RecordScreen(
                          selectedDate: selectedDay,
                          recordsBox: widget.recordsBox,
                          lastUsedMenusBox: widget.lastUsedMenusBox,
                          settingsBox: widget.settingsBox,
                          setCountBox: widget.setCountBox,
                          themeModeBox: widget.themeModeBox,
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          // アニメーションを右から左から下から上へ変更
                          const begin = Offset(0.0, 1.0); // 下から開始
                          const end = Offset.zero; // 最終位置は元の場所
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
                  } else {
                    // 異なる日付がタップされたら選択状態を更新
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                // カレンダーのスタイル設定
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18.0, fontWeight: FontWeight.bold),
                  leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
                  rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: colorScheme.error), // 週末のテキスト色
                  todayDecoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.5), // 今日の日付の背景色
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colorScheme.primary, // 選択された日付の背景色
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: colorScheme.onSurface),
                ),
                // eventLoader で部位名を返すように変更
                eventLoader: (day) {
                  String dateKey = DateFormat('yyyy-MM-dd').format(day);
                  DailyRecord? record = widget.recordsBox.get(dateKey);
                  if (record != null && record.menus.isNotEmpty) {
                    // 記録がある場合は、その日の部位のリストを返す
                    return record.menus.keys.toList();
                  }
                  return [];
                },
                // markerBuilder で部位ごとに色分けされたマーカーを生成
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        bottom: 1.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.map((event) {
                            // event は部位名（String）として扱う
                            String bodyPart = event.toString();
                            // 部位名に対応する色を取得、見つからなければデフォルトでグレー
                            Color markerColor = _bodyPartColors[bodyPart] ?? Colors.grey;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0.5),
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                              ),
                              width: 5.0, // マーカーのサイズ
                              height: 5.0,
                            );
                          }).toList(),
                        ),
                      );
                    }
                    return null; // イベントがない場合はマーカーを表示しない
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<DailyRecord>>(
              valueListenable: widget.recordsBox.listenable(),
              builder: (context, box, _) {
                String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay ?? DateTime.now());
                DailyRecord? record = box.get(dateKey);

                if (record == null || record.menus.isEmpty) {
                  return Center(
                    child: Text(
                      'この日の記録はありません。',
                      style: TextStyle(color: colorScheme.onBackground, fontSize: 16.0),
                    ),
                  );
                }

                // 最後に編集した部位を最上位に表示し、それ以外はソート
                List<String> sortedParts = record.menus.keys.toList();
                if (record.lastModifiedPart != null && sortedParts.contains(record.lastModifiedPart)) {
                  sortedParts.remove(record.lastModifiedPart);
                  sortedParts.insert(0, record.lastModifiedPart!);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: sortedParts.length,
                  itemBuilder: (context, index) {
                    String part = sortedParts[index];
                    List<MenuData> menus = record.menus[part]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      color: isLightMode && part == '有酸素運動' ? Colors.grey[300] : colorScheme.surfaceContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              part,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            // 変更点: 各種目のセットを個別に表示
                            ...menus.expand((menu) {
                              List<Widget> menuWidgets = [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    menu.name, // 種目名
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ];
                              // 各セットの情報を表示
                              for (int i = 0; i < menu.weights.length; i++) {
                                // 有酸素運動の場合は「分」と「秒」を使用
                                final weightUnit = part == '有酸素運動' ? '分' : 'Kg';
                                final repUnit = part == '有酸素運動' ? '秒' : '回';

                                menuWidgets.add(
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16.0, bottom: 2.0), // インデント
                                    child: Text(
                                      '${i + 1}セット　${menu.weights[i]}$weightUnit     ${menu.reps[i]}$repUnit',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                );
                              }
                              return menuWidgets;
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar( // フッターを追加
        color: colorScheme.surface, // フッターの背景色
        elevation: 10.0, // 影の深さ
        child: Container(
          height: 60.0, // フッターの高さを調整
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min, // コンテンツに合わせて高さを最小化
            children: [
              SizedBox( // ボタンのサイズを明示的に指定
                width: 36.0, // ボタンの幅をさらに小さく
                height: 36.0, // ボタンの高さをさらに小さく
                child: FloatingActionButton( // FloatingActionButton を使用
                  onPressed: () {
                    // フッターの追加ボタンから記録画面へ遷移
                    // 現在選択されている日付（_selectedDay）をRecordScreenに渡す
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => RecordScreen(
                          selectedDate: _selectedDay ?? DateTime.now(), // _selectedDayがnullの場合は現在の日付
                          recordsBox: widget.recordsBox,
                          lastUsedMenusBox: widget.lastUsedMenusBox,
                          settingsBox: widget.settingsBox,
                          setCountBox: widget.setCountBox,
                          themeModeBox: widget.themeModeBox,
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          // アニメーションを右から左から下から上へ変更
                          const begin = Offset(0.0, 1.0); // 下から開始
                          const end = Offset.zero; // 最終位置は元の場所
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
                  },
                  backgroundColor: Colors.blue.shade600, // ボタンの色を青に
                  shape: const CircleBorder(), // 丸い形に
                  elevation: 0.0, // 影をなくす
                  child: const Icon(Icons.add, color: Colors.white, size: 18.0), // プラスアイコンのサイズを調整
                )
              ),
              const SizedBox(height: 2.0), // ボタンとテキストの間のスペースを調整
              Text(
                '追加',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12.0, fontWeight: FontWeight.bold), // テキストのサイズを調整
              ),
            ],
          ),
        ),
      ),
    );
  }
}
