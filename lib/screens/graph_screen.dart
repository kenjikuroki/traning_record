// lib/screens/graph_screen.dart
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../settings_manager.dart';
import 'calendar_screen.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import '../widgets/ad_banner.dart';

// ignore_for_file: library_private_types_in_public_api

enum DisplayMode { day, week }

enum AerobicMetric { distance, time, pace }

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
  static const String _prefGraphPart = 'graph_selected_part';
  static const String _prefGraphMenu = 'graph_selected_menu';
  static const String _prefGraphMode = 'graph_display_mode';
  static const String _prefAeroMetric = 'graph_aero_metric';

  List<String> _filteredBodyParts = [];
  String? _selectedPart;
  List<String> _menusForPart = [];
  String? _selectedMenu;
  DisplayMode _displayMode = DisplayMode.day;
  AerobicMetric _aeroMetric = AerobicMetric.distance;
  bool _isFavorite = false;

  // series
  List<FlSpot> _spots = [];
  List<DateTime> _xDates = [];
  double _minY = 0;
  double _maxY = 0;

  /// データのレンジ丸めに使う刻み
  double _yTickStep = 5;

  /// 目盛りラベル＆横線を出す間隔（＝「数字が出る場所」）
  double _yLabelStep = 5;

  // ====== part name mapping ======
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
      case '有酸素運動':
        return l10n.aerobicExercise;
      case '腕':
        return l10n.arm;
      case '胸':
        return l10n.chest;
      case '背中':
        return l10n.back;
      case '肩':
        return l10n.shoulder;
      case '足':
        return l10n.leg;
      case '全身':
        return l10n.fullBody;
      case 'その他１':
        return l10n.other1;
      case 'その他２':
        return l10n.other2;
      case 'その他３':
        return l10n.other3;
      case 'お気に入り':
        return l10n.favorites;
      default:
        return part;
    }
  }

  // ====== lifecycle ======
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  void _loadSettingsAndParts() {
    final l10n = AppLocalizations.of(context)!;

    final int? savedModeIdx = widget.settingsBox.get(_prefGraphMode) as int?;
    if (savedModeIdx != null &&
        savedModeIdx >= 0 &&
        savedModeIdx < DisplayMode.values.length) {
      _displayMode = DisplayMode.values[savedModeIdx];
    }

    final int? savedAeroIdx = widget.settingsBox.get(_prefAeroMetric) as int?;
    if (savedAeroIdx != null &&
        savedAeroIdx >= 0 &&
        savedAeroIdx < AerobicMetric.values.length) {
      _aeroMetric = AerobicMetric.values[savedAeroIdx];
    }

    final allBodyParts = [
      '有酸素運動',
      '腕',
      '胸',
      '背中',
      '肩',
      '足',
      '全身',
      'その他１',
      'その他２',
      'その他３',
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

    _filteredBodyParts = (savedBodyPartsSettings == null ||
        savedBodyPartsSettings.isEmpty)
        ? allBodyParts.map((p) => _translatePartToLocale(context, p)).toList()
        : allBodyParts
        .where((p) => savedBodyPartsSettings![p] == true)
        .map((p) => _translatePartToLocale(context, p))
        .toList();

    // ①の並び替えは既に反映済み：お気に入り → 体重
    _filteredBodyParts = [
      l10n.favorites,
      l10n.bodyWeight,
      ..._filteredBodyParts
    ];

    final String? savedPart = widget.settingsBox.get(_prefGraphPart) as String?;
    if (savedPart != null && _filteredBodyParts.contains(savedPart)) {
      _selectedPart = savedPart;
    } else {
      _selectedPart = null; // ★ ここを「最初の要素」ではなく null にする（②の核心）
    }

    if (mounted) {
      setState(() {
        if (_selectedPart != null) {
          _loadMenusForPart(_selectedPart!);
        }
      });
    }
  }


  // ====== load menus ======
  void _loadMenusForPart(String translatedPart) {
    final l10n = AppLocalizations.of(context)!;

    if (translatedPart == l10n.bodyWeight) {
      _menusForPart = [];
      _selectedMenu = null;
      // _isFavorite = false; // ←削除
      _loadBodyWeightData();
      _checkIfFavorite(); // ←追加：ここでお気に入り状態を反映
      _saveGraphPrefs();
      setState(() {});
      return;
    }

    // ...（以下は既存の処理）


    _menusForPart.clear();

    if (translatedPart == l10n.favorites) {
      final dynamic rawFavorites = widget.settingsBox.get('favorites');
      if (rawFavorites is List) {
        _menusForPart = rawFavorites.whereType<String>().toList();
      }
    } else {
      final originalPartName = _getOriginalPartName(context, translatedPart);
      final dynamic rawList = widget.lastUsedMenusBox.get(originalPartName);
      if (rawList is List) {
        final List<MenuData> lastUsedMenus =
            rawList.whereType<MenuData>().toList();
        _menusForPart = lastUsedMenus.map((m) => m.name).toList();
      }
    }

    final String? savedMenu = widget.settingsBox.get(_prefGraphMenu) as String?;
    if (savedMenu != null && _menusForPart.contains(savedMenu)) {
      _selectedMenu = savedMenu;
    } else {
      _selectedMenu = _menusForPart.isNotEmpty ? _menusForPart.first : null;
    }

    if (mounted) {
      setState(() {
        if (_selectedMenu == null) {
          // 実績なし：即クリア
          _spots = [];
          _xDates = [];
          _minY = 0;
          _maxY = 0;
          _checkIfFavorite();  // ←追加：☆/★の見た目を必ず更新
          _saveGraphPrefs();   // ←追加：状態保存もここで
        } else {
          _refreshDataForSelection(); // 中で _checkIfFavorite() 実行
        }
      });
    }
  }


  // ====== choose loader ======
  void _refreshDataForSelection() {
    final l10n = AppLocalizations.of(context)!;
    // ★ お気に入りタブで「体重」を選んだケースも体重扱いにする
    final isBody = (_selectedPart == l10n.bodyWeight) || (_selectedMenu == l10n.bodyWeight);
    final isAero = _isAerobicContext();

    if (isBody) {
      _loadBodyWeightData();
    } else if (isAero) {
      if (_selectedMenu != null) _loadAerobicData(_selectedMenu!);
    } else {
      if (_selectedMenu != null) _loadStrengthData(_selectedMenu!);
    }
    _checkIfFavorite();
    _saveGraphPrefs();
  }


  bool _menuIsAerobic(String? menuName) {
    if (menuName == null) return false;
    final raw = widget.lastUsedMenusBox.get('有酸素運動');
    if (raw is List) {
      for (final e in raw) {
        if (e is MenuData && e.name == menuName) return true;
      }
    }
    for (final r in widget.recordsBox.values.whereType<DailyRecord>()) {
      final list = r.menus['有酸素運動'];
      if (list != null && list.any((m) => m.name == menuName)) return true;
    }
    return false;
  }

  bool _isAerobicContext() {
    final l10n = AppLocalizations.of(context)!;
    return _selectedPart == l10n.aerobicExercise ||
        (_selectedPart == l10n.favorites && _menuIsAerobic(_selectedMenu));
  }

  // ====== parse helpers ======
  double? _parseDistanceKm(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final parts = s.split('.');
    final km = int.tryParse(parts[0]) ?? 0;
    final m = (parts.length > 1) ? int.tryParse(parts[1]) ?? 0 : 0;
    return km + m / 1000.0;
  }

  double? _parseDurationMin(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return double.tryParse(s);
    final mm = int.tryParse(parts[0]) ?? 0;
    final ss = int.tryParse(parts[1]) ?? 0;
    return mm + ss / 60.0;
  }

  String _formatMinToMMSS(double minutes) {
    final totalSec = (minutes * 60).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  // ====== body weight ======
  void _loadBodyWeightData() {
    final records = widget.recordsBox.toMap().values.whereType<DailyRecord>();

    final Map<DateTime, double> map = {};
    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        if (r.weight != null) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          map[d] = r.weight!;
        }
      }
    } else {
      final Map<DateTime, List<double>> weekly = {};
      for (final r in records) {
        if (r.weight != null) {
          final day = DateTime(r.date.year, r.date.month, r.date.day);
          final weekStart = day.subtract(Duration(days: day.weekday - 1));
          final key = DateTime(weekStart.year, weekStart.month, weekStart.day);
          weekly.putIfAbsent(key, () => []).add(r.weight!);
        }
      }
      weekly.forEach((k, list) {
        if (list.isNotEmpty) {
          map[k] = list.reduce((a, b) => a + b) / list.length;
        }
      });
    }

    // データ丸めは 0.5kg / 1lbs、ラベル＆横線は見やすさ優先で 5 間隔
    _yTickStep = (SettingsManager.currentUnit == 'kg') ? 0.5 : 1.0;
    _yLabelStep = _yTickStep;

    _buildSeriesFromMap(map, tickStep: _yTickStep);
    setState(() {});
  }

  // ====== strength ======
  void _loadStrengthData(String menuName) {
    final List<String> allPartsOriginal = [
      '有酸素運動',
      '腕',
      '胸',
      '背中',
      '肩',
      '足',
      '全身',
      'その他１',
      'その他２',
      'その他３',
    ];

    final Iterable<DailyRecord> records =
        widget.recordsBox.toMap().values.whereType<DailyRecord>();

    final Map<DateTime, double> map = {};

    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        double maxW = 0;
        for (final part in allPartsOriginal) {
          final list = r.menus[part];
          if (list == null) continue;
          final m = list.firstWhereOrNull((x) => x.name == menuName);
          if (m == null) continue;
          for (int i = 0; i < min(m.weights.length, m.reps.length); i++) {
            final w = double.tryParse(m.weights[i]) ?? 0;
            final reps = int.tryParse(m.reps[i]) ?? 0;
            if (reps >= 1) maxW = max(maxW, w);
          }
        }
        if (maxW > 0) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          map[d] = maxW;
        }
      }
    } else {
      final Map<DateTime, double> weeklyMax = {};
      for (final r in records) {
        double maxW = 0;
        for (final part in allPartsOriginal) {
          final list = r.menus[part];
          if (list == null) continue;
          final m = list.firstWhereOrNull((x) => x.name == menuName);
          if (m == null) continue;
          for (int i = 0; i < min(m.weights.length, m.reps.length); i++) {
            final w = double.tryParse(m.weights[i]) ?? 0;
            final reps = int.tryParse(m.reps[i]) ?? 0;
            if (reps >= 1) maxW = max(maxW, w);
          }
        }
        if (maxW > 0) {
          final day = DateTime(r.date.year, r.date.month, r.date.day);
          final weekStart = day.subtract(Duration(days: day.weekday - 1));
          final key = DateTime(weekStart.year, weekStart.month, weekStart.day);
          weeklyMax.update(key, (old) => max(old, maxW), ifAbsent: () => maxW);
        }
      }
      map.addAll(weeklyMax);
    }

    _yTickStep = 5.0;
    _yLabelStep = 5.0;

    _buildSeriesFromMap(map, tickStep: _yTickStep);
    setState(() {});
  }

  // ====== aerobic ======
  void _loadAerobicData(String menuName) {
    final Iterable<DailyRecord> records =
        widget.recordsBox.toMap().values.whereType<DailyRecord>();

    final Map<DateTime, double> map = {};

    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        final list = r.menus['有酸素運動'];
        if (list == null) continue;
        final m = list.firstWhereOrNull((x) => x.name == menuName);
        if (m == null) continue;

        final km = _parseDistanceKm(m.distance) ?? 0;
        final min = _parseDurationMin(m.duration) ?? 0;

        double? value;
        switch (_aeroMetric) {
          case AerobicMetric.distance:
            value = km > 0 ? km : null;
            break;
          case AerobicMetric.time:
            value = min > 0 ? min : null;
            break;
          case AerobicMetric.pace:
            if (km > 0 && min > 0) value = min / km;
            break;
        }
        if (value != null) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          map[d] = value;
        }
      }
    } else {
      final Map<DateTime, List<double>> weeklyList = {};
      for (final r in records) {
        final list = r.menus['有酸素運動'];
        if (list == null) continue;
        final m = list.firstWhereOrNull((x) => x.name == menuName);
        if (m == null) continue;

        final km = _parseDistanceKm(m.distance) ?? 0;
        final min = _parseDurationMin(m.duration) ?? 0;

        final day = DateTime(r.date.year, r.date.month, r.date.day);
        final weekStart = day.subtract(Duration(days: day.weekday - 1));
        final key = DateTime(weekStart.year, weekStart.month, weekStart.day);

        switch (_aeroMetric) {
          case AerobicMetric.distance:
            weeklyList.putIfAbsent(key, () => []).add(km);
            break;
          case AerobicMetric.time:
            weeklyList.putIfAbsent(key, () => []).add(min);
            break;
          case AerobicMetric.pace:
            if (km > 0 && min > 0) {
              weeklyList.putIfAbsent(key, () => []).add(min / km);
            }
            break;
        }
      }

      weeklyList.forEach((k, list) {
        if (list.isEmpty) return;
        double value;
        switch (_aeroMetric) {
          case AerobicMetric.distance:
          case AerobicMetric.time:
            value = list.reduce((a, b) => a + b);
            break;
          case AerobicMetric.pace:
            value = list.reduce(min);
            break;
        }
        map[k] = value;
      });
    }

    switch (_aeroMetric) {
      case AerobicMetric.distance:
        _yTickStep = 1.0;
        _yLabelStep = 1.0;
        break;
      case AerobicMetric.time:
        _yTickStep = 10.0;
        _yLabelStep = 10.0;
        break;
      case AerobicMetric.pace:
        _yTickStep = 0.5;
        _yLabelStep = 0.5;
        break;
    }

    _buildSeriesFromMap(map, tickStep: _yTickStep);
    setState(() {});
  }

  // ====== build series & axis ======
  void _buildSeriesFromMap(Map<DateTime, double> map, {required double tickStep}) {
    _spots = [];
    _xDates = [];
    _minY = 0;
    _maxY = 0;
    if (map.isEmpty) return;

    final sortedDates = map.keys.toList()..sort();

    // full x (day/weekly)
    final List<DateTime> full = [];
    DateTime cursor = sortedDates.first;
    final DateTime last = sortedDates.last;

    if (_displayMode == DisplayMode.day) {
      while (!cursor.isAfter(last)) {
        full.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    } else {
      while (!cursor.isAfter(last)) {
        final wkStart = cursor.subtract(Duration(days: cursor.weekday - 1));
        if (full.isEmpty || full.last != wkStart) full.add(wkStart);
        cursor = cursor.add(const Duration(days: 7));
      }
    }

    _xDates = full;
    final indexByDate = <DateTime, int>{};
    for (int i = 0; i < full.length; i++) {
      indexByDate[full[i]] = i;
    }

    for (final d in sortedDates) {
      final idx = indexByDate[_displayMode == DisplayMode.day
          ? d
          : d.subtract(Duration(days: d.weekday - 1))]!;
      final y = map[d]!;
      _spots.add(FlSpot(idx.toDouble(), y));
      _minY = (_spots.length == 1) ? y : min(_minY, y);
      _maxY = (_spots.length == 1) ? y : max(_maxY, y);
    }

    double floorTo(double v, double step) => (v / step).floorToDouble() * step;
    double ceilTo(double v, double step) => (v / step).ceilToDouble() * step;

    final l10n = AppLocalizations.of(context)!;
    // ★ メニュー=体重 も体重扱い
    final isBody = (_selectedPart == l10n.bodyWeight) || (_selectedMenu == l10n.bodyWeight);

    double minNice = floorTo(_minY, tickStep) - tickStep;
    double maxNice = ceilTo(_maxY, tickStep) + tickStep;

    // 体重はさらに上下 1 ステップずつ余白追加
    if (isBody) {
      minNice -= tickStep;
      maxNice += tickStep;
    }

    if ((maxNice - minNice).abs() < 1e-6) {
      minNice -= tickStep;
      maxNice += tickStep;
    }

    if (SettingsManager.currentUnit == 'kg' && (isBody || !_isAerobicContext())) {
      minNice = max(0.0, minNice);
    }

    _minY = minNice;
    _maxY = maxNice;
  }

  // ====== tick helpers ======
  bool _isLabelTick(double v) {
    final ratio = v / _yLabelStep;
    return (ratio - ratio.round()).abs() < 1e-6;
  }

  // ====== favorites ======
  void _checkIfFavorite() {
    final l10n = AppLocalizations.of(context)!;

    // 体重のときは体重名で判定
    final String? key =
    (_selectedPart == l10n.bodyWeight || _selectedMenu == l10n.bodyWeight)
        ? l10n.bodyWeight
        : _selectedMenu; // 通常はメニュー名

    if (key == null) {
      _isFavorite = false;
      return;
    }
    final rawFavorites = widget.settingsBox.get('favorites');
    final favs = (rawFavorites is List)
        ? rawFavorites.whereType<String>().toList()
        : <String>[];

    _isFavorite = favs.contains(key);
  }


  void _toggleFavorite() {
    final l10n = AppLocalizations.of(context)!;

    // 体重なら体重名、それ以外はメニュー名
    final String? key =
    (_selectedPart == l10n.bodyWeight || _selectedMenu == l10n.bodyWeight)
        ? l10n.bodyWeight
        : _selectedMenu;

    if (key == null) return;

    final rawFavorites = widget.settingsBox.get('favorites');
    final favorites = (rawFavorites is List)
        ? rawFavorites.whereType<String>().toList()
        : <String>[];

    final willAdd = !favorites.contains(key);
    if (willAdd) {
      favorites.add(key);
    } else {
      favorites.remove(key);
    }
    widget.settingsBox.put('favorites', favorites);

    setState(() {
      _isFavorite = willAdd;
      // お気に入りタブ表示中はリストを更新
      if (_selectedPart == l10n.favorites) {
        _loadMenusForPart(_selectedPart!);
      }
    });

    final msg = willAdd ? l10n.favorited(key) : l10n.unfavorited(key);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  void _saveGraphPrefs() {
    widget.settingsBox.put(_prefGraphPart, _selectedPart);
    widget.settingsBox.put(_prefGraphMenu, _selectedMenu);
    widget.settingsBox.put(_prefGraphMode, _displayMode.index);
    widget.settingsBox.put(_prefAeroMetric, _aeroMetric.index);
  }

  // ====== labels ======
  String _weekSuffix() {
    final lang = Localizations.localeOf(context).languageCode;
    return (lang == 'ja') ? '週' : 'wk';
  }

  String _formatDayLabel(DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('M/d', locale).format(d);
  }

  String _formatWeekLabel(DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return '${DateFormat('M/d', locale).format(d)}${_weekSuffix()}';
  }

  // X axis: すべての目盛りにラベル／縦線は整数インデックスのみ
  Widget _bottomTitle(double value, TitleMeta meta) {
    if (_xDates.isEmpty) return const SizedBox.shrink();
    if ((value - value.round()).abs() > 1e-6) return const SizedBox.shrink();
    final idx = value.round();
    if (idx < 0 || idx >= _xDates.length) return const SizedBox.shrink();

    final text = (_displayMode == DisplayMode.day)
        ? _formatDayLabel(_xDates[idx])
        : _formatWeekLabel(_xDates[idx]);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 6,
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }

  // Y axis: 上下端は非表示（ダブり防止）、ラベルは _yLabelStep 間隔
  Widget _leftTitle(double value, TitleMeta meta) {
    if (!_isLabelTick(value)) return const SizedBox.shrink();

    const eps = 0.01;
    final isMin = (value - _minY).abs() <= eps;
    final isMax = (value - _maxY).abs() <= eps;
    if (isMin || isMax) return const SizedBox.shrink();

    final isInteger = (_yLabelStep % 1 == 0);
    final label =
        isInteger ? value.round().toString() : value.toStringAsFixed(1);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 0,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }

  // unit overlay text
  String _unitOverlayText(AppLocalizations l10n) {
    // ★ メニュー=体重 も体重扱い
    final bool isBody = (_selectedPart == l10n.bodyWeight) || (_selectedMenu == l10n.bodyWeight);
    final bool hasMenu = _selectedMenu != null;
    if (!isBody && !hasMenu) return ''; // 種目なし → 非表示

    if (_isAerobicContext()) {
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          return l10n.km;
        case AerobicMetric.time:
          return l10n.min;
        case AerobicMetric.pace:
          return '${l10n.min}/${l10n.km}';
      }
    }
    return SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
  }


  // tooltip value
  String _formatTooltipValue(double y, AppLocalizations l10n) {
    if (_isAerobicContext()) {
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          return '${y.toStringAsFixed(2)} ${l10n.km}';
        case AerobicMetric.time:
          return '${_formatMinToMMSS(y)} ${l10n.min}';
        case AerobicMetric.pace:
          return '${_formatMinToMMSS(y)} ${l10n.min}/${l10n.km}';
      }
    }
    final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
    return '${y.toStringAsFixed(1)} $u';
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isAerobic = _isAerobicContext();

    final unitText = _unitOverlayText(l10n);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(
            l10n.graphScreenTitle,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
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
              Row(
                children: [
                  ToggleButtons(
                    isSelected: [
                      _displayMode == DisplayMode.day,
                      _displayMode == DisplayMode.week
                    ],
                    onPressed: (index) {
                      setState(() {
                        _displayMode =
                            index == 0 ? DisplayMode.day : DisplayMode.week;
                        _saveGraphPrefs();
                        _refreshDataForSelection();
                      });
                    },
                    borderRadius: BorderRadius.circular(20.0),
                    selectedColor: colorScheme.onPrimary,
                    fillColor: colorScheme.primary,
                    color: colorScheme.onSurface,
                    borderColor: colorScheme.outlineVariant,
                    selectedBorderColor: colorScheme.primary,
                    splashColor: colorScheme.primary.withValues(alpha: 0.2),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(l10n.dayDisplay),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(l10n.weekDisplay),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_selectedPart != l10n.favorites)
                    FavoritePillButton(
                      isFavorite: _isFavorite,
                      label: l10n.favorites,
                      onTap: _toggleFavorite,
                  ),
                ],
              ),
              if (isAerobic) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ToggleButtons(
                    isSelected: [
                      _aeroMetric == AerobicMetric.distance,
                      _aeroMetric == AerobicMetric.time,
                      _aeroMetric == AerobicMetric.pace,
                    ],
                    onPressed: (i) {
                      setState(() {
                        _aeroMetric = AerobicMetric.values[i];
                        _saveGraphPrefs();
                        if (_selectedMenu != null) {
                          _loadAerobicData(_selectedMenu!);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    selectedColor: colorScheme.onPrimary,
                    fillColor: colorScheme.primary,
                    color: colorScheme.onSurface,
                    borderColor: colorScheme.outlineVariant,
                    selectedBorderColor: colorScheme.primary,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.distance),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.time),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.pace),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12.0),
              Expanded(
                child: Card(
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalW = constraints.maxWidth;
                        final totalH = constraints.maxHeight;

                        final yAxisPanelW =
                            _xDates.isEmpty ? 0.0 : 40.0; // 余白減＆データ無しは0幅
                        final plotAvailW = max(60.0, totalW - yAxisPanelW - 4);
                        const stride = 70.0;
                        final points = max(1, _xDates.length);
                        final chartW = max(plotAvailW, points * stride);

                        // 単位は「空文字」または「データなし(_xDates.isEmpty)」なら非表示
                        final unitOverlay =
                            (unitText.isEmpty || _xDates.isEmpty)
                                ? const SizedBox.shrink()
                                : Positioned(
                                    left: 2,
                                    top: 6,
                                    child: Text(
                                      unitText,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );

                        // Left Y axis (fixed)
                        final yAxisChart = SizedBox(
                          width: yAxisPanelW,
                          height: totalH,
                          child: _xDates.isEmpty
                              ? const SizedBox.shrink()
                              : LineChart(
                                  LineChartData(
                                    minX: 0,
                                    maxX: 1,
                                    minY: _minY,
                                    maxY: _maxY,
                                    lineBarsData: const [],
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 36,
                                          interval: _yLabelStep,
                                          getTitlesWidget: _leftTitle,
                                        ),
                                      ),
                                      bottomTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      horizontalInterval: _yLabelStep,
                                      checkToShowHorizontalLine: (v) =>
                                          _isLabelTick(v),
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (v) => FlLine(
                                        color: colorScheme.outlineVariant,
                                        strokeWidth: 0.5,
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border(
                                        left: BorderSide(
                                            color: colorScheme.outlineVariant),
                                        bottom: BorderSide(
                                            color: colorScheme.outlineVariant),
                                      ),
                                    ),
                                  ),
                                ),
                        );

                        // Right (scrollable plot)
                        final scrollChart = Expanded(
                          child: _xDates.isEmpty
                              ? Center(
                                  child: Text(
                                    AppLocalizations.of(context)!.noGraphData,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: SizedBox(
                                    width: chartW,
                                    height: totalH,
                                    child: LineChart(
                                      LineChartData(
                                        minX: 0,
                                        maxX: (_xDates.length - 1).toDouble(),
                                        minY: _minY,
                                        maxY: _maxY,
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: _spots,
                                            isCurved: false,
                                            color: colorScheme.primary,
                                            barWidth: 3,
                                            dotData:
                                                const FlDotData(show: true),
                                            belowBarData:
                                                BarAreaData(show: false),
                                          ),
                                        ],
                                        titlesData: FlTitlesData(
                                          leftTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              interval: 1, // すべてのメモリ
                                              reservedSize: 22,
                                              getTitlesWidget: _bottomTitle,
                                            ),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                        ),
                                        gridData: FlGridData(
                                          show: true,
                                          horizontalInterval: _yLabelStep,
                                          checkToShowHorizontalLine: (v) =>
                                              _isLabelTick(v),
                                          drawVerticalLine: true,
                                          verticalInterval: 1, // すべてのメモリ
                                          checkToShowVerticalLine: (v) =>
                                              (v - v.round()).abs() < 1e-6,
                                          getDrawingHorizontalLine: (v) =>
                                              FlLine(
                                            color: colorScheme.outlineVariant,
                                            strokeWidth: 0.5,
                                          ),
                                          getDrawingVerticalLine: (v) => FlLine(
                                            color: colorScheme.outlineVariant,
                                            strokeWidth: 0.5,
                                          ),
                                        ),
                                        borderData: FlBorderData(
                                          show: true,
                                          border: Border(
                                            bottom: BorderSide(
                                                color:
                                                    colorScheme.outlineVariant),
                                            right: BorderSide(
                                                color:
                                                    colorScheme.outlineVariant),
                                          ),
                                        ),
                                        lineTouchData: LineTouchData(
                                          touchTooltipData:
                                              LineTouchTooltipData(
                                            getTooltipItems: (items) {
                                              final loc =
                                                  Localizations.localeOf(
                                                          context)
                                                      .toString();
                                              return items.map((s) {
                                                final i = s.x.toInt();
                                                final d = (i >= 0 &&
                                                        i < _xDates.length)
                                                    ? _xDates[i]
                                                    : null;
                                                final dateStr = (_displayMode ==
                                                        DisplayMode.day)
                                                    ? (d != null
                                                        ? DateFormat('M/d', loc)
                                                            .format(d)
                                                        : '')
                                                    : (d != null
                                                        ? _formatWeekLabel(d)
                                                        : '');
                                                final valStr =
                                                    _formatTooltipValue(
                                                        s.y, l10n);
                                                return LineTooltipItem(
                                                  '$dateStr\n$valStr',
                                                  TextStyle(
                                                    color: colorScheme
                                                        .onPrimaryContainer,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                );
                                              }).toList();
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        );

                        return Stack(
                          children: [
                            SizedBox(
                              width: totalW,
                              height: totalH,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  yAxisChart,
                                  const SizedBox(width: 2),
                                  scrollChart,
                                ],
                              ),
                            ),
                            unitOverlay,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: l10n.selectTrainingPart,
                      hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    initialValue: _selectedPart,
                    items: _filteredBodyParts
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPart = value;
                          _saveGraphPrefs();
                          _loadMenusForPart(value); // メニュー決定 → 内部で再計算される
                          _checkIfFavorite();       // ←任意追加（より堅牢に）
                        });
                      }
                    },

                    dropdownColor: colorScheme.surfaceContainer,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  const SizedBox(height: 8.0),
                  if (_selectedPart != l10n.bodyWeight)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: l10n.selectExercise,
                        hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14.0),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      initialValue: _selectedMenu,
                      items: _menusForPart
                          .map(
                            (menu) => DropdownMenuItem(
                              value: menu,
                              child: Text(
                                menu,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMenu = value;
                            _saveGraphPrefs();
                            _refreshDataForSelection(); // データ読み込み
                            _checkIfFavorite();         // ←任意追加（より堅牢に）
                          });
                        } else {
                          setState(() {
                            _spots = [];
                            _xDates = [];
                            _minY = 0;
                            _maxY = 0;
                            _checkIfFavorite(); // ←追加：null時は必ず☆へ
                          });
                        }
                      },
                      dropdownColor: colorScheme.surfaceContainer,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: 'Record',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Graph',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: 2,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          onTap: (index) {
            if (index == 2) return;
            if (index == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    selectedDate: DateTime.now(),
                  ),
                ),
              );
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordScreen(
                    selectedDate: DateTime.now(),
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class FavoritePillButton extends StatelessWidget {
  final bool isFavorite;
  final String label;
  final VoidCallback onTap;

  const FavoritePillButton({
    super.key,
    required this.isFavorite,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = isFavorite ? '$label★' : '$label✩';

    return Material(
      color: cs.surfaceContainerHighest,
      shape: const StadiumBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isFavorite ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
