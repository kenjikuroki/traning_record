import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/meal.dart';
import '../models/menu_data.dart';

class MealEditScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox;
  final int? initialHour;
  final int? initialMinute;

  const MealEditScreen({
    super.key,
    required this.selectedDate,
    required this.recordsBox,
    this.initialHour,
    this.initialMinute,
  });

  @override
  State<MealEditScreen> createState() => _MealEditScreenState();
}

class _MealEditScreenState extends State<MealEditScreen> {
  late _MealEditorCard _card;
  List<Map<String, dynamic>> _otherMeals = [];
  double _totalKcal = 0;
  double _otherTotalKcal = 0;
  bool _saving = false;

  int get _targetHour => (widget.initialHour ?? TimeOfDay.now().hour).clamp(0, 23);
  int get _targetMinute => (widget.initialMinute ?? 0).clamp(0, 59);

  @override
  void initState() {
    super.initState();
    _loadMealEntry();
  }

  void _loadMealEntry() {
    final dateKey = _getDateKey(widget.selectedDate);
    final record = widget.recordsBox.get(dateKey);
    final rawMeals = record?.meals;
    final targetHour = _targetHour;
    final targetMinute = _targetMinute;

    _otherMeals = [];
    _otherTotalKcal = 0;
    _card = _createEmptyCard(
      _mealCategoryFromHour(targetHour),
      hour: targetHour,
      minute: targetMinute,
    );

    if (rawMeals != null) {
      for (final entry in rawMeals) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final category = _mealCategoryFromString(map['category'] as String?);
        final itemsRaw = map['items'];
        final subtotalRaw = map['subtotal'];
        final hourRaw = map['hour'];
        final minuteRaw = map['minute'];
        final parsedHour =
            (hourRaw is num) ? hourRaw.toInt().clamp(0, 23) : _defaultMealHour(category);
        final parsedMinute = (minuteRaw is num) ? minuteRaw.toInt().clamp(0, 59) : 0;

        if (parsedHour == targetHour && parsedMinute == targetMinute) {
          final controllers = _controllersFromItems(itemsRaw);
          final subtotal = _parseSubtotal(subtotalRaw);
          _card = _MealEditorCard(
            category: category,
            items: controllers,
            subtotal: subtotal,
            hour: parsedHour,
            minute: parsedMinute,
          );
        } else {
          final copy = Map<String, dynamic>.from(map);
          _otherMeals.add(copy);
          final otherSubtotal = _parseSubtotal(copy['subtotal']);
          _otherTotalKcal += otherSubtotal;
        }
      }
    }

