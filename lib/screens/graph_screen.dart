// lib/screens/graph_screen.dart
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
  // ★ 吹き出しのアンカー
  final GlobalKey _kFav = GlobalKey();   // お気に入りピル／★ボタン
  final GlobalKey _kChart = GlobalKey(); // グラフの親Card
  final GlobalKey _kPart = GlobalKey();  // 部位セレクタのDropdown
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

  /// 目盛りラベル＆横線の間隔
  double _yLabelStep = 5;

  // ====== Yパン／ズーム用の状態 ======
  // 計算上のベース範囲（データから決めた初期範囲＝20%余白込み）
  double _baseMinY = 0;
  double _baseMaxY = 0;

  // 現在表示中の範囲（null のときはベースを使う）
  double? _viewMinY;
  double? _viewMaxY;

  // スケールの操作用
  double _gestureStartScale = 1.0;
  double _gestureStartMinY = 0;
  double _gestureStartMaxY = 0;

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

    _filteredBodyParts = [
      l10n.favorites,
      l10n.bodyWeight,
      ..._filteredBodyParts
    ];

    final String? savedPart = widget.settingsBox.get(_prefGraphPart) as String?;
    if (savedPart != null && _filteredBodyParts.contains(savedPart)) {
      _selectedPart = savedPart;
    } else {
      _selectedPart = null; // 最初は未選択
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
      _loadBodyWeightData();
      _checkIfFavorite();
      _saveGraphPrefs();
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

    _buildSeriesFromMap(map);
    setState(() {});
  }

  // ====== “綺麗な”目盛り間隔を選ぶ ======
  double _niceStepForRange(double range, {int targetTicks = 10}) {
    if (range <= 0) return 1;
    final raw = range / targetTicks;
    final exp = pow(10, (log(raw) / ln10).floor()).toDouble();
    final f = raw / exp; // 1〜10 の間
    double nice;
    if (f < 1.5) {
      nice = 1;
    } else if (f < 3) {
      nice = 2;
    } else if (f < 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * exp;
  }

  // ====== build series & axis ======
  void _buildSeriesFromMap(Map<DateTime, double> map) {
    _spots = [];
    _xDates = [];
    _minY = 0;
    _maxY = 0;
    if (map.isEmpty) {
      // 参照が空のときは表示も空に
      _viewMinY = _viewMaxY = null;
      return;
    }

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

    // “綺麗な”境界に合わせて丸め
    double floorTo(double v, double step) => (v / step).floorToDouble() * step;
    double ceilTo(double v, double step) => (v / step).ceilToDouble() * step;

    // まずステップを仮決定して丸める
    final roughRange = max(1e-6, _maxY - _minY);
    final baseStep = _niceStepForRange(roughRange, targetTicks: 8);
    double minNice = floorTo(_minY, baseStep);
    double maxNice = ceilTo(_maxY, baseStep);

    // 初期表示は 20% 余白
    final rangeNice = max(1e-6, maxNice - minNice);
    final extra = rangeNice * 0.2;
    _baseMinY = minNice - extra;
    _baseMaxY = maxNice + extra;

    // 初期ビューをベースにリセット
    _resetYViewToBase();

    // 目盛り間隔を（表示レンジをもとに）再計算
    final currentRange = max(1e-6, (_viewMaxY! - _viewMinY!));
    _yLabelStep = _niceStepForRange(currentRange, targetTicks: 10);
  }

  // ====== Yレンジの決定（ビュー or ベース） ======
  double get _minYForChart => _viewMinY ?? _baseMinY;
  double get _maxYForChart => _viewMaxY ?? _baseMaxY;

  void _resetYViewToBase() {
    _viewMinY = _baseMinY;
    _viewMaxY = _baseMaxY;
  }

  void _clampYView() {
    if (_viewMinY == null || _viewMaxY == null) return;
    // ベース範囲の±50%まで動ける
    final baseRange = max(1e-6, _baseMaxY - _baseMinY);
    final pad = baseRange * 0.5;
    final hardMin = _baseMinY - pad;
    final hardMax = _baseMaxY + pad;

    final viewRange = max(1e-6, _viewMaxY! - _viewMinY!);
    // 下限・上限クランプ
    if (_viewMinY! < hardMin) {
      _viewMaxY = hardMin + viewRange;
      _viewMinY = hardMin;
    }
    if (_viewMaxY! > hardMax) {
      _viewMinY = hardMax - viewRange;
      _viewMaxY = hardMax;
    }

    // 目盛り間隔も再計算
    _yLabelStep = _niceStepForRange(viewRange, targetTicks: 10);
  }

  // 縦ドラッグ（パン）
  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_viewMinY == null || _viewMaxY == null) return;
    // ドラッグ量をレンジに比例させる。感度は 0.01 で調整。
    final range = max(1e-6, _viewMaxY! - _viewMinY!);
    final deltaY = -d.delta.dy * (range * 0.01);
    _viewMinY = _viewMinY! + deltaY;
    _viewMaxY = _viewMaxY! + deltaY;
    _clampYView();
    setState(() {});
  }

  // ピンチ（2本指）でYズーム
  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartScale = 1.0;
    _gestureStartMinY = _minYForChart;
    _gestureStartMaxY = _maxYForChart;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_xDates.isEmpty) return;
    // 1本指のときは無視（横スクロールに委譲）
    if (d.pointerCount < 2) return;

    final scale = d.verticalScale; // 縦方向のスケール変化
    if (!scale.isFinite || scale == 0) return;

    final startRange = max(1e-6, _gestureStartMaxY - _gestureStartMinY);
    // 画面中心を基準にスケーリング
    final center = (_gestureStartMinY + _gestureStartMaxY) / 2.0;
    final newRange = startRange / scale.clamp(0.2, 5.0);
    _viewMinY = center - newRange / 2;
    _viewMaxY = center + newRange / 2;

    // ズーム下限・上限（あまり極端にならないよう制限）
    final baseRange = max(1e-6, _baseMaxY - _baseMinY);
    final minRange = baseRange * 0.05; // 5% まで拡大可
    final maxRange = baseRange * 5.0;  // 5倍まで縮小可
    final vr = (_viewMaxY! - _viewMinY!).clamp(minRange, maxRange);
    final c = (_viewMinY! + _viewMaxY!) / 2;
    _viewMinY = c - vr / 2;
    _viewMaxY = c + vr / 2;

    _clampYView();
    setState(() {});
  }

  // ====== tick helpers ======
  bool _isLabelTick(double v) {
    final step = _yLabelStep;
    final ratio = v / step;
    return (ratio - ratio.round()).abs() < 1e-6;
  }

  // ====== favorites ======
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

  // Y axis: 上下端は非表示（ダブり防止）、_yLabelStep 間隔
  Widget _leftTitle(double value, TitleMeta meta) {
    if (!_isLabelTick(value)) return const SizedBox.shrink();

    const eps = 0.01;
    final isMin = (value - _minYForChart).abs() <= eps;
    final isMax = (value - _maxYForChart).abs() <= eps;
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        padding: const EdgeInsets.all(16.0), // ← named 引数でビルドエラー解消
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
                    key: _kFav,
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
                key: _kChart,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 4,
                clipBehavior: Clip.antiAlias, // ★ 角丸外へのはみ出し防止
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalW = constraints.maxWidth;
                      final totalH = constraints.maxHeight;

                      final yAxisPanelW = _xDates.isEmpty ? 0.0 : 40.0;
                      final plotAvailW = max(60.0, totalW - yAxisPanelW - 4);
                      const stride = 70.0;
                      final points = max(1, _xDates.length);
                      final chartW = max(plotAvailW, points * stride);

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
                            minY: _minYForChart,
                            maxY: _maxYForChart,
                            clipData: const FlClipData.all(), // ★ クリップ
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
                            : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: _onVerticalDragUpdate,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: SizedBox(
                              width: chartW,
                              height: totalH,
                              child: LineChart(
                                LineChartData(
                                  minX: 0,
                                  maxX: (_xDates.length - 1).toDouble(),
                                  minY: _minYForChart,
                                  maxY: _maxYForChart,
                                  clipData:
                                  const FlClipData.all(), // ★ クリップ
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
                                        interval: 1,
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
                                    verticalInterval: 1,
                                    checkToShowVerticalLine: (v) =>
                                    (v - v.round()).abs() < 1e-6,
                                    getDrawingHorizontalLine: (v) =>
                                        FlLine(
                                          color:
                                          colorScheme.outlineVariant,
                                          strokeWidth: 0.5,
                                        ),
                                    getDrawingVerticalLine: (v) =>
                                        FlLine(
                                          color:
                                          colorScheme.outlineVariant,
                                          strokeWidth: 0.5,
                                        ),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border(
                                      bottom: BorderSide(
                                          color: colorScheme
                                              .outlineVariant),
                                      right: BorderSide(
                                          color: colorScheme
                                              .outlineVariant),
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
                                              fontWeight:
                                              FontWeight.w600,
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
                  key: _kPart,
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
                        _loadMenusForPart(value);
                        _checkIfFavorite();
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
                          color: colorScheme.onSurfaceVariant, fontSize: 14.0),
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
                          _refreshDataForSelection();
                          _checkIfFavorite();
                        });
                      } else {
                        setState(() {
                          _spots = [];
                          _xDates = [];
                          _minY = 0;
                          _maxY = 0;
                          _checkIfFavorite();
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
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final box = widget.settingsBox;
      final seen = box.get('hint_seen_graph') as bool? ?? false;
      if (seen) return;

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
      await box.put('hint_seen_graph', true);
    });
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
