
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../models/timeline_day.dart';
import '../services/timeline_mapper.dart';
import 'meal_edit_screen.dart';
import 'record_screen.dart';

class DailyTimelineScreen extends StatefulWidget {
  final DateTime date;
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const DailyTimelineScreen({
    super.key,
    required this.date,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<DailyTimelineScreen> createState() => _DailyTimelineScreenState();
}

class _DailyTimelineScreenState extends State<DailyTimelineScreen> {
  late TimelineDay _timelineDay;
  late final TimelineMapper _timelineMapper;
  late DateTime _currentDate;
  bool _isSwitchingDay = false;
  int _slideDirection = 0;
  int? _pendingSlideDirection;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    _timelineDay = TimelineDay(date: _currentDate, entries: []);
    _timelineMapper = TimelineMapper(widget.recordsBox, widget.settingsBox);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTimelineDay());
  }

  @override
  void didUpdateWidget(covariant DailyTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDate(widget.date, _currentDate)) {
      _loadTimelineDay(targetDate: widget.date);
    }
  }

  Future<void> _loadTimelineDay({DateTime? targetDate}) async {
    final date = targetDate ?? _currentDate;
    final timeline =
        await _timelineMapper.buildTimelineFromDailyRecord(date);
    if (!mounted) return;
    setState(() {
      _currentDate = date;
      _timelineDay = timeline;
      _isSwitchingDay = false;
      _slideDirection = _pendingSlideDirection ?? 0;
      _pendingSlideDirection = null;
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleAddEntry(int hour) async {
    final tappedTime = DateTime(
      _currentDate.year,
      _currentDate.month,
      _currentDate.day,
      hour,
    );

    final selection = await showModalBottomSheet<_TimelineSelection>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final options = [
          ('筋トレ', TimelineEntryType.strength),
          ('食事', TimelineEntryType.meal),
          ('体重', TimelineEntryType.weight),
          ('有酸素', TimelineEntryType.cardio),
          ('予定', TimelineEntryType.schedule),
        ];
        final parts = _strengthPartOptions(l10n);
        TimelineEntryType? awaitingPart;
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 24.0),
                    child: Row(
                      children: [
                        for (final option in options)
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _buildTimelineTypeButton(
                              option.$1,
                              option.$2,
                              onPressed: () {
                                if (option.$2 == TimelineEntryType.strength) {
                                  setSheetState(() {
                                    awaitingPart = TimelineEntryType.strength;
                                  });
                                } else {
                                  Navigator.pop(
                                    context,
                                    _TimelineSelection(type: option.$2),
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (awaitingPart == TimelineEntryType.strength)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 24.0,
                      ),
                      child: Row(
                        children: [
                          for (final part in parts)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: _buildTimelineTypeButton(
                                part,
                                TimelineEntryType.strength,
                                onPressed: () {
                                  Navigator.pop(
                                    context,
                                    _TimelineSelection(
                                      type: TimelineEntryType.strength,
                                      strengthPart: part,
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );

    if (selection == null) {
      return;
    }
    final selectedType = selection.type;

    if (selectedType == TimelineEntryType.meal) {
      await _ensureMealPlaceholder(hour);
      await _openMealEditScreen(hour: hour, minute: 0);
      return;
    }

    setState(() {
      _timelineDay.entries.add(TimelineEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        startTime: tappedTime,
        type: selectedType,
        refId: selection.strengthPart,
      ));
    });
  }

  Future<void> _ensureMealPlaceholder(int hour) async {
    final dateKey = _getDateKey(_currentDate);
    final record = widget.recordsBox.get(dateKey);
    final meals = <Map<String, dynamic>>[];
    if (record?.meals != null) {
      for (final entry in record!.meals!) {
        if (entry is Map) {
          meals.add(Map<String, dynamic>.from(entry));
        }
      }
    }

    final exists = meals.any((map) {
      final rawHour = map['hour'];
      return rawHour is num && rawHour.toInt() == hour;
    });

    if (!exists) {
      final category = _mealCategoryKeyForHour(hour);
      meals.add({
        'category': category,
        'items': <Map<String, dynamic>>[],
        'subtotal': 0,
        'hour': hour,
        'minute': 0,
      });

      meals.sort((a, b) {
        final ah = (a['hour'] as num?)?.toInt() ?? 0;
        final bh = (b['hour'] as num?)?.toInt() ?? 0;
        return ah.compareTo(bh);
      });

      final updated = _copyRecordWithMeals(record, meals);
      await widget.recordsBox.put(dateKey, updated);
    }
  }

  DailyRecord _copyRecordWithMeals(
    DailyRecord? base,
    List<Map<String, dynamic>> meals,
  ) {
    final mealsValue = meals.isEmpty
        ? null
        : meals.map((e) => Map<String, dynamic>.from(e)).toList();
    if (base == null) {
      return DailyRecord(
        date: _currentDate,
        menus: <String, List<MenuData>>{},
        lastModifiedPart: null,
        weight: null,
        bodyFatPercent: null,
        waistCm: null,
        meals: mealsValue,
        bmr: null,
        trainingStart: null,
        trainingEnd: null,
      );
    }

    return DailyRecord(
      date: base.date,
      menus: base.menus.map(
        (key, value) => MapEntry(key, List<MenuData>.from(value)),
      ),
      lastModifiedPart: base.lastModifiedPart,
      weight: base.weight,
      bodyFatPercent: base.bodyFatPercent,
      waistCm: base.waistCm,
      meals: mealsValue,
      bmr: base.bmr,
      trainingStart: base.trainingStart,
      trainingEnd: base.trainingEnd,
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _mealCategoryKeyForHour(int hour) {
    if (hour < 11) return 'morning';
    if (hour < 15) return 'noon';
    if (hour < 21) return 'evening';
    return 'snack';
  }

  Future<void> _changeDay(int delta) async {
    if (_isSwitchingDay) return;
    final nextDate = _currentDate.add(Duration(days: delta));
    setState(() {
      _isSwitchingDay = true;
      _pendingSlideDirection = delta > 0 ? 1 : -1;
    });
    await _loadTimelineDay(targetDate: nextDate);
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) {
      return;
    }
    if (velocity < 0) {
      _changeDay(1);
    } else {
      _changeDay(-1);
    }
  }

  Widget _buildTimelineList(ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      key: ValueKey(_getDateKey(_currentDate)),
      itemCount: 24,
      itemBuilder: (context, index) {
        final hour = index;
        final timeLabel = '${hour.toString().padLeft(2, '0')}:00';
        final entriesAtThisHour = _timelineDay.entries.where((entry) {
          return _isSameDate(entry.startTime, _currentDate) &&
              entry.startTime.hour == hour;
        }).toList();

        return Container(
          constraints: const BoxConstraints(minHeight: 56.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 60,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                    child: Text(
                      timeLabel,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _handleAddEntry(hour),
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entriesAtThisHour.isEmpty)
                            const SizedBox(height: 48),
                          ...entriesAtThisHour.map((entry) {
                            return _TimelineEntryCard(
                              entry: entry,
                              onTap: () {
                                _openDetailForEntry(entry);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDetailForEntry(TimelineEntry entry) async {
    if (entry.type == TimelineEntryType.meal) {
      await _openMealEditScreen(hour: entry.startTime.hour, minute: entry.startTime.minute);
      return;
    }

    final focus = _mapEntryTypeToInitialFocus(entry.type);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          selectedDate: _currentDate,
          recordsBox: widget.recordsBox,
          lastUsedMenusBox: widget.lastUsedMenusBox,
          settingsBox: widget.settingsBox,
          setCountBox: widget.setCountBox,
          initialFocus: focus,
          initialStrengthPart:
              entry.type == TimelineEntryType.strength ? entry.refId : null,
          initialBaseTime: entry.startTime,
        ),
      ),
    );

    await _loadTimelineDay();
  }

  RecordInitialFocus _mapEntryTypeToInitialFocus(TimelineEntryType type) {
    switch (type) {
      case TimelineEntryType.strength:
        return RecordInitialFocus.strength;
      case TimelineEntryType.meal:
        return RecordInitialFocus.meal;
      case TimelineEntryType.memo:
        return RecordInitialFocus.memo;
      case TimelineEntryType.weight:
        return RecordInitialFocus.weight;
      case TimelineEntryType.cardio:
        return RecordInitialFocus.cardio;
      case TimelineEntryType.schedule:
        return RecordInitialFocus.schedule;
    }
  }

  Widget _buildTimelineTypeButton(
    String label,
    TimelineEntryType type, {
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(label),
    );
  }

  Future<void> _openMealEditScreen({int? hour, int? minute}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealEditScreen(
          selectedDate: _currentDate,
          recordsBox: widget.recordsBox,
          initialHour: hour,
          initialMinute: minute,
        ),
      ),
    );
    await _loadTimelineDay();
  }

  List<String> _strengthPartOptions(AppLocalizations l10n) {
    return [
      l10n.chest,
      l10n.back,
      l10n.shoulder,
      l10n.arm,
      l10n.abs,
      l10n.leg,
      l10n.fullBody,
      l10n.bodyWeightTraining,
      l10n.other1,
      l10n.other2,
      l10n.other3,
    ];
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    
    // 日付フォーマット (例: 2025/11/30 (Sun))
    // 簡易的なフォーマットを使用
    final dateStr = DateFormat('yyyy/MM/dd (E)').format(_currentDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.recordScreenTitle,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordScreen(
                    selectedDate: _currentDate,
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    initialStrengthPart: null,
                  ),
                ),
              );
              await _loadTimelineDay();
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _handleHorizontalSwipe,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final currentKey = ValueKey(_getDateKey(_currentDate));
            final direction = _slideDirection == 0 ? 0 : _slideDirection.sign;

            if (direction == 0) {
              return FadeTransition(opacity: animation, child: child);
            }

            final bool isIncoming = child.key == currentKey;
            final Offset begin = isIncoming
                ? Offset(direction.toDouble(), 0)
                : Offset(-direction.toDouble(), 0);
            final offsetAnim = Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation);

            return ClipRect(
              child: SlideTransition(
                position: offsetAnim,
                child: child,
              ),
            );
          },
          child: _buildTimelineList(theme, colorScheme),
        ),
      ),
    );
  }
}

class _TimelineEntryCard extends StatelessWidget {
  final TimelineEntry entry;
  final VoidCallback? onTap;

  const _TimelineEntryCard({
    required this.entry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    // タイプごとのスタイル定義
    final (IconData iconData, String label, Color bgColor, Color fgColor) =
        switch (entry.type) {
      TimelineEntryType.strength => (
          Icons.fitness_center_rounded,
          _strengthDisplayLabel(l10n, locale),
          Colors.purple.shade50,
          Colors.purple.shade900
        ),
      TimelineEntryType.meal => (
          Icons.restaurant_rounded,
          '食事',
          Colors.orange.shade50,
          Colors.orange.shade900
        ),
      TimelineEntryType.memo => (
          Icons.edit_rounded,
          'メモ',
          Colors.blueGrey.shade50,
          Colors.blueGrey.shade900
        ),
      TimelineEntryType.weight => (
          Icons.monitor_weight_rounded,
          '体重',
          Colors.blue.shade50,
          Colors.blue.shade900
        ),
      TimelineEntryType.cardio => (
          Icons.favorite_rounded,
          '有酸素',
          Colors.red.shade50,
          Colors.red.shade900
        ),
      TimelineEntryType.schedule => (
          Icons.event_rounded,
          '予定',
          Colors.amber.shade50,
          Colors.amber.shade900
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: fgColor.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(iconData, color: fgColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _strengthDisplayLabel(AppLocalizations l10n, Locale locale) {
    final raw = entry.refId?.trim();
    final base = (raw == null || raw.isEmpty)
        ? l10n.timelineStrengthFallback
        : raw;
    if (locale.languageCode == 'ja') {
      return '$baseトレ';
    }
    return '$base Tr';
  }
}

class _TimelineSelection {
  final TimelineEntryType type;
  final String? strengthPart;

  const _TimelineSelection({required this.type, this.strengthPart});
}