    _recalculateTotals(notify: false);
  }

  List<_MealItemControllers> _controllersFromItems(dynamic itemsRaw) {
    final controllers = <_MealItemControllers>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final itemMap = item.cast<String, dynamic>();
        final name = itemMap['name']?.toString() ?? '';
        double? kcal;
        final rawKcal = itemMap['kcal'];
        if (rawKcal is num) {
          kcal = rawKcal.toDouble();
        } else if (rawKcal is String) {
          kcal = double.tryParse(rawKcal);
        }
        controllers.add(_MealItemControllers(name: name, kcal: kcal));
      }
    }
    while (controllers.length < 3) {
      controllers.add(_MealItemControllers());
    }
    return controllers;
  }

  double _parseSubtotal(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  void dispose() {
    _card.dispose();
    super.dispose();
  }

  void _recalculateTotals({bool notify = true}) {
    double subtotal = 0;
    for (final item in _card.items) {
      final value = double.tryParse(item.kcalController.text.trim());
      if (value != null && value > 0) {
        subtotal += value;
      }
    }
    _card.subtotal = subtotal;
    if (notify) {
      setState(() => _totalKcal = subtotal + _otherTotalKcal);
    } else {
      _totalKcal = subtotal + _otherTotalKcal;
    }
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    final mealsPayload = _buildMealsPayload();
    final dateKey = _getDateKey(widget.selectedDate);
    final current = widget.recordsBox.get(dateKey);
    final updated = _createUpdatedRecord(current, mealsPayload);
    await widget.recordsBox.put(dateKey, updated);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  List<Map<String, dynamic>> _buildMealsPayload() {
    final result = _otherMeals.map((e) => Map<String, dynamic>.from(e)).toList();
    final items = <Map<String, dynamic>>[];
    for (final item in _card.items) {
      final name = item.nameController.text.trim();
      final kcalText = item.kcalController.text.trim();
      final kcal = kcalText.isEmpty ? null : double.tryParse(kcalText);
      if (name.isEmpty && kcal == null) {
        continue;
      }
      items.add({'name': name, 'kcal': kcal});
    }

    if (items.isNotEmpty || _card.subtotal > 0) {
      result.add({
        'category': _card.category.name,
        'items': items,
        'subtotal': _card.subtotal,
        'hour': _card.hour,
        'minute': _card.minute,
      });
    }

    result.sort((a, b) {
      final ah = (a['hour'] as num?)?.toInt() ?? 0;
      final bh = (b['hour'] as num?)?.toInt() ?? 0;
      final am = (a['minute'] as num?)?.toInt() ?? 0;
      final bm = (b['minute'] as num?)?.toInt() ?? 0;
      final cmp = ah.compareTo(bh);
      if (cmp != 0) return cmp;
      return am.compareTo(bm);
    });

    return result;
  }

  DailyRecord _createUpdatedRecord(
    DailyRecord? current,
    List<Map<String, dynamic>> meals,
  ) {
    final mealsValue = meals.isEmpty ? null : meals;
    if (current == null) {
      return DailyRecord(
        date: widget.selectedDate,
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
      date: current.date,
      menus: current.menus.map(
        (key, value) => MapEntry(key, List<MenuData>.from(value)),
      ),
      lastModifiedPart: current.lastModifiedPart,
      weight: current.weight,
      bodyFatPercent: current.bodyFatPercent,
      waistCm: current.waistCm,
      meals: mealsValue,
      bmr: current.bmr,
      trainingStart: current.trainingStart,
      trainingEnd: current.trainingEnd,
    );
  }

  String _formatDateLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat('yyyy/MM/dd (E)', locale);
    return fmt.format(widget.selectedDate);
  }

  String _formatKcalDisplay(BuildContext context, double value) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = NumberFormat('#,##0', locale);
    return formatter.format(value.round());
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay(hour: _card.hour ?? _targetHour, minute: _card.minute ?? _targetMinute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      _card.hour = picked.hour;
      _card.minute = picked.minute;
    });
  }

  void _addMealItemRow() {
    setState(() {
      _card.items.add(_MealItemControllers());
    });
    _recalculateTotals();
  }

  void _removeMealItemRow(int index) {
    if (_card.items.length == 1) {
      _card.items.first.clear();
      _recalculateTotals();
      return;
    }
    final removed = _card.items.removeAt(index);
    removed.dispose();
    setState(() {});
    _recalculateTotals();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLabel = _formatDateLabel(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.meal} | $dateLabel'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _handleSave,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledForegroundColor: Theme.of(context).disabledColor,
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildMealCard(context, l10n),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.mealTotalToday,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${_formatKcalDisplay(context, _totalKcal)} ${l10n.kcalUnit}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MealCategory>(
                      isExpanded: true,
                      value: _card.category,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _card.category = value;
                        });
                      },
                      items: MealCategory.values
                          .map(
                            (cat) => DropdownMenuItem<MealCategory>(
                              value: cat,
                              child: Text(
                                _mealCategoryLabel(cat, l10n),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_timeLabel(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_card.items.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildMealItemRow(context, index, l10n),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addMealItemRow,
                icon: const Icon(Icons.add),
                label: Text(l10n.addMealItem),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${l10n.mealSubtotal}: ${_formatKcalDisplay(context, _card.subtotal)} ${l10n.kcalUnit}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItemRow(
    BuildContext context,
    int index,
    AppLocalizations l10n,
  ) {
    final controllers = _card.items[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: controllers.nameController,
            decoration: InputDecoration(
              labelText: l10n.mealItem,
              hintText: l10n.mealInputHint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: controllers.kcalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.calorie,
              suffixText: l10n.kcalUnit,
            ),
            onChanged: (_) => _recalculateTotals(),
          ),
        ),
        IconButton(
          tooltip: l10n.delete,
          onPressed: () => _removeMealItemRow(index),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  String _timeLabel(BuildContext context) {
    final time = TimeOfDay(
      hour: _card.hour ?? _targetHour,
      minute: _card.minute ?? _targetMinute,
    );
    return time.format(context);
  }

  _MealEditorCard _createEmptyCard(MealCategory category,
      {int? hour, int? minute}) {
    return _MealEditorCard(
      category: category,
      items: List.generate(3, (_) => _MealItemControllers()),
      subtotal: 0,
      hour: hour,
      minute: minute,
    );
  }

  MealCategory _mealCategoryFromString(String? value) {
    switch (value) {
      case 'noon':
        return MealCategory.noon;
      case 'evening':
        return MealCategory.evening;
      case 'snack':
        return MealCategory.snack;
      case 'morning':
      default:
        return MealCategory.morning;
    }
  }

  MealCategory _mealCategoryFromHour(int hour) {
    if (hour < 11) return MealCategory.morning;
    if (hour < 15) return MealCategory.noon;
    if (hour < 20) return MealCategory.evening;
    return MealCategory.snack;
  }

  String _mealCategoryLabel(MealCategory category, AppLocalizations l10n) {
    switch (category) {
      case MealCategory.morning:
        return l10n.mealMorning;
      case MealCategory.noon:
        return l10n.mealNoon;
      case MealCategory.evening:
        return l10n.mealEvening;
      case MealCategory.snack:
        return l10n.mealSnack;
    }
  }

  String _getDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  int _defaultMealHour(MealCategory category) {
    switch (category) {
      case MealCategory.morning:
        return 8;
      case MealCategory.noon:
        return 12;
      case MealCategory.evening:
        return 19;
      case MealCategory.snack:
        return 21;
    }
  }
}

class _MealEditorCard {
  MealCategory category;
  final List<_MealItemControllers> items;
  double subtotal;
  int? hour;
  int? minute;

  _MealEditorCard({
    required this.category,
    required this.items,
    required this.subtotal,
    this.hour,
    this.minute,
  });

  void dispose() {
    for (final item in items) {
      item.dispose();
    }
  }
}

class _MealItemControllers {
  final TextEditingController nameController;
  final TextEditingController kcalController;

  _MealItemControllers({String? name, double? kcal})
      : nameController = TextEditingController(text: name ?? ''),
        kcalController = TextEditingController(
          text: kcal == null
              ? ''
              : (kcal == kcal.roundToDouble()
                  ? kcal.toStringAsFixed(0)
                  : kcal.toString()),
        );

  void dispose() {
    nameController.dispose();
    kcalController.dispose();
  }

  void clear() {
    nameController.clear();
    kcalController.clear();
  }
}
