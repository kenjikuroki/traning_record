import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // To use DateFormat

import '../models/menu_data.dart'; // MenuData and DailyRecord models
import 'record_screen.dart'; // RecordScreen import
import 'settings_screen.dart'; // SettingsScreen import
import '../widgets/custom_widgets.dart'; // Import custom widgets
import '../main.dart'; // To use currentThemeMode

// ignore_for_file: library_private_types_in_public_api

class CalendarScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox; // Match Box type to dynamic
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
  Map<DateTime, List<String>> _events = {}; // Store events (part names) for dates with records
  DailyRecord? _currentDayRecord; // Hold the DailyRecord for the selected day

  List<String> _filteredBodyParts = [];
  final List<String> _allBodyParts = [
    '有酸素運動', '腕', '胸', '背中', '肩', '足', '全身', 'その他１', 'その他２', 'その他３',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents(); // For calendar markers
    _loadSettingsAndParts(); // For filtered parts
    _loadDailyRecordForSelectedDay(); // Load record for initial display day
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for theme mode changes to update the UI
    currentThemeMode.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    currentThemeMode.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    if (mounted) {
      setState(() {}); // Rebuild the UI when the theme mode changes
    }
  }

  void _loadEvents() {
    _events.clear();
    for (int i = 0; i < widget.recordsBox.length; i++) {
      final key = widget.recordsBox.keyAt(i);
      final record = widget.recordsBox.getAt(i);

      if (key is String && record != null) {
        try {
          DateTime date = DateTime.parse(key);
          _events[DateTime(date.year, date.month, date.day)] = record.menus.keys.toList();
        } catch (e) {
          print('Error parsing date key from Hive: $key, Error: $e');
        }
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
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _loadSettingsAndParts() {
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

  // --- 修正された _onDaySelected メソッド ---
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) {
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
              themeModeBox: widget.themeModeBox, // この行が正しく追加されていることを確認してください
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
            _loadEvents();
            _loadDailyRecordForSelectedDay();
          }
        });
      }
    } else {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _loadDailyRecordForSelectedDay();
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
        _loadSettingsAndParts();
        _loadDailyRecordForSelectedDay();
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
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected,
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
              weekendTextStyle: TextStyle(color: colorScheme.error),
              todayDecoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              rowDecoration: BoxDecoration(color: colorScheme.surface),
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
                            part,
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
                                    menu.name,
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
                                      if (setIndex >= menu.weights.length || setIndex >= menu.reps.length) {
                                        return const SizedBox.shrink();
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
                                  if (menuIndex < menuList.length - 1) const SizedBox(height: 12),
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
    );
  }
}
