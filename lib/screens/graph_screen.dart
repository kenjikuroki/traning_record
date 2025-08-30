// lib/screens/graph_screen.dart
import 'dart:ui';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import 'calendar_screen.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import '../widgets/ad_banner.dart';
import '../widgets/coach_bubble.dart';
import 'package:flutter/services.dart';

// ignore_for_file: library_private_types_in_public_api

enum DisplayMode { day, week }
enum AerobicMetric { distance, time, pace }

class GraphScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;
  final bool isActive;

  const GraphScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.isActive,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  // 吹き出しアンカー
  final GlobalKey _kFav = GlobalKey();
  final GlobalKey _kChart = GlobalKey();
  final GlobalKey _kPart = GlobalKey();

  // 設定キー
  static const String _prefGraphPart = 'graph_selected_part';
  static const String _prefGraphMenu = 'graph_selected_menu';
  static const String _prefGraphMode = 'graph_display_mode';
  static const String _prefAeroMetric = 'graph_aero_metric';

  // UI寸法
  static const double _kControlHeight = 40.0;
  static const double _kControlRadius = 20.0;
  static const double _kPickerHeight = 48.0;

  // X1点あたり幅
  static const double _kXStridePx = 48.0;

  // Y目盛の“見た目”間隔：固定 24px（初期余白も 24px）
  static const double _kYTickPx = 24.0;
  static const double _kYAxisWidth = 48.0;

  // X軸ラベル領域の高さ（左右で統一）
  static const double _kXAxisReservedPx = 24.0;

  // Y軸スクロール開始を早める上下の“空き目盛”数
  static const int _kYPadStepsTop = 2;
  static const int _kYPadStepsBottom = 2;

  // X の右余白スクロール
  static const int _kPadTailDays = 7;
  static const int _kPadTailWeeks = 4;

  // プロット領域高さ（レイアウト時に更新）
  double _plotHeightPx = 1.0;

  // 選択状態
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

  // 固定刻み（文脈で決める：間引きしない／常に固定）
  double _yLabelStep = 5;

  // 表示レンジ（ズーム無し＝常にベース）
  double _baseMinY = 0;
  double _baseMaxY = 0;

  // 目標ライン
  final TextEditingController _goalController = TextEditingController();
  double? _goalValue;

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

  // ====== Graphヒント ======
  bool _graphCoachDone = false;

  bool _isActuallyVisible() {
    if (!mounted || !widget.isActive) return false;
    final ticker = context.findAncestorWidgetOfExactType<TickerMode>();
    if (ticker != null && ticker.enabled == false) return false;
    final ro = context.findRenderObject();
    if (ro is RenderBox) {
      if (!ro.attached) return false;
      final size = ro.hasSize ? ro.size : Size.zero;
      if (size.isEmpty) return false;
    }
    return true;
  }

  Future<void> _tryShowGraphCoachIfVisible() async {
    if (!mounted || _graphCoachDone) return;
    final seen = (widget.settingsBox.get('hint_seen_graph') as bool?) ?? false;
    if (seen) {
      _graphCoachDone = true;
      return;
    }
    if (!_isActuallyVisible()) return;

    final anchorsReady = [
      _kPart.currentContext,
      _kChart.currentContext,
      _kFav.currentContext,
    ].every((c) => c != null);
    if (!anchorsReady) return;

    final l10n = AppLocalizations.of(context)!;
    await CoachBubbleController.showSequence(
      context: context,
      anchors: [_kPart, _kChart, _kFav],
      messages: [
        l10n.hintGraphSelectPart,
        l10n.hintGraphChartArea,
        l10n.hintGraphFavorite,
      ],
      semanticsPrefix: l10n.coachBubbleSemantic,
    );
    await widget.settingsBox.put('hint_seen_graph', true);
    _graphCoachDone = true;
  }

  // ====== lifecycle ======
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  @override
  void didUpdateWidget(covariant GraphScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryShowGraphCoachIfVisible();
      });
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
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

    _filteredBodyParts =
    (savedBodyPartsSettings == null || savedBodyPartsSettings.isEmpty)
        ? allBodyParts
        .map<String>((p) => _translatePartToLocale(context, p))
        .toList()
        : allBodyParts
        .where((p) => savedBodyPartsSettings![p] == true)
        .map<String>((p) => _translatePartToLocale(context, p))
        .toList();

    // 先頭に「お気に入り」「体重」
    _filteredBodyParts =
    [l10n.favorites, l10n.bodyWeight, ..._filteredBodyParts];

    final String? savedPart = widget.settingsBox.get(_prefGraphPart) as String?;
    _selectedPart =
    (savedPart != null && _filteredBodyParts.contains(savedPart))
        ? savedPart
        : null;

    if (mounted) {
      setState(() {
        if (_selectedPart != null) _loadMenusForPart(_selectedPart!);
      });
    }
  }

  // ====== load menus ======
  void _loadMenusForPart(String translatedPart) {
    final l10n = AppLocalizations.of(context)!;

    if (translatedPart == l10n.bodyWeight) {
      _menusForPart = [];
      _selectedMenu = null;
      _loadBodyWeightData();
      _checkIfFavorite();
      _saveGraphPrefs();
      _loadGoalForCurrentContext();
      setState(() {});
      return;
    }

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
          _spots = [];
          _xDates = [];
          _minY = 0;
          _maxY = 0;
          _checkIfFavorite();
          _saveGraphPrefs();
          _loadGoalForCurrentContext();
        } else {
          _refreshDataForSelection();
        }
      });
    }
  }

  Future<void> _closeKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  // ====== choose loader ======
  void _refreshDataForSelection() {
    final l10n = AppLocalizations.of(context)!;
    final isBody =
        (_selectedPart == l10n.bodyWeight) || (_selectedMenu == l10n.bodyWeight);
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
    _loadGoalForCurrentContext();
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

  bool _isBodyWeightContext() {
    final l10n = AppLocalizations.of(context)!;
    return _selectedPart == l10n.bodyWeight || _selectedMenu == l10n.bodyWeight;
  }

  bool _isStrengthContext() {
    return !_isAerobicContext() && !_isBodyWeightContext() && _selectedMenu != null;
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
    if (parts.length == 2) {
      final mm = int.tryParse(parts[0]) ?? 0;
      final ss = int.tryParse(parts[1]) ?? 0;
      return mm + ss / 60.0;
    }
    return double.tryParse(s);
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
        if (list.isNotEmpty) map[k] = list.reduce((a, b) => a + b) / list.length;
      });
    }
    _buildSeriesFromMap(map);
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

    _buildSeriesFromMap(map);
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
        final minVal = _parseDurationMin(m.duration) ?? 0;

        double? value;
        switch (_aeroMetric) {
          case AerobicMetric.distance:
            value = km > 0 ? km : null;
            break;
          case AerobicMetric.time:
            value = minVal > 0 ? minVal : null;
            break;
          case AerobicMetric.pace:
            if (km > 0 && minVal > 0) value = minVal / km;
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
        final minVal = _parseDurationMin(m.duration) ?? 0;

        final day = DateTime(r.date.year, r.date.month, r.date.day);
        final weekStart = day.subtract(Duration(days: day.weekday - 1));
        final key = DateTime(weekStart.year, weekStart.month, weekStart.day);

        switch (_aeroMetric) {
          case AerobicMetric.distance:
            weeklyList.putIfAbsent(key, () => []).add(km);
            break;
          case AerobicMetric.time:
            weeklyList.putIfAbsent(key, () => []).add(minVal);
            break;
          case AerobicMetric.pace:
            if (km > 0 && minVal > 0) weeklyList.putIfAbsent(key, () => []).add(minVal / km);
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

    _buildSeriesFromMap(map);
    setState(() {});
  }

  // ====== tick helpers ======
  // ラベルとグリッドの起点を「実際にチャートへ渡している minY」にそろえる
  double get _tickStart {
    final step = _yLabelStep;
    final minY = _baseMinY; // ← 今の実装では両チャートとも minY=_baseMinY を渡しているのでこれでOK
    return (minY / step).floorToDouble() * step;
  }

  bool _isLabelTick(double v) {
    final step = _yLabelStep;
    final ratio = (v - _tickStart) / step;
    return (ratio - ratio.round()).abs() < 1e-6;
  }

  // ====== build series & axis ======
  void _buildSeriesFromMap(Map<DateTime, double> map) {
    _spots = [];
    _xDates = [];
    _minY = 0;
    _maxY = 0;
    if (map.isEmpty) {
      _baseMinY = 0;
      _baseMaxY = 0;
      return;
    }

    final sortedDates = map.keys.toList()..sort();

    // full x
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

    // 固定刻み（間引き無し）
    if (_isStrengthContext()) {
      _yLabelStep = (SettingsManager.currentUnit == 'kg') ? 5.0 : 11.0;
    } else if (_isBodyWeightContext()) {
      _yLabelStep = (SettingsManager.currentUnit == 'kg') ? 0.5 : 1.0;
    } else {
      // 有酸素（例の固定値）
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          _yLabelStep = 1.0; // 1km
          break;
        case AerobicMetric.time:
          _yLabelStep = 10.0; // 10分
          break;
        case AerobicMetric.pace:
          _yLabelStep = 0.5; // 0.5 分/ km (=30秒)
          break;
      }
    }

    double floorTo(double v, double step) => (v / step).floorToDouble() * step;
    double ceilTo(double v, double step) => (v / step).ceilToDouble() * step;

    // データにフィットさせたベースを作る
    _baseMinY = floorTo(_minY, _yLabelStep);
    _baseMaxY = ceilTo(_maxY, _yLabelStep);

    // 上下に“空き目盛”を加えて、Y方向にもスクロール余裕を作る（定数を使用）
    _baseMinY = floorTo(_baseMinY - _kYPadStepsBottom * _yLabelStep, _yLabelStep);
    _baseMaxY = ceilTo (_baseMaxY + _kYPadStepsTop    * _yLabelStep, _yLabelStep);

    // 有酸素は負値なし
    if (_isAerobicContext()) _baseMinY = max(0, _baseMinY);
  }

  // X軸パディング付き配列
  List<DateTime> get _axisDates {
    if (_xDates.isEmpty) return [];
    final List<DateTime> list = List<DateTime>.from(_xDates);
    final pad = (_displayMode == DisplayMode.day) ? _kPadTailDays : _kPadTailWeeks;
    DateTime last = list.last;
    for (int i = 1; i <= pad; i++) {
      last = last.add(Duration(days: _displayMode == DisplayMode.day ? 1 : 7));
      list.add(last);
    }
    return list;
  }

  // ラベル
  String _weekSuffix() {
    final lang = Localizations.localeOf(context).languageCode; // ← これでOK
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

  Widget _bottomTitle(double value, TitleMeta meta) {
    final dates = _axisDates;
    if (dates.isEmpty) return const SizedBox.shrink();
    if ((value - value.round()).abs() > 1e-6) return const SizedBox.shrink();
    final idx = value.round();
    if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();

    final text = (_displayMode == DisplayMode.day)
        ? _formatDayLabel(dates[idx])
        : _formatWeekLabel(dates[idx]);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _leftTitle(double value, TitleMeta meta) {
    if (!_isLabelTick(value)) return const SizedBox.shrink();
    final isInteger = (_yLabelStep % 1 == 0);
    final label = isInteger ? value.round().toString() : value.toStringAsFixed(1);
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

  String _unitOverlayText(AppLocalizations l10n) {
    final bool isBody =
        (_selectedPart == l10n.bodyWeight) || (_selectedMenu == l10n.bodyWeight);
    final bool hasMenu = _selectedMenu != null;
    if (!isBody && !hasMenu) return '';

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

  void _checkIfFavorite() {
    final l10n = AppLocalizations.of(context)!;
    final String? key =
    (_selectedPart == l10n.bodyWeight || _selectedMenu == l10n.bodyWeight)
        ? l10n.bodyWeight
        : _selectedMenu;
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
      if (_selectedPart == l10n.favorites) _loadMenusForPart(_selectedPart!);
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

  String _goalStorageKey() {
    final l10n = AppLocalizations.of(context)!;
    String ctx;
    if (_isBodyWeightContext()) {
      ctx = 'body';
    } else if (_isAerobicContext()) {
      ctx = 'aero_${_aeroMetric.name}_${_selectedMenu ?? ''}';
    } else if (_isStrengthContext()) {
      ctx = 'strength_${_selectedMenu ?? ''}';
    } else {
      ctx = 'unknown';
    }
    final unit = _unitOverlayText(l10n);
    return 'graph_goal::$ctx::$unit';
  }

  void _loadGoalForCurrentContext() {
    final key = _goalStorageKey();
    final v = widget.settingsBox.get(key);
    double? parsed;
    if (v is num)
      parsed = v.toDouble();
    else if (v is String) parsed = _parseDurationMin(v) ?? double.tryParse(v);
    _goalValue = parsed;

    if (_goalValue == null) {
      _goalController.text = '';
    } else {
      _goalController.text = _goalDisplayString();
    }
    setState(() {});
  }

  void _saveGoalForCurrentContext() {
    final key = _goalStorageKey();
    if (_goalValue == null) {
      widget.settingsBox.delete(key);
    } else {
      widget.settingsBox.put(key, _goalValue);
    }
  }

  void _applyGoalFromText(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      setState(() {
        _goalValue = null;
      });
      _saveGoalForCurrentContext();
      return;
    }
    double? v;
    if (_isAerobicContext() &&
        (_aeroMetric == AerobicMetric.time || _aeroMetric == AerobicMetric.pace)) {
      v = _parseDurationMin(s);
    } else {
      v = double.tryParse(s);
    }
    setState(() {
      _goalValue = v;
      _goalController.text = _goalDisplayString();
    });
    _saveGoalForCurrentContext();
  }

  Future<int?> _showWheelPicker({
    required String title,
    required List<String> items,
    required int initialIndex,
  }) async {
    if (items.isEmpty) return null;
    int current = initialIndex.clamp(0, items.length - 1);
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(current),
                        child: Text(MaterialLocalizations.of(context).okButtonLabel),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: current),
                    itemExtent: 36,
                    onSelectedItemChanged: (i) => current = i,
                    children: items
                        .map((e) => Center(
                      child: Text(
                        e,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<double?> _showNumberPicker({
    required String title,
    required double minValue,
    required double maxValue,
    required double step,
    required int fractionDigits,
    double? current,
    String suffix = '',
  }) async {
    double floorToStep(double v) => (v / step).floorToDouble() * step;
    double ceilToStep(double v) => (v / step).ceilToDouble() * step;

    double lo = minValue;
    double hi = maxValue;
    if (lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }

    lo = floorToStep(lo);
    hi = ceilToStep(hi);

    if (current != null) {
      lo = min(lo, floorToStep(current));
      hi = max(hi, ceilToStep(current));
    }

    final maxItems = 2000;
    int itemsCount = ((hi - lo) / step).round() + 1;
    if (itemsCount > maxItems) {
      final k = (itemsCount / maxItems).ceil();
      step *= k;
      lo = floorToStep(minValue);
      hi = ceilToStep(maxValue);
      itemsCount = ((hi - lo) / step).round() + 1;
    }

    final List<double> values = List.generate(itemsCount, (i) => lo + step * i);
    int initialIndex;
    if (current == null) {
      initialIndex = (values.length / 2).floor();
    } else {
      initialIndex = values.indexWhere((v) => (v - current!).abs() <= step / 2);
      if (initialIndex < 0) {
        initialIndex = values.indexWhere((v) => v > current!);
        if (initialIndex < 0) initialIndex = values.length - 1;
      }
    }

    final items = values
        .map((v) => '${v.toStringAsFixed(fractionDigits)}${suffix.isNotEmpty ? ' $suffix' : ''}')
        .toList();

    final picked = await _showWheelPicker(
      title: title,
      items: items,
      initialIndex: initialIndex,
    );
    if (picked == null) return null;
    return double.tryParse(values[picked].toStringAsFixed(fractionDigits));
  }

  Future<Duration?> _showTimeWheelPicker({
    required String title,
    Duration? initial,
    String suffix = '',
    int maxMinutes = 600,
  }) async {
    final init = initial ?? const Duration(minutes: 30);
    int selMin = init.inMinutes.clamp(0, maxMinutes);
    int selSec = ((init.inSeconds) % 60).clamp(0, 59);

    return showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final minCtrl = FixedExtentScrollController(initialItem: selMin);
        final secCtrl = FixedExtentScrollController(initialItem: selSec);
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        '$title ${suffix.isNotEmpty ? '($suffix)' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(Duration(minutes: selMin, seconds: selSec)),
                        child: Text(MaterialLocalizations.of(context).okButtonLabel),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: minCtrl,
                          itemExtent: 36,
                          onSelectedItemChanged: (i) => selMin = i,
                          children: List.generate(
                            maxMinutes + 1,
                                (i) => Center(
                                child: Text('$i 分',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                          ),
                        ),
                      ),
                      Container(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: secCtrl,
                          itemExtent: 36,
                          onSelectedItemChanged: (i) => selSec = i,
                          children: List.generate(
                            60,
                                (i) => Center(
                                child: Text('$i 秒',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGoalPicker() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isBodyWeightContext()) {
      final isKg = SettingsManager.currentUnit == 'kg';
      final step = isKg ? 0.5 : 1.0;
      final unit = isKg ? l10n.kg : l10n.lbs;

      double lo = (_baseMinY - 10).floorToDouble();
      double hi = (_baseMaxY + 10).ceilToDouble();
      if (hi < lo + 5) hi = lo + 5;
      if (isKg) {
        lo = (lo / 0.5).floor() * 0.5;
        hi = (hi / 0.5).ceil() * 0.5;
      }

      final v = await _showNumberPicker(
        title: l10n.bodyWeight,
        minValue: lo,
        maxValue: hi,
        step: step,
        fractionDigits: isKg ? 1 : 0,
        current: _goalValue,
        suffix: unit,
      );
      if (v != null) {
        setState(() {
          _goalValue = v;
          _goalController.text = _goalDisplayString();
        });
        _saveGoalForCurrentContext();
      }
      return;
    }

    if (_isAerobicContext()) {
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          {
            final v = await _showNumberPicker(
              title: l10n.distance,
              minValue: max(0.0, _baseMinY - 2),
              maxValue: _baseMaxY + 5,
              step: 0.1,
              fractionDigits: 1,
              current: _goalValue,
              suffix: l10n.km,
            );
            if (v != null) {
              setState(() {
                _goalValue = v;
                _goalController.text = _goalDisplayString();
              });
              _saveGoalForCurrentContext();
            }
            return;
          }
        case AerobicMetric.time:
          {
            final init = Duration(minutes: ((_goalValue ?? 30).clamp(0, 600)).round());
            final dur = await _showTimeWheelPicker(
              title: l10n.time,
              initial: init,
              suffix: l10n.min,
            );
            if (dur != null) {
              setState(() {
                _goalValue = dur.inSeconds / 60.0;
                _goalController.text = _goalDisplayString();
              });
              _saveGoalForCurrentContext();
            }
            return;
          }
        case AerobicMetric.pace:
          {
            final init =
            Duration(seconds: (((_goalValue ?? 6.0) * 60).clamp(60, 60 * 30)).round());
            final dur = await _showTimeWheelPicker(
              title: l10n.pace,
              initial: init,
              suffix: '${l10n.min}/${l10n.km}',
            );
            if (dur != null) {
              setState(() {
                _goalValue = dur.inSeconds / 60.0;
                _goalController.text = _goalDisplayString();
              });
              _saveGoalForCurrentContext();
            }
            return;
          }
      }
    }

    if (_isStrengthContext()) {
      final isKg = SettingsManager.currentUnit == 'kg';
      final step = isKg ? 5.0 : 11.0;
      final unit = isKg ? l10n.kg : l10n.lbs;

      double lo = (_baseMinY - 20).floorToDouble();
      double hi = (_baseMaxY + 20).ceilToDouble();
      if (hi < 100) hi = 100;

      final v = await _showNumberPicker(
        title: _selectedMenu ?? '',
        minValue: lo,
        maxValue: hi,
        step: step,
        fractionDigits: isKg ? 1 : 0,
        current: _goalValue,
        suffix: unit,
      );
      if (v != null) {
        setState(() {
          _goalValue = v;
          _goalController.text = _goalDisplayString();
        });
        _saveGoalForCurrentContext();
      }
      return;
    }
  }

  String _goalDisplayString() {
    final l10n = AppLocalizations.of(context)!;
    if (_goalValue == null) return '';
    if (_isAerobicContext()) {
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          return '${_goalValue!.toStringAsFixed(1)} ${l10n.km}';
        case AerobicMetric.time:
          return '${_formatMinToMMSS(_goalValue!)} ${l10n.min}';
        case AerobicMetric.pace:
          return '${_formatMinToMMSS(_goalValue!)} ${l10n.min}/${l10n.km}';
      }
    }
    final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
    final fd = _isBodyWeightContext() ? 1 : (u == l10n.kg ? 1 : 0);
    return '${_goalValue!.toStringAsFixed(fd)} $u';
  }

  Future<void> _openPartPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final list = _filteredBodyParts;
    if (list.isEmpty) return;
    final init = _selectedPart != null ? list.indexOf(_selectedPart!) : 0;
    final picked = await _showWheelPicker(
      title: l10n.selectTrainingPart,
      items: list,
      initialIndex: init < 0 ? 0 : init,
    );
    if (picked == null) return;
    final value = list[picked];
    setState(() {
      _selectedPart = value;
      _saveGraphPrefs();
      _loadMenusForPart(value);
      _checkIfFavorite();
    });
  }

  Future<void> _openMenuPicker() async {
    final l10n = AppLocalizations.of(context)!;
    if (_menusForPart.isEmpty) return;
    final init = _selectedMenu != null ? _menusForPart.indexOf(_selectedMenu!) : 0;
    final picked = await _showWheelPicker(
      title: l10n.selectExercise,
      items: _menusForPart,
      initialIndex: init < 0 ? 0 : init,
    );
    if (picked == null) return;
    final value = _menusForPart[picked];
    setState(() {
      _selectedMenu = value;
      _saveGraphPrefs();
      _refreshDataForSelection();
      _checkIfFavorite();
    });
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isAerobic = _isAerobicContext();
    final unitText = _unitOverlayText(l10n);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryShowGraphCoachIfVisible();
    });

    // 日/週トグル
    Widget dayWeekToggle = SizedBox(
      height: _kControlHeight,
      child: ToggleButtons(
        isSelected: [
          _displayMode == DisplayMode.day,
          _displayMode == DisplayMode.week
        ],
        onPressed: (index) {
          setState(() {
            _displayMode = index == 0 ? DisplayMode.day : DisplayMode.week;
            _saveGraphPrefs();
            _refreshDataForSelection();
          });
        },
        constraints: const BoxConstraints(minHeight: _kControlHeight),
        borderRadius: BorderRadius.circular(_kControlRadius),
        selectedColor: colorScheme.onPrimary,
        fillColor: colorScheme.primary,
        color: colorScheme.onSurface,
        borderColor: colorScheme.outlineVariant,
        selectedBorderColor: colorScheme.primary,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(l10n.dayDisplay),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(l10n.weekDisplay),
          ),
        ],
      ),
    );

    // 目標ボタン
    Widget goalButton = SizedBox(
      height: _kControlHeight,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          side: BorderSide(color: colorScheme.outlineVariant),
          backgroundColor: colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: _openGoalPicker,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_outlined, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _goalController.text.isEmpty ? l10n.enterGoal : _goalController.text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget favButton = (_selectedPart != l10n.favorites)
        ? FavoritePillButton(
      key: _kFav,
      isFavorite: _isFavorite,
      label: l10n.favorites,
      onTap: _toggleFavorite,
      height: _kControlHeight,
    )
        : const SizedBox.shrink();

    final partDisplay = _selectedPart ?? l10n.selectTrainingPart;
    final menuDisplay =
    (_selectedPart == l10n.bodyWeight) ? '' : (_selectedMenu ?? l10n.selectExercise);

    Widget partMenuRow = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: _kPickerHeight,
            child: InkWell(
              key: _kPart,
              onTap: _openPartPicker,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          partDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_selectedPart != l10n.bodyWeight)
          Expanded(
            child: SizedBox(
              height: _kPickerHeight,
              child: InkWell(
                onTap: _menusForPart.isNotEmpty ? _openMenuPicker : null,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _menusForPart.isNotEmpty
                          ? colorScheme.outlineVariant
                          : colorScheme.outline,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            menuDisplay.isEmpty ? l10n.selectExercise : menuDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _menusForPart.isNotEmpty
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.expand_more,
                            color: _menusForPart.isNotEmpty
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.outline),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0.0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'グラフ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.00),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeKeyboard,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const AdBanner(screenName: 'graph'),
                const SizedBox(height: 12.0),

                Row(
                  children: [
                    Expanded(child: dayWeekToggle),
                    const SizedBox(width: 8),
                    Expanded(child: goalButton),
                    const SizedBox(width: 8),
                    Expanded(child: favButton),
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
                          if (_selectedMenu != null) _loadAerobicData(_selectedMenu!);
                          _loadGoalForCurrentContext();
                        });
                      },
                      constraints: const BoxConstraints(minHeight: 34),
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

                const SizedBox(height: 8),

                // ====== グラフ ======
                Expanded(
                  child: Card(
                    key: _kChart,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalW = constraints.maxWidth;
                          final totalH = constraints.maxHeight;

                          _plotHeightPx = totalH;
                          final yAxisPanelW = _axisDates.isEmpty ? 0.0 : _kYAxisWidth;
                          final plotAvailW = max(60.0, totalW - yAxisPanelW - 4);
                          final points = max(1, _axisDates.length);
                          final chartW = max(plotAvailW, points * _kXStridePx);

                          final unitOverlay = (unitText.isEmpty || _axisDates.isEmpty)
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

                          // 必要なチャート全高：Yピッチ固定（_kYTickPx）で算出。
// いまは計算値が小さいとカード内に下余白が残るので、totalH を下限にする。
                          final tickCount = ((_baseMaxY - _baseMinY) / _yLabelStep).round() + 1;

// もともとの計算（上 24px + 下 24px）はそのまま使いつつ…
                          final double computedChartH = 24 + (tickCount - 1) * _kYTickPx + 24;

// ここを変更：カードの実高 totalH を下限にする
                          final double chartH = max(totalH, computedChartH);

                          // 左Y軸（縦スクロールと同期）
                          final yAxisChart = SizedBox(
                            width: yAxisPanelW,
                            height: chartH,
                            child: _axisDates.isEmpty
                                ? const SizedBox.shrink()
                                : LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: 1,
                                minY: _baseMinY,
                                maxY: _baseMaxY,
                                clipData: const FlClipData.all(),
                                lineBarsData: const [],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: _kYAxisWidth - 4,
                                      interval: _yLabelStep,
                                      getTitlesWidget: _leftTitle,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: _kXAxisReservedPx, // 右と統一
                                      getTitlesWidget: (v, meta) => const SizedBox.shrink(),
                                    ),
                                  ),
                                  topTitles:
                                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles:
                                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: _yLabelStep,
                                  checkToShowHorizontalLine: (v) => _isLabelTick(v),
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (v) =>
                                      FlLine(color: colorScheme.outlineVariant, strokeWidth: 0.5),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    left: BorderSide(color: colorScheme.outlineVariant),
                                    bottom: BorderSide(color: colorScheme.outlineVariant),
                                  ),
                                ),
                              ),
                            ),
                          );

                          // 右側：縦横スクロール（ズーム無し）
                          final plotArea = _axisDates.isEmpty
                              ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.noGraphData,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          )
                              : SizedBox(
                            height: chartH,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: SizedBox(
                                width: chartW,
                                height: chartH,
                                child: LineChart(
                                  LineChartData(
                                    minX: 0,
                                    maxX: (_axisDates.length - 1).toDouble(),
                                    minY: _baseMinY,
                                    maxY: _baseMaxY,
                                    clipData: const FlClipData.all(),
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
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          reservedSize: _kXAxisReservedPx, // 左と統一
                                          getTitlesWidget: _bottomTitle,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      horizontalInterval: _yLabelStep,
                                      checkToShowHorizontalLine: (v) => _isLabelTick(v),
                                      drawVerticalLine: true,
                                      verticalInterval: 1,
                                      checkToShowVerticalLine: (v) => (v - v.round()).abs() < 1e-6,
                                      getDrawingHorizontalLine: (v) => FlLine(
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
                                        bottom: BorderSide(color: colorScheme.outlineVariant),
                                        right: BorderSide(color: colorScheme.outlineVariant),
                                      ),
                                    ),
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (items) {
                                          final loc = Localizations.localeOf(context).toString();
                                          return items.map((s) {
                                            final i = s.x.toInt();
                                            final d = (i >= 0 && i < _xDates.length) ? _xDates[i] : null;
                                            final dateStr = (_displayMode == DisplayMode.day)
                                                ? (d != null ? DateFormat('M/d', loc).format(d) : '')
                                                : (d != null ? _formatWeekLabel(d) : '');
                                            final valStr = _formatTooltipValue(s.y, l10n);
                                            return LineTooltipItem(
                                              '$dateStr\n$valStr',
                                              TextStyle(
                                                color: colorScheme.onPrimaryContainer,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    extraLinesData: ExtraLinesData(
                                      horizontalLines: (_goalValue != null)
                                          ? [
                                        HorizontalLine(
                                          y: _goalValue!,
                                          color: colorScheme.tertiary,
                                          strokeWidth: 2,
                                          dashArray: [6, 4],
                                        ),
                                      ]
                                          : const [],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );


                          // 縦スクロールで Y軸とプロットを一緒に動かす
                          return Stack(
                            children: [
                              SizedBox(
                                width: totalW,
                                height: totalH,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  physics: const BouncingScrollPhysics(),
                                  child: SizedBox(
                                    height: chartH,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        yAxisChart,
                                        const SizedBox(width: 2),
                                        Expanded(child: plotArea),
                                      ],
                                    ),
                                  ),
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

                const SizedBox(height: 8),
                partMenuRow,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }
}

class FavoritePillButton extends StatelessWidget {
  final bool isFavorite;
  final String label;
  final VoidCallback onTap;
  final double height;

  const FavoritePillButton({
    super.key,
    required this.isFavorite,
    required this.label,
    required this.onTap,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = isFavorite ? '$label★' : '$label✩';

    return SizedBox(
      height: height,
      child: Material(
        color: cs.surfaceContainerHighest,
        shape: const StadiumBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
        ),
      ),
    );
  }
}
