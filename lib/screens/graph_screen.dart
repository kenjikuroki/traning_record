// lib/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../models/record_models.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import 'calendar_screen.dart';

// ignore_for_file: library_private_types_in_public_api

enum DisplayMode { day, week }
enum AeroMetric { distance, time, pace }

class GraphScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const GraphScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  // 保存キー
  static const String _prefGraphPart = 'graph_selected_part';
  static const String _prefGraphMenu = 'graph_selected_menu';
  static const String _prefGraphMode = 'graph_display_mode';
  static const String _prefAeroMetric = 'graph_aero_metric';

  // 選択状態
  List<String> _filteredBodyParts = [];
  String? _selectedPart;
  List<String> _menusForPart = [];
  String? _selectedMenu;
  bool _isFavorite = false;

  DisplayMode _displayMode = DisplayMode.day;
  AeroMetric _aeroMetric = AeroMetric.distance;

  // 体重/筋トレ 軸・点
  List<DateTime> _lineAxisDates = [];
  List<FlSpot> _spots = [];
  double _lineAxisMinY = 0;
  double _lineAxisMaxY = 1;
  double _lineYInterval = 1;

  // 有酸素 軸・点
  List<DateTime> _aeroAxisDates = [];
  List<FlSpot> _aeroSpots = [];
  double _aeroAxisMinY = 0;
  double _aeroAxisMaxY = 1;
  double _aeroYInterval = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  // ----- 名前変換 -----
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
    if (translatedPart == l10n.favorites) return 'お気に入り';
    if (translatedPart == l10n.bodyWeight) return '体重';
    return translatedPart;
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
      case 'お気に入り': return l10n.favorites;
      default: return part;
    }
  }

  bool _isAerobicSelectedNow() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedPart == l10n.aerobicExercise) return true;
    if (_selectedPart == l10n.favorites && _selectedMenu != null) {
      return _menuExistsInAerobic(_selectedMenu!);
    }
    return false;
  }

  // ----- 初期ロード -----
  void _loadSettingsAndParts() {
    final l10n = AppLocalizations.of(context)!;
    final allBodyParts = ['有酸素運動','腕','胸','背中','肩','足','全身','その他１','その他２','その他３'];

    Map<String, bool>? savedBodyPartsSettings;
    final dynamic rawSettings = widget.settingsBox.get('selectedBodyParts');
    if (rawSettings != null && rawSettings is Map) {
      savedBodyPartsSettings = {};
      rawSettings.forEach((k, v) {
        if (k is String && v is bool) savedBodyPartsSettings![k] = v;
      });
    }

    _filteredBodyParts = (savedBodyPartsSettings == null || savedBodyPartsSettings.isEmpty)
        ? allBodyParts
        : allBodyParts.where((p) => savedBodyPartsSettings![p] == true).toList();
    _filteredBodyParts = _filteredBodyParts.map((p) => _translatePartToLocale(context, p)).toList();
    _filteredBodyParts = [l10n.bodyWeight, l10n.favorites, ..._filteredBodyParts];

    final int? savedModeIdx = widget.settingsBox.get(_prefGraphMode) as int?;
    if (savedModeIdx != null && savedModeIdx >= 0 && savedModeIdx < DisplayMode.values.length) {
      _displayMode = DisplayMode.values[savedModeIdx];
    }
    final int? savedAeroIdx = widget.settingsBox.get(_prefAeroMetric) as int?;
    if (savedAeroIdx != null && savedAeroIdx >= 0 && savedAeroIdx < AeroMetric.values.length) {
      _aeroMetric = AeroMetric.values[savedAeroIdx];
    }

    final String? savedPart = widget.settingsBox.get(_prefGraphPart) as String?;
    _selectedPart = (savedPart != null && _filteredBodyParts.contains(savedPart))
        ? savedPart
        : (_filteredBodyParts.isNotEmpty ? _filteredBodyParts.first : null);

    if (mounted && _selectedPart != null) {
      _loadMenusForPart(_selectedPart!);
      setState(() {});
    }
  }

  void _loadMenusForPart(String translatedPart) {
    final l10n = AppLocalizations.of(context)!;
    _menusForPart.clear();

    if (translatedPart == l10n.bodyWeight) {
      _selectedMenu = null;
      _isFavorite = false;
      _loadBodyWeightData();
      _saveGraphPrefs();
      return;
    }

    if (translatedPart == l10n.favorites) {
      final dynamic rawFavorites = widget.settingsBox.get('favorites');
      if (rawFavorites is List) _menusForPart = rawFavorites.whereType<String>().toList();
    } else {
      final originalPartName = _getOriginalPartName(context, translatedPart);
      final dynamic rawList = widget.lastUsedMenusBox.get(originalPartName);
      if (rawList is List) {
        final List<MenuData> lastUsedMenus = rawList.whereType<MenuData>().toList();
        _menusForPart = lastUsedMenus.map((m) => m.name).toList();
      }
    }

    final String? savedMenu = widget.settingsBox.get(_prefGraphMenu) as String?;
    _selectedMenu = (savedMenu != null && _menusForPart.contains(savedMenu))
        ? savedMenu
        : (_menusForPart.isNotEmpty ? _menusForPart.first : null);

    if (mounted) {
      if (_isAerobicSelectedNow()) {
        _loadAerobicData(_selectedMenu);
      } else if (_selectedPart == l10n.favorites && _selectedMenu != null) {
        if (_menuExistsInAerobic(_selectedMenu!)) {
          _loadAerobicData(_selectedMenu);
        } else {
          _loadGraphData(_selectedMenu!);
        }
      } else if (_selectedMenu != null) {
        _loadGraphData(_selectedMenu!);
      } else {
        _spots = [];
        _lineAxisDates = [];
      }
      _checkIfFavorite();
      setState(() {});
    }
  }

  // ----- 表示/整形 -----
  String _formatAxisDate(DateTime dt) {
    final locale = Localizations.localeOf(context).toString();
    if (_displayMode == DisplayMode.week) {
      final core = DateFormat('M/d', locale).format(dt);
      return Localizations.localeOf(context).languageCode == 'ja' ? '$core週' : 'wk of $core';
    }
    return DateFormat('M/d', locale).format(dt);
  }

  double _niceStep(double range) {
    if (range <= 0 || !range.isFinite) return 1;
    final raw = range / 5.0;
    final exp = pow(10, (log(raw) / ln10).floor()).toDouble();
    final f = raw / exp;
    double nf;
    if (f <= 1) nf = 1;
    else if (f <= 2) nf = 2;
    else if (f <= 2.5) nf = 2.5;
    else if (f <= 5) nf = 5;
    else nf = 10;
    return nf * exp;
  }

  String _formatYAxis(double minY, double maxY, double v) {
    final range = (maxY - minY).abs();
    if (range >= 10) return v.toStringAsFixed(0);
    if (range >= 1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  // ----- 体重 -----
  void _loadBodyWeightData() {
    _spots = [];
    _lineAxisDates = [];

    final Map<int, double> map = {}; // dayMs -> value
    for (final r in widget.recordsBox.toMap().values.whereType<DailyRecord>()) {
      if (r.weight == null) continue;
      if (_displayMode == DisplayMode.day) {
        final k = _dayKey(r.date);
        map[k] = r.weight!;
      } else {
        final k = _weekKey(r.date);
        map[k] = (map[k] ?? 0) + r.weight!; // 一旦合計
      }
    }
    if (_displayMode == DisplayMode.week) {
      // 週は平均
      final counts = <int, int>{};
      for (final r in widget.recordsBox.toMap().values.whereType<DailyRecord>()) {
        if (r.weight == null) continue;
        final k = _weekKey(r.date);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      map.updateAll((k, v) => v / (counts[k] ?? 1));
    }

    _lineAxisDates = _buildContinuousAxis(map.keys, weekly: _displayMode == DisplayMode.week);

    for (int i = 0; i < _lineAxisDates.length; i++) {
      final ms = _displayMode == DisplayMode.day ? _dayKey(_lineAxisDates[i]) : _weekKey(_lineAxisDates[i]);
      final val = map[ms];
      if (val != null) _spots.add(FlSpot(i.toDouble(), val));
    }

    _recalcLineAxis();
    setState(() {});
  }

  // ----- 筋トレ -----
  void _loadGraphData(String menuName) {
    _spots = [];
    _lineAxisDates = [];

    final allBodyParts = ['有酸素運動','腕','胸','背中','肩','足','全身','その他１','その他２','その他３'];
    final Map<int, double> map = {}; // dayMs or weekMs -> best

    for (final r in widget.recordsBox.toMap().values.whereType<DailyRecord>()) {
      double? bestForThisDay;
      for (final part in allBodyParts) {
        final list = r.menus[part];
        if (list == null) continue;
        final md = list.firstWhereOrNull((m) => m.name == menuName);
        if (md == null) continue;
        for (int i = 0; i < md.weights.length; i++) {
          final w = double.tryParse(md.weights[i]);
          final reps = int.tryParse(md.reps[i]);
          if (w != null && reps != null && reps >= 1) {
            bestForThisDay = (bestForThisDay == null) ? w : max(bestForThisDay!, w);
          }
        }
      }
      if (bestForThisDay != null) {
        if (_displayMode == DisplayMode.day) {
          final k = _dayKey(r.date);
          map[k] = max(map[k] ?? 0, bestForThisDay!);
        } else {
          final k = _weekKey(r.date);
          map[k] = max(map[k] ?? 0, bestForThisDay!);
        }
      }
    }

    _lineAxisDates = _buildContinuousAxis(map.keys, weekly: _displayMode == DisplayMode.week);

    for (int i = 0; i < _lineAxisDates.length; i++) {
      final ms = _displayMode == DisplayMode.day ? _dayKey(_lineAxisDates[i]) : _weekKey(_lineAxisDates[i]);
      final val = map[ms];
      if (val != null) _spots.add(FlSpot(i.toDouble(), val));
    }

    _recalcLineAxis();
    _checkIfFavorite();
    _saveGraphPrefs();
    setState(() {});
  }

  // ----- 有酸素 -----
  double _parseDistanceKm(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final parts = raw.split('.');
    final km = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return km + (m / 1000.0);
  }

  int _parseDurationSec(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final parts = raw.split(':');
    if (parts.length == 1) return (int.tryParse(parts[0]) ?? 0) * 60;
    final min = int.tryParse(parts[0]) ?? 0;
    final sec = int.tryParse(parts[1]) ?? 0;
    return min * 60 + sec;
  }

  void _loadAerobicData(String? menuName) {
    _aeroSpots = [];
    _aeroAxisDates = [];

    final Map<int, double> dayDist = {};     // dayMs -> km
    final Map<int, double> dayTimeMin = {};  // dayMs -> min

    for (final r in widget.recordsBox.toMap().values.whereType<DailyRecord>()) {
      final dayMs = _dayKey(r.date);
      final list = r.menus['有酸素運動'];
      if (list == null) continue;

      double sumKm = 0;
      int sumSec = 0;

      for (final m in list) {
        if (menuName != null && m.name != menuName) continue;
        sumKm += _parseDistanceKm(m.distance);
        sumSec += _parseDurationSec(m.duration);
      }

      if (sumKm > 0) dayDist[dayMs] = (dayDist[dayMs] ?? 0) + sumKm;
      if (sumSec > 0) dayTimeMin[dayMs] = (dayTimeMin[dayMs] ?? 0) + (sumSec / 60.0);
    }

    Map<int, double> series;
    if (_displayMode == DisplayMode.day) {
      series = switch (_aeroMetric) {
        AeroMetric.distance => dayDist,
        AeroMetric.time => dayTimeMin,
        AeroMetric.pace => _calcPaceKmPerMin(dayDist, dayTimeMin),
      };
    } else {
      series = _aggWeek(
        series: switch (_aeroMetric) {
          AeroMetric.distance => dayDist,
          AeroMetric.time => dayTimeMin,
          AeroMetric.pace => _calcPaceKmPerMin(dayDist, dayTimeMin),
        },
        isPace: _aeroMetric == AeroMetric.pace,
        dayDist: dayDist,
        dayTimeMin: dayTimeMin,
      );
    }

    _aeroAxisDates = _buildContinuousAxis(series.keys, weekly: _displayMode == DisplayMode.week);

    for (int i = 0; i < _aeroAxisDates.length; i++) {
      final ms = _displayMode == DisplayMode.day ? _dayKey(_aeroAxisDates[i]) : _weekKey(_aeroAxisDates[i]);
      final val = series[ms];
      if (val != null) _aeroSpots.add(FlSpot(i.toDouble(), val));
    }

    _recalcAeroAxis();
    _saveGraphPrefs();
    _checkIfFavorite();
    setState(() {});
  }

  Map<int, double> _calcPaceKmPerMin(Map<int, double> distKm, Map<int, double> timeMin) {
    final Map<int, double> out = {};
    final keys = {...distKm.keys, ...timeMin.keys}.toList()..sort();
    for (final k in keys) {
      final d = distKm[k] ?? 0;
      final t = timeMin[k] ?? 0;
      if (d > 0 && t > 0) out[k] = d / t; // km/分
    }
    return out;
  }

  Map<int, double> _aggWeek({
    required Map<int, double> series,
    required bool isPace,
    Map<int, double>? dayDist,
    Map<int, double>? dayTimeMin,
  }) {
    if (!isPace) {
      final Map<int, double> wk = {};
      series.forEach((dayMs, v) {
        final ws = _weekKey(DateTime.fromMillisecondsSinceEpoch(dayMs));
        wk[ws] = (wk[ws] ?? 0) + v;
      });
      return wk;
    } else {
      final Map<int, double> wkD = {};
      final Map<int, double> wkT = {};
      (dayDist ?? {}).forEach((dayMs, v) {
        final ws = _weekKey(DateTime.fromMillisecondsSinceEpoch(dayMs));
        wkD[ws] = (wkD[ws] ?? 0) + v;
      });
      (dayTimeMin ?? {}).forEach((dayMs, v) {
        final ws = _weekKey(DateTime.fromMillisecondsSinceEpoch(dayMs));
        wkT[ws] = (wkT[ws] ?? 0) + v;
      });
      final Map<int, double> wk = {};
      for (final k in {...wkD.keys, ...wkT.keys}) {
        final d = wkD[k] ?? 0;
        final t = wkT[k] ?? 0;
        if (d > 0 && t > 0) wk[k] = d / t; // km/分
      }
      return wk;
    }
  }

  // ----- 連続X軸（欠測日も含む） -----
  List<DateTime> _buildContinuousAxis(Iterable<int> keys, {required bool weekly}) {
    final sorted = keys.toList()..sort();
    if (sorted.isEmpty) return [];
    DateTime start = DateTime.fromMillisecondsSinceEpoch(sorted.first);
    DateTime end = DateTime.fromMillisecondsSinceEpoch(sorted.last);

    if (weekly) {
      start = _weekStart(start);
      end = _weekStart(end);
      final List<DateTime> out = [];
      var cur = start;
      while (!cur.isAfter(end)) {
        out.add(cur);
        cur = cur.add(const Duration(days: 7));
      }
      return out;
    } else {
      final List<DateTime> out = [];
      var cur = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      while (!cur.isAfter(last)) {
        out.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
      return out;
    }
  }

  // ----- 軸計算 -----
  void _recalcLineAxis() {
    if (_spots.isEmpty) {
      _lineAxisMinY = 0;
      _lineAxisMaxY = 1;
      _lineYInterval = 1;
      return;
    }
    final minY = _spots.map((e) => e.y).reduce(min);
    final maxY = _spots.map((e) => e.y).reduce(max);
    final step = _niceStep((maxY - minY).abs().clamp(0.0001, double.infinity));
    _lineYInterval = step;
    _lineAxisMinY = (minY / step).floor() * step;
    _lineAxisMaxY = (maxY / step).ceil() * step;
    if (_lineAxisMaxY <= _lineAxisMinY) _lineAxisMaxY = _lineAxisMinY + step;
  }

  void _recalcAeroAxis() {
    if (_aeroSpots.isEmpty) {
      _aeroAxisMinY = 0;
      _aeroAxisMaxY = 1;
      _aeroYInterval = 1;
      return;
    }
    final minY = _aeroSpots.map((e) => e.y).reduce(min);
    final maxY = _aeroSpots.map((e) => e.y).reduce(max);
    final step = _niceStep((maxY - minY).abs().clamp(0.0001, double.infinity));
    _aeroYInterval = step;
    _aeroAxisMinY = (minY / step).floor() * step;
    _aeroAxisMaxY = (maxY / step).ceil() * step;
    if (_aeroAxisMaxY <= _aeroAxisMinY) _aeroAxisMaxY = _aeroAxisMinY + step;
  }

  // ----- お気に入り -----
  void _checkIfFavorite() {
    if (_selectedMenu == null) {
      _isFavorite = false;
      return;
    }
    final dynamic rawFavorites = widget.settingsBox.get('favorites');
    _isFavorite = rawFavorites is List && rawFavorites.contains(_selectedMenu);
  }

  void _toggleFavorite() {
    if (_selectedMenu == null) return;
    final dynamic rawFavorites = widget.settingsBox.get('favorites');
    List<String> favorites = rawFavorites is List ? rawFavorites.whereType<String>().toList() : [];

    final l10n = AppLocalizations.of(context)!;
    String message;

    if (favorites.contains(_selectedMenu!)) {
      favorites.remove(_selectedMenu!);
      message = l10n.unfavorited(_selectedMenu!); // 多言語対応
    } else {
      favorites.add(_selectedMenu!);
      message = l10n.favorited(_selectedMenu!);   // 多言語対応
    }

    widget.settingsBox.put('favorites', favorites);

    setState(() {
      _isFavorite = favorites.contains(_selectedMenu);
      _loadMenusForPart(_selectedPart!);
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _saveGraphPrefs() {
    widget.settingsBox.put(_prefGraphPart, _selectedPart);
    widget.settingsBox.put(_prefGraphMenu, _selectedMenu);
    widget.settingsBox.put(_prefGraphMode, _displayMode.index);
    widget.settingsBox.put(_prefAeroMetric, _aeroMetric.index);
  }

  bool _menuExistsInAerobic(String name) {
    for (final r in widget.recordsBox.toMap().values.whereType<DailyRecord>()) {
      final list = r.menus['有酸素運動'];
      if (list != null && list.any((m) => m.name == name)) return true;
    }
    return false;
  }

  // Utils（日付キー）
  int _dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  DateTime _weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  int _weekKey(DateTime d) {
    final ws = _weekStart(d);
    return DateTime(ws.year, ws.month, ws.day).millisecondsSinceEpoch;
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final isBodyWeight = _selectedPart == l10n.bodyWeight;
    final isAerobic = _isAerobicSelectedNow();

    final String yUnitForLine = isBodyWeight
        ? SettingsManager.currentUnit
        : (SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs);

    final String yUnitForAero = () {
      final ja = Localizations.localeOf(context).languageCode == 'ja';
      switch (_aeroMetric) {
        case AeroMetric.distance: return ja ? 'km' : 'km';
        case AeroMetric.time:     return ja ? '分' : 'min';
        case AeroMetric.pace:     return ja ? 'km/分' : 'km/min';
      }
    }();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(
            l10n.graphScreenTitle,
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const AdBanner(screenName: 'graph'),
              const SizedBox(height: 16.0),

              // 上段：日/週トグル + 右端：お気に入り
              Row(
                children: [
                  ToggleButtons(
                    isSelected: [_displayMode == DisplayMode.day, _displayMode == DisplayMode.week],
                    onPressed: (index) {
                      setState(() {
                        _displayMode = index == 0 ? DisplayMode.day : DisplayMode.week;
                        _saveGraphPrefs();
                        if (isBodyWeight) {
                          _loadBodyWeightData();
                        } else if (isAerobic) {
                          _loadAerobicData(_selectedMenu);
                        } else if (_selectedMenu != null) {
                          _loadGraphData(_selectedMenu!);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(20.0),
                    selectedColor: colorScheme.onPrimary,
                    fillColor: colorScheme.primary,
                    color: colorScheme.onSurface,
                    borderColor: colorScheme.outlineVariant,
                    selectedBorderColor: colorScheme.primary,
                    splashColor: colorScheme.primary.withOpacity(0.2),
                    children: <Widget>[
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text(l10n.dayDisplay)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text(l10n.weekDisplay)),
                    ],
                  ),
                  const Spacer(),
                  if (!isBodyWeight && _selectedMenu != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary.withOpacity(0.15),
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: _toggleFavorite,
                      child: Row(
                        children: [
                          Text(AppLocalizations.of(context)!.favorites,
                              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text(_isFavorite ? '★' : '☆',
                              style: TextStyle(
                                color: _isFavorite ? Colors.indigo : colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12.0),

              if (isAerobic) _buildAeroMetricToggle(colorScheme),
              if (isAerobic) const SizedBox(height: 8.0),

              // グラフ（左Y軸固定 + 横スクロール）
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final axisCount = (isAerobic ? _aeroAxisDates.length : _lineAxisDates.length);
                    // ★ X軸の間隔を広めに：Day=96px/日、Week=120px/週
                    final perTickWidth = _displayMode == DisplayMode.week ? 120.0 : 96.0;
                    final chartWidth = max(constraints.maxWidth, perTickWidth * max(1, axisCount));

                    final Widget chart = Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: (isAerobic ? _buildAeroLine(colorScheme) : _buildLineChart(colorScheme, isBodyWeight)),
                    );

                    return Stack(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 56), // 固定Y軸スペース
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(width: chartWidth, child: chart),
                              ),
                            ),
                          ],
                        ),
                        // 固定Y軸（単位ラベルは数値より少し上に）
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: true,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 56,
                                child: _FixedYAxis(
                                  minY: isAerobic ? _aeroAxisMinY : _lineAxisMinY,
                                  maxY: isAerobic ? _aeroAxisMaxY : _lineAxisMaxY,
                                  interval: isAerobic ? _aeroYInterval : _lineYInterval,
                                  formatter: (v) => _formatYAxis(
                                    isAerobic ? _aeroAxisMinY : _lineAxisMinY,
                                    isAerobic ? _aeroAxisMaxY : _lineAxisMaxY,
                                    v,
                                  ),
                                  unitLabel: isAerobic ? yUnitForAero : yUnitForLine,
                                  colorScheme: colorScheme,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 12.0),

              // セレクタ
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: l10n.selectTrainingPart,
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
                    ),
                    value: _selectedPart,
                    items: _filteredBodyParts
                        .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold)),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPart = value;
                          _saveGraphPrefs();
                          _loadMenusForPart(value);
                        });
                      }
                    },
                    dropdownColor: colorScheme.surfaceContainer,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  const SizedBox(height: 8.0),
                  if (_selectedPart != l10n.bodyWeight)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: l10n.selectExercise,
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
                      ),
                      value: _selectedMenu,
                      items: _menusForPart
                          .map((menu) => DropdownMenuItem(
                        value: menu,
                        child: Text(menu, style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold)),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMenu = value;
                          _saveGraphPrefs();
                          if (_isAerobicSelectedNow()) {
                            _loadAerobicData(_selectedMenu);
                          } else if (_selectedMenu != null) {
                            _loadGraphData(_selectedMenu!);
                          }
                        });
                      },
                      dropdownColor: colorScheme.surfaceContainer,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
            BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Record'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Graph'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
          currentIndex: 2,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          onTap: (index) {
            if (index == 2) return;
            if (index == 0) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarScreen(
                recordsBox: widget.recordsBox,
                lastUsedMenusBox: widget.lastUsedMenusBox,
                settingsBox: widget.settingsBox,
                setCountBox: widget.setCountBox,
                selectedDate: DateTime.now(),
              )));
            } else if (index == 1) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => RecordScreen(
                selectedDate: DateTime.now(),
                recordsBox: widget.recordsBox,
                lastUsedMenusBox: widget.lastUsedMenusBox,
                settingsBox: widget.settingsBox,
                setCountBox: widget.setCountBox,
              )));
            } else if (index == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(
                recordsBox: widget.recordsBox,
                lastUsedMenusBox: widget.lastUsedMenusBox,
                settingsBox: widget.settingsBox,
                setCountBox: widget.setCountBox,
              )));
            }
          },
        ),
      ),
    );
  }

  // 有酸素メトリクス切替
  Widget _buildAeroMetricToggle(ColorScheme colorScheme) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final labels = ja ? ['距離', '時間', 'ペース'] : ['Distance', 'Time', 'Pace'];
    return ToggleButtons(
      isSelected: [
        _aeroMetric == AeroMetric.distance,
        _aeroMetric == AeroMetric.time,
        _aeroMetric == AeroMetric.pace,
      ],
      onPressed: (i) {
        setState(() {
          _aeroMetric = AeroMetric.values[i];
          _saveGraphPrefs();
          _loadAerobicData(_selectedMenu);
        });
      },
      borderRadius: BorderRadius.circular(20.0),
      selectedColor: colorScheme.onPrimary,
      fillColor: colorScheme.primary,
      color: colorScheme.onSurface,
      borderColor: colorScheme.outlineVariant,
      selectedBorderColor: colorScheme.primary,
      splashColor: colorScheme.primary.withOpacity(0.2),
      children: labels.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text(t))).toList(),
    );
  }

  // 体重/筋トレ 折れ線（X軸は毎日/毎週すべて表示）
  Widget _buildLineChart(ColorScheme colorScheme, bool isBodyWeight) {
    final l10n = AppLocalizations.of(context)!;
    final unit = isBodyWeight
        ? SettingsManager.currentUnit
        : (SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs);

    final nAxis = _lineAxisDates.length;

    return LineChart(
      LineChartData(
        minX: -0.5,
        maxX: max(0, nAxis - 1).toDouble() + 0.5,
        minY: _lineAxisMinY,
        maxY: _lineAxisMaxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= _lineAxisDates.length) return const SizedBox();
                // ★ すべての軸に日付を表示
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _formatAxisDate(_lineAxisDates[i]),
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: false,
            color: colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          // ★ すべての目盛で縦グリッド
          getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.35), strokeWidth: 0.5),
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.5), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: colorScheme.outlineVariant, width: 1)),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => items.map((s) {
              final i = s.x.round().clamp(0, _lineAxisDates.length - 1);
              final dt = _lineAxisDates[i];
              final valueText = '${s.y.toStringAsFixed(1)} $unit';
              return LineTooltipItem(
                '${_formatAxisDate(dt)}\n$valueText',
                TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 有酸素 折れ線（X軸は毎日/毎週すべて表示）
  Widget _buildAeroLine(ColorScheme colorScheme) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final unit = switch (_aeroMetric) {
      AeroMetric.distance => (ja ? 'km' : 'km'),
      AeroMetric.time => (ja ? '分' : 'min'),
      AeroMetric.pace => (ja ? 'km/分' : 'km/min'),
    };

    final nAxis = _aeroAxisDates.length;

    return LineChart(
      LineChartData(
        minX: -0.5,
        maxX: max(0, nAxis - 1).toDouble() + 0.5,
        minY: _aeroAxisMinY,
        maxY: _aeroAxisMaxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= _aeroAxisDates.length) return const SizedBox();
                // ★ すべての軸に表示
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _formatAxisDate(_aeroAxisDates[i]),
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _aeroSpots,
            isCurved: false,
            color: colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.35), strokeWidth: 0.5),
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.5), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: colorScheme.outlineVariant, width: 1)),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => items.map((s) {
              final i = s.x.round().clamp(0, _aeroAxisDates.length - 1);
              final dt = _aeroAxisDates[i];
              final valueText = '${s.y.toStringAsFixed(2)} $unit';
              return LineTooltipItem(
                '${_formatAxisDate(dt)}\n$valueText',
                TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// 固定Y軸（単位ラベルは数値より少し上に）
class _FixedYAxis extends StatelessWidget {
  final double minY;
  final double maxY;
  final double interval;
  final String Function(double) formatter;
  final String unitLabel;
  final ColorScheme colorScheme;

  const _FixedYAxis({
    required this.minY,
    required this.maxY,
    required this.interval,
    required this.formatter,
    required this.unitLabel,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final ticks = <double>[];
    if (interval > 0 && maxY > minY) {
      double v = (minY / interval).ceil() * interval;
      while (v <= maxY + 1e-9) {
        ticks.add(double.parse(v.toStringAsFixed(6)));
        v += interval;
      }
    } else {
      ticks.addAll([minY, maxY]);
    }

    // 単位ラベル分のヘッダー高さを少し大きめに
    const headerH = 24.0;

    return LayoutBuilder(
      builder: (ctx, cons) {
        final usableH = max(0.0, cons.maxHeight - headerH);
        return Stack(
          children: [
            // 単位ラベル（上部・数値より少し高め）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    unitLabel,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            // 右境界線（単位ラベル分下げる）
            Positioned(
              top: headerH,
              bottom: 0,
              right: 0,
              child: Container(width: 1, color: colorScheme.outlineVariant),
            ),
            // 目盛ラベル
            ...ticks.map((t) {
              final frac = (t - minY) / (maxY - minY == 0 ? 1 : (maxY - minY));
              final top = (usableH) - frac * (usableH) + headerH - 8; // -8は視覚補正
              return Positioned(
                left: 4,
                top: top.clamp(headerH, cons.maxHeight - 16),
                child: Text(
                  formatter(t),
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
