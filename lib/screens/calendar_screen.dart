import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // DateFormat を使用するためにインポート

import '../models/menu_data.dart'; // MenuData and DailyRecord models
import 'record_screen.dart'; // RecordScreen import
import 'settings_screen.dart'; // SettingsScreen import
import '../widgets/custom_widgets.dart'; // カスタムウィジェットをインポート
import '../main.dart'; // currentThemeMode を使用するためにインポート

// ignore_for_file: library_private_types_in_public_api

class CalendarScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox; // Boxの型をdynamicに合わせる
  final Box<int> setCountBox;
  final Box<int> themeModeBox;

  const CalendarScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {}; // 記録がある日付のイベント（部位名）を保存
  DailyRecord? _currentDayRecord; // 選択された日付のDailyRecordを保持

  List<String> _filteredBodyParts = [];
  final List<String> _allBodyParts = [
    '有酸素運動', '腕', '胸', '背中', '肩', '足', '全身', 'その他１', 'その他２', 'その他３',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents(); // カレンダーマーカー用
    _loadSettingsAndParts(); // フィルタリングされた部位用
    _loadDailyRecordForSelectedDay(); // 初期表示日の記録をロード
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // テーマモード変更を検知してUIを更新
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

  void _loadEvents() {
    _events.clear();
    for (var record in widget.recordsBox.values) {
      try {
        DateTime date = DateTime.parse(record.key);
        _events[DateTime(date.year, date.month, date.day)] = record.menus.keys.toList(); // 日付を正規化して保存
      } catch (e) {
        print('Error parsing date key from Hive: ${record.key}, Error: $e');
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _loadDailyRecordForSelectedDay() {
    if (_selectedDay != null) {
      String dateKey = _getDateKey(_selectedDay!);
      setState(() {
        _currentDayRecord = widget.recordsBox.get(dateKey);
      });
    } else {
      setState(() {
        _currentDayRecord = null;
      });
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    // _eventsのキーをDateTime型に正規化して比較
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _loadSettingsAndParts() {
    // 型安全にMap<String, bool>を構築
    Map<String, bool>? savedBodyPartsSettings;
    final dynamic rawSettings = widget.settingsBox.get('selectedBodyParts');

    if (rawSettings != null && rawSettings is Map) {
      savedBodyPartsSettings = {};
      rawSettings.forEach((key, value) {
        if (key is String && value is bool) {
          savedBodyPartsSettings![key] = value;
        }
      });
    }

    if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
      _filteredBodyParts = _allBodyParts
          .where((part) => savedBodyPartsSettings![part] == true)
          .toList();
      if (_filteredBodyParts.isEmpty) {
        _filteredBodyParts = List.from(_allBodyParts);
      }
    } else {
      _filteredBodyParts = List.from(_allBodyParts);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) {
      // 同じ日付を2回タップ -> RecordScreenへ遷移
      if (_selectedDay != null) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => RecordScreen(
              selectedDate: _selectedDay!,
              recordsBox: widget.recordsBox,
              lastUsedMenusBox: widget.lastUsedMenusBox,
              settingsBox: widget.settingsBox,
              setCountBox: widget.setCountBox,
              themeModeBox: widget.themeModeBox,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ).then((_) {
          if (mounted) {
            _loadEvents(); // RecordScreenから戻ったらイベントを再ロード
            _loadDailyRecordForSelectedDay(); // 記録も再ロード
          }
        });
      }
    } else {
      // 異なる日付をタップ、または初回タップ -> 日付を選択
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _loadDailyRecordForSelectedDay(); // 新しく選択された日の記録をロード
      });
    }
  }

  void _navigateToSettings(BuildContext context) {
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
    ).then((_) {
      if (mounted) {
        _loadSettingsAndParts(); // 設定画面から戻ったら設定を再ロード
        _loadDailyRecordForSelectedDay(); // 記録も再ロード
      }
    });
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'カレンダー',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: 24.0, color: colorScheme.onSurface),
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ja_JP', // 日本語ロケールを設定
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected, // 2回タップで遷移するロジックを適用
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            calendarFormat: CalendarFormat.month,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18.0, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
              rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: colorScheme.error), // 土日の色
              todayDecoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: colorScheme.secondary, // イベントマーカーの色
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              rowDecoration: BoxDecoration(color: colorScheme.surface), // カレンダーの行の背景色
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              weekendStyle: TextStyle(color: colorScheme.error),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _currentDayRecord != null && _currentDayRecord!.menus.isNotEmpty
                ? ListView.builder(
              itemCount: _currentDayRecord!.menus.length,
              itemBuilder: (context, index) {
                final part = _currentDayRecord!.menus.keys.elementAt(index);
                final menuList = _currentDayRecord!.menus[part]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Card(
                    color: colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            part, // 部位名
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: menuList.length,
                            itemBuilder: (context, menuIndex) {
                              final menu = menuList[menuIndex];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    menu.name, // 種目名
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: menu.weights.length,
                                    itemBuilder: (context, setIndex) {
                                      // インデックスが有効であることを確認
                                      if (setIndex >= menu.weights.length || setIndex >= menu.reps.length) {
                                        return const SizedBox.shrink(); // 範囲外の場合は何も表示しない
                                      }
                                      final weight = menu.weights[setIndex];
                                      final rep = menu.reps[setIndex];
                                      String weightUnit = (part == '有酸素運動') ? '分' : 'kg';
                                      String repUnit = (part == '有酸素運動') ? '秒' : '回';

                                      return Text(
                                        '${setIndex + 1}セット：$weight $weightUnit $rep $repUnit',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 14.0,
                                        ),
                                      );
                                    },
                                  ),
                                  if (menuIndex < menuList.length - 1) const SizedBox(height: 12), // メニュー間のスペース
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
                : Center(
              child: Text(
                '選択された日付には記録がありません。',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
              ),
            ),
          ),
        ],
      ),
      // floatingActionButtonLocation と floatingActionButton は完全に削除
    );
  }
}
