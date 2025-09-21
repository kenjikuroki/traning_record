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
import '../widgets/centered_constrained.dart';

// ignore_for_file: library_private_types_in_public_api

enum DisplayMode { day, week }

enum AerobicMetric { distance, time, pace }

enum PersonalMetric { weight, bodyFat, bmi, waist }

class GraphScreen extends StatefulWidget {
  final Box<dynamic> recordsBox;
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
  final GlobalKey _kGoal = GlobalKey();

  // 連打抑止
  DateTime? _lastHintShownAt;
  static const Duration _kHintCooldown = Duration(milliseconds: 1200);

  void _showThrottledHint(String message) {
    final now = DateTime.now();
    if (_lastHintShownAt != null &&
        now.difference(_lastHintShownAt!) < _kHintCooldown) {
      return;
    }
    _lastHintShownAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

// --- length/waist unit helpers ---
  bool get _isMetricLength => SettingsManager.currentLengthUnit == 'km';

// distance
  double _kmToUser(double km) => _isMetricLength ? km : km * 0.62137119223733;
  String _distanceUnit(AppLocalizations l10n) {
    if (_isMetricLength) return l10n.km;
    // l10n.mile が無い環境のフォールバック
    try {
      return (l10n as dynamic).mile as String;
    } catch (_) {
      return 'mi';
    }
  }

// pace (min per km -> min per mile)
  double _minPerKmToUser(double minPerKm) =>
      _isMetricLength ? minPerKm : minPerKm * 1.609344;

// waist
  double _waistToUser(double cm) => _isMetricLength ? cm : cm / 2.54;
  String _waistUnit(AppLocalizations l10n) {
    if (_isMetricLength) {
      try {
        return (l10n as dynamic).cm as String;
      } catch (_) {
        return 'cm';
      }
    } else {
      // l10n.in / l10n.inch / l10n.unitIn どれも無い場合のフォールバック
      try {
        return (l10n as dynamic).inches as String;
      } catch (_) {}
      try {
        return (l10n as dynamic).inch as String;
      } catch (_) {}
      try {
        return (l10n as dynamic).unitIn as String;
      } catch (_) {}
      return 'in';
    }
  }

  bool get _noMenusForSelectedPart {
    final l10n = AppLocalizations.of(context)!;
    return _selectedPart != null &&
        _selectedPart != l10n.personal &&
        _selectedPart != l10n.favorites &&
        _menusForPart.isEmpty;
  }

  // 設定キー
  static const String _prefGraphPart = 'graph_selected_part';
  static const String _prefGraphMenu = 'graph_selected_menu';
  static const String _prefGraphMode = 'graph_display_mode';
  static const String _prefAeroMetric = 'graph_aero_metric';
  static const String _prefPersonalMetric = 'graph_personal_metric';

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
  PersonalMetric _personalMetric = PersonalMetric.weight;
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
    if (translatedPart == l10n.personal) return 'パーソナル';
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
    return translatedPart;
  }

  String _personalMetricLabel(AppLocalizations l10n) {
    // l10n に waist が無い場合は 'ウエスト' でフォールバック
    final waistLabel = (() {
      try {
        return l10n.waist;
      } catch (_) {
        return 'ウエスト';
      }
    })();
    switch (_personalMetric) {
      case PersonalMetric.weight:
        return l10n.bodyWeight;
      case PersonalMetric.bodyFat:
        return l10n.bodyFatPercentage;
      case PersonalMetric.bmi:
        return 'BMI';
      case PersonalMetric.waist:
        return waistLabel;
    }
  }

  // --- Personal表示名⇔メトリック/キー 変換ヘルパー ---
  PersonalMetric? _metricFromDisplay(AppLocalizations l10n, String label) {
    final waistLabel = (() {
      try {
        return l10n.waist;
      } catch (_) {
        return 'ウエスト';
      }
    })();
    if (label == l10n.bodyWeight) return PersonalMetric.weight;
    if (label == l10n.bodyFatPercentage) return PersonalMetric.bodyFat;
    if (label == 'BMI') return PersonalMetric.bmi;
    if (label == waistLabel) return PersonalMetric.waist;
    return null;
  }

  String _favoriteKeyForPersonalMetric(PersonalMetric m) {
    switch (m) {
      case PersonalMetric.weight:
        return 'personal:bodyWeight';
      case PersonalMetric.bodyFat:
        return 'personal:bodyFat';
      case PersonalMetric.bmi:
        return 'personal:bmi';
      case PersonalMetric.waist:
        return 'personal:waist';
    }
  }

  String _displayNameFromFavoriteKey(AppLocalizations l10n, String key) {
    final waistLabel = (() {
      try {
        return l10n.waist;
      } catch (_) {
        return 'ウエスト';
      }
    })();
    if (key == l10n.bodyWeight || key == 'personal:bodyWeight')
      return l10n.bodyWeight;
    if (key == 'personal:bodyFat') return l10n.bodyFatPercentage;
    if (key == 'personal:bmi') return 'BMI';
    if (key == 'personal:waist') return waistLabel;
    if (key.startsWith('menu:')) return key.substring(5);
    return key; // 後方互換・未知キー
  }

