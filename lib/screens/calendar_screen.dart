import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../models/record_models.dart';
import '../settings_manager.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import '../widgets/custom_widgets.dart';

// ignore_for_file: library_private_types_in_public_api

class CalendarScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const CalendarScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {};
  DailyRecord? _currentDayRecord;

  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
    _loadDailyRecordForSelectedDay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getOriginalPartName(BuildContext context, String translatedPart) {
    final l10n = AppLocalizations.of(context)!;
    if (translatedPart == l10n.aerobicExercise) return '有酸素運動';
    if (translatedPart == l10n.arm) return '腕';
    if (translatedPart == l10n.chest) return '胸';
    if (translatedPart == l10n.back) return '背中';
    if (translatedPart == l10n.shoulder) return '肩';
    if (translatedPart == l10n.leg) return '足';
    if (translatedPart == l10n.fullBody) return '全身';
    if (translatedPart == l10n.other1) return 'その他１';
    if (translatedPart == l10n.other2) return 'その他２';
    if (translatedPart == l10n.other3) return 'その他３';
    return translatedPart;
  }

  void _loadEvents() {
    _events.clear();
    for (int i = 0; i < widget.recordsBox.length; i++) {
      final key = widget.recordsBox.keyAt(i);
      final record = widget.recordsBox.getAt(i);

      if (key is String && record != null) {
        try {
          DateTime date = DateTime.parse(key);
          final partNames = record.menus.keys.toList();
          _events[DateTime(date.year, date.month, date.day)] = partNames;
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
    final l10n = AppLocalizations.of(context)!;
    _allBodyParts = [
      l10n.aerobicExercise, l10n.arm, l10n.chest, l10n.back, l10n.shoulder, l10n.leg,
      l10n.fullBody, l10n.other1, l10n.other2, l10n.other3,
    ];

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
          .where((translatedPart) {
        final originalPart = _getOriginalPartName(context, translatedPart);
        return savedBodyPartsSettings![originalPart] == true;
      })
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
            _loadSettingsAndParts();
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          l10n.calendar,
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: 24.0, color: colorScheme.onSurface),
            tooltip: l10n.settings,
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: Localizations.localeOf(context).toString(),
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
                            _translatePartToLocale(context, part),
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

                                      String weightUnit = (part == '有酸素運動') ? l10n.min : l10n.kg;
                                      String repUnit = (part == '有酸素運動') ? l10n.sec : l10n.reps;

                                      return Text(
                                        '${setIndex + 1}${l10n.sets}：$weight $weightUnit $rep $repUnit',
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
                l10n.noRecordMessage,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translatePartToLocale(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
      case '有酸素運動': return l10n.aerobicExercise;
      case '腕': return l10n.arm;
      case '胸': return l10n.chest;
      case '背中': return l10n.back;
      case '肩': return l10n.shoulder;
      case '足': return l10n.leg;
      case '全身': return l10n.fullBody;
      case 'その他１': return l10n.other1;
      case 'その他２': return l10n.other2;
      case 'その他３': return l10n.other3;
      default: return part;
    }
  }
}