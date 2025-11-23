// lib/screens/graph_screen.dart
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
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

enum DisplayMode { day, week, month }

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
        _menusForPart.isEmpty;
  }

  // 設定キー
  static const String _prefGraphPart = 'graph_selected_part';
  static const String _prefGraphMenu = 'graph_selected_menu';
  static const String _prefGraphMode = 'graph_display_mode';
  static const String _prefAeroMetric = 'graph_aero_metric';
  static const String _prefPersonalMetric = 'graph_personal_metric';
  static const String _prefPersonalMetricKey = 'graph_personal_metric_key';
  static const String _prefFavoritesKey = 'graph_favorites_v2';
  static const String _prefFavoritesKeyV3 = 'graph_favorites_v3';
  static const String _kFavoritesOriginal = 'お気に入り';
  static const String _kFavoritesNew = 'お気に入り（新）';
  static const Set<String> _kDefaultFavoriteCanonicalKeys = {
    'personal:weight',
    'personal:bodyFat',
    'personal:bmi',
    'personal:waist',
  };

  // UI寸法
  static const double _kControlHeight = 32.0;
  static const double _kControlRadius = 16.0;
  static const double _kPickerHeight = 36.0;

  // X1点あたり幅
  static const double _kXStridePx = 24.0;

  // Y目盛の“見た目”間隔：固定 24px（初期余白も 24px）
  static const double _kYTickPx = 24.0;
  static const double _kYAxisWidth = 30.0;

  // X軸ラベル領域の高さ（左右で統一）
  static const double _kXAxisReservedPx = 24.0;

  // Y軸スクロール開始を早める上下の“空き目盛”数
  static const int _kYPadStepsTop = 2;
  static const int _kYPadStepsBottom = 2;

  // X の右余白スクロール
  static const int _kPadTailDays = 60;
  static const int _kPadTailWeeks = 20;
  static const int _kPadTailMonths = 24;

  // プロット領域高さ（レイアウト時に更新）
  double _plotHeightPx = 1.0;

  // 選択状態
  List<String> _filteredBodyParts = [];
  final Map<String, String> _partLabelToOriginal = {};
  String? _selectedPart;
  String? _selectedPartOriginal;
  List<String> _menusForPart = [];
  String? _selectedMenu;
  final Map<String, String> _favoriteDisplayToKey = {};
  DisplayMode _displayMode = DisplayMode.day;
  AerobicMetric _aeroMetric = AerobicMetric.distance;
  PersonalMetric _personalMetric = PersonalMetric.weight;
  String _selectedPersonalMetricKey = 'personal:weight';
  bool _isFavorite = false;
  StreamSubscription<BoxEvent>? _settingsSubscription;
  bool _showBodyFatMetric = false;
  bool _showBmiMetric = false;
  bool _showWaistMetric = false;
  bool _showWeightMetric = true;

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
    final cached = _partLabelToOriginal[translatedPart];
    if (cached != null) return cached;
    final l10n = AppLocalizations.of(context)!;
    if (translatedPart == l10n.aerobicExercise) return '有酸素運動';
    if (translatedPart == l10n.personal) return 'パーソナル';
    if (translatedPart == l10n.arm) return '腕';
    if (translatedPart == l10n.chest) return '胸';
    if (translatedPart == l10n.back) return '背中';
    if (translatedPart == l10n.shoulder) return '肩';
    if (translatedPart == l10n.leg) return '足';
    if (translatedPart == l10n.abs) return '腹筋';
    if (translatedPart == l10n.fullBody) return '全身';
    if (translatedPart == l10n.bodyWeightTraining) return '自重';
    if (translatedPart == l10n.other1) return 'その他１';
    if (translatedPart == l10n.other2) return 'その他２';
    if (translatedPart == l10n.other3) return 'その他３';
    if (translatedPart == l10n.favorites) return _kFavoritesOriginal;
    return translatedPart;
  }

  void _setSelectedPart(String? value) {
    _selectedPart = value;
    if (value == null) {
      _selectedPartOriginal = null;
      return;
    }
    if (!mounted) {
      _selectedPartOriginal =
          _partLabelToOriginal[value] ?? value;
      return;
    }
    _selectedPartOriginal = _getOriginalPartName(context, value);
  }

  void _syncPersonalMetricFromFavorite(
      AppLocalizations l10n, String display) {
    final rawKey = _favoriteDisplayToKey[display] ?? display;
    final metric =
        _personalMetricFromKey(rawKey) ?? _metricFromDisplay(l10n, rawKey);
    if (metric != null) {
      final key = _personalMetricKey(metric);
      final changed =
          metric != _personalMetric || _selectedPersonalMetricKey != key;
      _personalMetric = metric;
      _selectedPersonalMetricKey = key;
      if (changed) {
        _saveGraphPrefs();
      }
    }
  }

  static const Map<PersonalMetric, String> _kPersonalMetricKeys = {
    PersonalMetric.weight: 'personal:weight',
    PersonalMetric.bodyFat: 'personal:bodyFat',
    PersonalMetric.bmi: 'personal:bmi',
    PersonalMetric.waist: 'personal:waist',
  };

  PersonalMetric? _personalMetricFromKey(String? key) {
    if (key == null) return null;
    final normalized = key.trim();
    switch (normalized) {
      case 'personal:weight':
      case 'personal:bodyWeight':
      case 'personal:bodyweight':
        return PersonalMetric.weight;
      case 'personal:bodyFat':
      case 'personal:bodyfat':
      case 'personal:bodyFatPercentage':
      case 'personal:bodyfatpercentage':
        return PersonalMetric.bodyFat;
      case 'personal:bmi':
        return PersonalMetric.bmi;
      case 'personal:waist':
        return PersonalMetric.waist;
    }
    final lower = normalized.toLowerCase();
    switch (lower) {
      case 'personal:weight':
        return PersonalMetric.weight;
      case 'personal:bodyfat':
        return PersonalMetric.bodyFat;
      case 'personal:bmi':
        return PersonalMetric.bmi;
      case 'personal:waist':
        return PersonalMetric.waist;
    }
    return null;
  }

  String _personalMetricKey(PersonalMetric metric) {
    return _kPersonalMetricKeys[metric]!;
  }

  String _normalizedFavoriteEntry(AppLocalizations l10n, String entry) {
    final trimmed = entry.trim();
    if (trimmed.startsWith('menu:')) return trimmed;
    final metric =
        _personalMetricFromKey(trimmed) ?? _metricFromDisplay(l10n, trimmed);
    if (metric != null) {
      return _personalMetricKey(metric);
    }
    return trimmed;
  }

  bool _isPersonalMetricEnabled(PersonalMetric metric) {
    switch (metric) {
      case PersonalMetric.weight:
        return _showWeightMetric;
      case PersonalMetric.bodyFat:
        return _showBodyFatMetric;
      case PersonalMetric.bmi:
        return _showBmiMetric;
      case PersonalMetric.waist:
        return _showWaistMetric;
    }
  }

  void _ensureValidPersonalMetric() {
    if (!_isPersonalMetricEnabled(_personalMetric)) {
      final options = _availablePersonalMetrics();
      if (options.isNotEmpty) {
        _personalMetric = options.first;
        _selectedPersonalMetricKey = _personalMetricKey(_personalMetric);
      }
    }
  }

  List<PersonalMetric> _availablePersonalMetrics() {
    final options = <PersonalMetric>[];
    // Only add weight if explicitly enabled
    if (_showWeightMetric) {
      options.add(PersonalMetric.weight);
    }
    if (_showBodyFatMetric) options.add(PersonalMetric.bodyFat);
    if (_showBmiMetric) options.add(PersonalMetric.bmi);
    if (_showWaistMetric) options.add(PersonalMetric.waist);
    
    return options;
  }

  String _personalMetricLabel(AppLocalizations l10n) {
    final options = _availablePersonalMetrics();
    if (options.isEmpty) return '-';
    final metric =
        _personalMetricFromKey(_selectedPersonalMetricKey) ?? _personalMetric;
    return _labelForMetric(l10n, metric);
  }

  String _labelForMetric(AppLocalizations l10n, PersonalMetric metric) {
    final waistLabel = (() {
      try {
        return l10n.waist;
      } catch (_) {
        return 'ウエスト';
      }
    })();
    switch (metric) {
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
    final trimmed = label.trim();
    final lowerLabel = trimmed.toLowerCase();
    if (trimmed.startsWith('personal:')) {
      final metric = _personalMetricFromKey(trimmed);
      if (metric != null) return metric;
    }
    if (trimmed.startsWith('menu:')) {
      return null;
    }
    final weightSynonyms = <String>{
      l10n.bodyWeight.toLowerCase(),
      'body weight',
      'bodyweight',
      'weight',
      'bw',
      '体重',
    };
    if (trimmed == l10n.bodyWeight || trimmed == 'personal:bodyWeight') {
      return PersonalMetric.weight;
    }
    if (weightSynonyms.contains(lowerLabel)) {
      return PersonalMetric.weight;
    }
    final bodyFatSynonyms = <String>{
      l10n.bodyFatPercentage.toLowerCase(),
      'body fat',
      'bodyfat',
      'fat',
      '体脂肪',
      '体脂肪率',
    };
    if (trimmed == l10n.bodyFatPercentage) return PersonalMetric.bodyFat;
    if (bodyFatSynonyms.contains(lowerLabel)) return PersonalMetric.bodyFat;
    if (trimmed.toUpperCase() == 'BMI') return PersonalMetric.bmi;
    final waistSynonyms = <String>{
      waistLabel.toLowerCase(),
      'waist',
      'waistline',
      'ウエスト',
    };
    if (trimmed == waistLabel) return PersonalMetric.waist;
    if (waistSynonyms.contains(lowerLabel)) return PersonalMetric.waist;
    final fallback = _personalMetricFromKey(_selectedPersonalMetricKey);
    if (fallback != null) return fallback;
    return null;
  }

  String _favoriteKeyForPersonalMetric(PersonalMetric m) {
    return _personalMetricKey(m);
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
    if (key == 'personal:weight') return l10n.bodyWeight;
    if (key == 'personal:bodyFat') return l10n.bodyFatPercentage;
    if (key == 'personal:bmi') return 'BMI';
    if (key == 'personal:waist') return waistLabel;
    if (key.startsWith('menu:')) return key.substring(5);
    return key; // 後方互換・未知キー
  }


  Future<void> _openPersonalMetricPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final options = _availablePersonalMetrics();
    if (options.isEmpty) return;
    final labels = options.map((m) => _labelForMetric(l10n, m)).toList();
    int initialIndex = options.indexOf(_personalMetric);
    if (initialIndex < 0) initialIndex = 0;
    final picked = await _showWheelPicker(
      title: l10n.selectExercise,
      items: labels,
      initialIndex: initialIndex,
    );
    if (picked == null) return;
    setState(() {
      _personalMetric = options[picked];
      _selectedPersonalMetricKey = _personalMetricKey(_personalMetric);
      _saveGraphPrefs();
      _loadPersonalData();
      _loadGoalForCurrentContext();
    });
    _checkIfFavoriteNew(); // ← 追加：指標切替後に再判定
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
      case '腹筋':
        return l10n.abs;
      case '全身':
        return l10n.fullBody;
      case '自重':
        return l10n.bodyWeightTraining;
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
    _graphCoachDone = true;
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

  final ScrollController _verticalScrollController1 = ScrollController();
  final ScrollController _verticalScrollController2 = ScrollController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    _settingsSubscription =
        widget.settingsBox.watch().listen(_handleSettingsBoxEvent);

    _verticalScrollController1.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      if (_verticalScrollController1.hasClients &&
          _verticalScrollController2.hasClients) {
        _verticalScrollController2
            .jumpTo(_verticalScrollController1.position.pixels);
      }
      _isSyncing = false;
    });

    _verticalScrollController2.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      if (_verticalScrollController1.hasClients &&
          _verticalScrollController2.hasClients) {
        _verticalScrollController1
            .jumpTo(_verticalScrollController2.position.pixels);
      }
      _isSyncing = false;
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _verticalScrollController1.dispose();
    _verticalScrollController2.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _loadSettingsAndParts() {
    final l10n = AppLocalizations.of(context)!;

    _cleanupFavorites(); // Ensure cleanup on startup

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

    _showWeightMetric =
        (widget.settingsBox.get('show_weight_input') as bool?) ?? true;
    _showBodyFatMetric =
        (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    _showBmiMetric = (widget.settingsBox.get('manage.bmi') as bool?) ?? false;
    _showWaistMetric =
        (widget.settingsBox.get('manage.waist') as bool?) ?? false;

    PersonalMetric? savedPersonalMetric;
    final dynamic rawPersonalKey =
        widget.settingsBox.get(_prefPersonalMetricKey);
    if (rawPersonalKey is String) {
      savedPersonalMetric = _personalMetricFromKey(rawPersonalKey) ??
          _metricFromDisplay(l10n, rawPersonalKey);
      if (savedPersonalMetric != null) {
        _selectedPersonalMetricKey = _personalMetricKey(savedPersonalMetric);
      }
    }

    if (savedPersonalMetric == null) {
      final int? savedPersIdx =
          widget.settingsBox.get(_prefPersonalMetric) as int?;
      if (savedPersIdx != null &&
          savedPersIdx >= 0 &&
          savedPersIdx < PersonalMetric.values.length) {
        savedPersonalMetric = PersonalMetric.values[savedPersIdx];
      }
    }

    if (savedPersonalMetric != null) {
      _personalMetric = savedPersonalMetric;
      _selectedPersonalMetricKey = _personalMetricKey(_personalMetric);
    } else {
      _personalMetric = PersonalMetric.weight;
      _selectedPersonalMetricKey = _personalMetricKey(_personalMetric);
    }

    _ensureValidPersonalMetric();

    // 部位リスト（パーソナルは別扱い）
    final allBodyParts = [
      '有酸素運動',
      '腕',
      '胸',
      '背中',
      '肩',
      '足',
      '腹筋',
      '全身',
      '自重',
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

    final baseOriginalParts = (savedBodyPartsSettings == null ||
            savedBodyPartsSettings.isEmpty)
        ? List<String>.from(allBodyParts)
        : allBodyParts
            .where((p) => savedBodyPartsSettings![p] == true)
            .toList();

    _filteredBodyParts = [];
    _partLabelToOriginal.clear();

    final personalLabel = l10n.personal;
    _filteredBodyParts.add(personalLabel);
    _partLabelToOriginal[personalLabel] = 'パーソナル';

    // Add new favorites
    _filteredBodyParts.add('お気に入り');
    _partLabelToOriginal['お気に入り'] = _kFavoritesNew;

    for (final original in baseOriginalParts) {
      final label = _translatePartToLocale(context, original);
      _filteredBodyParts.add(label);
      _partLabelToOriginal[label] = original;
    }

    final String? savedPart = widget.settingsBox.get(_prefGraphPart) as String?;
    if (savedPart != null && _filteredBodyParts.contains(savedPart)) {
      _setSelectedPart(savedPart);
    } else if (_filteredBodyParts.isNotEmpty) {
      _setSelectedPart(_filteredBodyParts.first);
    } else {
      _setSelectedPart(null);
    }

    if (mounted) {
      setState(() {
        if (_selectedPart != null) _loadMenusForPart(_selectedPart!);
      });
    }
  }

  bool _isLegacyDefaultFavorite(String raw, AppLocalizations l10n) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return true;
    if (_isLegacyDefaultFavoriteLabel(l10n, trimmed)) return true;
    if (trimmed.startsWith('menu:')) {
      final label = trimmed.substring(5);
      if (_isLegacyDefaultFavoriteLabel(l10n, label)) return true;
    }
    final canonical = _canonicalFavoriteKey(trimmed, l10n);
    if (canonical != null &&
        _kDefaultFavoriteCanonicalKeys.contains(canonical)) {
      return true;
    }
    return false;
  }

  bool _isLegacyDefaultFavoriteLabel(AppLocalizations l10n, String value) {
    final waistLabel = (() {
      try {
        return l10n.waist;
      } catch (_) {
        return 'ウエスト';
      }
    })();
    final lower = value.toLowerCase();
    
    // Check localized and English defaults
    if (value == l10n.bodyWeight ||
        lower == l10n.bodyWeight.toLowerCase() ||
        lower == 'weight' ||
        lower == 'body weight') {
      return true;
    }
    if (value == l10n.bodyFatPercentage ||
        lower == l10n.bodyFatPercentage.toLowerCase() ||
        lower == 'body fat' ||
        lower == 'body fat %') {
      return true;
    }
    if (value.toUpperCase() == 'BMI') {
      return true;
    }
    if (value == waistLabel ||
        lower == waistLabel.toLowerCase() ||
        lower == 'waist') {
      return true;
    }
    if (_isAerobicLabel(value, l10n)) {
      return true;
    }
    return false;
  }

  String? _canonicalFavoriteKey(String raw, AppLocalizations l10n) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('personal:') || trimmed.startsWith('menu:')) {
      return trimmed;
    }

    final metric =
        _personalMetricFromKey(trimmed) ?? _metricFromDisplay(l10n, trimmed);
    if (metric != null) {
      return _favoriteKeyForPersonalMetric(metric);
    }

    if (_isAerobicLabel(trimmed, l10n)) {
      return 'menu:${l10n.aerobicExercise}';
    }

    return null;
  }

  bool _isAerobicLabel(String label, AppLocalizations l10n) {
    final lower = label.toLowerCase();
    final aerobicLabels = {
      l10n.aerobicExercise.toLowerCase(),
      'aerobic',
      'aerobic exercise',
      '有酸素運動',
    };
    return aerobicLabels.contains(lower);
  }

  void _handleSettingsBoxEvent(BoxEvent event) {
    const keys = {
      'manage.bodyFat',
      'manage.bmi',
      'manage.waist',
      'show_weight_input'
    };
    if (!keys.contains(event.key)) return;
    if (!mounted) return;

    final newWeight =
        (widget.settingsBox.get('show_weight_input') as bool?) ?? true;
    final newBodyFat =
        (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    final newBmi = (widget.settingsBox.get('manage.bmi') as bool?) ?? false;
    final newWaist =
        (widget.settingsBox.get('manage.waist') as bool?) ?? false;

    final changed = newWeight != _showWeightMetric ||
        newBodyFat != _showBodyFatMetric ||
        newBmi != _showBmiMetric ||
        newWaist != _showWaistMetric;
    if (!changed) return;

    _showWeightMetric = newWeight;
    _showBodyFatMetric = newBodyFat;
    _showBmiMetric = newBmi;
    _showWaistMetric = newWaist;
    _ensureValidPersonalMetric();

    // Ensure disabled metrics are removed from favorites
    _cleanupFavorites();

    _loadPersonalData();
    if (_selectedPart != null &&
        _selectedPartOriginal == _kFavoritesOriginal) {
      _loadMenusForPart(_selectedPart!);
    } else {
      _checkIfFavoriteNew();
    }
    _saveGraphPrefs();
  }

  void _cleanupFavorites() {
    final l10n = AppLocalizations.of(context)!;
    final dynamic rawFavorites = widget.settingsBox.get(_prefFavoritesKey);
    if (rawFavorites is! List) return;

    final favList = rawFavorites.whereType<String>().toList();
    final validKeys = <String>[];
    bool changed = false;

    for (final rawKey in favList) {
      if (_isLegacyDefaultFavorite(rawKey, l10n)) {
        changed = true;
        continue;
      }

      final canonical = _canonicalFavoriteKey(rawKey, l10n);
      if (canonical == null) {
        changed = true;
        continue;
      }

      if (_kDefaultFavoriteCanonicalKeys.contains(canonical)) {
        changed = true;
        continue;
      }

      if (canonical.startsWith('personal:')) {
        changed = true;
        continue;
      }

      validKeys.add(canonical);
    }

    if (changed || validKeys.length != favList.length) {
      widget.settingsBox.put(_prefFavoritesKey, validKeys);
    }
  }

  // ====== load menus ======
  void _loadMenusForPart(String translatedPart) {
    final l10n = AppLocalizations.of(context)!;

    final partOriginal = _getOriginalPartName(context, translatedPart);

    // パーソナル：メニューは不要（画面内のトグルで切替）
    if (partOriginal == 'パーソナル') {
      _menusForPart = [];
      _selectedMenu = null;
      _loadPersonalData();
      _saveGraphPrefs();
      _loadGoalForCurrentContext();
      setState(() {});
      return;
    }

    _menusForPart.clear();
    _favoriteDisplayToKey.clear();

    if (partOriginal == _kFavoritesOriginal) {
      _favoriteDisplayToKey.clear();
      _menusForPart = ['-'];
    } else if (partOriginal == _kFavoritesNew) {
      // Load from new favorites v3
      final dynamic rawFavorites = widget.settingsBox.get(_prefFavoritesKeyV3);
      if (rawFavorites is List) {
        final favList = rawFavorites.whereType<String>().toList();
        final displays = <String>[];
        
        for (final rawKey in favList) {
          if (rawKey.startsWith('menu:')) {
            final menuName = rawKey.substring(5);
            displays.add(menuName);
            _favoriteDisplayToKey[menuName] = rawKey;
          }
        }
        _menusForPart = displays;
      }
      if (_menusForPart.isEmpty) {
        _menusForPart = ['-'];
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
    if (partOriginal == _kFavoritesOriginal && _selectedMenu != null) {
      _syncPersonalMetricFromFavorite(l10n, _selectedMenu!);
    }

    if (mounted) {
      setState(() {
        if (_selectedMenu == null) {
          _spots = [];
          _xDates = [];
          _minY = 0;
          _maxY = 0;
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
    if (_selectedPartOriginal == _kFavoritesOriginal &&
        _selectedMenu != null) {
      _syncPersonalMetricFromFavorite(l10n, _selectedMenu!);
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
    _checkIfFavoriteNew();
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
    final original = _selectedPartOriginal;
    return original == '有酸素運動' ||
        (original == _kFavoritesOriginal && _menuIsAerobic(_selectedMenu));
  }

  bool _isPersonalContext() {
    final l10n = AppLocalizations.of(context)!;
    final original = _selectedPartOriginal;
    if (original == 'パーソナル') return true;
    if (original == _kFavoritesOriginal) {
      if (_selectedMenu != null) {
        final display = _selectedMenu!;
        final rawKey = _favoriteDisplayToKey[display] ?? display;
        if (rawKey.startsWith('personal:')) return true;
        if (_metricFromDisplay(l10n, rawKey) != null) return true;
        // If a menu is selected and it's not personal, it's NOT personal context
        return false;
      }
      if (_selectedPersonalMetricKey.startsWith('personal:')) return true;
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
    _ensureValidPersonalMetric();
    final metric =
        _personalMetricFromKey(_selectedPersonalMetricKey) ?? _personalMetric;
    _personalMetric = metric;
    final key = _personalMetricKey(metric);
    if (_selectedPersonalMetricKey != key) {
      _selectedPersonalMetricKey = key;
    }

    if (_displayMode == DisplayMode.day) {
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
          double? v;
          switch (key) {
            case 'personal:weight':
              {
                final wKg = _safeWeightKg(dr);
                if (wKg != null) v = _kgToUser(wKg); // ← 週もユーザー単位で表示
                break;
              }
            case 'personal:bodyFat':
              v = _safeBodyFat(dr);
              break;
            case 'personal:bmi':
              {
                final wKg = _safeWeightKg(dr);
                final h =
                    _heightMetersFromSettings() ?? _heightMetersFromRecord(dr);
                if (wKg != null && h != null && h > 0) v = wKg / (h * h);
                break;
              }
            case 'personal:waist':
              {
                final w = _safeWaist(dr); // 保存は cm
                if (w != null) v = _waistToUser(w); // ← 週も cm / in に変換
                break;
              }
            default:
              break;
          }
          if (v != null) map[day] = v;
        } catch (_) {}
      }
    } else if (_displayMode == DisplayMode.week) {
      // 週集計（体重/ウエストもユーザー単位で）
      final Map<DateTime, List<double>> wk = {};
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
          final weekStart = day.subtract(Duration(days: day.weekday - 1));
          final weekKey =
              DateTime(weekStart.year, weekStart.month, weekStart.day);

          double? v;
          switch (key) {
            case 'personal:weight':
              {
                // まず kg で安全取得 → 表示単位へ変換
                final wKg = _safeWeightKg(dr);
                if (wKg != null) v = _kgToUser(wKg);
                break;
              }
            case 'personal:bodyFat':
              v = _safeBodyFat(dr);
              break;
            case 'personal:bmi':
              {
                final wKg = _safeWeightKg(dr);
                final h =
                    _heightMetersFromSettings() ?? _heightMetersFromRecord(dr);
                if (wKg != null && h != null && h > 0) v = wKg / (h * h);
                break;
              }
            case 'personal:waist':
              {
                // 保存は cm 想定 → 表示単位へ変換
                final w = _safeWaist(dr);
                if (w != null) v = _waistToUser(w);
                break;
              }
            default:
              break;
          }

          if (v != null) wk.putIfAbsent(weekKey, () => []).add(v);
        } catch (_) {}
      }

      // 週平均
      wk.forEach((k, list) {
        if (list.isNotEmpty) {
          map[k] = list.reduce((a, b) => a + b) / list.length;
        }
      });
    } else {
      final Map<DateTime, List<double>> monthly = {};
      for (final r in records) {
        try {
          final dr = r as dynamic;
          final day = DateTime(dr.date.year, dr.date.month, dr.date.day);
          final monthKey = DateTime(day.year, day.month, 1);

          double? v;
          switch (key) {
            case 'personal:weight':
              {
                final wKg = _safeWeightKg(dr);
                if (wKg != null) v = _kgToUser(wKg);
                break;
              }
            case 'personal:bodyFat':
              v = _safeBodyFat(dr);
              break;
            case 'personal:bmi':
              {
                final wKg = _safeWeightKg(dr);
                final h =
                    _heightMetersFromSettings() ?? _heightMetersFromRecord(dr);
                if (wKg != null && h != null && h > 0) v = wKg / (h * h);
                break;
              }
            case 'personal:waist':
              {
                final w = _safeWaist(dr);
                if (w != null) v = _waistToUser(w);
                break;
              }
            default:
              break;
          }

          if (v != null) monthly.putIfAbsent(monthKey, () => []).add(v);
        } catch (_) {}
      }

      monthly.forEach((k, list) {
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
    } else if (_displayMode == DisplayMode.week) {
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
    } else {
      final Map<DateTime, double> monthlyMax = {};
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
            final monthKey = DateTime(day.year, day.month, 1);
            monthlyMax.update(monthKey, (old) => max(old, maxW),
                ifAbsent: () => maxW);
          }
        } catch (_) {}
      }
      map.addAll(monthlyMax);
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
    } else if (_displayMode == DisplayMode.week) {
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
    } else {
      final Map<DateTime, List<double>> monthlyList = {};
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
          final monthKey = DateTime(day.year, day.month, 1);

          switch (_aeroMetric) {
            case AerobicMetric.distance:
              monthlyList.putIfAbsent(monthKey, () => []).add(_kmToUser(km));
              break;
            case AerobicMetric.time:
              monthlyList.putIfAbsent(monthKey, () => []).add(minVal);
              break;
            case AerobicMetric.pace:
              if (km > 0 && minVal > 0) {
                final paceMinPerKm = minVal / km;
                monthlyList
                    .putIfAbsent(monthKey, () => [])
                    .add(_minPerKmToUser(paceMinPerKm));
              }
              break;
          }
        } catch (_) {}
      }

      monthlyList.forEach((k, list) {
        if (list.isEmpty) return;
        double value;
        switch (_aeroMetric) {
          case AerobicMetric.distance:
          case AerobicMetric.time:
            value = list.reduce((a, b) => a + b);
            break;
          case AerobicMetric.pace:
            value = list.reduce((a, b) => a + b) / list.length;
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
    final DateTime first = sortedDates.first;
    final DateTime last = sortedDates.last;
    late DateTime cursor;

    if (_displayMode == DisplayMode.day) {
      cursor = first;
      while (!cursor.isAfter(last)) {
        full.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    } else if (_displayMode == DisplayMode.week) {
      cursor = first;
      while (!cursor.isAfter(last)) {
        final wkStart = cursor.subtract(Duration(days: cursor.weekday - 1));
        if (full.isEmpty || full.last != wkStart) {
          full.add(wkStart);
        }
        cursor = cursor.add(const Duration(days: 7));
      }
    } else {
      final DateTime firstMonth = DateTime(first.year, first.month, 1);
      final DateTime lastMonth = DateTime(last.year, last.month, 1);
      cursor = firstMonth;
      while (!cursor.isAfter(lastMonth)) {
        full.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    }

    _xDates = full;
    final indexByDate = <DateTime, int>{};
    for (int i = 0; i < full.length; i++) {
      indexByDate[full[i]] = i;
    }

    for (final d in sortedDates) {
      late final DateTime key;
      if (_displayMode == DisplayMode.day) {
        key = d;
      } else if (_displayMode == DisplayMode.week) {
        key = d.subtract(Duration(days: d.weekday - 1));
      } else {
        key = DateTime(d.year, d.month, 1);
      }
      final idx = indexByDate[key]!;
      final y = map[d]!;
      _spots.add(FlSpot(idx.toDouble() + 1, y));
      _minY = (_spots.length == 1) ? y : min(_minY, y);
      _maxY = (_spots.length == 1) ? y : max(_maxY, y);
    }

    // 固定刻み
// 固定刻み（文脈で決める：間引きしない／常に固定）
    if (_isStrengthContext()) {
      _yLabelStep = 5.0; // kg / lbs ともに 5 刻み
    } else if (_isPersonalContext()) {
      final personalKey = _personalMetricKey(
          _personalMetricFromKey(_selectedPersonalMetricKey) ??
              _personalMetric);
      switch (personalKey) {
        case 'personal:weight':
          _yLabelStep = (SettingsManager.currentUnit == 'kg') ? 0.5 : 1.0;
          break;
        case 'personal:bodyFat':
          _yLabelStep = 1.0; // 1%
          break;
        case 'personal:bmi':
          _yLabelStep = 1.0;
          break;
        case 'personal:waist':
          _yLabelStep = _isMetricLength ? 1.0 : 0.5; // cm:1.0 / in:0.5
          break;
        default:
          _yLabelStep = 1.0;
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

    _baseMinY = max(0, _baseMinY);
  }

  // X軸パディング付き配列
  List<DateTime> get _axisDates {
    if (_xDates.isEmpty) return [];
    final List<DateTime> list = List<DateTime>.from(_xDates);
    final int pad;
    if (_displayMode == DisplayMode.day) {
      pad = _kPadTailDays;
    } else if (_displayMode == DisplayMode.week) {
      pad = _kPadTailWeeks;
    } else {
      pad = _kPadTailMonths;
    }
    DateTime last = list.last;
    for (int i = 1; i <= pad; i++) {
      if (_displayMode == DisplayMode.day) {
        last = last.add(const Duration(days: 1));
      } else if (_displayMode == DisplayMode.week) {
        last = last.add(const Duration(days: 7));
      } else {
        last = DateTime(last.year, last.month + 1, last.day);
      }
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

  String _formatMonthLabel(DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('yyyy/M', locale).format(d);
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final dates = _axisDates;
    if (dates.isEmpty) return const SizedBox.shrink();
    if ((value - value.round()).abs() > 1e-6) return const SizedBox.shrink();
    final idx = value.round() - 1;
    if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();

    // 1つ飛ばしで表示（重なり防止）
    if (idx % 2 != 0) return const SizedBox.shrink();

    late final String text;
    if (_displayMode == DisplayMode.day) {
      text = _formatDayLabel(dates[idx]);
    } else if (_displayMode == DisplayMode.week) {
      text = _formatWeekLabel(dates[idx]);
    } else {
      text = _formatMonthLabel(dates[idx]);
    }

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
      final personalKey = _personalMetricKey(
          _personalMetricFromKey(_selectedPersonalMetricKey) ??
              _personalMetric);
      switch (personalKey) {
        case 'personal:weight':
          return SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
        case 'personal:bodyFat':
          return l10n.percentSymbol;
        case 'personal:bmi':
          return ''; // 単位なし
        case 'personal:waist':
          return _waistUnit(l10n); // cm / in
        default:
          return '';
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
      final personalKey = _personalMetricKey(
          _personalMetricFromKey(_selectedPersonalMetricKey) ??
              _personalMetric);
      switch (personalKey) {
        case 'personal:weight':
          final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
          return '${y.toStringAsFixed(1)} $u';
        case 'personal:bodyFat':
          return '${y.toStringAsFixed(1)} ${l10n.percentSymbol}';
        case 'personal:bmi':
          return y.toStringAsFixed(1);
        case 'personal:waist':
          return '${y.toStringAsFixed(1)} ${_waistUnit(l10n)}';
        default:
          return y.toStringAsFixed(1);
      }
    }
    final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
    final digits = _isStrengthContext() ? 0 : 1; // 強度は 0 桁
    return '${y.toStringAsFixed(digits)} $u';
  }

  void _checkIfFavorite() {
    if (!mounted) return;
    setState(() {
      _isFavorite = false;
    });
  }

  void _toggleFavorite({bool showMessage = true}) {
    return;
  }


  // ====== 新お気に入り（メニュー専用） ======
  void _checkIfFavoriteNew() {
    if (!mounted) return;
    
    String? key;
    if (_selectedMenu != null && !_isPersonalContext()) {
      key = 'menu:${_selectedMenu!}';
    }

    if (key == null) {
      setState(() {
        _isFavorite = false;
      });
      return;
    }

    final rawFavorites = widget.settingsBox.get(_prefFavoritesKeyV3);
    final favorites = (rawFavorites is List)
        ? rawFavorites.whereType<String>().toList()
        : <String>[];

    setState(() {
      _isFavorite = favorites.contains(key);
    });
  }

  void _toggleFavoriteNew() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_selectedMenu == null || _isPersonalContext()) {
      return;
    }

    final key = 'menu:${_selectedMenu!}';
    final display = _selectedMenu!;

    final rawFavorites = widget.settingsBox.get(_prefFavoritesKeyV3);
    final favorites = (rawFavorites is List)
        ? rawFavorites.whereType<String>().toList()
        : <String>[];

    final willAdd = !favorites.contains(key);
    if (willAdd) {
      favorites.add(key);
    } else {
      favorites.remove(key);
    }
    widget.settingsBox.put(_prefFavoritesKeyV3, favorites);

    setState(() {
      _isFavorite = willAdd;
      if (_selectedPartOriginal == _kFavoritesNew) {
        _loadMenusForPart(_selectedPart!);
      }
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
    widget.settingsBox.put(_prefPersonalMetricKey, _selectedPersonalMetricKey);
  }

  String _goalStorageKey() {
    String ctx;
    if (_isPersonalContext()) {
      final key = _selectedPersonalMetricKey;
      ctx = 'personal_${key.replaceFirst('personal:', '')}';
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
      final metric =
          _personalMetricFromKey(_selectedPersonalMetricKey) ?? _personalMetric;
      final personalKey = _personalMetricKey(metric);
      switch (personalKey) {
        case 'personal:weight':
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
        case 'personal:bodyFat':
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
        case 'personal:bmi':
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
        case 'personal:waist':
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
            final rangeSpan = (_baseMaxY - _baseMinY).abs();
            final padding = _isMetricLength ? 20.0 : 8.0;
            final expand = max(padding, rangeSpan);
            final minValue = _baseMinY.isFinite
                ? max(minDefault, (_baseMinY - expand).floorToDouble())
                : minDefault;
            final maxValue = _baseMaxY.isFinite
                ? max(maxDefault, (_baseMaxY + expand).ceilToDouble())
                : maxDefault;

            final v = await _showNumberPicker(
              title: waistLabel,
              minValue: minValue,
              maxValue: maxValue,
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
        default:
          return;
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
      final metric =
          _personalMetricFromKey(_selectedPersonalMetricKey) ?? _personalMetric;
      final personalKey = _personalMetricKey(metric);
      switch (personalKey) {
        case 'personal:weight':
          {
            final u = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
            return '${_goalValue!.toStringAsFixed(1)} $u';
          }
        case 'personal:bodyFat':
          return '${_goalValue!.toStringAsFixed(1)} ${l10n.percentSymbol}';
        case 'personal:bmi':
          return _goalValue!.toStringAsFixed(1);
        case 'personal:waist':
          return '${_goalValue!.toStringAsFixed(1)} ${_waistUnit(l10n)}';
        default:
          return _goalValue!.toStringAsFixed(1);
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
      _setSelectedPart(value);
      _saveGraphPrefs();
      _loadMenusForPart(value);
    });
    _checkIfFavoriteNew();
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

      _saveGraphPrefs();
      _refreshDataForSelection();
    });
    _checkIfFavoriteNew();
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
              _displayMode == DisplayMode.month,
            ],
            onPressed: (index) {
              setState(() {
                if (index == 0) {
                  _displayMode = DisplayMode.day;
                } else if (index == 1) {
                  _displayMode = DisplayMode.week;
                } else {
                  _displayMode = DisplayMode.month;
                }
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
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Text(l10n.dayDisplay),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Text(l10n.weekDisplay),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Text(l10n.monthDisplay),
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: _kGoal,
            borderRadius: BorderRadius.circular(12),
            onTap: (_noMenus && !_isPersonalContext())
                ? () => _showThrottledHint(l10n.hintRecordFirst)
                : _openGoalPicker,
            child: Ink(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: colorScheme.primary.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
        ),
      ),
    );

    // お気に入り(お気に入りタブでは無効化)
    final bool isFavoritesTab =
        _selectedPartOriginal == _kFavoritesOriginal ||
        _selectedPartOriginal == _kFavoritesNew;
    final bool favEnabled =
        !isFavoritesTab && !(_noMenus && !_isPersonalContext());

    Widget favButton = Opacity(
      opacity: favEnabled ? 1.0 : 0.4,
      child: FavoritePillButton(
        key: _kFav,
        isFavorite: favEnabled ? _isFavorite : false,
        label: l10n.favorites,
        onTap: favEnabled
            ? () {
                // 旧お気に入りも今までどおり更新
                _toggleFavorite(showMessage: false);
                // 新お気に入りも別キーで更新
                _toggleFavoriteNew();
              }
            : () {},
        height: _kControlHeight,
      ),
    );

    final partDisplay = _selectedPart ?? l10n.selectTrainingPart;
    final menuDisplay = (_selectedPart == l10n.personal)
        ? ''
        : (_selectedMenu ?? l10n.selectExercise);

    Widget partMenuRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
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
                  border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
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
    ),
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
      child: Scaffold(
        backgroundColor: SettingsManager.backgroundAssetNotifier.value.isEmpty
            ? null
            : Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          top: true,
          bottom: false,
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeKeyboard,
              child: CenteredConstrained(
                maxWidth: 760,
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AdBanner(screenName: 'graph'),
                    const SizedBox(height: 4.0),
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
                          child: Column(
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  dayWeekToggle,
                                  const SizedBox(width: 8),
                                  Expanded(child: goalButton),
                                  const SizedBox(width: 8),
                                  SizedBox(width: 60, child: favButton),
                                ],
                              ),
                              if (aerobicToggle != null) ...[
                                const SizedBox(height: 8),
                                aerobicToggle,
                              ],
                              const SizedBox(height: 8),
                              Expanded(
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
                                    final chartW = _axisDates.isEmpty
                                        ? plotAvailW
                                        : points * _kXStridePx;

                                    final unitOverlay =
                                        (unitText.isEmpty ||
                                                _axisDates.isEmpty)
                                            ? const SizedBox.shrink()
                                            : Positioned(
                                                left: 4,
                                                top: 6,
                                                child: Text(
                                                  unitText,
                                                  style: TextStyle(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              );

                                    double viewMinY = _baseMinY;
                                    double viewMaxY = _baseMaxY;

                                    if (_goalValue != null) {
                                      viewMinY = min(viewMinY, _goalValue!);
                                      viewMaxY = max(viewMaxY, _goalValue!);
                                    }

                                    viewMinY =
                                        (viewMinY / _yLabelStep).floor() *
                                            _yLabelStep -
                                        _kYPadStepsBottom * _yLabelStep;
                                    viewMaxY =
                                        (viewMaxY / _yLabelStep).ceil() *
                                            _yLabelStep +
                                        _kYPadStepsTop * _yLabelStep;

                                    viewMinY = max(0, viewMinY);

                                    final tickCount =
                                        ((viewMaxY - viewMinY) / _yLabelStep)
                                                .round() +
                                            1;
                                    final double computedChartH =
                                        24 + (tickCount - 1) * _kYTickPx + 24;
                                    final double chartH =
                                        max(totalH, computedChartH);

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
                                                clipData:
                                                    const FlClipData.all(),
                                                lineBarsData: const [],
                                                titlesData: FlTitlesData(
                                                  leftTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize:
                                                          _kYAxisWidth - 4,
                                                      interval: _yLabelStep,
                                                      getTitlesWidget:
                                                          _leftTitle,
                                                    ),
                                                  ),
                                                  bottomTitles:
                                                      const AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: false,
                                                    ),
                                                  ),
                                                  topTitles: const AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: false,
                                                    ),
                                                  ),
                                                  rightTitles:
                                                      const AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: false,
                                                    ),
                                                  ),
                                                ),
                                                gridData: FlGridData(
                                                  show: true,
                                                  horizontalInterval:
                                                      _yLabelStep,
                                                  checkToShowHorizontalLine:
                                                      (v) => _isLabelTick(v),
                                                  drawVerticalLine: false,
                                                  getDrawingHorizontalLine:
                                                      (v) => FlLine(
                                                    color: colorScheme
                                                        .outlineVariant,
                                                    strokeWidth: 0.5,
                                                  ),
                                                ),
                                                borderData: FlBorderData(
                                                  show: false,
                                                ),
                                              ),
                                            ),
                                    );

                                    final xAxisChart = SizedBox(
                                      width: chartW,
                                      height: _kXAxisReservedPx,
                                      child: _axisDates.isEmpty
                                          ? const SizedBox.shrink()
                                          : LineChart(
                                              LineChartData(
                                                minX: 0,
                                                maxX: points.toDouble(),
                                                minY: 0,
                                                maxY: 1,
                                                clipData:
                                                    const FlClipData.none(),
                                                lineBarsData: const [],
                                                titlesData: FlTitlesData(
                                                  leftTitles:
                                                      const AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: false,
                                                    ),
                                                  ),
                                                  bottomTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize:
                                                          _kXAxisReservedPx,
                                                      interval: 1,
                                                      getTitlesWidget:
                                                          _bottomTitle,
                                                    ),
                                                  ),
                                                  topTitles: const AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: false,
                                                    ),
                                                  ),
                                                  rightTitles:
                                                      const AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: false,
                                                    ),
                                                  ),
                                                ),
                                                gridData:
                                                    const FlGridData(show: false),
                                                borderData: FlBorderData(
                                                    show: false),
                                              ),
                                            ),
                                    );

                                    final plotArea = _axisDates.isEmpty
                                        ? Container(
                                            height:
                                                totalH - 2 - _kXAxisReservedPx,
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                SizedBox.square(
                                                  dimension: min(
                                                    MediaQuery.of(context)
                                                            .size.height /
                                                        3,
                                                    240.0,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                    child: Image.asset(
                                                      'assets/graph/hint.png',
                                                      fit: BoxFit.contain,
                                                      errorBuilder:
                                                          (_, __, ___) => Icon(
                                                        Icons.insights,
                                                        size: 72,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  l10n.noGraphData,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  style: TextStyle(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 14,
                                                    height: 1.15,
                                                    letterSpacing: 0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            height: chartH,
                                            child: SingleChildScrollView(
                                              scrollDirection:
                                                  Axis.horizontal,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              child: SizedBox(
                                                width: chartW,
                                                height: chartH,
                                                child: LineChart(
                                                  LineChartData(
                                                    minX: 0,
                                                    maxX: points.toDouble(),
                                                    minY: viewMinY,
                                                    maxY: viewMaxY,
                                                    clipData: const FlClipData
                                                        .all(),
                                                    extraLinesData:
                                                        ExtraLinesData(
                                                      horizontalLines:
                                                          <HorizontalLine>[
                                                        HorizontalLine(
                                                          y: 0,
                                                          color: colorScheme
                                                              .outlineVariant,
                                                          strokeWidth: 0.5,
                                                        ),
                                                        if (_goalValue != null)
                                                          HorizontalLine(
                                                            y: _goalValue!,
                                                            color: colorScheme
                                                                .tertiary,
                                                            strokeWidth: 2,
                                                            dashArray: [6, 4],
                                                          ),
                                                      ],
                                                      verticalLines: [
                                                        VerticalLine(
                                                          x: 0,
                                                          color: colorScheme
                                                              .outlineVariant,
                                                          strokeWidth: 0.5,
                                                        ),
                                                      ],
                                                    ),
                                                    lineBarsData: [
                                                      LineChartBarData(
                                                        spots: _spots,
                                                        isCurved: false,
                                                        color: colorScheme
                                                            .primary,
                                                        barWidth: 3,
                                                        dotData:
                                                            const FlDotData(
                                                                show: true),
                                                        belowBarData:
                                                            BarAreaData(
                                                                show: false),
                                                      ),
                                                    ],
                                                    titlesData:
                                                        FlTitlesData(
                                                      leftTitles:
                                                          const AxisTitles(
                                                        sideTitles:
                                                            SideTitles(
                                                          showTitles: false,
                                                        ),
                                                      ),
                                                      bottomTitles:
                                                          const AxisTitles(
                                                        sideTitles:
                                                            SideTitles(
                                                          showTitles: false,
                                                        ),
                                                      ),
                                                      topTitles:
                                                          const AxisTitles(
                                                        sideTitles:
                                                            SideTitles(
                                                          showTitles: false,
                                                        ),
                                                      ),
                                                      rightTitles:
                                                          const AxisTitles(
                                                        sideTitles:
                                                            SideTitles(
                                                          showTitles: false,
                                                        ),
                                                      ),
                                                    ),
                                                    gridData: FlGridData(
                                                      show: true,
                                                      horizontalInterval:
                                                          _yLabelStep,
                                                      checkToShowHorizontalLine:
                                                          (v) =>
                                                              _isLabelTick(v),
                                                      drawVerticalLine: true,
                                                      verticalInterval: 1,
                                                      checkToShowVerticalLine:
                                                          (v) =>
                                                              (v - v.round())
                                                                      .abs() <
                                                                  1e-6,
                                                      getDrawingHorizontalLine:
                                                          (v) => FlLine(
                                                        color: colorScheme
                                                            .outlineVariant,
                                                        strokeWidth: 0.5,
                                                      ),
                                                      getDrawingVerticalLine:
                                                          (v) => FlLine(
                                                        color: colorScheme
                                                            .outlineVariant,
                                                        strokeWidth: 0.5,
                                                      ),
                                                    ),
                                                    borderData: FlBorderData(
                                                        show: false),
                                                    lineTouchData: LineTouchData(
                                                      handleBuiltInTouches:
                                                          true,
                                                      touchTooltipData:
                                                          LineTouchTooltipData(
                                                        tooltipRoundedRadius:
                                                            12,
                                                        tooltipPadding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        getTooltipColor:
                                                            (_) => colorScheme
                                                                .primaryContainer,
                                                        getTooltipItems:
                                                            (spots) {
                                                          final loc =
                                                              Localizations
                                                                      .localeOf(
                                                                          context)
                                                                  .toLanguageTag();
                                                          return spots
                                                              .map(
                                                                (s) {
                                                                  final i =
                                                                      s.spotIndex;
                                                                  final d =
                                                                      (i >= 0 &&
                                                                              i <
                                                                                  _xDates.length)
                                                                          ?
                                                                          _xDates[
                                                                              i]
                                                                          :
                                                                          null;
                                                                  final dateStr =
                                                                      (_displayMode ==
                                                                              DisplayMode.day)
                                                                          ? (d !=
                                                                                  null
                                                                              ? DateFormat('M/d', loc)
                                                                                  .format(d)
                                                                              : '')
                                                                          : (d !=
                                                                                  null
                                                                              ? _formatWeekLabel(d)
                                                                              : '');
                                                                  final valStr =
                                                                      _formatTooltipValue(
                                                                          s.y,
                                                                          l10n);
                                                                  return LineTooltipItem(
                                                                    '${dateStr}\n$valStr',
                                                                    TextStyle(
                                                                      color: colorScheme
                                                                          .onPrimaryContainer,
                                                                      fontWeight:
                                                                          FontWeight.w600,
                                                                    ),
                                                                  );
                                                                },
                                                              )
                                                              .toList();
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );

                                    return Container(
                                      width: totalW,
                                      height: totalH,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: yAxisPanelW,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child:
                                                      SingleChildScrollView(
                                                    controller:
                                                        _verticalScrollController1,
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    child: yAxisChart,
                                                  ),
                                                ),
                                                SizedBox(
                                                    height:
                                                        _kXAxisReservedPx),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child:
                                                SingleChildScrollView(
                                              scrollDirection:
                                                  Axis.horizontal,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              child: SizedBox(
                                                width: chartW,
                                                height: totalH - 2,
                                                child: Stack(
                                                  children: [
                                                    Positioned(
                                                      top: 0,
                                                      left: 0,
                                                      right: 0,
                                                      bottom:
                                                          _kXAxisReservedPx,
                                                      child:
                                                          SingleChildScrollView(
                                                        controller:
                                                            _verticalScrollController2,
                                                        physics: const
                                                            BouncingScrollPhysics(),
                                                        child: plotArea,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      left: 0,
                                                      right: 0,
                                                      bottom: 0,
                                                      height:
                                                          _kXAxisReservedPx,
                                                      child: xAxisChart,
                                                    ),
                                                    unitOverlay,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              partMenuRow,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final icon = isFavorite ? Icons.star : Icons.star_border;

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: isFavorite ? cs.primary : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFavorite ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: Padding(
                // 横幅を細くするために左右の余白は小さめ
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Icon(
                  icon,
                  size: 18,
                  color: isFavorite ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