  Future<void> _openPersonalMetricPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final waistLabel = (() {
      try {
        return l10n.waist;
      } catch (_) {
        return 'ウエスト';
      }
    })();
    final items = [l10n.bodyWeight, l10n.bodyFatPercentage, 'BMI', waistLabel];
    final picked = await _showWheelPicker(
      title: l10n.selectExercise,
      items: items,
      initialIndex: _personalMetric.index,
    );
    if (picked == null) return;
    setState(() {
      _personalMetric = PersonalMetric.values[picked];
      _saveGraphPrefs();
      _loadPersonalData();
      _loadGoalForCurrentContext();
      _checkIfFavorite(); // ← 追加：指標切替後に再判定
    });
  }

  String _translatePartToLocale(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
      case '有酸素運動':
        return l10n.aerobicExercise;
      case 'パーソナル':
        return l10n.personal;
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
      _kGoal.currentContext,
      _kFav.currentContext,
    ].every((c) => c != null);
    if (!anchorsReady) return;

    final l10n = AppLocalizations.of(context)!;
    await CoachBubbleController.showSequence(
      context: context,
      anchors: [_kPart, _kChart, _kGoal, _kFav],
      messages: [
        l10n.hintGraphSelectPart,
        l10n.hintGraphChartArea,
        l10n.hintGraphSetGoal,
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

    final int? savedPersIdx =
        widget.settingsBox.get(_prefPersonalMetric) as int?;
    if (savedPersIdx != null &&
        savedPersIdx >= 0 &&
        savedPersIdx < PersonalMetric.values.length) {
      _personalMetric = PersonalMetric.values[savedPersIdx];
    }

    // 部位（パーソナル/お気に入りはここに含めない）
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

    // 先頭に「お気に入り」「パーソナル」
    _filteredBodyParts = [l10n.favorites, l10n.personal, ..._filteredBodyParts];

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

    // パーソナル：メニューは不要（画面内のトグルで切替）
    if (translatedPart == l10n.personal) {
      _menusForPart = [];
      _selectedMenu = null;
      _loadPersonalData();
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
        final l = rawFavorites.whereType<String>().toList();
        _menusForPart = l
            .map((k) => _displayNameFromFavoriteKey(l10n, k))
            .toSet()
            .toList(); // 重複除去
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

    // FavoritesでPersonalを選んだ場合は_current metric を同期
    if (translatedPart == l10n.favorites && _selectedMenu != null) {
      final m = _metricFromDisplay(l10n, _selectedMenu!);
      if (m != null && m != _personalMetric) {
        _personalMetric = m;
        _saveGraphPrefs();
      }
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

    // Favorites上でPersonal表示名が選ばれていたら _personalMetric を合わせる
    if (_selectedPart == l10n.favorites && _selectedMenu != null) {
      final m = _metricFromDisplay(l10n, _selectedMenu!);
      if (m != null && m != _personalMetric) {
        _personalMetric = m;
        _saveGraphPrefs();
      }
    }

    final isPersonal = _isPersonalContext();
    final isAero = _isAerobicContext();

    if (isPersonal) {
      _loadPersonalData();
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
    try {
      for (final r in widget.recordsBox.values) {
        final dr = r as dynamic;
        final menusMap = dr.menus;
        if (menusMap is! Map) continue;
        for (final entry in menusMap.entries) {
          final list = entry.value;
          if (list is! List) continue;
          for (final x in list) {
            if (_sameMenuName(x, menuName)) {
              final hasAero = ((x as dynamic).distance != null &&
                      (x as dynamic).distance.toString().trim().isNotEmpty) ||
                  ((x as dynamic).duration != null &&
                      (x as dynamic).duration.toString().trim().isNotEmpty);
              if (hasAero) return true;
            }
          }
        }
      }
    } catch (_) {}
    return false;
  }

  bool _isAerobicContext() {
    final l10n = AppLocalizations.of(context)!;
    return _selectedPart == l10n.aerobicExercise ||
        (_selectedPart == l10n.favorites && _menuIsAerobic(_selectedMenu));
  }

  bool _isPersonalContext() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedPart == l10n.personal) return true;
    if (_selectedPart == l10n.favorites && _selectedMenu != null) {
      return _metricFromDisplay(l10n, _selectedMenu!) != null;
    }
    return false;
  }

  bool _isStrengthContext() {
    return !_isAerobicContext() &&
        !_isPersonalContext() &&
        _selectedMenu != null;
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
    var s = raw.trim();
    if (s.isEmpty) return null;

    // 数字+単位（例: "1h30m", "90m"）も将来に備えて軽く対応
    final unitMatch = RegExp(r'^(\d+)(h|m)$', caseSensitive: false);
    if (!s.contains(':')) {
      final m = unitMatch.firstMatch(s);
      if (m != null) {
        final v = int.tryParse(m.group(1)!);
        if (v == null) return null;
        return (m.group(2)!.toLowerCase() == 'h') ? v * 60.0 : v.toDouble();
      }
      return double.tryParse(s);
    }

    final parts = s.split(':').map((e) => e.trim()).toList();
    int h = 0, m = 0, sec = 0;

    if (parts.length == 3) {
      // hh:mm:ss
      h = int.tryParse(parts[0]) ?? 0;
      m = int.tryParse(parts[1]) ?? 0;
      sec = int.tryParse(parts[2]) ?? 0;
      return h * 60.0 + m + sec / 60.0;
    } else if (parts.length == 2) {
      final a = int.tryParse(parts[0]) ?? 0;
      final b = int.tryParse(parts[1]) ?? 0;
      // ヒューリスティック:
      //  - 「時間:分」を優先: a <= 5（0〜5時間想定）か、a==0 のときは hh:mm とみなす
      //  - それ以外は mm:ss
      final asHourMinute = (a <= 5);
      if (asHourMinute) {
        h = a;
        m = b;
        sec = 0;
        return h * 60.0 + m;
      } else {
        // mm:ss
        return a + b / 60.0;
      }
    }
    return null;
  }

  String _formatMinToMMSS(double minutes) {
    final totalSec = (minutes * 60).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  // 文字列や単位混じりの数値を安全に double にする（%, kg, lb, cm, カンマなどに対応）
  double? _parseNumber(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    var s = v.toString().trim();
    if (s.isEmpty) return null;

    // 許可文字以外を除去（数字・符号・小数点・カンマ）
    s = s.replaceAll(RegExp(r'[^0-9\-\.,]'), '');

    // 小数点としてカンマを使っている場合 "20,5" → "20.5"
    if (s.contains(',') && !s.contains('.')) {
      s = s.replaceAll(',', '.');
    } else {
      // 千区切りのカンマは除去 "1,234.5" → "1234.5"
      s = s.replaceAll(',', '');
    }
    return double.tryParse(s);
  }

  // ====== PERSONAL（体重/体脂肪率/BMI） ======
  // 体脂肪率（複数キー対応）
  double? _safeBodyFat(dynamic r) {
    // どれか1つでも値が取れたら返す
    try {
      final v = (r as dynamic).bodyFat;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    // ★ ここを追加：実際の保存先は bodyFatPercent
    try {
      final v = (r as dynamic).bodyFatPercent;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).bodyFatPercentage;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).bodyFatRate;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).fatPercentage;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    return null;
  }

// レコードから身長(m)を拾う（設定が無い時のフォールバック）
  double? _heightMetersFromRecord(dynamic r) {
    try {
      final v = (r as dynamic).height_m;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).heightCm;
      if (v is num) return v.toDouble() / 100.0;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d / 100.0;
      }
    } catch (_) {}
    try {
      final v = (r as dynamic).height_cm;
      if (v is num) return v.toDouble() / 100.0;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d / 100.0;
      }
    } catch (_) {}
    try {
      final v = (r as dynamic).height; // cm か m 想定：>10 は cm とみなす
      if (v is num) return v > 10 ? v.toDouble() / 100.0 : v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d > 10 ? d / 100.0 : d;
      }
    } catch (_) {}
    return null;
  }

// ウエスト(cm)を拾う
  double? _safeWaist(dynamic r) {
    try {
      final v = (r as dynamic).waist;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).waistCm;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).waist_cm;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    return null;
  }

  double? _heightMetersFromSettings() {
    // 現行キー（Settings画面）
    final hPersonalCm = widget.settingsBox.get('personal.heightCm');
    if (hPersonalCm is num && hPersonalCm > 0)
      return hPersonalCm.toDouble() / 100.0;
    if (hPersonalCm is String) {
      final d = double.tryParse(hPersonalCm);
      if (d != null && d > 0) return d / 100.0;
    }

    final hPersonalM = widget.settingsBox.get('personal.heightM');
    if (hPersonalM is num && hPersonalM > 0) return hPersonalM.toDouble();
    if (hPersonalM is String) {
      final d = double.tryParse(hPersonalM);
      if (d != null && d > 0) return d;
    }

    // 旧キー（cm）
    final h = widget.settingsBox.get('height_cm');
    if (h is num && h > 0) return h.toDouble() / 100.0;
    if (h is String) {
      final d = double.tryParse(h);
      if (d != null && d > 0) return d / 100.0;
    }

    // 旧キー（m）
    final h2 = widget.settingsBox.get('height_m');
    if (h2 is num && h2 > 0) return h2.toDouble();
    if (h2 is String) {
      final d = double.tryParse(h2);
      if (d != null && d > 0) return d;
    }

    // さらに旧キー 'height'（>10 を cm とみなす）
    final h3 = widget.settingsBox.get('height');
    final n = _parseNumber(h3);
    if (n != null && n > 0) return n > 10 ? (n / 100.0) : n;

    return null;
  }

  String? _genderFromSettings() {
    final g = widget.settingsBox.get('gender');
    if (g == null) return null;
    final s = g.toString().toLowerCase();
    if (s.contains('male')) return 'male';
    if (s.contains('female')) return 'female';
    return null;
  }

  double _toKg(double w) =>
      (SettingsManager.currentUnit == 'kg') ? w : (w * 0.45359237);

  double _kgToUser(double kg) =>
      (SettingsManager.currentUnit == 'kg') ? kg : kg * 2.2046226218;

  /// レコードから体重を**kg**で取得（String/num・kg/lbs・いろんなキー名に対応）
  double? _safeWeightKg(dynamic r) {
    double? asKg;

    // 明示kg
    try {
      final v = (r as dynamic).weightKg;
      if (v is num) asKg = v.toDouble();
      if (v is String) asKg = double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).weight_kg;
      if (asKg == null) {
        if (v is num) asKg = v.toDouble();
        if (v is String) asKg = double.tryParse(v);
      }
    } catch (_) {}

    // 明示lbs
    try {
      final v = (r as dynamic).weightLbs;
      if (v is num) asKg = v.toDouble() * 0.45359237;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) asKg = d * 0.45359237;
      }
    } catch (_) {}
    try {
      final v = (r as dynamic).weight_lbs;
      if (v is num) asKg = v.toDouble() * 0.45359237;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) asKg = d * 0.45359237;
      }
    } catch (_) {}

    // 汎用 'weight'（**現在の単位設定**で入力されたとみなしkgへ変換）
    if (asKg == null) {
      try {
        final v = (r as dynamic).weight;
        double? raw;
        if (v is num) raw = v.toDouble();
        if (v is String) raw = double.tryParse(v);
        if (raw != null) asKg = _toKg(raw); // 既存ロジックを尊重
      } catch (_) {}
    }

    return asKg;
  }

  void _loadPersonalData() {
    final Iterable records = widget.recordsBox.toMap().values;
    final Map<DateTime, double> map = {};
    final heightM = _heightMetersFromSettings();

    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
          double? v;
          switch (_personalMetric) {
            case PersonalMetric.weight:
              {
                final wKg = _safeWeightKg(dr);
                if (wKg != null) v = _kgToUser(wKg); // ← 週もユーザー単位で表示
                break;
              }
            case PersonalMetric.bodyFat:
              v = _safeBodyFat(dr);
              break;
            case PersonalMetric.bmi:
              {
                final wKg = _safeWeightKg(dr);
                final h =
                    _heightMetersFromSettings() ?? _heightMetersFromRecord(dr);
                if (wKg != null && h != null && h > 0) v = wKg / (h * h);
                break;
              }
            case PersonalMetric.waist:
              {
                final w = _safeWaist(dr); // 保存は cm
                if (w != null) v = _waistToUser(w); // ← 週も cm / in に変換
                break;
              }
          }
          if (v != null) map[day] = v;
        } catch (_) {}
      }
    } else {
      // 週集計（体重/ウエストもユーザー単位で）
      final Map<DateTime, List<double>> wk = {};
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
          final weekStart = day.subtract(Duration(days: day.weekday - 1));
          final key = DateTime(weekStart.year, weekStart.month, weekStart.day);

          double? v;
          switch (_personalMetric) {
            case PersonalMetric.weight:
              {
                // まず kg で安全取得 → 表示単位へ変換
                final wKg = _safeWeightKg(dr);
                if (wKg != null) v = _kgToUser(wKg);
                break;
              }
            case PersonalMetric.bodyFat:
              v = _safeBodyFat(dr);
              break;
            case PersonalMetric.bmi:
              {
                final wKg = _safeWeightKg(dr);
                final h =
                    _heightMetersFromSettings() ?? _heightMetersFromRecord(dr);
                if (wKg != null && h != null && h > 0) v = wKg / (h * h);
                break;
              }
            case PersonalMetric.waist:
              {
                // 保存は cm 想定 → 表示単位へ変換
                final w = _safeWaist(dr);
                if (w != null) v = _waistToUser(w);
                break;
              }
          }

          if (v != null) wk.putIfAbsent(key, () => []).add(v);
        } catch (_) {}
      }

      // 週平均
      wk.forEach((k, list) {
        if (list.isNotEmpty) {
          map[k] = list.reduce((a, b) => a + b) / list.length;
        }
      });
    }

    _buildSeriesFromMap(map);
    setState(() {});
  }

  // メニュー名の一致判定（空白除去・小文字化・全角スペース対応）
  bool _sameMenuName(dynamic x, String target) {
    String nrm(String s) => s
        .replaceAll(RegExp(r'\s+'), '') // 連続空白を除去
        .replaceAll('　', '') // 全角スペースも除去
        .toLowerCase();
    try {
      final a = (x as dynamic).name?.toString() ?? '';
      return nrm(a) == nrm(target);
    } catch (_) {
      return false;
    }
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
    final Iterable records = widget.recordsBox.toMap().values;
    final Map<DateTime, double> map = {};

    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        double maxW = 0;
        try {
          final dr = r as dynamic;
          final menusMap = dr.menus;
          if (menusMap is Map) {
            for (final entry in menusMap.entries) {
              final list = entry.value;
              if (list is List) {
                final m =
                    list.firstWhereOrNull((x) => _sameMenuName(x, menuName));
                if (m == null) continue;

                final wList = (m.weights as List?) ?? const [];
                final rList = (m.reps as List?) ?? const [];
                final len = max(wList.length, rList.length);

                for (int i = 0; i < len; i++) {
                  final wRaw = (i < wList.length) ? wList[i] : null;
                  final rRaw = (i < rList.length) ? rList[i] : null;

                  final w = (_parseNumber(wRaw) ?? 0).toDouble(); // "60kg" 等OK
                  int reps = (_parseNumber(rRaw) ?? 0).round(); // "10回" 等OK
                  if (reps <= 0 && w > 0) reps = 1; // フォールバック

                  if (reps >= 1) maxW = max(maxW, w);
                }
              }
            }
          }
        } catch (_) {}

        if (maxW > 0) {
          try {
            final dr = r as dynamic;
            final d = DateTime(dr.date.year, dr.date.month, dr.date.day);
            map[d] = maxW;
          } catch (_) {}
        }
      }
    } else {
      final Map<DateTime, double> weeklyMax = {};
      for (final r in records) {
        double maxW = 0;
        try {
          final dr = r as dynamic;
          final menusMap = dr.menus;
          if (menusMap is Map) {
            for (final entry in menusMap.entries) {
              final list = entry.value;
              if (list is List) {
                final m =
                    list.firstWhereOrNull((x) => _sameMenuName(x, menuName));
                if (m == null) continue;

                final wList = (m.weights as List?) ?? const [];
                final rList = (m.reps as List?) ?? const [];
                final len = max(wList.length, rList.length);

                for (int i = 0; i < len; i++) {
                  final wRaw = (i < wList.length) ? wList[i] : null;
                  final rRaw = (i < rList.length) ? rList[i] : null;

                  final w = (_parseNumber(wRaw) ?? 0).toDouble();
                  int reps = (_parseNumber(rRaw) ?? 0).round();
                  if (reps <= 0 && w > 0) reps = 1;

                  if (reps >= 1) maxW = max(maxW, w);
                }
              }
            }
          }

          if (maxW > 0) {
            final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
            final weekStart = day.subtract(Duration(days: day.weekday - 1));
            final key =
                DateTime(weekStart.year, weekStart.month, weekStart.day);
            weeklyMax.update(key, (old) => max(old, maxW),
                ifAbsent: () => maxW);
          }
        } catch (_) {}
      }
      map.addAll(weeklyMax);
    }
    _buildSeriesFromMap(map);
    setState(() {});
  }

  // ====== aerobic ======
  void _loadAerobicData(String menuName) {
    final Iterable records = widget.recordsBox.toMap().values;
    final Map<DateTime, double> map = {};

    // まず '有酸素運動' を優先し、無ければ全パートから名前一致で拾う
    List<dynamic>? _findAeroMenuList(dynamic dr) {
      try {
        final list = (dr as dynamic).menus['有酸素運動'];
        if (list != null) return list as List<dynamic>;
      } catch (_) {}
      try {
        final menusMap = (dr as dynamic).menus;
        if (menusMap is Map) {
          for (final entry in menusMap.entries) {
            final list = entry.value;
            if (list is List &&
                list.any((x) => ((x as dynamic).name) == menuName)) {
              return list as List<dynamic>;
            }
          }
        }
      } catch (_) {}
      return null;
    }

    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final list = _findAeroMenuList(dr);
          if (list == null) continue;
          final m =
              list.firstWhereOrNull((x) => (x as dynamic).name == menuName);
          if (m == null) continue;

          final km = _parseDistanceKm((m as dynamic).distance) ?? 0;
          final minVal = _parseDurationMin((m as dynamic).duration) ?? 0;

          double? value;
          switch (_aeroMetric) {
            case AerobicMetric.distance:
              value = km > 0 ? _kmToUser(km) : null;
              break;
            case AerobicMetric.time:
              value = minVal > 0 ? minVal : null;
              break;
            case AerobicMetric.pace:
              if (km > 0 && minVal > 0) {
                final paceMinPerKm = minVal / km;
                value = _minPerKmToUser(paceMinPerKm);
              }
              break;
          }
          if (value != null) {
            final d = DateTime(dr.date.year, dr.date.month, dr.date.day);
            map[d] = value;
          }
        } catch (_) {}
      }
    } else {
      final Map<DateTime, List<double>> weeklyList = {};
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final list = _findAeroMenuList(dr);
          if (list == null) continue;
          final m =
              list.firstWhereOrNull((x) => (x as dynamic).name == menuName);
          if (m == null) continue;

          final km = _parseDistanceKm((m as dynamic).distance) ?? 0;
          final minVal = _parseDurationMin((m as dynamic).duration) ?? 0;

          final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
          final weekStart = day.subtract(Duration(days: day.weekday - 1));
          final key = DateTime(weekStart.year, weekStart.month, weekStart.day);

          switch (_aeroMetric) {
            case AerobicMetric.distance:
              weeklyList.putIfAbsent(key, () => []).add(_kmToUser(km));
              break;
            case AerobicMetric.time:
              weeklyList.putIfAbsent(key, () => []).add(minVal);
              break;
            case AerobicMetric.pace:
              if (km > 0 && minVal > 0) {
                final paceMinPerKm = minVal / km;
                weeklyList
                    .putIfAbsent(key, () => [])
                    .add(_minPerKmToUser(paceMinPerKm));
              }
              break;
          }
        } catch (_) {}
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
  double get _tickStart {
    final step = _yLabelStep;
    final minY = _baseMinY;
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

    // 固定刻み
// 固定刻み（文脈で決める：間引きしない／常に固定）
    if (_isStrengthContext()) {
      _yLabelStep = 5.0; // kg / lbs ともに 5 刻み
    } else if (_isPersonalContext()) {
      switch (_personalMetric) {
        case PersonalMetric.weight:
          _yLabelStep = (SettingsManager.currentUnit == 'kg') ? 0.5 : 1.0;
          break;
        case PersonalMetric.bodyFat:
          _yLabelStep = 1.0; // 1%
          break;
        case PersonalMetric.bmi:
          _yLabelStep = 1.0;
          break;
        case PersonalMetric.waist:
          _yLabelStep = _isMetricLength ? 1.0 : 0.5; // cm:1.0 / in:0.5
          break;
      }
    } else {
      // Aerobic
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          _yLabelStep = 1.0;
          break;
        case AerobicMetric.time:
          _yLabelStep = 10.0;
          break;
        case AerobicMetric.pace:
          _yLabelStep = 0.5;
          break;
      }
    }

    double floorTo(double v, double step) => (v / step).floorToDouble() * step;
    double ceilTo(double v, double step) => (v / step).ceilToDouble() * step;

    _baseMinY = floorTo(_minY, _yLabelStep);
    _baseMaxY = ceilTo(_maxY, _yLabelStep);

    _baseMinY =
        floorTo(_baseMinY - _kYPadStepsBottom * _yLabelStep, _yLabelStep);
    _baseMaxY = ceilTo(_baseMaxY + _kYPadStepsTop * _yLabelStep, _yLabelStep);

    if (_isAerobicContext() || _isPersonalContext())
      _baseMinY = max(0, _baseMinY);
  }

  // X軸パディング付き配列
  List<DateTime> get _axisDates {
    if (_xDates.isEmpty) return [];
    final List<DateTime> list = List<DateTime>.from(_xDates);
    final pad =
        (_displayMode == DisplayMode.day) ? _kPadTailDays : _kPadTailWeeks;
    DateTime last = list.last;
    for (int i = 1; i <= pad; i++) {
      last = last.add(Duration(days: _displayMode == DisplayMode.day ? 1 : 7));
      list.add(last);
    }
    return list;
  }

  // ラベル
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

  String _unitOverlayText(AppLocalizations l10n) {
    final bool isPersonal = _isPersonalContext();
    final bool hasMenu = _selectedMenu != null;
    if (!isPersonal && !hasMenu) return '';

    if (_isAerobicContext()) {
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          return _distanceUnit(l10n); // km / mi
        case AerobicMetric.time:
          return l10n.min; // 分
        case AerobicMetric.pace:
          return '${l10n.min}/${_distanceUnit(l10n)}'; // 分/km or 分/mi
      }
    } else if (_isPersonalContext()) {
      switch (_personalMetric) {
        case PersonalMetric.weight:
          return SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
        case PersonalMetric.bodyFat:
          return l10n.percentSymbol;
        case PersonalMetric.bmi:
          return ''; // 単位なし
        case PersonalMetric.waist:
          return _waistUnit(l10n); // cm / in
      }
    }
    return SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
  }

  String _formatTooltipValue(double y, AppLocalizations l10n) {
    if (_isAerobicContext()) {
      switch (_aeroMetric) {
        case AerobicMetric.distance:
          return '${y.toStringAsFixed(2)} ${_distanceUnit(l10n)}';
        case AerobicMetric.time:
          return '${_formatMinToMMSS(y)} ${l10n.min}';
        case AerobicMetric.pace:
          return '${_formatMinToMMSS(y)} ${l10n.min}/${_distanceUnit(l10n)}';
      }
    } else if (_isPersonalContext()) {
      switch (_personalMetric) {
        case PersonalMetric.weight:
          final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
          return '${y.toStringAsFixed(1)} $u';
        case PersonalMetric.bodyFat:
          return '${y.toStringAsFixed(1)} ${l10n.percentSymbol}';
        case PersonalMetric.bmi:
          return y.toStringAsFixed(1);
        case PersonalMetric.waist:
          return '${y.toStringAsFixed(1)} ${_waistUnit(l10n)}';
      }
    }
    final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
    final digits = _isStrengthContext() ? 0 : 1; // 強度は 0 桁
    return '${y.toStringAsFixed(digits)} $u';
  }

  void _checkIfFavorite() {
    final l10n = AppLocalizations.of(context)!;
    String? key;

    if (_isPersonalContext()) {
      key = _favoriteKeyForPersonalMetric(_personalMetric);
    } else if (_selectedMenu != null) {
      key = 'menu:${_selectedMenu!}';
    }

    if (key == null) {
      _isFavorite = false;
      return;
    }

    final rawFavorites = widget.settingsBox.get('favorites');
    final favs = (rawFavorites is List)
        ? rawFavorites.whereType<String>().toList()
        : <String>[];

    // 後方互換：体重のみ旧形式 '体重' もOK
    final legacyHit = (_personalMetric == PersonalMetric.weight)
        ? favs.contains(l10n.bodyWeight)
        : false;

    _isFavorite = favs.contains(key) || legacyHit;
  }

  void _toggleFavorite() {
    final l10n = AppLocalizations.of(context)!;

    String? key;
    String display;

    if (_isPersonalContext()) {
      key = _favoriteKeyForPersonalMetric(_personalMetric);
      display = _personalMetricLabel(l10n);
    } else if (_selectedMenu != null) {
      key = 'menu:${_selectedMenu!}';
      display = _selectedMenu!;
    } else {
      return;
    }

    final rawFavorites = widget.settingsBox.get('favorites');
    final favorites = (rawFavorites is List)
        ? rawFavorites.whereType<String>().toList()
        : <String>[];

    // 後方互換整理：体重のみ旧 '体重' を除去
    favorites.removeWhere((e) => e == null);
    if (key == 'personal:bodyWeight' && favorites.contains(l10n.bodyWeight)) {
      favorites.remove(l10n.bodyWeight);
    }

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

    final msg = willAdd ? l10n.favorited(display) : l10n.unfavorited(display);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _saveGraphPrefs() {
    widget.settingsBox.put(_prefGraphPart, _selectedPart);
    widget.settingsBox.put(_prefGraphMenu, _selectedMenu);
    widget.settingsBox.put(_prefGraphMode, _displayMode.index);
    widget.settingsBox.put(_prefAeroMetric, _aeroMetric.index);
    widget.settingsBox.put(_prefPersonalMetric, _personalMetric.index);
  }

  String _goalStorageKey() {
    String ctx;
    if (_isPersonalContext()) {
      ctx = 'personal_${_personalMetric.name}';
    } else if (_isAerobicContext()) {
      ctx = 'aero_${_aeroMetric.name}_${_selectedMenu ?? ''}';
    } else if (_isStrengthContext()) {
      ctx = 'strength_${_selectedMenu ?? ''}';
    } else {
      ctx = 'unknown';
    }
    final unit = _unitOverlayText(AppLocalizations.of(context)!);
    return 'graph_goal::$ctx::$unit';
  }

  void _loadGoalForCurrentContext() {
    final key = _goalStorageKey();
    final v = widget.settingsBox.get(key);
    double? parsed;
    if (v is num) {
      parsed = v.toDouble();
    } else if (v is String) {
      parsed = _parseDurationMin(v) ?? double.tryParse(v);
    }
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
        (_aeroMetric == AerobicMetric.time ||
            _aeroMetric == AerobicMetric.pace)) {
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

  // ====== 参考レンジ（黄色の点線） ======
  List<double>? _referenceRange() {
    if (_isPersonalContext()) {
      if (_personalMetric == PersonalMetric.bmi) {
        final min =
            (widget.settingsBox.get('bmiRangeMin') as num?)?.toDouble() ?? 18.5;
        final max =
            (widget.settingsBox.get('bmiRangeMax') as num?)?.toDouble() ?? 25.0;
        return [min, max];
      } else if (_personalMetric == PersonalMetric.bodyFat) {
        final overrideMin =
            (widget.settingsBox.get('bodyFatRangeMin') as num?)?.toDouble();
        final overrideMax =
            (widget.settingsBox.get('bodyFatRangeMax') as num?)?.toDouble();
        if (overrideMin != null && overrideMax != null)
          return [overrideMin, overrideMax];
        // 性別未設定時の汎用レンジ
        final gender = _genderFromSettings();
        switch (gender) {
          case 'male':
            return [10.0, 20.0];
          case 'female':
            return [20.0, 30.0];
          default:
            return [14.0, 24.0];
        }
      }
    }
    return null;
  }

  List<HorizontalLine> _referenceLines() {
    final range = _referenceRange();
    if (range == null) return const [];
    return [
      HorizontalLine(
          y: range[0], color: Colors.amber, strokeWidth: 2, dashArray: [6, 4]),
      HorizontalLine(
          y: range[1], color: Colors.amber, strokeWidth: 2, dashArray: [6, 4]),
    ];
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
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(current),
                        child: Text(AppLocalizations.of(context)!.ok),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: current),
                    itemExtent: 36,
                    onSelectedItemChanged: (i) => current = i,
                    children: items
                        .map((e) => Center(
                              child: Text(
                                e,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
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
        .map((v) =>
            '${v.toStringAsFixed(fractionDigits)}${suffix.isNotEmpty ? ' $suffix' : ''}')
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
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx)
                            .pop(Duration(minutes: selMin, seconds: selSec)),
                        child: Text(AppLocalizations.of(context)!.ok),
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
                                child: Text(
                                    '$i ${AppLocalizations.of(context)!.min}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600))),
                          ),
                        ),
                      ),
                      Container(
                          width: 1,
                          color: Theme.of(context).colorScheme.outlineVariant),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: secCtrl,
                          itemExtent: 36,
                          onSelectedItemChanged: (i) => selSec = i,
                          children: List.generate(
                            60,
                            (i) => Center(
                                child: Text(
                                    '$i ${AppLocalizations.of(context)!.sec}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600))),
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

    // PERSONAL
    if (_isPersonalContext()) {
      switch (_personalMetric) {
        case PersonalMetric.weight:
          {
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
        case PersonalMetric.bodyFat:
          {
            final v = await _showNumberPicker(
              title: l10n.bodyFatPercentage,
              minValue: max(0.0, _baseMinY - 5),
              maxValue: (_baseMaxY + 5),
              step: 0.5,
              fractionDigits: 1,
              current: _goalValue,
              suffix: l10n.percentSymbol,
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
        case PersonalMetric.bmi:
          {
            final v = await _showNumberPicker(
              title: 'BMI',
              minValue: max(10.0, _baseMinY - 5),
              maxValue: max(30.0, _baseMaxY + 5),
              step: 0.5,
              fractionDigits: 1,
              current: _goalValue,
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
        case PersonalMetric.waist:
          {
            final waistLabel = (() {
              try {
                return l10n.waist;
              } catch (_) {
                return 'ウエスト';
              }
            })();
            final wu = _waistUnit(l10n);
            final minDefault =
                _isMetricLength ? 40.0 : 16.0; // だいたい 40cm / 16in
            final maxDefault =
                _isMetricLength ? 120.0 : 50.0; // だいたい 120cm / 50in
            final step = _isMetricLength ? 0.5 : 0.25;

            final v = await _showNumberPicker(
              title: waistLabel,
              minValue: max(minDefault, _baseMinY - 5),
              maxValue: max(maxDefault, _baseMaxY + 5),
              step: step,
              fractionDigits: 1,
              current: _goalValue,
              suffix: wu,
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
    }

    // AEROBIC
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
              // ← km固定ではなくユーザーの長さ単位（km / mi）
              suffix: _distanceUnit(l10n),
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
            final init = Duration(
              minutes: ((_goalValue ?? 30).clamp(0, 600)).round(),
            );
            final dur = await _showTimeWheelPicker(
              title: l10n.time,
              suffix: l10n.min,
              initial: init,
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
            final init = Duration(
              seconds: (((_goalValue ?? 6.0) * 60).clamp(60, 60 * 30)).round(),
            );
            final dur = await _showTimeWheelPicker(
              title: l10n.pace,
              // ← これも km 固定ではなくユーザーの長さ単位
              suffix: '${l10n.min}/${_distanceUnit(l10n)}',
              initial: init,
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

    // STRENGTH
    if (_isStrengthContext()) {
      final isKg = SettingsManager.currentUnit == 'kg';
      final step = 5.0; // kg / lbs ともに 5 刻み
      final unit = isKg ? l10n.kg : l10n.lbs;

      double lo = (_baseMinY - 20).floorToDouble();
      double hi = (_baseMaxY + 20).ceilToDouble();
      if (hi < 100) hi = 100;

      final v = await _showNumberPicker(
        title: _selectedMenu ?? '',
        minValue: lo,
        maxValue: hi,
        step: step,
        fractionDigits: 0, // 強度系は常に整数表示
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
          return '${_goalValue!.toStringAsFixed(1)} ${_distanceUnit(l10n)}';
        case AerobicMetric.time:
          return '${_formatMinToMMSS(_goalValue!)} ${l10n.min}';
        case AerobicMetric.pace:
          return '${_formatMinToMMSS(_goalValue!)} ${l10n.min}/${_distanceUnit(l10n)}';
      }
    }

    if (_isPersonalContext()) {
      switch (_personalMetric) {
        case PersonalMetric.weight:
          {
            final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
            return '${_goalValue!.toStringAsFixed(1)} $u';
          }
        case PersonalMetric.bodyFat:
          return '${_goalValue!.toStringAsFixed(1)} ${l10n.percentSymbol}';
        case PersonalMetric.bmi:
          return _goalValue!.toStringAsFixed(1);
        case PersonalMetric.waist:
          return '${_goalValue!.toStringAsFixed(1)} ${_waistUnit(l10n)}';
      }
    }

    final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
    final fd = _isStrengthContext() ? 0 : 1; // 強度は常に整数
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
    final init =
        _selectedMenu != null ? _menusForPart.indexOf(_selectedMenu!) : 0;
    final picked = await _showWheelPicker(
      title: l10n.selectExercise,
      items: _menusForPart,
      initialIndex: init < 0 ? 0 : init,
    );
    if (picked == null) return;
    final value = _menusForPart[picked];
    setState(() {
      _selectedMenu = value;

      // FavoritesでPersonal表示名ならメトリックを同期
      final m = _metricFromDisplay(l10n, value);
      if (_selectedPart == l10n.favorites && m != null) {
        _personalMetric = m;
      }

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
    final isPersonal = _isPersonalContext();
    final unitText = _unitOverlayText(l10n);
    final bool _noMenus = _noMenusForSelectedPart;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryShowGraphCoachIfVisible();
    });
    // 日/週トグル
    Widget dayWeekToggle = SizedBox(
      height: _kControlHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kControlRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: ToggleButtons(
            isSelected: [
              _displayMode == DisplayMode.day,
              _displayMode == DisplayMode.week,
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
        ),
      ),
    );

    // 目標ボタン（未登録部位なら控えめ＆タップでヒント）
    Widget goalButton = Opacity(
      opacity: (_noMenus && !_isPersonalContext()) ? 0.4 : 1.0,
      child: SizedBox(
        height: _kControlHeight,
        child: OutlinedButton(
          key: _kGoal,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            side: BorderSide(color: colorScheme.outlineVariant),
            backgroundColor: colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: (_noMenus && !_isPersonalContext())
              ? () => _showThrottledHint(l10n.hintRecordFirst)
              : _openGoalPicker,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_outlined, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _goalController.text.isEmpty
                      ? l10n.enterGoal
                      : _goalController.text,
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
      ),
    );

    // お気に入り（常時表示。未登録部位のみ無効化）
    final bool favEnabled = !(_noMenus && !_isPersonalContext());

    Widget favButton = Opacity(
      opacity: favEnabled ? 1.0 : 0.4,
      child: FavoritePillButton(
        key: _kFav,
        isFavorite: favEnabled ? _isFavorite : false,
        label: l10n.favorites,
        onTap: favEnabled ? _toggleFavorite : () {},
        height: _kControlHeight,
      ),
    );

    final partDisplay = _selectedPart ?? l10n.selectTrainingPart;
    final menuDisplay = (_selectedPart == l10n.personal)
        ? ''
        : (_selectedMenu ?? l10n.selectExercise);

    Widget partMenuRow = Row(
      children: [
        // 左: 部位
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
                          _selectedPart ?? l10n.selectTrainingPart,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more,
                          color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 右: 種目（Personal のときは「体重/体脂肪率/BMI」をここで選ぶ）
        Expanded(
          child: SizedBox(
            height: _kPickerHeight,
            child: InkWell(
              onTap: isPersonal
                  ? _openPersonalMetricPicker
                  : (_menusForPart.isNotEmpty
                      ? _openMenuPicker
                      : () => _showThrottledHint(l10n.hintRecordFirst)),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isPersonal || _menusForPart.isNotEmpty)
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
                          isPersonal
                              ? _personalMetricLabel(l10n) // ← Personal はここに表示
                              : ((_selectedMenu ?? '').isEmpty
                                  ? l10n.selectExercise
                                  : _selectedMenu!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: (isPersonal || _menusForPart.isNotEmpty)
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        color: (isPersonal || _menusForPart.isNotEmpty)
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // AEROBIC トグル
    Widget? aerobicToggle = isAerobic
        ? SizedBox(
            height: _kControlHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kControlRadius),
                ),
                clipBehavior: Clip.antiAlias,
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
                      _loadGoalForCurrentContext();
                    });
                  },
                  constraints: const BoxConstraints(minHeight: _kControlHeight),
                  borderRadius: BorderRadius.circular(_kControlRadius),
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
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: SettingsManager.backgroundAssetNotifier.value.isEmpty
          ? null
          : Colors.transparent,
      appBar: AppBar(
        // カレンダー画面と同じ配置に合わせる（左に16pxの余白）
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        titleSpacing: 16, // ← これでカレンダーと同じ左寄せ位置
        centerTitle: false,
        title: Text(
          l10n.graphScreenTitle,
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),

      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeKeyboard,
          child: CenteredConstrained(
            maxWidth: 760,
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

                if (aerobicToggle != null) ...[
                  const SizedBox(height: 8),
                  aerobicToggle,
                ],

                const SizedBox(height: 8),

                // ====== グラフ ======
                Expanded(
                  child: Card(
                    key: _kChart,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalW = constraints.maxWidth;
                          final totalH = constraints.maxHeight;

                          _plotHeightPx = totalH;
                          final yAxisPanelW =
                              _axisDates.isEmpty ? 0.0 : _kYAxisWidth;
                          final plotAvailW =
                              max(60.0, totalW - yAxisPanelW - 4);
                          final points = max(1, _axisDates.length);
                          final chartW = max(plotAvailW, points * _kXStridePx);

                          final unitOverlay =
                              (unitText.isEmpty || _axisDates.isEmpty)
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

                          // 目標 & 参考レンジ込みの表示レンジ
                          double viewMinY = _baseMinY;
                          double viewMaxY = _baseMaxY;

                          final ref = _referenceRange();
                          if (ref != null) {
                            viewMinY = min(viewMinY, ref[0]);
                            viewMaxY = max(viewMaxY, ref[1]);
                          }
                          if (_goalValue != null) {
                            viewMinY = min(viewMinY, _goalValue!);
                            viewMaxY = max(viewMaxY, _goalValue!);
                          }

                          viewMinY =
                              (viewMinY / _yLabelStep).floor() * _yLabelStep -
                                  _kYPadStepsBottom * _yLabelStep;
                          viewMaxY =
                              (viewMaxY / _yLabelStep).ceil() * _yLabelStep +
                                  _kYPadStepsTop * _yLabelStep;

                          if (_isAerobicContext() || _isPersonalContext()) {
                            viewMinY = max(0, viewMinY);
                          }

                          final tickCount =
                              ((viewMaxY - viewMinY) / _yLabelStep).round() + 1;
                          final double computedChartH =
                              24 + (tickCount - 1) * _kYTickPx + 24;
                          final double chartH = max(totalH, computedChartH);

                          // 左Y軸
                          final yAxisChart = SizedBox(
                            width: yAxisPanelW,
                            height: chartH,
                            child: _axisDates.isEmpty
                                ? const SizedBox.shrink()
                                : LineChart(
                                    LineChartData(
                                      minX: 0,
                                      maxX: 1,
                                      minY: viewMinY,
                                      maxY: viewMaxY,
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
                                            reservedSize: _kXAxisReservedPx,
                                            getTitlesWidget: (v, meta) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
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
                                            color: colorScheme.outlineVariant,
                                          ),
                                          bottom: BorderSide(
                                            color: colorScheme.outlineVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          );

                          // 右側プロット
                          final plotArea = _axisDates.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.noGraphData,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                      height: 1.15,
                                      letterSpacing: 0,
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
                                          maxX: (_axisDates.length - 1)
                                              .toDouble(),
                                          minY: viewMinY,
                                          maxY: viewMaxY,
                                          clipData: const FlClipData.all(),
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
                                                reservedSize: _kXAxisReservedPx,
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
                                              color: colorScheme.outlineVariant,
                                              strokeWidth: 0.5,
                                            ),
                                            getDrawingVerticalLine: (v) =>
                                                FlLine(
                                              color: colorScheme.outlineVariant,
                                              strokeWidth: 0.5,
                                            ),
                                          ),
                                          borderData: FlBorderData(
                                            show: true,
                                            border: Border(
                                              bottom: BorderSide(
                                                color:
                                                    colorScheme.outlineVariant,
                                              ),
                                              right: BorderSide(
                                                color:
                                                    colorScheme.outlineVariant,
                                              ),
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
                                                return items.map(
                                                  (s) {
                                                    final i = s.x.toInt();
                                                    final d = (i >= 0 &&
                                                            i < _xDates.length)
                                                        ? _xDates[i]
                                                        : null;
                                                    final dateStr =
                                                        (_displayMode ==
                                                                DisplayMode.day)
                                                            ? (d != null
                                                                ? DateFormat(
                                                                        'M/d',
                                                                        loc)
                                                                    .format(d)
                                                                : '')
                                                            : (d != null
                                                                ? _formatWeekLabel(
                                                                    d)
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
                                                  },
                                                ).toList();
                                              },
                                            ),
                                          ),
                                          extraLinesData: ExtraLinesData(
                                            horizontalLines: <HorizontalLine>[
                                              // 参考レンジ（黄色点線）
                                              ..._referenceLines(),
                                              // 目標
                                              if (_goalValue != null)
                                                HorizontalLine(
                                                  y: _goalValue!,
                                                  color: colorScheme.tertiary,
                                                  strokeWidth: 2,
                                                  dashArray: [6, 4],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                          // 縦スクロールで同期
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
