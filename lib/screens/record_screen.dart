// lib/screens/record_screen.dart
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'dart:async';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_catalog.dart';
import '../models/meal.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import '../utils/training_display_utils.dart';
import '../widgets/ad_banner.dart';
import '../widgets/big_earning_ad.dart';
import '../widgets/stopwatch_widget.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

Future<bool> _ensureCameraPermission(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isGranted) return true;
  status = await Permission.camera.request();
  if (status.isGranted) return true;

  if (status.isPermanentlyDenied) {
    final l10n = AppLocalizations.of(context)!;
    showAppSnack(
      context,
      l10n.cameraPermissionRequired,
      actionLabel: l10n.openSettings,
      onAction: () => openAppSettings(),
    );
  }
  return false;
}

void showAppSnack(
  BuildContext context,
  String message, {
  int milliseconds = 1800,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(milliseconds: milliseconds),
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}

class _MealRowControllers {
  _MealRowControllers({
    required this.nameController,
    required this.kcalController,
  });

  final TextEditingController nameController;
  final TextEditingController kcalController;

  void dispose() {
    nameController.dispose();
    kcalController.dispose();
  }
}

const double kUnifiedFieldMinHeight = 36.0;

const String kUiFont = 'NotoSansJP';

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const RecordScreen({
    super.key,
    required this.selectedDate,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

enum _QuickReview { save, discard }

enum _AerobicFailureReason { noMatch }

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
// === Interval Timer Keys (per input card) ===
  final Map<String, GlobalKey<ExerciseInputTimerState>> _intervalTimerKeys = {};

  GlobalKey<ExerciseInputTimerState> _ensureTimerKey(
      int secIndex, int menuIndex) {
    final id = '${secIndex}_${menuIndex}';
    return _intervalTimerKeys.putIfAbsent(
        id, () => GlobalKey<ExerciseInputTimerState>());
  }

  static const Duration _kIdleAutoPause = Duration(hours: 5);
  static const Duration _kHardCap = Duration(hours: 5);
  static const double _bmiNudgeRight = 25.0;
  static const double _bmiUnitReserve = 25.0;
  static const double _unitReserveW = 22.0;
  static const Duration _overlaySlideDuration = Duration(milliseconds: 280);
  static const Duration _overlayFadeDuration = Duration(milliseconds: 240);
  static const Curve _overlayInCurve = Curves.easeOutCubic;
  static const Curve _overlayOutCurve = Curves.easeInCubic;

  Color _fabBg(BuildContext c) =>
      Theme.of(c).floatingActionButtonTheme.backgroundColor ??
      Theme.of(c).colorScheme.primary;

  Color _fabFg(BuildContext c) =>
      Theme.of(c).floatingActionButtonTheme.foregroundColor ??
      Theme.of(c).colorScheme.onPrimary;

  late final AnimationController _fabCtrl;

  // ===== メモ・オーバーレイ（フローティング） =====
  bool _memoOverlayVisible = false; // 表示中か
  bool _memoOverlayOpening = false; // キーボード待ち中か
  bool _memoSlideIn = false; // 上からのスライド演出
  // ===== 食事・オーバーレイ =====
  bool _mealOverlayVisible = false;
  bool _mealOverlayOpening = false;
  bool _mealSlideIn = false;
  final FocusNode _mealOverlayFocus = FocusNode();
  int? _mealOverlayIndex;
  bool _lastWaistUnitIsInch = SettingsManager.isWaistInch; // 追加
  // ===== 種目・オーバーレイ（フローティング） =====
  bool _menuOverlayVisible = false;
  bool _menuOverlayOpening = false;
  bool _menuSlideIn = false;
  final FocusNode _menuOverlayFocus = FocusNode();
  int? _menuSecIndex;
  int? _menuMenuIndex;

  final GlobalKey _kPhotoCardsKey = GlobalKey();
  final GlobalKey _kMemoCardKey = GlobalKey();

  static const int _kDailyPhotoCap = 24;

  final ScrollController _scrollCtrl = ScrollController();
  bool _initialized = false;

  bool _weightFocused = false;

  InputDecoration _underlineDec([BuildContext? ctx]) {
    // State の context をフォールバックに使う
    final c = ctx ?? context;
    final cs = Theme.of(c).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: false,
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: cs.onSurfaceVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    );
  }

  bool _isTopMostRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  // ===== パーソナル・オーバーレイ（体重/体脂肪/ウエスト/BMI 編集） =====
  bool _personalOverlayVisible = false;
  bool _personalSlideIn = false;
  final FocusNode _personalOverlayFocus = FocusNode();

  final GlobalKey _kRecordPart = GlobalKey();
  final GlobalKey _kExerciseField = GlobalKey();
  final GlobalKey _kFabKey = GlobalKey();
  final GlobalKey _kMenuSaveButton = GlobalKey();
  final GlobalKey _kStopwatchArea = GlobalKey();
  final GlobalKey _kAdArea = GlobalKey();

  bool _firstBuildDone = false;

  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];
  List<SectionData> _sections = [];
  int _currentSetCount = 3;

  int? _currentSectionIndex;
  int? _currentMenuIndex;

  bool _showSavedChip = false;
  Timer? _savedChipTimer;

  StreamSubscription<BoxEvent>? _setCountSub;

  bool _fabOpen = false;

  bool _calcAerobicCalories = SettingsManager.enableAerobicCalories;

  Map<String, List<String>> _customExercises = {};

  final List<MealCardState> _mealCards = [];
  final List<List<_MealRowControllers>> _mealControllers = [];
  final List<bool> _mealCollapsed = [];
  double _totalMealKcal = 0;
  int? _currentMealIndex;

  final TextEditingController _weightController = TextEditingController();

  // 体脂肪入力用
  final TextEditingController _bodyFatController = TextEditingController();

  // ウエスト入力用 ← 追加
  final TextEditingController _waistController = TextEditingController();

  // BMI 表示用（参照のみ）
  final TextEditingController _bmiController = TextEditingController();

  // 基礎代謝入力用
  final TextEditingController _bmrController = TextEditingController();

  // パーソナルカード表示フラグ（1枚だけ）
  bool _showPersonalCard = false;
  bool _personalCollapsed = true;
  bool _personalSelected = false;
  bool _suppressNextMenuOverlay = false;
  int? _skipTapSectionIndex;
  int? _skipTapMenuIndex;

// BMI 表示用（null のときは未計算/未設定表示）
  double? _bmiValue;

// 設定から読む身長(cm)
  double? _heightCm;

  // Memo（プレビュー用コントローラ）
  bool _showMemo = false;
  final TextEditingController _memoController = TextEditingController();

  // メモ・オーバーレイ（後方互換フラグ）
  bool _memoOverlayOpen = false; // 旧：インライン編集モードのフラグ（互換のため残す）
  final FocusNode _memoOverlayFocus = FocusNode();

  // Photos
  final ImagePicker _imagePicker = ImagePicker();
  List<String> _mediaPaths = [];

  // Stopwatch
  static final StopwatchController _swController = StopwatchController();
  DateTime _lastInteractionAt = DateTime.now();
  Timer? _inactivityTimer;
  Timer? _capTimer;
  DateTime? _backgroundedAt;
  bool _wasRunning = false;
  DateTime? _resumedAt;

  Timer? _scrollDebounce;
  GlobalKey? _pendingScrollKey;
  double _pendingScrollAlignment = 0.22;

  // 体型カードの下あたり、クラス内メソッドとして追加
  void _applyWaistDisplayUnitFromCm() {
    final raw = _waistController.text.trim();
    if (raw.isEmpty) return;
    final cm = double.tryParse(raw);
    if (cm == null) return;

    final disp = SettingsManager.waistCmToDisplay(cm);
    _waistController.text = SettingsManager.isWaistInch
        ? disp.toStringAsFixed(1) // in
        : disp.toStringAsFixed(0); // cm
  }

  void _onLengthUnitChanged() {
    if (!mounted) return;
    final nowInch = SettingsManager.isWaistInch;
    if (nowInch != _lastWaistUnitIsInch) {
      // 表示中のウエスト値を cm⇄inch 変換
      final raw = _waistController.text.trim();
      final v = double.tryParse(raw);
      if (v != null) {
        final converted = nowInch ? (v / 2.54) : (v * 2.54);
        _waistController.text = nowInch
            ? converted.toStringAsFixed(1) // inch 表示
            : converted.toStringAsFixed(0); // cm 表示
      }
      _lastWaistUnitIsInch = nowInch;
    }
    setState(() {}); // ラベル等の再描画
  }

  void _onShowStopwatchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onDisplayPreferencesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onIntervalTimerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    WidgetsBinding.instance.addObserver(this);
    SettingsManager.showStopwatchNotifier.addListener(_onShowStopwatchChanged);
    SettingsManager.showIntervalTimerNotifier
        .addListener(_onIntervalTimerChanged);
    SettingsManager.showTotalVolumeNotifier
        .addListener(_onDisplayPreferencesChanged);
    SettingsManager.showSatisfactionNotifier
        .addListener(_onDisplayPreferencesChanged);

    // ★追加：単位切替（inch/cm 等）のUI反映
    SettingsManager.lengthUnitNotifier.addListener(_onLengthUnitChanged);
    SettingsManager.aerobicCalorieNotifier
        .addListener(_onAerobicCalorieSettingChanged);
    SettingsManager.personalWeightNotifier
        .addListener(_onPersonalWeightSettingChanged);
    SettingsManager.manageBmrNotifier.addListener(_onBmrToggleChanged);
    _weightController.addListener(_handleWeightChanged);
    _calcAerobicCalories = SettingsManager.enableAerobicCalories;

    _setCountSub = widget.setCountBox.watch(key: 'setCount').listen((event) {
      final int newCount = (event.value as int?) ?? 3;
      _currentSetCount = newCount;
      final changed = _trimTrailingEmptySetsForAllMenus(newCount);
      if (changed && mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _firstBuildDone = true);
    });

    // First hint
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) return;
      final box = widget.settingsBox;
      final seen = box.get('hint_seen_record') as bool? ?? false;
      if (seen) return;

      final deadline = DateTime.now().add(const Duration(milliseconds: 800));
      while (DateTime.now().isBefore(deadline)) {
        if (!mounted) return;
        if (_kRecordPart.currentContext != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted || _kRecordPart.currentContext == null) return;

      final l10n = AppLocalizations.of(context)!;
      // (hint removed)
      await box.put('hint_seen_record', true);
    });

    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final idle = DateTime.now().difference(_lastInteractionAt);
      if (idle >= _kIdleAutoPause && _swController.isRunning) {
        final l10n = AppLocalizations.of(context)!;
        _pauseWithSnack(l10n.autoPausedIdle5h);
      }
    });

    _capTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final running = _swController.isRunning;
      if (running && !_wasRunning) {
        _resumedAt = DateTime.now();
      } else if (!running && _wasRunning) {
        _resumedAt = null;
      }
      if (running && _resumedAt != null) {
        final runFor = DateTime.now().difference(_resumedAt!);
        if (runFor >= _kHardCap) {
          final l10n = AppLocalizations.of(context)!;
          _pauseWithSnack(l10n.autoPausedOver5h, withResume: true);
          _resumedAt = null;
        }
      }
      _wasRunning = running;
    });

    _scrollCtrl.addListener(() => _lastInteractionAt = DateTime.now());
    _loadMediaForSelectedDate();
    if (_calcAerobicCalories) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _recalculateAllAerobicCalories(force: true);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHeightFromSettings();
    if (!_initialized) {
      _initialized = true;
      _loadSettingsAndParts();
    }
  }

  @override
  void dispose() {
    _fabCtrl.dispose(); // ← 追加
    SettingsManager.showStopwatchNotifier
        .removeListener(_onShowStopwatchChanged);
    SettingsManager.showIntervalTimerNotifier
        .removeListener(_onIntervalTimerChanged);
    SettingsManager.showTotalVolumeNotifier
        .removeListener(_onDisplayPreferencesChanged);
    SettingsManager.showSatisfactionNotifier
        .removeListener(_onDisplayPreferencesChanged);
    WidgetsBinding.instance.removeObserver(this);

    _inactivityTimer?.cancel();
    _capTimer?.cancel();
    _savedChipTimer?.cancel();
    _setCountSub?.cancel();
    _scrollDebounce?.cancel();

    _resetMealState();

    _scrollCtrl.dispose();
    for (var section in _sections) {
      section.dispose();
    }
    _sections.clear();

    _weightController.removeListener(_handleWeightChanged);
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _bmiController.dispose();
    _bmrController.dispose();
    _memoController.dispose();
    _mealOverlayFocus.dispose();
    _memoOverlayFocus.dispose();
    _menuOverlayFocus.dispose();

    // ★ 重要：リスナー解除は super.dispose() の前に
    SettingsManager.lengthUnitNotifier.removeListener(_onLengthUnitChanged);
    SettingsManager.aerobicCalorieNotifier
        .removeListener(_onAerobicCalorieSettingChanged);
    SettingsManager.personalWeightNotifier
        .removeListener(_onPersonalWeightSettingChanged);
    SettingsManager.manageBmrNotifier.removeListener(_onBmrToggleChanged);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedAt != null) {
        final away = DateTime.now().difference(_backgroundedAt!);
        if (away.inMinutes >= 30 && _swController.isRunning) {
          final l10n = AppLocalizations.of(context)!;
          _pauseWithSnack(l10n.autoPausedBackground30m, withResume: true);
        }
      }
      _backgroundedAt = null;
      _lastInteractionAt = DateTime.now();
      unawaited(_recoverLostImageIfAny());
      _loadMediaForSelectedDate();
    }
  }

  void _pauseWithSnack(String message, {bool withResume = false}) {
    _swController.pause();
    if (!mounted || !_isTopMostRoute(context)) return;

    final l10n = AppLocalizations.of(context)!;
    final action = withResume
        ? SnackBarAction(
            label: l10n.resume,
            onPressed: () {
              _swController.start();
              _lastInteractionAt = DateTime.now();
              _resumedAt = DateTime.now();
              _wasRunning = true;
            },
          )
        : null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 7),
        action: action,
      ),
    );
  }

  String _formatAppBarDate(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final date = widget.selectedDate;
    if (locale.languageCode == 'ja') {
      final base = DateFormat('yyyy/MM/dd', locale.toString()).format(date);
      final weekday = DateFormat.E(locale.toString()).format(date);
      return '$base（$weekday）';
    }
    return DateFormat.yMMMMEEEEd(locale.toString()).format(date);
  }

  void _showSavedChipFor(Duration duration) {
    _savedChipTimer?.cancel();
    setState(() => _showSavedChip = true);
    _savedChipTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _showSavedChip = false);
    });
  }

  Future<void> _dismissKeyboardSafely(BuildContext ctx) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    final deadline = DateTime.now().add(const Duration(milliseconds: 500));
    while (mounted &&
        MediaQuery.of(ctx).viewInsets.bottom > 0 &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _scrollIntoView(int secIndex, int menuIndex) async {
    final key = _sections[secIndex].menuKeys[menuIndex];
    if (key is GlobalKey && key.currentContext != null) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    } else {
      final sKey = _sections[secIndex].key;
      if (sKey is GlobalKey && sKey.currentContext != null) {
        await Scrollable.ensureVisible(
          sKey.currentContext!,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.10,
        );
      }
    }
  }

  Future<void> _scrollSectionCardIntoView(int secIndex) async {
    final sk = _sections[secIndex].key;
    if (sk is GlobalKey && sk.currentContext != null) {
      await Scrollable.ensureVisible(
        sk.currentContext!,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.10,
      );
    }
  }

  Future<void> _scrollIntoViewKey(GlobalKey key,
      {double alignment = 0.22}) async {
    _pendingScrollKey = key;
    _pendingScrollAlignment = alignment;
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 140), () async {
      if (!mounted) return;
      final ctx = _pendingScrollKey?.currentContext;
      if (ctx == null) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final targetCtx = _pendingScrollKey?.currentContext;
      if (targetCtx == null) return;
      await Scrollable.ensureVisible(
        targetCtx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: _pendingScrollAlignment,
      );
    });
  }

  Future<void> _scrollToBottom() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollCtrl.hasClients) return;
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!_scrollCtrl.hasClients) return;
    final target = _scrollCtrl.position.maxScrollExtent;
    await _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _waitForKeyboardStable({int timeoutMs = 700}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    double? last;
    int stableTick = 0;
    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 32));
      final kb = MediaQuery.of(context).viewInsets.bottom;
      if (last != null && (kb - last!).abs() < 1.0) {
        stableTick++;
        if (stableTick >= 3) break;
      } else {
        stableTick = 0;
        last = kb;
      }
    }
  }

  // ===== 種目パート選択・初期化など（元のまま） =====
  void _focusMenuNameField(int secIndex, int menuIndex) {
    if (!mounted) return;
    if (secIndex < 0 || secIndex >= _sections.length) return;

    final keys = _sections[secIndex].nameFieldKeys;
    if (menuIndex < 0 || menuIndex >= keys.length) return;

    final ctx = keys[menuIndex].currentContext;
    if (ctx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final targetCtx = keys[menuIndex].currentContext;
      if (targetCtx == null) return;

      EditableTextState? editable;
      void findEditable(Element e) {
        if (editable != null) return;
        if (e is StatefulElement && e.state is EditableTextState) {
          editable = e.state as EditableTextState;
        }
        e.visitChildren(findEditable);
      }

      final rootElem = targetCtx as Element;
      rootElem.visitChildren(findEditable);

      if (editable?.widget.focusNode != null) {
        editable!.widget.focusNode!.requestFocus();
        await SystemChannels.textInput.invokeMethod('TextInput.show');
      } else {
        FocusScope.of(targetCtx).unfocus();
        await SystemChannels.textInput.invokeMethod('TextInput.show');
      }

      final ctrl = _sections[secIndex].menuControllers[menuIndex];
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    });
  }

  void _applySelectedPart(int secIndex, String? value) {
    final section = _sections[secIndex];
    setState(() {
      section.selectedPart = value;
      section.menuKeys.clear();
      section.nameFieldKeys.clear();
      _clearSectionControllersAndMaps(section);

      if (section.selectedPart != null) {
        final current = section.selectedPart!;
        final originalPart = _getOriginalPartName(context, current);
        final dateKey = _getDateKey(widget.selectedDate);
        final record = widget.recordsBox.get(dateKey);

        final recList = record?.menus[originalPart] ?? <MenuData>[];
        final rawLU = widget.lastUsedMenusBox.get(originalPart);
        final luList = (rawLU is List)
            ? rawLU.whereType<MenuData>().toList()
            : <MenuData>[];

        final Map<String, MenuData> recBy = {
          for (final m in recList) m.name: m
        };
        final Map<String, MenuData> luBy = {for (final m in luList) m.name: m};

        final l10n = AppLocalizations.of(context)!;
        final bool isAerobic = current == l10n.aerobicExercise;

        final List<String> names = [
          ...recList.map((m) => m.name),
          ...luList.where((m) => !recBy.containsKey(m.name)).map((m) => m.name),
        ];

        // 追加要件：最低枚数を保証（筋トレ=7, 有酸素=5）。
        // 追加要件：初回は「人気3＋補助2」を事前配置（有酸素は人気3）し、その下に空カード2。
// 既存の記録や直近使用がある場合は従来通りに最低枚数だけ空カードで埋める。
        if (recList.isEmpty && luList.isEmpty) {
          final presets = _presetPopularAndAssistNames(originalPart);
          names.clear();
          if (isAerobic) {
            // 有酸素：人気3 + 空2 = 5
            names.addAll(presets.take(3));
            names.addAll(List.filled(2, ''));
          } else {
            // 筋トレ系：人気3＋補助2 + 空2 = 7
            names.addAll(presets.take(5));
            names.addAll(List.filled(2, ''));
          }
        } else {
          // 従来ロジック：最低枚数（有酸素=5, それ以外=7）を空カードで埋める
          final int minCount = isAerobic ? 5 : 7;
          if (names.isEmpty) {
            names.addAll(List.filled(minCount, ''));
          } else if (names.length < minCount) {
            names.addAll(List.filled(minCount - names.length, ''));
          }
        }

        for (final name in names) {
          final rec = recBy[name];
          final lu = luBy[name];

          section.menuControllers.add(TextEditingController(text: name));
          section.menuKeys.add(GlobalKey());
          section.nameFieldKeys.add(GlobalKey());
          // 満足度は当日の記録がある場合のみ復元
          section.satisfactionList.add(rec?.satisfaction);

          if (isAerobic) {
            final String dist = (rec?.distance?.trim().isNotEmpty ?? false)
                ? rec!.distance!.trim()
                : (lu?.distance?.trim() ?? '');
            final String dura = (rec?.duration?.trim().isNotEmpty ?? false)
                ? rec!.duration!.trim()
                : (lu?.duration?.trim() ?? '');
            final bool isSug = !(rec?.distance?.trim().isNotEmpty == true ||
                rec?.duration?.trim().isNotEmpty == true);
            section.aerobicDistanceCtrls.add(TextEditingController(text: dist));
            section.aerobicDurationCtrls.add(TextEditingController(text: dura));
            section.aerobicSuggestFlags.add(isSug);
            final String calorieRaw =
                (rec?.calories?.trim().isNotEmpty ?? false)
                    ? rec!.calories!.trim()
                    : '';
            final bool calSug = !(rec?.calories?.trim().isNotEmpty ?? false);
            section.aerobicCaloriesCtrls
                .add(TextEditingController(text: calorieRaw));
            section.aerobicCalorieSuggestFlags
                .add(calSug || calorieRaw.isEmpty);
            section.aerobicCalorieHintVisible.add(false);
            section.aerobicCalorieHintShown.add(false);
            section.setInputDataList.add(<SetInputData>[]);
            section.previousVolumeList.add(lu?.totalVolume ?? rec?.totalVolume);
          } else {
            final int recLen =
                rec == null ? 0 : min(rec.weights.length, rec.reps.length);
            final int luLen =
                lu == null ? 0 : min(lu.weights.length, lu.reps.length);
            final int mergedLen = max(_currentSetCount, max(recLen, luLen));

            final row = <SetInputData>[];
            for (int i = 0; i < mergedLen; i++) {
              String w = '';
              String r = '';
              bool isSuggestion = true;
              bool checked = false;

              if (i < recLen) {
                w = rec!.weights[i];
                r = rec.reps[i];
                if (w.trim().isNotEmpty || r.trim().isNotEmpty) {
                  isSuggestion = false;
                }
                final checkedList = rec.checkedStates;
                if (checkedList != null && i < checkedList.length) {
                  checked = checkedList[i];
                } else {
                  checked = true;
                }
                if (!checked) {
                  isSuggestion = true;
                }
              } else if (i < luLen) {
                w = lu!.weights[i];
                r = lu.reps[i];
                isSuggestion = true;
              }

              row.add(SetInputData(
                weightController: TextEditingController(text: w),
                repController: TextEditingController(text: r),
                isSuggestion: isSuggestion,
                checked: checked,
              ));
            }
            section.setInputDataList.add(row);
            section.previousVolumeList.add(lu?.totalVolume ?? rec?.totalVolume);
          }
        }

        _currentSectionIndex = secIndex;
        _currentMenuIndex = 0;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _touchCard(secIndex, 0);
      final keys = _sections[secIndex].nameFieldKeys;
      if (keys.isNotEmpty) {
        await _scrollIntoComfortZoneAfterKeyboard(keys[0],
            pivot: 0.0, topExtra: 28);
      }
    });

    _scheduleHintsAfterPart();
  }

  Future<void> _showPartPicker(int secIndex) async {
    final parts = _filteredBodyParts;
    int initial = 0;
    final current = _sections[secIndex].selectedPart;
    if (current != null) {
      final idx = parts.indexOf(current);
      if (idx >= 0) initial = idx;
    }
    int temp = initial;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return InheritedTheme.captureAll(
          context,
          Material(
            color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 260,
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetCtx)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(sheetCtx)!.selectTrainingPart,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(sheetCtx).colorScheme.onSurface,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetCtx, null),
                            child: Text(
                              MaterialLocalizations.of(sheetCtx)
                                  .cancelButtonLabel,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(sheetCtx, parts[temp]),
                            child: Text(
                              MaterialLocalizations.of(sheetCtx).okButtonLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        scrollController:
                            FixedExtentScrollController(initialItem: initial),
                        onSelectedItemChanged: (i) => temp = i,
                        children: parts
                            .map(
                              (p) => Center(
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    color: Theme.of(sheetCtx)
                                        .colorScheme
                                        .onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked is String) {
      _applySelectedPart(secIndex, picked);
    }
  }

  String _getOriginalPartName(BuildContext context, String translatedPart) {
    final l10n = AppLocalizations.of(context)!;
    if (translatedPart == l10n.aerobicExercise) return '有酸素運動';
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
      default:
        return part;
    }
  }

  void _loadSettingsAndParts() {
    _loadCustomExercises();
    final l10n = AppLocalizations.of(context)!;

    _allBodyParts = [
      l10n.aerobicExercise,
      l10n.arm,
      l10n.chest,
      l10n.back,
      l10n.shoulder,
      l10n.leg,
      l10n.abs,
      l10n.fullBody,
      l10n.bodyWeightTraining,
      l10n.other1,
      l10n.other2,
      l10n.other3,
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

    int? savedSetCount = widget.setCountBox.get('setCount');
    final dateKey = _getDateKey(widget.selectedDate);
    final record = widget.recordsBox.get(dateKey);

    Set<String> partsInRecord = {};
    if (record != null) {
      partsInRecord = record.menus.keys.toSet();
    }

    _filteredBodyParts = [];
    if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
      _filteredBodyParts = _allBodyParts.where((translatedPart) {
        final original = _getOriginalPartName(context, translatedPart);
        return savedBodyPartsSettings![original] == true;
      }).toList();
    } else {
      _filteredBodyParts = List.from(_allBodyParts);
    }

    for (final originalPart in partsInRecord) {
      final translated = _translatePartToLocale(context, originalPart);
      if (!_filteredBodyParts.contains(translated)) {
        _filteredBodyParts.add(translated);
      }
    }

    _filteredBodyParts.sort((a, b) {
      final ia = _allBodyParts.indexOf(a);
      final ib = _allBodyParts.indexOf(b);
      return ia.compareTo(ib);
    });

    _currentSetCount = savedSetCount ?? 3;

    if (mounted) {
      setState(() {
        _loadInitialSections();
      });
    }
  }

  void _loadCustomExercises() {
    final dynamic raw = widget.settingsBox.get('customExercisesByPart');
    if (raw is Map) {
      final map = <String, List<String>>{};
      raw.forEach((key, value) {
        if (key is String && value is List) {
          final entries = value
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (entries.isNotEmpty) {
            map[key] = entries;
          }
        }
      });
      _customExercises = map;
    } else {
      _customExercises = {};
    }
  }

  Future<void> _saveCustomExercises() async {
    final map = <String, List<String>>{
      for (final entry in _customExercises.entries)
        entry.key: List<String>.from(entry.value),
    };
    await widget.settingsBox.put('customExercisesByPart', map);
  }

  Future<bool> _addCustomExercise(String originalPart, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final existing = _customExercises[originalPart];
    if (existing != null && existing.contains(trimmed)) {
      return false;
    }
    final map = Map<String, List<String>>.from(_customExercises);
    final list = List<String>.from(map[originalPart] ?? const []);
    list.add(trimmed);
    map[originalPart] = list;
    _customExercises = map;
    await _saveCustomExercises();
    return true;
  }

  List<String> _exerciseOptionsForPart(
    String originalPart, {
    String? currentName,
  }) {
    final options = LinkedHashSet<String>();
    final trimmedCurrent = currentName?.trim() ?? '';
    final l10n = AppLocalizations.of(context)!;
    options.addAll(ExerciseCatalog.defaultsFor(originalPart, l10n: l10n));
    final customList = _customExercises[originalPart];
    if (customList != null) {
      for (final name in customList) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          options.add(trimmed);
        }
      }
    }
    final dynamic rawLastUsed = widget.lastUsedMenusBox.get(originalPart);
    if (rawLastUsed is List) {
      for (final item in rawLastUsed) {
        if (item is MenuData) {
          final trimmed = item.name.trim();
          if (trimmed.isNotEmpty) {
            options.add(trimmed);
          }
        } else if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            options.add(trimmed);
          }
        }
      }
    }
    for (final section in _sections) {
      final selected = section.selectedPart;
      if (selected == null) continue;
      if (_getOriginalPartName(context, selected) != originalPart) continue;
      for (final ctrl in section.menuControllers) {
        final trimmed = ctrl.text.trim();
        if (trimmed.isNotEmpty) {
          options.add(trimmed);
        }
      }
    }
    if (trimmedCurrent.isNotEmpty && !options.contains(trimmedCurrent)) {
      options.add(trimmedCurrent);
    }
    return options.where((name) => name.isNotEmpty).toList(growable: false);
  }

  // 人気3＋補助2（有酸素は人気3）のプリセット。
// originalPart は日本語のオリジナル部位名（例: '胸', '背中', '有酸素運動'）。
  List<String> _presetPopularAndAssistNames(String originalPart) {
    switch (originalPart) {
      case '有酸素運動':
        // 人気3（+ 下で空2を足す）
        return ['ランニング', 'ウォーキング', 'エアロバイク'];

      case '腕':
        // 人気3
        final popular = ['ダンベルカール', 'バーベルカール', 'ケーブルトライセプスプレスダウン'];
        // 補助2
        final assist = ['ハンマーカール', 'スカルクラッシャー'];
        return [...popular, ...assist];

      case '胸':
        final popular = ['バーベルベンチプレス', 'ダンベルベンチプレス', 'インクラインベンチプレス'];
        final assist = ['ケーブルクロスオーバー', 'ダンベルフライ'];
        return [...popular, ...assist];

      case '背中':
        final popular = ['ラットプルダウン', 'ダンベルワンハンドロウ', 'チンニング（アシスト）'];
        final assist = ['シーテッドロウ', 'フェイスプル'];
        return [...popular, ...assist];

      case '肩':
        final popular = ['ダンベルショルダープレス', 'サイドレイズ', 'アーノルドプレス'];
        final assist = ['リアレイズ', 'フロントレイズ'];
        return [...popular, ...assist];

      case '足':
        final popular = ['バーベルスクワット', 'レッグプレス', 'ヒップスラスト'];
        final assist = ['レッグエクステンション', 'レッグカール'];
        return [...popular, ...assist];

      case '腹筋':
        final popular = ['クランチ', 'レッグレイズ', 'アブローラー'];
        final assist = ['ケーブルクランチ', 'バイシクルクランチ'];
        return [...popular, ...assist];

      case '全身':
        final popular = ['ケトルベルスイング', 'バーピージャンプ', 'クリーン＆プレス'];
        final assist = ['ファーマーズウォーク', 'ステップアップ'];
        return [...popular, ...assist];

      case '自重':
        final popular = ['腕立て伏せ', 'スクワット', 'プランク'];
        final assist = ['ディップス', 'ランジ'];
        return [...popular, ...assist];

      // その他* はプリセットなし（空2のみ後段で付与）
      default:
        return const [];
    }
  }

  Future<String?> _promptCustomExerciseName(AppLocalizations l10n) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CustomExerciseDialog(
        l10n: l10n,
        material: MaterialLocalizations.of(ctx),
      ),
    );
    if (result == null) {
      return null;
    }
    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      showAppSnack(context, l10n.customExerciseNameRequired);
      return null;
    }
    return trimmed;
  }

  Future<void> _showExercisePicker(int secIndex, int menuIndex) async {
    if (secIndex < 0 || secIndex >= _sections.length) {
      return;
    }
    final section = _sections[secIndex];
    if (menuIndex < 0 || menuIndex >= section.menuControllers.length) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final partLabel = section.selectedPart;
    if (partLabel == null) {
      showAppSnack(context, l10n.selectTrainingPart);
      return;
    }
    final originalPart = _getOriginalPartName(context, partLabel);
    final controller = section.menuControllers[menuIndex];
    List<String> pickerOptions = _exerciseOptionsForPart(
      originalPart,
      currentName: controller.text,
    );
    int tempIndex = 0;
    if (pickerOptions.isNotEmpty) {
      final currentName = controller.text.trim();
      final found = pickerOptions.indexOf(currentName);
      if (found >= 0) {
        tempIndex = found;
      }
    }

    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) {
        return InheritedTheme.captureAll(
          context,
          StatefulBuilder(
            builder: (stateCtx, setSheetState) {
              final cs = Theme.of(stateCtx).colorScheme;
              final sheetL10n = AppLocalizations.of(stateCtx)!;
              final sheetMaterial = MaterialLocalizations.of(stateCtx);

              Future<void> handleAdd() async {
                final newName = await _promptCustomExerciseName(sheetL10n);
                if (newName == null) {
                  if (!stateCtx.mounted) return;
                  return;
                }
                final added = await _addCustomExercise(originalPart, newName);
                if (!stateCtx.mounted) return;
                if (!added) {
                  showAppSnack(stateCtx, sheetL10n.customExerciseDuplicate);
                  return;
                }
                pickerOptions = _exerciseOptionsForPart(
                  originalPart,
                  currentName: newName,
                );
                tempIndex = pickerOptions.indexOf(newName);
                if (tempIndex < 0) {
                  tempIndex = 0;
                }
                if (!stateCtx.mounted) return;
                setSheetState(() {});
              }

              Widget buildPicker() {
                if (pickerOptions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        sheetL10n.customExercisePickerEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                if (tempIndex >= pickerOptions.length) {
                  tempIndex = pickerOptions.length - 1;
                }
                if (tempIndex < 0) {
                  tempIndex = 0;
                }
                return CupertinoPicker(
                  itemExtent: 36,
                  useMagnifier: true,
                  magnification: 1.08,
                  scrollController:
                      FixedExtentScrollController(initialItem: tempIndex),
                  onSelectedItemChanged: (i) => tempIndex = i,
                  children: [
                    for (final name in pickerOptions)
                      Center(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontFamily: kUiFont,
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                );
              }

              return SafeArea(
                child: SizedBox(
                  height: 320,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Text(
                              sheetL10n.selectExercise,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: handleAdd,
                              child: Text(sheetL10n.addNewExercise),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(stateCtx, null),
                              child: Text(sheetMaterial.cancelButtonLabel),
                            ),
                            TextButton(
                              onPressed: pickerOptions.isEmpty
                                  ? null
                                  : () => Navigator.pop(
                                        stateCtx,
                                        pickerOptions[tempIndex],
                                      ),
                              child: Text(sheetMaterial.okButtonLabel),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: buildPicker()),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }
    final trimmedResult = result.trim();
    if (trimmedResult.isEmpty || trimmedResult == controller.text.trim()) {
      return;
    }
    setState(() {
      controller.text = trimmedResult;
    });
  }

  // === ここから パーソナル・フローティングエディタ ===

  Future<void> _openPersonalOverlaySmooth() async {
    if (_personalOverlayVisible) return;

    _personalOverlayFocus.requestFocus();

    if (!mounted) return;
    setState(() {
      _personalOverlayVisible = true;
      _fabOpen = false; // FABダイヤルは閉じる
      _personalSlideIn = false; // 初期は少し上
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _personalSlideIn = true);
    });
  }

  Future<void> _savePersonalAndClose() async {
    _updateBmiDisplay();
    final didSave = _saveAllSectionsData();
    if (didSave) _showSavedChipFor(const Duration(milliseconds: 900));

    await _dismissKeyboardSafely(context);
    if (!mounted) return;
    setState(() => _personalSlideIn = false);
    await Future.delayed(_overlaySlideDuration);
    if (!mounted) return;
    setState(() => _personalOverlayVisible = false);
  }

  String _formatOneDecimal(double value) {
    final String fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  Future<double?> _showPersonalDecimalPicker({
    required String title,
    required int maxInteger,
    required String? unitLabel,
    double? initialValue,
  }) async {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    double sanitized = initialValue ?? 0.0;
    if (sanitized.isNaN || sanitized.isInfinite) {
      sanitized = 0.0;
    }
    if (sanitized < 0) {
      sanitized = 0.0;
    }
    final double maxValue = maxInteger + 0.9;
    if (sanitized > maxValue) {
      sanitized = maxValue;
    }
    sanitized = double.parse(sanitized.toStringAsFixed(1));
    int intPart = sanitized.toInt();
    if (intPart < 0) {
      intPart = 0;
    } else if (intPart > maxInteger) {
      intPart = maxInteger;
    }
    int decimalPart = ((sanitized - intPart) * 10).round();
    if (decimalPart < 0) {
      decimalPart = 0;
    } else if (decimalPart > 9) {
      decimalPart = 9;
    }
    int tempInt = intPart;
    int tempDec = decimalPart;

    final intController = FixedExtentScrollController(initialItem: intPart);
    final decController = FixedExtentScrollController(initialItem: decimalPart);

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      useRootNavigator: false,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) {
        return InheritedTheme.captureAll(
          context,
          Builder(
            builder: (modalCtx) {
              final modalCs = Theme.of(modalCtx).colorScheme;
              final modalMaterial = MaterialLocalizations.of(modalCtx);
              final String header = (unitLabel == null || unitLabel.isEmpty)
                  ? title
                  : '$title ($unitLabel)';
              return SafeArea(
                child: SizedBox(
                  height: 320,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: modalCs.onSurfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Text(
                              header,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: modalCs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(modalCtx, null),
                              child: Text(modalMaterial.cancelButtonLabel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(
                                modalCtx,
                                <int>[tempInt, tempDec],
                              ),
                              child: Text(modalMaterial.okButtonLabel),
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
                                itemExtent: 36,
                                useMagnifier: true,
                                magnification: 1.08,
                                scrollController: intController,
                                onSelectedItemChanged: (i) => tempInt = i,
                                children: [
                                  for (int i = 0; i <= maxInteger; i++)
                                    Center(
                                      child: Text(
                                        i.toString(),
                                        style: TextStyle(
                                          fontFamily: kUiFont,
                                          color: modalCs.onSurface,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              color: modalCs.onSurfaceVariant.withOpacity(0.12),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 36,
                                useMagnifier: true,
                                magnification: 1.08,
                                scrollController: decController,
                                onSelectedItemChanged: (i) => tempDec = i,
                                children: [
                                  for (int i = 0; i < 10; i++)
                                    Center(
                                      child: Text(
                                        '.${i.toString()}',
                                        style: TextStyle(
                                          fontFamily: kUiFont,
                                          color: modalCs.onSurface,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
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
          ),
        );
      },
    );

    if (result == null) {
      return null;
    }

    final int selectedInt = result[0].clamp(0, maxInteger).toInt();
    final int selectedDec = result[1].clamp(0, 9).toInt();
    final double computed = selectedInt + selectedDec / 10.0;
    return double.parse(computed.toStringAsFixed(1));
  }

  Future<void> _openPersonalWeightPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final unitLabel = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
    final current = double.tryParse(_weightController.text.trim());
    final picked = await _showPersonalDecimalPicker(
      title: l10n.bodyWeight,
      maxInteger: 999,
      unitLabel: unitLabel,
      initialValue: current,
    );
    if (picked == null) {
      return;
    }
    final String formatted = _formatOneDecimal(picked);
    if (_weightController.text.trim() == formatted) {
      return;
    }
    _weightController.text = formatted;
    _updateBmiDisplay();
  }

  Future<void> _openBodyFatPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final current = double.tryParse(_bodyFatController.text.trim());
    final picked = await _showPersonalDecimalPicker(
      title: l10n.bodyFat,
      maxInteger: 99,
      unitLabel: l10n.percentSymbol,
      initialValue: current,
    );
    if (picked == null) {
      return;
    }
    final String formatted = _formatOneDecimal(picked);
    if (_bodyFatController.text.trim() == formatted) {
      return;
    }
    _bodyFatController.text = formatted;
  }

  Future<void> _openWaistPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final current = double.tryParse(_waistController.text.trim());
    final unitLabel = SettingsManager.isWaistInch ? l10n.unitIn : l10n.unitCm;
    final picked = await _showPersonalDecimalPicker(
      title: l10n.waist,
      maxInteger: 999,
      unitLabel: unitLabel,
      initialValue: current,
    );
    if (picked == null) {
      return;
    }
    final String formatted = _formatOneDecimal(picked);
    if (_waistController.text.trim() == formatted) {
      return;
    }
    _waistController.text = formatted;
  }

  Future<void> _openBmrPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final current =
        double.tryParse(_bmrController.text.trim().replaceAll(',', ''));
    final picked = await _showPersonalDecimalPicker(
      title: l10n.bmrTitleShort,
      maxInteger: 9999,
      unitLabel: l10n.kcalUnit,
      initialValue: current,
    );
    if (picked == null) {
      return;
    }
    final String formatted = _formatOneDecimal(picked);
    if (_bmrController.text.trim() == formatted) {
      return;
    }
    setState(() {
      _bmrController.text = formatted;
    });
  }

  void _disposeMealControllers() {
    for (final list in _mealControllers) {
      for (final controllers in list) {
        controllers.dispose();
      }
    }
    _mealControllers.clear();
  }

  void _resetMealState() {
    _disposeMealControllers();
    _mealCards.clear();
    _mealControllers.clear();
    _mealCollapsed.clear();
    _totalMealKcal = 0;
    _currentMealIndex = null;
  }

  MealCategory _mealCategoryFromString(String value) {
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

  Future<MealCategory?> _showMealCategoryPicker({MealCategory? current}) async {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<MealCategory>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                l10n.mealCategory,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...MealCategory.values.map(
                (cat) {
                  final selected = current == cat;
                  return ListTile(
                    dense: true,
                    title: Text(
                      _mealCategoryLabel(cat, l10n),
                      style: TextStyle(color: cs.onSurface),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(cat),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  _MealRowControllers _createMealRowControllers({
    String name = '',
    double? kcal,
  }) {
    return _MealRowControllers(
      nameController: TextEditingController(text: name),
      kcalController: TextEditingController(
        text: kcal == null ? '' : _formatKcalInput(kcal),
      ),
    );
  }

  void _loadMealCardsFromRecord(DailyRecord? record) {
    _resetMealState();
    final raw = record?.meals;
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final category =
            _mealCategoryFromString((map['category'] as String?) ?? 'morning');
        final itemsRaw = map['items'];
        final List<dynamic> itemList = (itemsRaw is List) ? itemsRaw : const [];
        final items = <MealItem>[];
        final controllers = <_MealRowControllers>[];
        for (final item in itemList) {
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
          items.add(MealItem(name: name, kcal: kcal));
          controllers.add(
            _createMealRowControllers(name: name, kcal: kcal),
          );
        }
        while (items.length < 3) {
          items.add(MealItem());
          controllers.add(_createMealRowControllers());
        }
        final subtotalRaw = map['subtotal'];
        double subtotal = 0;
        if (subtotalRaw is num) {
          subtotal = subtotalRaw.toDouble();
        } else if (subtotalRaw is String) {
          subtotal = double.tryParse(subtotalRaw) ?? 0;
        }

        final card = MealCardState(
          category: category,
          items: items,
          subtotalKcal: subtotal,
        );
        _mealCards.add(card);
        _mealControllers.add(controllers);
        _mealCollapsed.add(true);
      }
      _recalculateMealTotals();
    } catch (_) {
      _resetMealState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        showAppSnack(context, l10n.mealRestoreFailed);
      });
    }
  }

  int _addMealCard(MealCategory category) {
    final items = List<MealItem>.generate(3, (_) => MealItem());
    final controllers = List<_MealRowControllers>.generate(
        3, (_) => _createMealRowControllers());
    final card = MealCardState(
      category: category,
      items: items,
      subtotalKcal: 0,
    );
    _mealCards.add(card);
    _mealControllers.add(controllers);
    _mealCollapsed.add(true);
    _recalculateMealTotals();
    return _mealCards.length - 1;
  }

  void _addMealItemRow(int cardIndex) {
    _mealCards[cardIndex].items.add(MealItem());
    _mealControllers[cardIndex].add(_createMealRowControllers());
  }

  Future<void> _showMealOverlay(int cardIndex) async {
    if (_mealOverlayVisible || _mealOverlayOpening) return;
    if (cardIndex < 0 || cardIndex >= _mealCards.length) {
      return;
    }

    _mealOverlayOpening = true;
    _mealOverlayIndex = cardIndex;
    _mealOverlayFocus.requestFocus();

    if (!mounted) return;
    setState(() {
      _mealOverlayVisible = true;
      _mealOverlayOpening = false;
      _mealSlideIn = false;
      _fabOpen = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _mealSlideIn = true);
    });
  }

  Future<void> _saveMealOverlayAndClose() async {
    if (!_mealOverlayVisible) return;
    FocusScope.of(context).unfocus();
    await _dismissKeyboardSafely(context);
    _recalculateMealTotals();
    if (!mounted) return;
    setState(() => _mealSlideIn = false);
    await Future.delayed(_overlaySlideDuration);
    if (!mounted) return;
    setState(() {
      _mealOverlayVisible = false;
      _mealOverlayIndex = null;
      _mealOverlayOpening = false;
    });
  }

  void _toggleMealCollapse(int index) {
    if (index < 0 || index >= _mealCollapsed.length) {
      return;
    }
    setState(() {
      _mealCollapsed[index] = !_mealCollapsed[index];
    });
  }

  void _reorderMealCards(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _mealCards.length) {
      return;
    }
    if (newIndex < 0 || newIndex > _mealCards.length) {
      return;
    }
    if (oldIndex == newIndex) {
      return;
    }
    final MealCardState? activeCard = (_currentMealIndex != null &&
            _currentMealIndex! >= 0 &&
            _currentMealIndex! < _mealCards.length)
        ? _mealCards[_currentMealIndex!]
        : null;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final card = _mealCards.removeAt(oldIndex);
      final controllers = _mealControllers.removeAt(oldIndex);
      final collapsed = _mealCollapsed.removeAt(oldIndex);
      _mealCards.insert(newIndex, card);
      _mealControllers.insert(newIndex, controllers);
      _mealCollapsed.insert(newIndex, collapsed);
      if (activeCard != null) {
        final newActiveIndex = _mealCards.indexOf(activeCard);
        _currentMealIndex = newActiveIndex >= 0 ? newActiveIndex : null;
      }
    });
  }

  void _removeMealCard(int index) {
    if (index < 0 || index >= _mealCards.length) {
      return;
    }

    final controllers = _mealControllers[index];
    for (final c in controllers) {
      c.dispose();
    }

    setState(() {
      _mealControllers.removeAt(index);
      _mealCards.removeAt(index);
      if (index >= 0 && index < _mealCollapsed.length) {
        _mealCollapsed.removeAt(index);
      }

      if (_mealCards.isEmpty) {
        _currentMealIndex = null;
      } else if (_currentMealIndex != null) {
        if (_currentMealIndex! == index) {
          final nextIndex = index >= _mealCards.length ? _mealCards.length - 1 : index;
          _currentMealIndex = nextIndex;
        } else if (_currentMealIndex! > index) {
          _currentMealIndex = _currentMealIndex! - 1;
        }
      }

      _recalculateMealTotals();
    });
  }

  void _removeAllMealCards() {
    setState(_resetMealState);
  }

  Future<void> _confirmRemoveAllMealCards(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(l10n.mealDeleteConfirmTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                l10n.no,
                style: TextStyle(color: cs.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(
                l10n.yes,
                style: TextStyle(color: cs.primary),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      _removeAllMealCards();
    }
  }

  void _onMealNameChanged(int cardIndex, int itemIndex, String value) {
    if (cardIndex < 0 || cardIndex >= _mealCards.length) {
      return;
    }
    if (itemIndex < 0 || itemIndex >= _mealCards[cardIndex].items.length) {
      return;
    }
    _mealCards[cardIndex].items[itemIndex].name = value;
  }

  void _onMealKcalChanged(int cardIndex, int itemIndex, String value) {
    final trimmed = value.trim();
    final parsed = trimmed.isEmpty ? null : double.tryParse(trimmed);
    if (cardIndex < 0 || cardIndex >= _mealCards.length) {
      return;
    }
    if (itemIndex < 0 || itemIndex >= _mealCards[cardIndex].items.length) {
      return;
    }
    _mealCards[cardIndex].items[itemIndex].kcal = parsed;
    _recalculateMealTotals();
  }

  void _recalculateMealTotals() {
    double total = 0;
    for (final card in _mealCards) {
      double subtotal = 0;
      for (final item in card.items) {
        final kcal = item.kcal;
        if (kcal != null && kcal > 0) {
          subtotal += kcal;
        }
      }
      card.subtotalKcal = subtotal;
      total += subtotal;
    }
    _totalMealKcal = total;
  }

  List<Map<String, dynamic>> _serializeMeals() {
    final result = <Map<String, dynamic>>[];
    for (final card in _mealCards) {
      result.add({
        'category': card.category.name,
        'items': [
          for (final item in card.items)
            {
              'name': item.name,
              'kcal': item.kcal,
            }
        ],
        'subtotal': card.subtotalKcal,
      });
    }
    return result;
  }

  String _formatKcalDisplay(double value) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = NumberFormat('#,##0', locale);
    return formatter.format(value.round());
  }

  String _formatKcalInput(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  double? _calculateBmr() {
    final weightKg = _currentWeightKg() ?? SettingsManager.personalWeightKg;
    final heightCm = _heightCmFromSettingsBox();
    final birthDate = _birthDateFromSettings();
    final gender = _genderForBmr();
    if (weightKg == null ||
        heightCm == null ||
        birthDate == null ||
        gender == null) {
      return null;
    }
    final age = _ageFromBirth(birthDate);
    if (age == null) return null;
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final offset = gender == 'male' ? 5 : -161;
    final result = base + offset;
    if (!result.isFinite) return null;
    return result;
  }

  double? _heightCmFromSettingsBox() {
    final candidates = [
      widget.settingsBox.get('personal.heightCm'),
      widget.settingsBox.get('height_cm'),
      widget.settingsBox.get('heightCm'),
      widget.settingsBox.get('user_height_cm'),
      widget.settingsBox.get('height'),
    ];
    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    final personalMeters = widget.settingsBox.get('personal.heightM');
    if (personalMeters is num) return personalMeters.toDouble() * 100;
    if (personalMeters is String) {
      final parsed = double.tryParse(personalMeters);
      if (parsed != null) return parsed * 100;
    }

    final meters = widget.settingsBox.get('height_m');
    if (meters is num) return meters.toDouble() * 100;
    if (meters is String) {
      final parsed = double.tryParse(meters);
      if (parsed != null) return parsed * 100;
    }

    return null;
  }

  DateTime? _birthDateFromSettings() {
    final stored = widget.settingsBox.get('personal.birthDate');
    if (stored is DateTime) return stored;
    if (stored is String) {
      return DateTime.tryParse(stored);
    }
    return null;
  }

  String? _genderForBmr() {
    final candidates = [
      widget.settingsBox.get('personal.gender'),
      widget.settingsBox.get('gender'),
    ];
    for (final value in candidates) {
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower.contains('male') || lower.contains('男')) return 'male';
        if (lower.contains('female') || lower.contains('女')) return 'female';
      }
    }
    return null;
  }

  int? _ageFromBirth(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final hadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) {
      age -= 1;
    }
    if (age < 0) return null;
    return age;
  }

  void _loadInitialSections() {
    final dateKey = _getDateKey(widget.selectedDate);
    final record = widget.recordsBox.get(dateKey);

    _loadMealCardsFromRecord(record);

    for (var s in _sections) {
      s.dispose();
    }
    _sections.clear();

    if (record?.weight != null) {
      _weightController.text = record!.weight.toString();
    } else {
      _weightController.clear();
    }

    // ▼ 追加：固定フィールドがあれば優先表示
    if (record?.bodyFatPercent != null) {
      _bodyFatController.text = record!.bodyFatPercent!.toString();
    }
    if (record?.waistCm != null) {
      _waistController.text = record!.waistCm!.toString();
    }

    // （レガシーデータ用）settingsBox からの復元は残す
    final pm = widget.settingsBox.get('personalMetrics-$dateKey');

    if (pm is Map) {
      final bf = pm['bodyFat'];
      if (bf is num) {
        _bodyFatController.text = bf.toString();
      } else if (bf is String) {
        _bodyFatController.text = bf;
      }

      final wst = pm['waist'];
      if (wst is num) {
        _waistController.text = wst.toString();
      } else if (wst is String) {
        _waistController.text = wst;
      }
    } else {
      _bodyFatController.clear();
      _waistController.clear();
    }

    // 体重(と身長)から BMI を初期計算
    _updateBmiDisplay();

    final savedBmr = record?.bmr;
    if (savedBmr != null) {
      _bmrController.text = _formatKcalInput(savedBmr);
    } else {
      final autoBmr = _calculateBmr();
      if (autoBmr != null) {
        _bmrController.text = _formatKcalInput(autoBmr);
      } else {
        _bmrController.clear();
      }
    }

    String? recoveredNote;
    try {
      final dyn = record as dynamic;
      recoveredNote = dyn?.note as String?;
    } catch (_) {}
    if (recoveredNote == null) {
      final m = widget.settingsBox.get('memo-$dateKey');
      if (m is Map) {
        final body = (m['body'] as String?) ?? '';
        final titleCompat = (m['title'] as String?) ?? '';
        recoveredNote = body.isNotEmpty ? body : titleCompat;
      }
    }
    _memoController.text = (recoveredNote ?? '');
    _showMemo = _memoController.text.trim().isNotEmpty;

    if (record == null || record.menus.isEmpty) {
      // 初期は「未選択のカード1つ」だけ
      final section = SectionData.createEmpty(
        _currentSetCount,
        shouldPopulateDefaults: false,
      );
      section.selectedPart = null; // 未選択状態

      _sections.clear();
      _sections.add(section);

      _currentSectionIndex = 0;
      _currentMenuIndex = null;
      setState(() {});
      return;
    }

    final Map<String, SectionData> tempSectionsMap = {};
    final partsFromRecords = record.menus.keys.toList();

    for (final originalPart in partsFromRecords) {
      final translatedPart = _translatePartToLocale(context, originalPart);
      final l10n = AppLocalizations.of(context)!;
      final isAerobic = translatedPart == l10n.aerobicExercise;

      final section = tempSectionsMap.putIfAbsent(
        translatedPart,
        () => SectionData(
          key: GlobalKey(),
          selectedPart: translatedPart,
          menuControllers: [],
          setInputDataList: [],
          menuKeys: [],
          nameFieldKeys: [],
          menuCollapsedStates: [],
          satisfactionList: [],
          previousVolumeList: [],
          aerobicDistanceCtrls: [],
          aerobicDurationCtrls: [],
          aerobicSuggestFlags: [],
          aerobicCaloriesCtrls: [],
          aerobicCalorieSuggestFlags: [],
        ),
      );

      final recList = record.menus[originalPart] ?? <MenuData>[];
      final dynamic rawLU = widget.lastUsedMenusBox.get(originalPart);
      final luList =
          (rawLU is List) ? rawLU.whereType<MenuData>().toList() : <MenuData>[];

      final Map<String, MenuData> recBy = {for (final m in recList) m.name: m};
      final Map<String, MenuData> luBy = {for (final m in luList) m.name: m};

      final List<String> names = [
        ...recList.map((m) => m.name),
        ...luList.where((m) => !recBy.containsKey(m.name)).map((m) => m.name),
      ];

      if (names.isEmpty) names.add('');

      for (final name in names) {
        final rec = recBy[name];
        final lu = luBy[name];

        section.menuControllers.add(TextEditingController(text: name));
        section.menuKeys.add(GlobalKey());
        section.nameFieldKeys.add(GlobalKey());
        section.menuCollapsedStates.add(true);
        section.satisfactionList.add(rec?.satisfaction);

        if (isAerobic) {
          final String dist = (rec?.distance?.trim().isNotEmpty ?? false)
              ? rec!.distance!.trim()
              : (lu?.distance?.trim() ?? '');
          final String dura = (rec?.duration?.trim().isNotEmpty ?? false)
              ? rec!.duration!.trim()
              : (lu?.duration?.trim() ?? '');
          final bool isSug = !(rec?.distance?.trim().isNotEmpty == true ||
              rec?.duration?.trim().isNotEmpty == true);

          section.aerobicDistanceCtrls.add(TextEditingController(text: dist));
          section.aerobicDurationCtrls.add(TextEditingController(text: dura));
          section.aerobicSuggestFlags.add(isSug);
          final String cal = (rec?.calories?.trim().isNotEmpty ?? false)
              ? rec!.calories!.trim()
              : (lu?.calories?.trim() ?? '');
          final bool calSug = !(rec?.calories?.trim().isNotEmpty == true);
          section.aerobicCaloriesCtrls.add(TextEditingController(text: cal));
          section.aerobicCalorieSuggestFlags.add(calSug);
          section.aerobicCalorieHintVisible.add(false);
          section.aerobicCalorieHintShown.add(false);
          section.setInputDataList.add(<SetInputData>[]);
          section.previousVolumeList.add(lu?.totalVolume ?? rec?.totalVolume);
        } else {
          final int recLen =
              rec == null ? 0 : min(rec.weights.length, rec.reps.length);
          final int luLen =
              lu == null ? 0 : min(lu.weights.length, lu.reps.length);
          final int mergedLen = max(_currentSetCount, max(recLen, luLen));

          final row = <SetInputData>[];
          for (int i = 0; i < mergedLen; i++) {
            String w = '';
            String r = '';
            bool isSuggestion = true;
            bool checked = false;

            if (i < recLen) {
              w = rec!.weights[i];
              r = rec.reps[i];
              if (w.trim().isNotEmpty || r.trim().isNotEmpty) {
                isSuggestion = false;
              }
              final checkedList = rec.checkedStates;
              if (checkedList != null && i < checkedList.length) {
                checked = checkedList[i];
              } else {
                checked = true;
              }
              if (!checked) {
                isSuggestion = true;
              }
            } else if (i < luLen) {
              w = lu!.weights[i];
              r = lu.reps[i];
              isSuggestion = true;
            }
            row.add(SetInputData(
              weightController: TextEditingController(text: w),
              repController: TextEditingController(text: r),
              isSuggestion: isSuggestion,
              checked: checked,
            ));
          }
          section.setInputDataList.add(row);
          section.previousVolumeList.add(lu?.totalVolume ?? rec?.totalVolume);
        }
      }
    }

    _sections = tempSectionsMap.values.toList();
    _sections.sort((a, b) {
      if (a.selectedPart == null && b.selectedPart == null) return 0;
      if (a.selectedPart == null) return 1;
      if (b.selectedPart == null) return -1;
      final ia = _allBodyParts.indexOf(a.selectedPart!);
      final ib = _allBodyParts.indexOf(b.selectedPart!);
      return ia.compareTo(ib);
    });

    if (_sections.isNotEmpty &&
        _sections.first.selectedPart != null &&
        _sections.first.menuControllers.isNotEmpty) {
      _currentSectionIndex = 0;
      _currentMenuIndex = 0;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollIntoView(0, 0);
      });
    } else {
      _currentSectionIndex = null;
      _currentMenuIndex = null;
      setState(() {});
    }
    _applyWaistDisplayUnitFromCm();

    if (SettingsManager.enableAerobicCalories) {
      _recalculateAllAerobicCalories(force: true);
    }

// 既に値があれば当日パーソナルカードを自動表示
    _showPersonalCard = _weightController.text.trim().isNotEmpty ||
        _bodyFatController.text.trim().isNotEmpty ||
        _waistController.text.trim().isNotEmpty;
  }

  String _getDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _clearSectionControllersAndMaps(SectionData section) {
    for (var c in section.menuControllers) {
      c.dispose();
    }
    for (var list in section.setInputDataList) {
      for (var d in list) {
        d.dispose();
      }
    }
    for (var c in section.aerobicDistanceCtrls) {
      c.dispose();
    }
    for (var c in section.aerobicDurationCtrls) {
      c.dispose();
    }
    for (var c in section.aerobicCaloriesCtrls) {
      c.dispose();
    }
    section.menuControllers.clear();
    section.setInputDataList.clear();
    section.aerobicDistanceCtrls.clear();
    section.aerobicDurationCtrls.clear();
    section.aerobicSuggestFlags.clear();
    section.aerobicCaloriesCtrls.clear();
    section.aerobicCalorieSuggestFlags.clear();
    section.aerobicCalorieHintVisible.clear();
    section.aerobicCalorieHintShown.clear();
    section.nameFieldKeys.clear();
    // 追加
    section.menuCollapsedStates.clear();
    section.satisfactionList.clear();
    section.previousVolumeList.clear();
  }

  bool _saveAllSectionsData({bool showHint = true}) {
    final dateKey = _getDateKey(widget.selectedDate);
    final Map<String, List<MenuData>> allMenusForRecord = {};
    // 追加：満足度保存用（部位→{種目名: 値}）
    String? lastModifiedPart;
    bool hasAnyRecordData = false;
    final l10n = AppLocalizations.of(context)!;
    final mealsPayload = _serializeMeals();

    if (mealsPayload.isNotEmpty) {
      hasAnyRecordData = true;
    }

    for (int sec = 0; sec < _sections.length; sec++) {
      final section = _sections[sec];
      if (section.selectedPart == null) continue;
      final originalPart = _getOriginalPartName(context, section.selectedPart!);
      final isAerobic = section.selectedPart == l10n.aerobicExercise;

      final listForLastUsed = <MenuData>[];
      final listForRecord = <MenuData>[];

      for (int i = 0; i < section.menuControllers.length; i++) {
        final name = section.menuControllers[i].text.trim();
        if (name.isEmpty) continue;

        // 追加：このメニューの満足度（null=未選択）
        final int? sat = (i < section.satisfactionList.length)
            ? section.satisfactionList[i]
            : null;

        if (isAerobic) {
          final distance = i < section.aerobicDistanceCtrls.length
              ? section.aerobicDistanceCtrls[i].text
              : '';
          final duration = i < section.aerobicDurationCtrls.length
              ? section.aerobicDurationCtrls[i].text
              : '';
          final isSug = i < section.aerobicSuggestFlags.length
              ? section.aerobicSuggestFlags[i]
              : true;
          var calorieText = i < section.aerobicCaloriesCtrls.length
              ? section.aerobicCaloriesCtrls[i].text.trim()
              : '';
          var calSug = i < section.aerobicCalorieSuggestFlags.length
              ? section.aerobicCalorieSuggestFlags[i]
              : true;

          listForLastUsed.add(MenuData(
            name: name,
            weights: const <String>[],
            reps: const <String>[],
            distance: distance,
            duration: duration,
            calories: calorieText.isNotEmpty ? calorieText : null,
            satisfaction: sat,
            checkedStates: null,
            totalVolume: null,
          ));

          final double parsedDistance =
              double.tryParse(distance.replaceAll(',', '')) ?? 0;
          final double minutes =
              _parseDurationMinutes(duration.replaceAll(',', ''));
          final bool hasDistance = parsedDistance > 0;
          final bool hasDuration = minutes > 0;
          var hasCalories = calorieText.isNotEmpty;

          final bool shouldAttemptHint =
              SettingsManager.enableAerobicCalories &&
                  name.isNotEmpty &&
                  (hasDistance || hasDuration) &&
                  !hasCalories;
          if (shouldAttemptHint) {
            _updateCalorieSuggestion(
              sec,
              i,
              force: true,
              shouldShowHint: showHint,
            );
            calorieText = i < section.aerobicCaloriesCtrls.length
                ? section.aerobicCaloriesCtrls[i].text.trim()
                : '';
            calSug = i < section.aerobicCalorieSuggestFlags.length
                ? section.aerobicCalorieSuggestFlags[i]
                : true;
            hasCalories = calorieText.isNotEmpty;
            if (!showHint && i < section.aerobicCalorieHintVisible.length) {
              section.aerobicCalorieHintVisible[i] = false;
            }
          }

          if ((!isSug && (hasDistance || hasDuration)) ||
              (!calSug && hasCalories) ||
              (hasCalories && SettingsManager.enableAerobicCalories)) {
            listForRecord.add(MenuData(
              name: name,
              weights: const <String>[],
              reps: const <String>[],
              distance: distance,
              duration: duration,
              calories: hasCalories ? calorieText : null,
              satisfaction: sat,
              checkedStates: null,
              totalVolume: null,
            ));
            hasAnyRecordData = true;
            lastModifiedPart ??= originalPart;
          }
        } else {
          final weightsAll = <String>[];
          final repsAll = <String>[];
          final checkedAll = <bool>[];
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final set = section.setInputDataList[i][s];
            weightsAll.add(set.weightController.text);
            repsAll.add(set.repController.text);
            checkedAll.add(set.checked);
          }
          final double? totalVolume =
              calculateTotalVolume(section.setInputDataList[i]);
          listForLastUsed.add(MenuData(
            name: name,
            weights: weightsAll,
            reps: repsAll,
            calories: null,
            satisfaction: sat,
            checkedStates: checkedAll,
            totalVolume: totalVolume,
          ));

          final weightsConfirmed = <String>[];
          final repsConfirmed = <String>[];
          final checkedConfirmed = <bool>[];
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final set = section.setInputDataList[i][s];
            final w = set.weightController.text;
            final r = set.repController.text;
            final hasValue = w.trim().isNotEmpty || r.trim().isNotEmpty;
            if (set.checked && hasValue) {
              weightsConfirmed.add(w);
              repsConfirmed.add(r);
              checkedConfirmed.add(true);
            }
          }
          if (weightsConfirmed.isNotEmpty || repsConfirmed.isNotEmpty) {
            listForRecord.add(MenuData(
              name: name,
              weights: weightsConfirmed,
              reps: repsConfirmed,
              calories: null,
              satisfaction: sat,
              checkedStates: checkedConfirmed,
              totalVolume: totalVolume,
            ));
            hasAnyRecordData = true;
            lastModifiedPart ??= originalPart;
          }
        }
      }

      if (listForLastUsed.isNotEmpty) {
        widget.lastUsedMenusBox.put(originalPart, listForLastUsed);
      } else {
        widget.lastUsedMenusBox.delete(originalPart);
      }
      if (listForRecord.isNotEmpty) {
        allMenusForRecord[originalPart] = listForRecord;
      }
    }

    final memoText = _memoController.text.trim();
    if (memoText.isNotEmpty) {
      hasAnyRecordData = true;
    }

    double? bodyWeight;
    double? bodyWeightKgForPersonal;
    if (_weightController.text.isNotEmpty) {
      bodyWeight = double.tryParse(_weightController.text);
      if (bodyWeight != null) {
        hasAnyRecordData = true;
        bodyWeightKgForPersonal = (SettingsManager.currentUnit == 'kg')
            ? bodyWeight
            : bodyWeight * 0.45359237;
      }
    }

    double? bmrManual;
    final String rawBmr = _bmrController.text.trim().replaceAll(',', '');
    if (rawBmr.isNotEmpty) {
      final parsed = double.tryParse(rawBmr);
      if (parsed != null) {
        bmrManual = parsed;
        hasAnyRecordData = true;
      }
    }

    // ▼ 追加：体脂肪率/ウエストを先に数値化（固定フィールドへ保存するため）
    final String rawBf = _bodyFatController.text.trim();
    final double? bodyFatVal = rawBf.isEmpty ? null : double.tryParse(rawBf);

    final String rawWaist = _waistController.text.trim();
    double? waistVal;
    if (rawWaist.isNotEmpty) {
      final w = double.tryParse(rawWaist);
      if (w != null) {
        waistVal = SettingsManager.isWaistInch ? (w * 2.54) : w; // -> cm
      }
    }

    bool didChangeStorage = false;
    if (hasAnyRecordData || bodyFatVal != null || waistVal != null) {
      final newRecord = DailyRecord(
        date: widget.selectedDate,
        menus: allMenusForRecord,
        lastModifiedPart: lastModifiedPart,
        weight: bodyWeight,
        bodyFatPercent: bodyFatVal,
        // 追加
        waistCm: waistVal,
        // 追加
        meals: mealsPayload.isEmpty ? null : mealsPayload,
        bmr: bmrManual,
      );

      try {
        final dyn = newRecord as dynamic;
        dyn.note = memoText;
      } catch (_) {}

      widget.recordsBox.put(dateKey, newRecord);
      didChangeStorage = true;

      widget.settingsBox.put('memo-$dateKey', {'body': memoText});
    } else {
      final had = widget.recordsBox.containsKey(dateKey);
      widget.recordsBox.delete(dateKey);
      widget.settingsBox.delete('memo-$dateKey');
// （削除）満足度は MenuData に保存

      didChangeStorage = had;
    }

    if (bodyWeightKgForPersonal != null) {
      SettingsManager.setPersonalWeightKg(bodyWeightKgForPersonal);
    }
    // ───────── 体脂肪/ウエスト/BMI の保存（当日分）─────────
    {
      final pmKey = 'personalMetrics-$dateKey';
      final Map<String, dynamic> pmNew = {};
      final prevPm = widget.settingsBox.get(pmKey);

      // 体脂肪
      final String rawBf = _bodyFatController.text.trim();
      final bfVal = double.tryParse(rawBf);
      if (bfVal != null) pmNew['bodyFat'] = bfVal;

      // ウエスト
      final String rawWaist = _waistController.text.trim();
      final w = double.tryParse(rawWaist);
      if (w != null) {
        pmNew['waist'] = SettingsManager.isWaistInch ? (w * 2.54) : w;
      }

      // BMI
      if (_bmiValue != null) {
        pmNew['bmi'] = double.parse(_bmiValue!.toStringAsFixed(1));
      }

      final bool hadOld = prevPm is Map && prevPm.isNotEmpty;
      final bool hasNew = pmNew.isNotEmpty;

      if (hasNew) {
        widget.settingsBox.put(pmKey, pmNew);
        didChangeStorage = true;
      } else if (hadOld) {
        widget.settingsBox.delete(pmKey);
        didChangeStorage = true;
      }
    }

// ───────────────────────────────────────────────

    return didChangeStorage;
  }

  bool _trimTrailingEmptySetsForAllMenus(int baseline) {
    final l10n = AppLocalizations.of(context)!;
    bool changed = false;

    for (final section in _sections) {
      if (section.selectedPart == null) continue;
      if (section.selectedPart == l10n.aerobicExercise) continue;

      for (int m = 0; m < section.setInputDataList.length; m++) {
        final row = section.setInputDataList[m];
        if (row.isEmpty) continue;

        int lastFilled = -1;
        for (int i = 0; i < row.length; i++) {
          final w = row[i].weightController.text.trim();
          final r = row[i].repController.text.trim();
          if (w.isNotEmpty || r.isNotEmpty) {
            lastFilled = i;
          }
        }

        final int keep =
            max(baseline, lastFilled + 1).clamp(0, row.length) as int;
        if (keep < row.length) {
          for (int i = row.length - 1; i >= keep; i--) {
            row[i].dispose();
            row.removeLast();
          }
          changed = true;
        }
      }
    }
    return changed;
  }

  double? _currentWeightKg() {
    final text = _weightController.text.trim();
    final parsed = double.tryParse(text);
    if (parsed != null) {
      return SettingsManager.currentUnit == 'kg' ? parsed : parsed * 0.45359237;
    }

    final personal = SettingsManager.personalWeightKg;
    return personal;
  }

  double? _currentBmrValue() {
    final raw = _bmrController.text.trim();
    if (raw.isNotEmpty) {
      final cleaned = raw.replaceAll(',', '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) {
        return parsed;
      }
    }
    return _calculateBmr();
  }

  String _formattedBmrDifference(AppLocalizations l10n) {
    final bmr = _currentBmrValue();
    if (bmr == null) {
      return '${l10n.bmrDiffShort}: —';
    }
    final diff = bmr - _totalMealKcal;
    return '${l10n.bmrDiffShort}: ${_formatKcalDisplay(diff)} ${l10n.kcalUnit}';
  }

  double _parseDurationMinutes(String text) {
    if (text.isEmpty) return 0;
    final parts = text.split(':');
    if (parts.length >= 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = parts.length >= 3 ? int.tryParse(parts[2]) ?? 0 : 0;
      return hours * 60 + minutes + (seconds / 60.0);
    }
    return double.tryParse(text) ?? 0;
  }

  double? _estimateMet(String name,
      {double? distanceKm, double? durationMinutes}) {
    final lower = name.toLowerCase();
    if (lower.contains('run') ||
        lower.contains('ランニング') ||
        lower.contains('マラソン')) {
      if (distanceKm != null &&
          distanceKm > 0 &&
          durationMinutes != null &&
          durationMinutes > 0) {
        final speed = distanceKm / (durationMinutes / 60.0);
        if (speed < 8.0) return 7.0;
        if (speed < 12.0) return 9.8;
        return 11.5;
      }
      return 9.8;
    }
    if (lower.contains('jog') || lower.contains('ジョギング')) {
      if (distanceKm != null &&
          distanceKm > 0 &&
          durationMinutes != null &&
          durationMinutes > 0) {
        final speed = distanceKm / (durationMinutes / 60.0);
        if (speed < 7.0) return 6.0;
        if (speed < 9.0) return 7.0;
        return 9.0;
      }
      return 7.0;
    }
    if (lower.contains('walk') ||
        lower.contains('ウォーキング') ||
        lower.contains('散歩')) {
      if (distanceKm != null &&
          distanceKm > 0 &&
          durationMinutes != null &&
          durationMinutes > 0) {
        final speed = distanceKm / (durationMinutes / 60.0);
        if (speed < 3.0) return 2.5;
        if (speed < 5.0) return 3.5;
        if (speed < 6.5) return 4.3;
        return 5.0;
      }
      return 3.5;
    }
    if (lower.contains('cycle') ||
        lower.contains('bike') ||
        lower.contains('サイクリング') ||
        lower.contains('バイク')) {
      if (distanceKm != null &&
          distanceKm > 0 &&
          durationMinutes != null &&
          durationMinutes > 0) {
        final speed = distanceKm / (durationMinutes / 60.0);
        if (speed < 16.0) return 6.8;
        if (speed < 20.0) return 8.0;
        if (speed < 25.0) return 10.0;
        return 12.0;
      }
      return 8.0;
    }
    if (lower.contains('swim') ||
        lower.contains('水泳') ||
        lower.contains('スイム')) {
      return 8.0;
    }
    if (lower.contains('elliptical') ||
        lower.contains('クロストレーナー') ||
        lower.contains('エリプティカル')) {
      return 5.5;
    }
    if (lower.contains('row') || lower.contains('ローイング')) {
      return 7.0;
    }
    if (lower.contains('rope') || lower.contains('縄跳び')) {
      return 11.0;
    }
    if (lower.contains('dance') || lower.contains('ダンス')) {
      return 5.5;
    }
    if (lower.contains('hike') || lower.contains('登山')) {
      return 6.0;
    }
    if (lower.contains('ski') || lower.contains('スキー')) {
      return 7.0;
    }
    return null;
  }

  double? _calculateCaloriesFor(int sectionIndex, int menuIndex) {
    final section = _sections[sectionIndex];
    if (menuIndex >= section.menuControllers.length) return null;
    final name = section.menuControllers[menuIndex].text.trim();
    if (name.isEmpty) return null;

    final durationText = (menuIndex < section.aerobicDurationCtrls.length)
        ? section.aerobicDurationCtrls[menuIndex].text
        : '';
    final double minutes = _parseDurationMinutes(durationText);
    if (minutes <= 0) return null;

    double? distanceKm;
    if (menuIndex < section.aerobicDistanceCtrls.length) {
      final rawDistance = section.aerobicDistanceCtrls[menuIndex].text.trim();
      if (rawDistance.isNotEmpty) {
        distanceKm = double.tryParse(rawDistance);
      }
    }

    final double? met = _estimateMet(
      name,
      distanceKm: distanceKm,
      durationMinutes: minutes,
    );
    if (met == null) return null;
    final weightKg = _currentWeightKg();
    if (weightKg == null) {
      return null;
    }
    final double calories = met * weightKg * (minutes / 60.0);
    if (!calories.isFinite || calories <= 0) return null;
    return calories;
  }

  bool _updateCalorieSuggestion(int sectionIndex, int menuIndex,
      {bool force = false, bool shouldShowHint = false}) {
    final enabled = SettingsManager.enableAerobicCalories;
    if (!enabled && !force) return false;
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return false;
    final section = _sections[sectionIndex];
    final l10n = AppLocalizations.of(context)!;
    if (section.selectedPart != l10n.aerobicExercise) return false;
    if (menuIndex < 0) return false;

    while (section.aerobicCaloriesCtrls.length <= menuIndex) {
      section.aerobicCaloriesCtrls.add(TextEditingController());
      section.aerobicCalorieSuggestFlags.add(true);
      section.aerobicCalorieHintVisible.add(false);
      section.aerobicCalorieHintShown.add(false);
    }

    final controller = section.aerobicCaloriesCtrls[menuIndex];
    final wasText = controller.text;
    final bool wasSuggestion = section.aerobicCalorieSuggestFlags[menuIndex];

    final name = (menuIndex < section.menuControllers.length)
        ? section.menuControllers[menuIndex].text.trim()
        : '';
    final distanceText = (menuIndex < section.aerobicDistanceCtrls.length)
        ? section.aerobicDistanceCtrls[menuIndex].text.trim()
        : '';
    final durationText = (menuIndex < section.aerobicDurationCtrls.length)
        ? section.aerobicDurationCtrls[menuIndex].text.trim()
        : '';
    final bool hasName = name.isNotEmpty;
    final double? parsedDistance =
        double.tryParse(distanceText.replaceAll(',', ''));
    final bool hasDistance = parsedDistance != null && parsedDistance > 0;
    final bool hasDuration =
        _parseDurationMinutes(durationText.replaceAll(',', '')) > 0;

    if (!force && !wasSuggestion) return false;
    if (force && !wasSuggestion && controller.text.trim().isNotEmpty) {
      return false;
    }

    if (!hasName || (!hasDistance && !hasDuration)) {
      if (menuIndex < section.aerobicCalorieHintVisible.length) {
        section.aerobicCalorieHintVisible[menuIndex] = false;
      }
      return false;
    }

    final double? calories = _calculateCaloriesFor(sectionIndex, menuIndex);
    if (calories == null) {
      if (shouldShowHint) {
        _showAerobicFailureHint(sectionIndex, menuIndex,
            reason: _AerobicFailureReason.noMatch);
      }
      return false;
    }
    final String newText = calories.round().toString();
    if (controller.text != newText) {
      controller.text = newText;
    }
    if (menuIndex < section.aerobicCalorieHintVisible.length) {
      section.aerobicCalorieHintVisible[menuIndex] = false;
    }
    section.aerobicCalorieSuggestFlags[menuIndex] = true;
    return controller.text != wasText;
  }

  void _showAerobicFailureHint(
    int sectionIndex,
    int menuIndex, {
    _AerobicFailureReason reason = _AerobicFailureReason.noMatch,
  }) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    final section = _sections[sectionIndex];
    while (section.aerobicCalorieHintVisible.length <= menuIndex) {
      section.aerobicCalorieHintVisible.add(false);
      section.aerobicCalorieHintShown.add(false);
    }
    if (section.aerobicCalorieHintShown[menuIndex]) return;
    section.aerobicCalorieHintShown[menuIndex] = true;
    section.aerobicCalorieHintVisible[menuIndex] = true;
    if (mounted) {
      setState(() {});
    }
  }

  void _dismissAerobicFailureHint(int sectionIndex, int menuIndex) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    final section = _sections[sectionIndex];
    if (menuIndex < 0 ||
        menuIndex >= section.aerobicCalorieHintVisible.length) {
      return;
    }
    if (!section.aerobicCalorieHintVisible[menuIndex]) return;
    if (mounted) {
      setState(() {
        section.aerobicCalorieHintVisible[menuIndex] = false;
      });
    }
  }

  void _recalculateAllAerobicCalories({bool force = false}) {
    final enabled = SettingsManager.enableAerobicCalories;
    if (!enabled && !force) return;
    bool updated = false;
    final l10n = AppLocalizations.of(context)!;
    for (int sec = 0; sec < _sections.length; sec++) {
      final section = _sections[sec];
      if (section.selectedPart != l10n.aerobicExercise) continue;
      for (int menu = 0; menu < section.menuControllers.length; menu++) {
        updated |= _updateCalorieSuggestion(sec, menu, force: force);
      }
    }
    if (updated && mounted) {
      setState(() {});
    }
  }

  void _handleWeightChanged() {
    if (!_calcAerobicCalories) return;
    _recalculateAllAerobicCalories(force: false);
  }

  void _onPersonalWeightSettingChanged() {
    if (!_calcAerobicCalories) return;
    if (_weightController.text.trim().isNotEmpty) return;
    _recalculateAllAerobicCalories(force: true);
  }

  void _onAerobicCalorieSettingChanged() {
    final enabled = SettingsManager.enableAerobicCalories;
    if (_calcAerobicCalories != enabled && mounted) {
      setState(() => _calcAerobicCalories = enabled);
    } else {
      _calcAerobicCalories = enabled;
    }
    bool cleared = false;
    if (!enabled) {
      for (final section in _sections) {
        for (int i = 0; i < section.aerobicCalorieHintVisible.length; i++) {
          if (section.aerobicCalorieHintVisible[i]) {
            section.aerobicCalorieHintVisible[i] = false;
            cleared = true;
          }
        }
      }
      if (cleared && mounted) {
        setState(() {});
      }
    } else {
      _recalculateAllAerobicCalories(force: true);
    }
  }

  void _onBmrToggleChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool _shouldShowCalorieField(SectionData section, int menuIndex) {
    final l10n = AppLocalizations.of(context)!;
    if (section.selectedPart != l10n.aerobicExercise) return false;
    final hasValue = menuIndex < section.aerobicCaloriesCtrls.length
        ? section.aerobicCaloriesCtrls[menuIndex].text.trim().isNotEmpty
        : false;
    return SettingsManager.enableAerobicCalories || hasValue;
  }

  void _onAerobicFieldChanged(int sectionIndex, int menuIndex) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    final section = _sections[sectionIndex];
    if (menuIndex < 0) return;
    while (section.aerobicCalorieSuggestFlags.length <= menuIndex) {
      section.aerobicCalorieSuggestFlags.add(true);
      section.aerobicCalorieHintVisible.add(false);
      section.aerobicCalorieHintShown.add(false);
    }
    section.aerobicCalorieSuggestFlags[menuIndex] = true;
    if (menuIndex < section.aerobicCalorieHintVisible.length) {
      section.aerobicCalorieHintVisible[menuIndex] = false;
    }
    if (_updateCalorieSuggestion(sectionIndex, menuIndex)) {
      if (mounted) setState(() {});
    }
  }

  void _onCaloriesChanged(int sectionIndex, int menuIndex, String value) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    final section = _sections[sectionIndex];
    if (menuIndex < 0 ||
        menuIndex >= section.aerobicCalorieSuggestFlags.length) {
      return;
    }
    final trimmed = value.trim();
    final bool wasSuggestion = section.aerobicCalorieSuggestFlags[menuIndex];
    bool updated = false;
    if (wasSuggestion) {
      section.aerobicCalorieSuggestFlags[menuIndex] = false;
      updated = true;
    }
    if (menuIndex < section.aerobicCalorieHintVisible.length &&
        section.aerobicCalorieHintVisible[menuIndex]) {
      section.aerobicCalorieHintVisible[menuIndex] = false;
      updated = true;
    }
    if (trimmed.isEmpty) {
      if (updated && mounted) {
        setState(() {});
      }
      return;
    }
    if (updated && mounted) {
      setState(() {});
    }
  }

  void _addMenuItem(int sectionIndex) {
    final l10n = AppLocalizations.of(context)!;
    final section = _sections[sectionIndex];
    if (section.selectedPart == null) return;

    if (section.menuControllers.length >= 15) {
      showAppSnack(context, l10n.exerciseLimitReached);
      return;
    }

    setState(() {
      final nameCtrl = TextEditingController();
      section.menuControllers.add(nameCtrl);
      section.menuKeys.add(GlobalKey());
      section.nameFieldKeys.add(GlobalKey());
      section.menuCollapsedStates.add(true);
// 追加
      section.satisfactionList.add(null);
      section.previousVolumeList.add(null);

      final isAerobic = section.selectedPart == l10n.aerobicExercise;
      if (isAerobic) {
        section.aerobicDistanceCtrls.add(TextEditingController());
        section.aerobicDurationCtrls.add(TextEditingController());
        section.aerobicSuggestFlags.add(true);
        section.aerobicCaloriesCtrls.add(TextEditingController());
        section.aerobicCalorieSuggestFlags.add(true);
        section.aerobicCalorieHintVisible.add(false);
        section.aerobicCalorieHintShown.add(false);
        section.setInputDataList.add(<SetInputData>[]);
      } else {
        final sets = _currentSetCount;
        final row = List<SetInputData>.generate(
          min(10, sets),
          (_) => SetInputData(
            weightController: TextEditingController(),
            repController: TextEditingController(),
            isSuggestion: true,
          ),
        );
        while (
            section.setInputDataList.length < section.menuControllers.length) {
          section.setInputDataList.add(<SetInputData>[]);
        }
        final idx = section.menuControllers.length - 1;
        section.setInputDataList[idx] = row;
      }
    });

    if (section.selectedPart == l10n.aerobicExercise &&
        section.aerobicCalorieHintVisible.length >=
            section.menuControllers.length) {
      section.aerobicCalorieHintVisible[
          section.aerobicCalorieHintVisible.length - 1] = false;
    }
    _touchCard(
        sectionIndex, _sections[sectionIndex].menuControllers.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollIntoView(
            sectionIndex, _sections[sectionIndex].menuControllers.length - 1);
      }
    });

    if (section.selectedPart == l10n.aerobicExercise) {
      final newIndex = section.menuControllers.length - 1;
      _updateCalorieSuggestion(sectionIndex, newIndex, force: true);
    }
  }

  void _addOneSetAt(int sectionIndex, int menuIndex) {
    final section = _sections[sectionIndex];
    if (menuIndex < 0 || menuIndex >= section.setInputDataList.length) return;
    final list = section.setInputDataList[menuIndex];
    if (list.length >= 10) return;
    setState(() {
      list.add(SetInputData(
        weightController: TextEditingController(),
        repController: TextEditingController(),
        isSuggestion: true,
      ));
    });
  }

  void _addTargetSection() {
    final l10n = AppLocalizations.of(context)!;

    if (_sections.length >= 10) {
      showAppSnack(context, l10n.partLimitReached);
      return;
    }

    setState(() {
      final newSection = SectionData.createEmpty(_currentSetCount,
          shouldPopulateDefaults: true);
      _sections.add(newSection);
      _currentSectionIndex = _sections.length - 1;
      _currentMenuIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _scrollToBottom();
    });
  }

  Future<void> _handleRemoveSection(int sectionIndex) async {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePartConfirmationTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }

    if (_menuOverlayVisible && _menuSecIndex == sectionIndex) {
      setState(() {
        _menuSlideIn = false;
      });
      await Future.delayed(_overlaySlideDuration);
      if (!mounted) return;
      setState(() {
        _menuOverlayVisible = false;
        _menuSecIndex = null;
        _menuMenuIndex = null;
      });
    }

    await _dismissKeyboardSafely(context);
    if (!mounted) return;

    final SectionData removedSection = _sections.removeAt(sectionIndex);
    removedSection.dispose();

    setState(() {
      _currentSectionIndex = null;
      _currentMenuIndex = null;

      if (_skipTapSectionIndex != null) {
        if (_skipTapSectionIndex == sectionIndex) {
          _skipTapSectionIndex = null;
          _skipTapMenuIndex = null;
        } else if (_skipTapSectionIndex! > sectionIndex) {
          _skipTapSectionIndex = _skipTapSectionIndex! - 1;
        }
      }

      if (_menuSecIndex != null) {
        if (_menuSecIndex == sectionIndex) {
          _menuSecIndex = null;
          _menuMenuIndex = null;
        } else if (_menuSecIndex! > sectionIndex) {
          _menuSecIndex = _menuSecIndex! - 1;
        }
      }

      if (_sections.isEmpty) {
        _currentSectionIndex = null;
        _currentMenuIndex = null;
      }
    });
  }

  void _reorderMenuItem(int sectionIndex, int oldIndex, int rawNewIndex) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    final section = _sections[sectionIndex];
    if (oldIndex < 0 || oldIndex >= section.menuControllers.length) return;
    if (rawNewIndex < 0 || rawNewIndex > section.menuControllers.length) return;
    if (section.menuControllers.isEmpty) return;

    var newIndex = rawNewIndex;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex == oldIndex) return;

    int _clampIndex(int index, int lengthInclusive) {
      if (lengthInclusive < 0) return 0;
      if (index < 0) return 0;
      if (index > lengthInclusive) return lengthInclusive;
      return index;
    }

    final maxIndex = section.menuControllers.length - 1;
    newIndex = _clampIndex(newIndex, maxIndex);

    void reorderList<T>(List<T> list) {
      if (oldIndex >= list.length) return;
      final item = list.removeAt(oldIndex);
      final target = _clampIndex(newIndex, list.length);
      list.insert(target, item);
    }

    reorderList(section.menuControllers);
    reorderList(section.setInputDataList);
    reorderList(section.menuKeys);
    reorderList(section.nameFieldKeys);
    reorderList(section.menuCollapsedStates);
    reorderList(section.satisfactionList);
    reorderList(section.previousVolumeList);
    reorderList(section.aerobicDistanceCtrls);
    reorderList(section.aerobicDurationCtrls);
    reorderList(section.aerobicSuggestFlags);
    reorderList(section.aerobicCaloriesCtrls);
    reorderList(section.aerobicCalorieSuggestFlags);
    reorderList(section.aerobicCalorieHintVisible);
    reorderList(section.aerobicCalorieHintShown);

    int _mapIndex(int current) {
      if (current == oldIndex) return newIndex;
      if (oldIndex < newIndex) {
        if (current > oldIndex && current <= newIndex) return current - 1;
      } else {
        if (current >= newIndex && current < oldIndex) return current + 1;
      }
      return current;
    }

    if (_currentSectionIndex == sectionIndex && _currentMenuIndex != null) {
      _currentMenuIndex = _mapIndex(_currentMenuIndex!);
    }

    if (_menuSecIndex == sectionIndex && _menuMenuIndex != null) {
      _menuMenuIndex = _mapIndex(_menuMenuIndex!);
    }

    setState(() {});
  }

  void _removeMenuItem(int sectionIndex, int menuIndex) async {
    // ここでは確認ダイアログを出さない（×ボタン側で既に確認済み）

    // このメニューをオーバーレイで編集中なら先に閉じる（RangeError対策）
    if (_menuOverlayVisible &&
        _menuSecIndex == sectionIndex &&
        _menuMenuIndex == menuIndex) {
      setState(() {
        _menuOverlayVisible = false;
        _menuSlideIn = false;
        _menuSecIndex = null;
        _menuMenuIndex = null;
      });
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    }

    // 実際の削除処理
    setState(() {
      final section = _sections[sectionIndex];

      // controllers / sets
      section.menuControllers[menuIndex].dispose();
      if (menuIndex < section.setInputDataList.length) {
        for (final s in section.setInputDataList[menuIndex]) {
          s.dispose();
        }
        section.setInputDataList.removeAt(menuIndex);
      }
      section.menuControllers.removeAt(menuIndex);

      // 補助配列
      if (section.menuKeys.length > menuIndex)
        section.menuKeys.removeAt(menuIndex);
      if (section.aerobicDistanceCtrls.length > menuIndex) {
        section.aerobicDistanceCtrls[menuIndex].dispose();
        section.aerobicDistanceCtrls.removeAt(menuIndex);
      }
      if (section.aerobicDurationCtrls.length > menuIndex) {
        section.aerobicDurationCtrls[menuIndex].dispose();
        section.aerobicDurationCtrls.removeAt(menuIndex);
      }
      if (section.aerobicSuggestFlags.length > menuIndex) {
        section.aerobicSuggestFlags.removeAt(menuIndex);
      }
      if (section.aerobicCaloriesCtrls.length > menuIndex) {
        section.aerobicCaloriesCtrls[menuIndex].dispose();
        section.aerobicCaloriesCtrls.removeAt(menuIndex);
      }
      if (section.aerobicCalorieSuggestFlags.length > menuIndex) {
        section.aerobicCalorieSuggestFlags.removeAt(menuIndex);
      }
      if (section.aerobicCalorieHintVisible.length > menuIndex) {
        section.aerobicCalorieHintVisible.removeAt(menuIndex);
      }
      if (section.aerobicCalorieHintShown.length > menuIndex) {
        section.aerobicCalorieHintShown.removeAt(menuIndex);
      }
      if (section.nameFieldKeys.length > menuIndex) {
        section.nameFieldKeys.removeAt(menuIndex);
      }
      if (section.menuCollapsedStates.length > menuIndex) {
        section.menuCollapsedStates.removeAt(menuIndex);
      }
// 追加
      if (section.satisfactionList.length > menuIndex) {
        section.satisfactionList.removeAt(menuIndex);
      }
      if (section.previousVolumeList.length > menuIndex) {
        section.previousVolumeList.removeAt(menuIndex);
      }

      // カレント選択の整合性
      if (section.menuControllers.isEmpty) {
        _currentMenuIndex = null;
      } else {
        _currentMenuIndex =
            menuIndex.clamp(0, section.menuControllers.length - 1);
      }
    });
  }

  void _toggleMenuCollapse(int sectionIndex, int menuIndex,
      {bool suppressOverlay = false}) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    final section = _sections[sectionIndex];
    if (menuIndex < 0) return;

    // ★不足分を true（折りたたみ中）で埋める＝安全初期化
    if (section.menuCollapsedStates.length <= menuIndex) {
      section.menuCollapsedStates.addAll(
        List<bool>.filled(
            menuIndex + 1 - section.menuCollapsedStates.length, true),
      );
    }

    // 今の状態を保持：true=折りたたみ中（これから開く）
    final bool wasCollapsed = section.menuCollapsedStates[menuIndex];

    setState(() {
      section.menuCollapsedStates[menuIndex] =
          !section.menuCollapsedStates[menuIndex];
      if (suppressOverlay) _suppressNextMenuOverlay = true;
    });

    // 「開いた」ときだけ自動スクロールして見える位置に合わせる
    if (wasCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = section.menuKeys[menuIndex].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 1.0,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _prepareMenuQuickAction(int sectionIndex, int menuIndex) {
    setState(() {
      _currentSectionIndex = sectionIndex;
      _currentMenuIndex = menuIndex;
      _lastInteractionAt = DateTime.now();
      _closeFabDial();
      _personalSelected = false;
      _currentMealIndex = null;
      _skipTapSectionIndex = sectionIndex;
      _skipTapMenuIndex = menuIndex;
      _suppressNextMenuOverlay = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _skipTapSectionIndex = null;
      _skipTapMenuIndex = null;
      _suppressNextMenuOverlay = false;
    });
  }

  void _touchCard(int sectionIndex, int menuIndex, {bool resetSkip = true}) {
    setState(() {
      _currentSectionIndex = sectionIndex;
      _currentMenuIndex = menuIndex;
      _lastInteractionAt = DateTime.now();
      _closeFabDial();
      _personalSelected = false;
      _currentMealIndex = null;
      if (resetSkip) {
        _skipTapSectionIndex = null;
        _skipTapMenuIndex = null;
        _suppressNextMenuOverlay = false;
      }
    });
  }

  void _focusMealCard(int index) {
    if (index < 0 || index >= _mealCards.length) {
      return;
    }
    setState(() {
      _currentMealIndex = index;
      _currentSectionIndex = null;
      _currentMenuIndex = null;
      _personalSelected = false;
      _lastInteractionAt = DateTime.now();
      _closeFabDial();
    });
  }

  void _handleAddSet(AppLocalizations l10n) {
    if (_sections.isEmpty) return;
    final secIdx = _currentSectionIndex ?? 0;
    final menuIdx = _currentMenuIndex ?? 0;
    final section = _sections[secIdx];

    if (section.selectedPart == l10n.aerobicExercise) return;
    _addOneSetAt(secIdx, menuIdx);
  }

  int? _resolveActiveSectionIndex() {
    final si = _currentSectionIndex;
    if (si != null && si >= 0 && si < _sections.length) {
      return si;
    }
    for (int i = 0; i < _sections.length; i++) {
      if (_sections[i].selectedPart != null) {
        return i;
      }
    }
    return null;
  }

  void _closeFabDial() {
    if (!_fabOpen) return;
    _fabOpen = false;
    _fabCtrl.reverse();
  }

  // 追加：＋パーソナル → カード出現（先頭に表示）
  void _handleAddPersonal() async {
    setState(() {
      _showPersonalCard = true;
      _closeFabDial();
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      _scrollIntoView(0, 0);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _handleRemovePersonalCard() async {
    final l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePersonalConfirmationTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }

    await _dismissKeyboardSafely(context);
    if (_personalOverlayVisible) {
      if (!mounted) return;
      setState(() => _personalSlideIn = false);
      await Future.delayed(_overlaySlideDuration);
      if (!mounted) return;
      setState(() => _personalOverlayVisible = false);
    }

    if (!mounted) return;
    setState(() {
      _showPersonalCard = false;
      _personalSelected = false;
      _personalCollapsed = true;
    });
  }

  void _handleAddExercise() {
    final l10n = AppLocalizations.of(context)!;
    final secIdx = _resolveActiveSectionIndex();
    if (secIdx == null) {
      showAppSnack(context, l10n.selectTrainingPart);
      return;
    }
    final section = _sections[secIdx];
    if (section.selectedPart == null) {
      showAppSnack(context, l10n.selectTrainingPart);
      return;
    }

    _addMenuItem(secIdx);
    setState(() {
      _currentSectionIndex = secIdx;
      _currentMenuIndex = _sections[secIdx].menuControllers.length - 1;
      _closeFabDial();
    });
  }

  void _handleAddPart() {
    _addTargetSection();
    setState(_closeFabDial);
  }

  void _handleAddPhoto() {
    setState(_closeFabDial);
    _startCaptureLoop();
  }

  // 追加：メモ追加（FABのダイヤル／メモカードから呼ぶ）
  Future<void> _handleAddMemo() async {
    setState(_closeFabDial);
    setState(() {
      _showMemo = true; // プレビューを出しておく（当日分メモが空でも）
    });
    // フローティング編集を開く（上からスッ）
    await _openMemoOverlaySmooth();
  }

  Future<void> _handleAddMeal() async {
    _closeFabDial();
    final existingCategories = _mealCards.map((c) => c.category).toSet();
    final missingCategories = MealCategory.values
        .where((category) => !existingCategories.contains(category))
        .toList();

    if (missingCategories.isEmpty) {
      return;
    }

    int? firstAddedIndex;
    setState(() {
      for (final category in missingCategories) {
        final idx = _addMealCard(category);
        firstAddedIndex ??= idx;
      }
      if (firstAddedIndex != null) {
        _currentMealIndex = firstAddedIndex;
        _currentSectionIndex = null;
        _currentMenuIndex = null;
        _personalSelected = false;
        _lastInteractionAt = DateTime.now();
      }
    });
  }

  // === ここからメモ・フローティングエディタ ===

  Future<void> _openMemoOverlaySmooth() async {
    if (_memoOverlayVisible || _memoOverlayOpening) return;

    _memoOverlayOpening = true;

    _memoOverlayFocus.requestFocus();

    if (!mounted) return;
    setState(() {
      _memoOverlayVisible = true;
      _memoOverlayOpening = false;
      _fabOpen = false; // ダイヤルは閉じる
      _memoSlideIn = false; // 初期は少し上の位置
    });

    // 次フレームで「上からスッ」と入れる
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _memoSlideIn = true);
    });
  }

  // 保存して閉じるを一本化
  Future<void> _saveMemoAndClose() async {
    setState(() {
      _showMemo = _memoController.text.trim().isNotEmpty;
    });
    final didSave = _saveAllSectionsData();
    if (didSave) _showSavedChipFor(const Duration(milliseconds: 900));

    FocusScope.of(context).unfocus();
    await _dismissKeyboardSafely(context);
    if (!mounted) return;
    setState(() => _memoSlideIn = false); // ← まずアニメ逆再生
    await Future.delayed(_overlaySlideDuration);
    if (!mounted) return;
    setState(() => _memoOverlayVisible = false); // ← その後非表示
  }

  void _openMemoOverlayInline() {
    setState(() => _memoOverlayOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _memoOverlayFocus.requestFocus();
      await SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _closeMemoOverlayAndSave() {
    setState(() {
      _memoOverlayOpen = false;
      _showMemo = _memoController.text.trim().isNotEmpty;
    });
    final didSave = _saveAllSectionsData();
    if (didSave) _showSavedChipFor(const Duration(milliseconds: 900));
  }

  // === ここから 種目・フローティングエディタ ===

  Future<void> _openMenuOverlaySmooth(int secIndex, int menuIndex) async {
    if (_menuOverlayVisible || _menuOverlayOpening) return;
    _menuOverlayOpening = true;

    _menuSecIndex = secIndex;
    _menuMenuIndex = menuIndex;

    _menuOverlayFocus.requestFocus();

    if (!mounted) return;
    setState(() {
      _menuOverlayVisible = true;
      _menuOverlayOpening = false;
      _fabOpen = false;
      _menuSlideIn = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // One-time overlay hint sequence
        final box = widget.settingsBox;
        final seenOverlay =
            box.get('hint_seen_record_overlay') as bool? ?? false;
        if (!mounted || seenOverlay) return;
        // wait a short while for elements to layout
        await Future<void>.delayed(const Duration(milliseconds: 150));
        final l10n = AppLocalizations.of(context)!;
        final secIndex2 = _menuSecIndex;
        final menuIndex2 = _menuMenuIndex;
        if (secIndex2 == null || menuIndex2 == null) return;
        if (secIndex2 < 0 || secIndex2 >= _sections.length) return;
        final section2 = _sections[secIndex2];
        if (menuIndex2 < 0 || menuIndex2 >= section2.nameFieldKeys.length)
          return;

        final anchors = <GlobalKey>[
          section2.nameFieldKeys[menuIndex2],
          // 近い位置に吹き出しを出すため、チェックボックスの代替としてカード全体のキーを使う
          if (menuIndex2 < section2.menuKeys.length)
            section2.menuKeys[menuIndex2],
          _kMenuSaveButton,
        ];
        final messages = <String>[
          l10n.hintRecordPickExercise,
          l10n.hintRecordCheckbox,
          l10n.hintRecordSave,
        ];

        // (hint removed)
        await box.put('hint_seen_record_overlay', true);
      });
      if (!mounted) return;
      setState(() => _menuSlideIn = true);
    });
  }

  Future<void> _saveMenuAndClose() async {
    final didSave = _saveAllSectionsData();
    if (didSave) _showSavedChipFor(const Duration(milliseconds: 900));
    await _dismissKeyboardSafely(context);
    if (!mounted) return;
    setState(() => _menuSlideIn = false);
    await Future.delayed(_overlaySlideDuration);
    if (!mounted) return;
    setState(() {
      _menuOverlayVisible = false;
      _menuSecIndex = null;
      _menuMenuIndex = null;
    });

    Future<void> _maybeShowFabHintAfterSave() async {
      final box = widget.settingsBox;
      final seen = box.get('hint_seen_record_fab_after_save') as bool? ?? false;
      if (seen) return;
      // wait for FAB to be in the tree
      final deadline = DateTime.now().add(const Duration(milliseconds: 800));
      while (DateTime.now().isBefore(deadline)) {
        if (!mounted) return;
        if (_kFabKey.currentContext != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted || _kFabKey.currentContext == null) return;
      final l10n = AppLocalizations.of(context)!;
      // (hint removed)
      await box.put('hint_seen_record_fab_after_save', true);
    }

    // After overlay closes, show FAB hint once
    await _maybeShowFabHintAfterSave();
  }

  Future<Directory> _mediaDirFor(DateTime date) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'media', _getDateKey(date)));
  }

  Future<void> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> _loadMediaForSelectedDate() async {
    try {
      final dir = await _mediaDirFor(widget.selectedDate);
      if (!await dir.exists()) {
        if (mounted) setState(() => _mediaPaths = []);
        return;
      }
      final files = dir.listSync().whereType<File>().where((f) {
        final pth = f.path.toLowerCase();
        return pth.endsWith('.jpg') ||
            pth.endsWith('.jpeg') ||
            pth.endsWith('.png') ||
            pth.endsWith('.heic');
      }).toList();

      files
          .sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      if (mounted) {
        setState(() => _mediaPaths = files.map((f) => f.path).toList());
      }
    } catch (_) {
      if (mounted) setState(() => _mediaPaths = []);
    }
  }

  // 設定(Box)から身長(cm)を読む
  void _loadHeightFromSettings() {
    final hc = widget.settingsBox.get('personal.heightCm');
    if (hc is num) {
      _heightCm = hc.toDouble();
    } else if (hc is String) {
      _heightCm = double.tryParse(hc);
    }
  }

// 体重/身長から BMI を再計算して _bmiValue を更新
  void _updateBmiDisplay() {
    final w = double.tryParse(_weightController.text);
    if (w == null || _heightCm == null || _heightCm == 0) {
      setState(() {
        _bmiValue = null;
        _bmiController.text = '';
      });
      return;
    }
    // lbs の場合は kg に変換
    final weightKg =
        (SettingsManager.currentUnit == 'lbs') ? (w * 0.45359237) : w;
    final hMeters = (_heightCm! / 100.0);
    final bmi = weightKg / (hMeters * hMeters);
    setState(() {
      _bmiValue = bmi;
      _bmiController.text = bmi.toStringAsFixed(1);
    });
  }

  bool _recoveringLost = false;

  Future<void> _recoverLostImageIfAny() async {
    if (!Platform.isAndroid) return;
    if (_recoveringLost) return;
    _recoveringLost = true;
    try {
      final LostDataResponse resp = await _imagePicker.retrieveLostData();
      if (resp.isEmpty) {
        return;
      }
      if (resp.file != null) {
        await _saveAndAppendXFile(resp.file!);
      } else if (resp.files != null && resp.files!.isNotEmpty) {
        for (final f in resp.files!) {
          await _saveAndAppendXFile(f);
        }
      }
    } catch (_) {
    } finally {
      _recoveringLost = false;
    }
  }

  Future<bool> _awaitMaybeLostData({int tries = 6}) async {
    for (int i = 0; i < tries; i++) {
      try {
        final resp = await _imagePicker.retrieveLostData();
        if (!resp.isEmpty) {
          if (resp.file != null) {
            await _saveAndAppendXFile(resp.file!);
            return true;
          }
          if (resp.files != null && resp.files!.isNotEmpty) {
            for (final f in resp.files!) {
              await _saveAndAppendXFile(f);
            }
            return true;
          }
          if (resp.exception != null) {
            return false;
          }
        }
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: i < 3 ? 200 : 500));
    }
    return false;
  }

  Future<void> _saveAndAppendXFile(XFile shot) async {
    final dir = await _mediaDirFor(widget.selectedDate);
    await _ensureDir(dir);

    final ext = p.extension(shot.path).toLowerCase();
    final ts = DateTime.now();
    final fileName =
        '${DateFormat('HHmmss_SSS').format(ts)}${ext.isNotEmpty ? ext : '.jpg'}';
    final savePath = p.join(dir.path, fileName);

    await shot.saveTo(savePath);

    await _loadMediaForSelectedDate();
    await _scrollIntoViewKey(_kPhotoCardsKey, alignment: 0.98);
  }

  Future<void> _startCaptureLoop() async {
    if (!await _ensureCameraPermission(context)) return;

    while (mounted) {
      if (_mediaPaths.length >= _kDailyPhotoCap) {
        final l10n = AppLocalizations.of(context)!;
        showAppSnack(context, l10n.mediaReachedDailyCap);
        break;
      }

      XFile? shot;
      try {
        shot = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
        );
      } catch (_) {}

      if (shot == null) {
        final recovered = await _awaitMaybeLostData();
        if (!recovered) {}
        break;
      }

      final res = await Navigator.of(context).push<_QuickReview>(
        PageRouteBuilder(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (_, __, ___) => _PhotoPreviewPage(imagePath: shot!.path),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity:
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              child: child),
        ),
      );

      if (!mounted) break;

      if (res == _QuickReview.save) {
        await _saveAndAppendXFile(shot);
        continue;
      } else if (res == _QuickReview.discard) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
        continue;
      } else {
        break;
      }
    }
  }

  void _openImageViewer(String path) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(String path) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mediaDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.mediaCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await File(path).delete();
              } catch (_) {}
              if (!mounted) return;
              setState(() {
                _mediaPaths.remove(path);
              });
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // ===== メモ：プレビュー（タップでフローティング編集へ） =====
  Widget _buildMealCard(int index) {
    if (index < 0 || index >= _mealCards.length) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final card = _mealCards[index];
    final categoryLabel = _mealCategoryLabel(card.category, l10n);
    final summaryItems = card.items.where((item) {
      final hasName = item.name.trim().isNotEmpty;
      final hasKcal = (item.kcal ?? 0) > 0;
      return hasName || hasKcal;
    }).toList();
    final bool isCollapsed =
        (index < _mealCollapsed.length) ? _mealCollapsed[index] : true;
    final bool isExpanded = !isCollapsed;
    final bool isActive = _currentMealIndex == index;
    final bool isLight = theme.brightness == Brightness.light;
    const Color kBrandBlue = Color(0xFF2563EB);
    final bool highlight = isExpanded || isActive;
    final borderColor = highlight
        ? (isLight ? kBrandBlue : cs.primary)
        : Colors.transparent;
    final shadowColor = highlight
        ? (isLight
            ? kBrandBlue.withOpacity(0.45)
            : cs.primary.withOpacity(0.45))
        : Colors.black.withOpacity(0.20);
    final handleColor = highlight ? cs.primary : cs.onSurfaceVariant;

    Widget buildPreviewBody() {
      final hasRecords = summaryItems.isNotEmpty;
      if (!hasRecords) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.mealEmptyNotice,
                style: TextStyle(
                  fontFamily: kUiFont,
                  color: cs.onSurfaceVariant,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }

      final children = <Widget>[];
      for (var i = 0; i < summaryItems.length; i++) {
          final item = summaryItems[i];
          final name = item.name.trim().isEmpty ? '—' : item.name.trim();
          final kcalText = (item.kcal == null || item.kcal! <= 0)
              ? '—'
              : '${_formatKcalDisplay(item.kcal!)} ${l10n.kcalUnit}';
          children.add(
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${i + 1}.',
                    style: TextStyle(
                      fontFamily: kUiFont,
                      color: cs.onSurfaceVariant,
                      fontSize: 13.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontFamily: kUiFont,
                        color: cs.onSurface,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    kcalText,
                    style: TextStyle(
                      fontFamily: kUiFont,
                      color: cs.onSurface,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      children.addAll([
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Text(
            '${l10n.mealSubtotal}: ${_formatKcalDisplay(card.subtotalKcal)} ${l10n.kcalUnit}',
            style: TextStyle(
              fontFamily: kUiFont,
              color: cs.onSurface,
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Text(
            '${l10n.mealTotalToday}: ${_formatKcalDisplay(_totalMealKcal)} ${l10n.kcalUnit}',
            style: TextStyle(
              fontFamily: kUiFont,
              color: cs.onSurfaceVariant,
              fontSize: 13.0,
            ),
          ),
        ),
      ]);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Card(
        margin: EdgeInsets.zero,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: borderColor,
            width: isExpanded ? 1.5 : 0,
          ),
        ),
        elevation: isExpanded ? 3.0 : 0.0,
        shadowColor: shadowColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 40,
                padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
                alignment: AlignmentDirectional.topCenter,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 22,
                  color: handleColor,
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12.0),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                onTap: () {
                  _focusMealCard(index);
                  _showMealOverlay(index);
                },
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () async {
                                _focusMealCard(index);
                                final selected = await _showMealCategoryPicker(
                                  current: card.category,
                                );
                                if (selected == null || !mounted) return;
                                if (selected == card.category) return;
                                setState(() {
                                  card.category = selected;
                                });
                              },
                              child: Text(
                                categoryLabel,
                                style: TextStyle(
                                  fontFamily: kUiFont,
                                  color: cs.onSurface,
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _focusMealCard(index);
                              _toggleMealCollapse(index);
                            },
                            tooltip: isCollapsed
                                ? l10n.expandCard
                                : l10n.collapseCard,
                            icon: Icon(
                              isCollapsed
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 180),
                        sizeCurve: Curves.easeOutCubic,
                        crossFadeState: isCollapsed
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: const SizedBox.shrink(),
                        secondChild: buildPreviewBody(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoCard() {
    if (!_showMemo) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final preview = _memoController.text.trim();

    return Padding(
      key: _kMemoCardKey,
      padding: EdgeInsets.zero,
      child: Card(
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleAddMemo, // ← クリックでフローティング編集を開く
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.memo,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined,
                        size: 18, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 8),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    style: TextStyle(color: cs.onSurface, height: 1.35),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    l10n.memoBodyPlaceholder,
                    style:
                        TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCards() {
    if (_mediaPaths.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final paths = List<String>.from(_mediaPaths.reversed);

    return Card(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.progressSnaps,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                const double gap = 6;
                final double cell = ((constraints.maxWidth - gap * 2) / 3)
                    .clamp(0, constraints.maxWidth);

                Widget buildThumb(String path) => InkWell(
                      onTap: () => _openImageViewer(path),
                      onLongPress: () => _confirmDelete(path),
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: cell,
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color:
                                    Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );

                if (paths.length == 1) {
                  return Align(
                    alignment: const Alignment(-0.8, 0),
                    child: buildThumb(paths[0]),
                  );
                } else if (paths.length == 2) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildThumb(paths[0]),
                      const SizedBox(width: gap),
                      buildThumb(paths[1]),
                    ],
                  );
                } else {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paths.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                    ),
                    itemBuilder: (context, i) {
                      final path = paths[i];
                      return InkWell(
                        onTap: () => _openImageViewer(path),
                        onLongPress: () => _confirmDelete(path),
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canAddExercise() {
    if (_sections.isEmpty) return false;
    final si = _resolveActiveSectionIndex();
    if (si == null) return false;
    return _sections[si].selectedPart != null;
  }

  Widget _buildStopwatchCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: _kStopwatchArea,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: StopwatchWidget(
          controller: _swController,
          compact: true,
          triangleOnlyStart: true,
        ),
      ),
    );
  }

  Widget _buildSavedPill(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('saved-pill'),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurfaceVariant.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            l10n.saved,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExit() async {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      return;
    }
    if (_memoOverlayOpen) {
      _closeMemoOverlayAndSave();
      return;
    }
    if (_menuOverlayVisible) {
      await _saveMenuAndClose();
      return;
    }
    if (_memoOverlayVisible) {
      await _saveMemoAndClose();
      return;
    }

    await _dismissKeyboardSafely(context);

    final trimmed = _trimTrailingEmptySetsForAllMenus(_currentSetCount);
    if (trimmed) setState(() {});
    final didSave = _saveAllSectionsData(showHint: false);

    if (didSave) {
      _showSavedChipFor(const Duration(milliseconds: 900));
      await Future<void>.delayed(const Duration(milliseconds: 360));
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // パーソナル編集用オーバーレイ（上から/高さ0.4/背景薄暗 + フェード＆スケール）
  Widget _buildPersonalEditorOverlay() {
    if (!_personalOverlayVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final bool showBodyFat =
        (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    final bool showWaist =
        (widget.settingsBox.get('manage.waist') as bool?) ?? false;
    final bool showBMI =
        (widget.settingsBox.get('manage.bmi') as bool?) ?? false;
    final bool showBmr =
        (widget.settingsBox.get('manage.bmr') as bool?) ?? false;

    final double topGap = media.padding.top + kToolbarHeight + 8;
    final double overlayHeight = media.size.height * 0.4;

    // ラベル右側の入力域で「下線 2/3」を実現する版
    Widget underlineField({
      required TextEditingController controller,
      String? unitSuffix,
      VoidCallback? onChanged,
      Future<void> Function()? onTap,
      bool readOnly = false,
    }) {
      final cs = Theme.of(context).colorScheme;
      return LayoutBuilder(
        builder: (ctx, constraints) {
          final double total = constraints.maxWidth; // ラベル右側の総幅
          final double unitReserve =
              (unitSuffix != null) ? (_unitReserveW + 6) : 0;
          // 単位ぶんを引いた残りの 2/3 を下線に
          final double fieldW =
              ((total - unitReserve) * 4 / 5).clamp(120.0, total - unitReserve);
          final bool shouldBlockInput = readOnly || onTap != null;

          return Row(
            children: [
              SizedBox(
                width: fieldW,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: kUnifiedFieldMinHeight),
                  child: TextField(
                    controller: controller,
                    readOnly: shouldBlockInput,
                    showCursor: shouldBlockInput ? false : null,
                    enableInteractiveSelection: shouldBlockInput ? false : null,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: kUiFont,
                      color: cs.onSurface,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: cs.onSurfaceVariant.withOpacity(0.4),
                            width: 1),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 0),
                    ),
                    onTap: onTap ?? (shouldBlockInput ? () {} : null),
                    onChanged:
                        shouldBlockInput ? null : (_) => onChanged?.call(),
                  ),
                ),
              ),
              if (unitSuffix != null) ...[
                const SizedBox(width: 6), // ← ここも 6px
                SizedBox(
                  width: _unitReserveW,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      unitSuffix,
                      style: TextStyle(
                        fontFamily: kUiFont,
                        color: cs.onSurfaceVariant,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
    }

    return Stack(
      children: [
        // 背景（タップで保存して閉じる）
        Positioned.fill(
          child: GestureDetector(
            onTap: _savePersonalAndClose,
            child: AnimatedOpacity(
              duration: _overlayFadeDuration,
              curve: _overlayInCurve,
              opacity: _personalSlideIn ? 1.0 : 0.0,
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          top: topGap,
          height: overlayHeight,
          child: AnimatedSlide(
            duration: _overlaySlideDuration,
            curve: _overlayInCurve,
            offset: _personalSlideIn ? Offset.zero : const Offset(0, -0.08),
            child: AnimatedScale(
              duration: _overlaySlideDuration,
              curve: _overlayInCurve,
              scale: _personalSlideIn ? 1.0 : 0.98, // ふわっと拡大
              child: AnimatedOpacity(
                duration: _overlayFadeDuration,
                curve: _overlayInCurve,
                opacity: _personalSlideIn ? 1.0 : 0.0,
                child: Material(
                  color: Colors.transparent,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ヘッダー
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 6, 8),
                          child: Row(
                            children: [
                              Text(
                                l10n.personal,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _savePersonalAndClose,
                                icon: const Icon(Icons.check_rounded),
                                label: Text(
                                  l10n.save,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface, // ← ラベル側で濃色を強制
                                  ),
                                ),
                                style: ButtonStyle(
                                  // ボタン側も濃色で統一（アイコン含む）
                                  foregroundColor: MaterialStatePropertyAll(
                                    Theme.of(context).colorScheme.onSurface,
                                  ),
                                  iconColor: MaterialStatePropertyAll(
                                    Theme.of(context).colorScheme.onSurface,
                                  ),
                                  // 押下時の被せ色が薄さに見えないよう完全透明に（任意）
                                  overlayColor: const MaterialStatePropertyAll(
                                      Colors.transparent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 本文
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Focus(
                              focusNode: _personalOverlayFocus,
                              child: Column(
                                children: [
                                  // 体重
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 96,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            l10n.bodyWeight,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: cs.onSurface,
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: underlineField(
                                          controller: _weightController,
                                          unitSuffix:
                                              SettingsManager.currentUnit ==
                                                      'kg'
                                                  ? l10n.kg
                                                  : l10n.lbs,
                                          onTap: _openPersonalWeightPicker,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // 体脂肪
                                  if (showBodyFat) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 96,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              l10n.bodyFat,
                                              style: TextStyle(
                                                fontFamily: kUiFont,
                                                color: cs.onSurface,
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: underlineField(
                                            controller: _bodyFatController,
                                            unitSuffix: l10n.percentSymbol,
                                            onTap: _openBodyFatPicker,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // ウエスト
                                  if (showWaist) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 96,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              l10n.waist,
                                              style: TextStyle(
                                                fontFamily: kUiFont,
                                                color: cs.onSurface,
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: underlineField(
                                            controller: _waistController,
                                            unitSuffix:
                                                SettingsManager.isWaistInch
                                                    ? l10n.unitIn
                                                    : l10n.unitCm,
                                            onTap: _openWaistPicker,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (showBMI) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 96,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              l10n.bmi,
                                              style: TextStyle(
                                                fontFamily: kUiFont,
                                                color: cs.onSurface,
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: underlineField(
                                            controller: _bmiController,
                                            readOnly: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (showBmr) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 96,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              l10n.bmrTitleShort,
                                              style: TextStyle(
                                                fontFamily: kUiFont,
                                                color: cs.onSurface,
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: underlineField(
                                            controller: _bmrController,
                                            unitSuffix: l10n.kcalUnit,
                                            onTap: _openBmrPicker,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 108,
                                        top: 4,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _formattedBmrDifference(l10n),
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
        ),
      ],
    );
  }

  Widget _buildMealEditorOverlay() {
    if (!_mealOverlayVisible || _mealOverlayIndex == null) {
      return const SizedBox.shrink();
    }

    final cardIndex = _mealOverlayIndex!;
    if (cardIndex < 0 || cardIndex >= _mealCards.length) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final card = _mealCards[cardIndex];
    final controllers = _mealControllers[cardIndex];
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = media.padding.bottom;
    final double bottomSpacerHeight = bottomInset + safeBottom + 12;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _saveMealOverlayAndClose,
            child: AnimatedOpacity(
              duration: _overlayFadeDuration,
              curve: _overlayInCurve,
              opacity: _mealSlideIn ? 1.0 : 0.0,
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 0,
          bottom: safeBottom + 12,
          child: AnimatedSlide(
            duration: _overlaySlideDuration,
            curve: _overlayInCurve,
            offset: _mealSlideIn ? Offset.zero : const Offset(0, -0.08),
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: AnimatedOpacity(
                      duration: _overlayFadeDuration,
                      curve: _overlayInCurve,
                      opacity: _mealSlideIn ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: _overlaySlideDuration,
                        curve: _overlayInCurve,
                        scale: _mealSlideIn ? 1.0 : 0.98,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
                              child: Row(
                                children: [
                                  Text(
                                    _mealCategoryLabel(card.category, l10n),
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _addMealItemRow(cardIndex);
                                      });
                                    },
                                    child: Text(
                                      l10n.addMealItem,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: _saveMealOverlayAndClose,
                                    icon: const Icon(Icons.check_rounded),
                                    label: Text(
                                      l10n.save,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 10, 16, 16),
                                child: Scrollbar(
                                  child: Focus(
                                    focusNode: _mealOverlayFocus,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      itemCount: controllers.length + 1,
                                      itemBuilder: (_, index) {
                                        if (index == controllers.length) {
                                          return SizedBox(
                                            height: bottomSpacerHeight,
                                          );
                                        }
                                        final row = controllers[index];
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom:
                                                index == controllers.length - 1
                                                    ? 0
                                                    : 12,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      row.nameController,
                                                  decoration:
                                                      _underlineDec(context)
                                                          .copyWith(
                                                    labelText: l10n.mealItem,
                                                  ),
                                                  onChanged: (value) {
                                                    _onMealNameChanged(
                                                      cardIndex,
                                                      index,
                                                      value,
                                                    );
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // 下線の中に単位を入れない。行レイアウトで右側に固定配置
                                              SizedBox(
                                                width: 110,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    // 入力欄（下線）— 余白を確保して右側に単位を置く
                                                    Expanded(
                                                      child: TextField(
                                                        controller: row.kcalController,
                                                        decoration: _underlineDec(context).copyWith(
                                                          labelText: null,
                                                          // プレースホルダーは不要
                                                          // hintText: '0',
                                                          // ← suffix/suffixText は使わない（常時固定表示のため）
                                                        ),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        textAlign: TextAlign.right,
                                                        style: TextStyle(
                                                          color: cs.onSurface,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        onChanged: (value) {
                                                          _onMealKcalChanged(
                                                            cardIndex,
                                                            index,
                                                            value,
                                                          );
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    // 右側固定の「kcal」— 初期から常時表示
                                                    Text(
                                                      l10n.kcalUnit,
                                                      style: TextStyle(
                                                        color: cs.onSurfaceVariant,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                8,
                                20,
                                16 + safeBottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l10n.mealSubtotal}: ${_formatKcalDisplay(card.subtotalKcal)} ${l10n.kcalUnit}',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l10n.mealTotalToday}: ${_formatKcalDisplay(_totalMealKcal)} ${l10n.kcalUnit}',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: const BigEarningAd(
                                androidNativeUnitId:
                                    'ca-app-pub-3331079517737737/9518673738',
                                iosNativeUnitId:
                                    'ca-app-pub-3331079517737737/3349399943',
                                androidBannerUnitId:
                                    'ca-app-pub-3331079517737737/9588577724',
                                iosBannerUnitId:
                                    'ca-app-pub-3331079517737737/6962414382',
                                factoryId: 'large_media',
                                height: 260,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== 記入オーバーレイ（画面内フローティングシート：上からスッ） =====
  Widget _buildMemoEditorOverlay() {
    if (!_memoOverlayVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = media.padding.bottom;
    final double bottomSpacerHeight = bottomInset + safeBottom + 12;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _saveMemoAndClose,
            child: AnimatedOpacity(
              duration: _overlayFadeDuration,
              curve: _overlayInCurve,
              opacity: _memoSlideIn ? 1.0 : 0.0,
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 0,
          bottom: safeBottom + 12,
          child: AnimatedSlide(
            duration: _overlaySlideDuration,
            curve: _overlayInCurve,
            offset: _memoSlideIn ? Offset.zero : const Offset(0, -0.08),
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: AnimatedOpacity(
                      duration: _overlayFadeDuration,
                      curve: _overlayInCurve,
                      opacity: _memoSlideIn ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: _overlaySlideDuration,
                        curve: _overlayInCurve,
                        scale: _memoSlideIn ? 1.0 : 0.98,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
                              child: Row(
                                children: [
                                  Text(
                                    l10n.memo,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _saveMemoAndClose,
                                    icon: const Icon(Icons.check_rounded),
                                    label: Text(
                                      l10n.save,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                child: Scrollbar(
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    children: [
                                      TextField(
                                        focusNode: _memoOverlayFocus,
                                        controller: _memoController,
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction:
                                            TextInputAction.newline,
                                        maxLength: 400,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(400)
                                        ],
                                        minLines: 6,
                                        maxLines: null,
                                        style: TextStyle(color: cs.onSurface),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: l10n.memoBodyPlaceholder,
                                          hintStyle: TextStyle(
                                            color: cs.onSurfaceVariant
                                                .withOpacity(0.6),
                                          ),
                                          border: InputBorder.none,
                                          counterStyle: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                  2, 8, 2, 12),
                                        ),
                                        onChanged: (_) {
                                          if (_fabOpen) {
                                            setState(() => _fabOpen = false);
                                          }
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 12, 16, 12),
                                        child: const BigEarningAd(
                                          androidNativeUnitId:
                                              'ca-app-pub-3331079517737737/9518673738',
                                          iosNativeUnitId:
                                              'ca-app-pub-3331079517737737/3349399943',
                                          androidBannerUnitId:
                                              'ca-app-pub-3331079517737737/9588577724',
                                          iosBannerUnitId:
                                              'ca-app-pub-3331079517737737/6962414382',
                                          factoryId: 'large_media',
                                          height: 260,
                                        ),
                                      ),
                                      SizedBox(height: bottomSpacerHeight),
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
            ),
          ),
        ),
      ],
    );
  }

  // 種目編集用オーバーレイ（メモと同様：上から／高さ0.4／背景薄暗）
  // 種目編集用オーバーレイ（上から／高さ0.4／背景薄暗）
  Widget _buildMenuEditorOverlay() {
    // オーバーレイ未表示 or 未選択時は描画しない
    if (!_menuOverlayVisible ||
        _menuSecIndex == null ||
        _menuMenuIndex == null) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final secIndex = _menuSecIndex!;
    final menuIndex = _menuMenuIndex!;

    // ===== インデックス安全ガード =====
    if (secIndex < 0 || secIndex >= _sections.length)
      return const SizedBox.shrink();
    final section = _sections[secIndex];
    if (menuIndex < 0 || menuIndex >= section.menuControllers.length)
      return const SizedBox.shrink();
    if (menuIndex >= section.setInputDataList.length)
      return const SizedBox.shrink();

    final bool isAerobic = section.selectedPart == l10n.aerobicExercise;

    final double topGap = 12.0;
    final double bottomGap = media.padding.bottom + 12;

    return Stack(
      children: [
        // 背景：タップで保存して閉じる
        Positioned.fill(
          child: GestureDetector(
            onTap: _saveMenuAndClose,
            child: AnimatedOpacity(
              duration: _overlayFadeDuration,
              curve: _overlayInCurve,
              opacity: _menuSlideIn ? 1.0 : 0.0,
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          top: topGap,
          bottom: bottomGap,
          child: AnimatedSlide(
            duration: _overlaySlideDuration,
            curve: _overlayInCurve,
            offset: _menuSlideIn ? Offset.zero : const Offset(0, -0.08),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                // ▼ フォーム全体をふわっと（フェード＋わずかにスケール）
                child: AnimatedOpacity(
                  duration: _overlayFadeDuration,
                  curve: _overlayInCurve,
                  opacity: _menuSlideIn ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: _overlaySlideDuration,
                    curve: _overlayInCurve,
                    scale: _menuSlideIn ? 1.0 : 0.98,
                    child: Column(
                      children: [
                        // ヘッダー：左=部位、右=＋セット＆保存
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
                          child: Row(
                            children: [
                              Text(
                                section.selectedPart ?? '',
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              if (!isAerobic &&
                                  SettingsManager.showIntervalTimer) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Center(
                                    child: ExerciseInputTimer(
                                      key: _ensureTimerKey(secIndex, menuIndex),
                                    ),
                                  ),
                                ),
                              ],
                              if (!isAerobic) ...[
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: (menuIndex <
                                              section.setInputDataList.length &&
                                          section.setInputDataList[menuIndex]
                                                  .length <
                                              10)
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          _addOneSetAt(secIndex, menuIndex);
                                        }
                                      : null,
                                  child: Text(l10n.addSet,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              TextButton.icon(
                                key: _kMenuSaveButton,
                                onPressed: _saveMenuAndClose,
                                icon: const Icon(Icons.check_rounded),
                                label: Text(l10n.save,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 内容：MenuList ...
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Scrollbar(
                              child: SingleChildScrollView(
                                child: Focus(
                                  focusNode: _menuOverlayFocus,
                                  child: MenuList(
                                    nameFieldKey:
                                        section.nameFieldKeys[menuIndex],
                                    menuController:
                                        section.menuControllers[menuIndex],
                                    removeMenuCallback: () =>
                                        _removeMenuItem(secIndex, menuIndex),
                                    setInputDataList:
                                        section.setInputDataList[menuIndex],
                                    isAerobic: isAerobic,
                                    distanceController: (menuIndex <
                                            section.aerobicDistanceCtrls.length)
                                        ? section
                                            .aerobicDistanceCtrls[menuIndex]
                                        : TextEditingController(),
                                    durationController: (menuIndex <
                                            section.aerobicDurationCtrls.length)
                                        ? section
                                            .aerobicDurationCtrls[menuIndex]
                                        : TextEditingController(),
                                    aerobicIsSuggestion: (menuIndex <
                                            section.aerobicSuggestFlags.length)
                                        ? section.aerobicSuggestFlags[menuIndex]
                                        : true,
                                    calorieController: (menuIndex <
                                            section.aerobicCaloriesCtrls.length)
                                        ? section
                                            .aerobicCaloriesCtrls[menuIndex]
                                        : null,
                                    showCalorieField: _shouldShowCalorieField(
                                        section, menuIndex),
                                    calorieIsSuggestion: (menuIndex <
                                            section.aerobicCalorieSuggestFlags
                                                .length)
                                        ? section.aerobicCalorieSuggestFlags[
                                            menuIndex]
                                        : true,
                                    showAerobicFailureHint: false,
                                    onConfirmAerobic: () {
                                      setState(() {
                                        if (menuIndex <
                                            section
                                                .aerobicSuggestFlags.length) {
                                          section.aerobicSuggestFlags[
                                              menuIndex] = false;
                                        }
                                      });
                                    },
                                    onAerobicFieldChanged: () =>
                                        _onAerobicFieldChanged(
                                            secIndex, menuIndex),
                                    onCalorieChanged: (value) =>
                                        _onCaloriesChanged(
                                            secIndex, menuIndex, value),
                                    onAerobicFailureHintTap: () =>
                                        _dismissAerobicFailureHint(
                                            secIndex, menuIndex),
                                    onAnyFieldFocused: () {},
                                    onMenuNameTap: () => _showExercisePicker(
                                        secIndex, menuIndex),
                                    onNameChanged: (prevEmpty, nowEmpty) {
                                      if (section.selectedPart ==
                                          l10n.aerobicExercise) {
                                        _onAerobicFieldChanged(
                                            secIndex, menuIndex);
                                      }
                                    },
                                    satisfaction: (menuIndex <
                                            section.satisfactionList.length)
                                        ? section.satisfactionList[menuIndex]
                                        : null,
                                    onSatisfactionChanged: (v) {
                                      setState(() {
                                        if (menuIndex <
                                            section.satisfactionList.length) {
                                          section.satisfactionList[menuIndex] =
                                              v;
                                        }
                                      });
                                    },
                                    previousTotalVolume: (menuIndex <
                                            section.previousVolumeList.length)
                                        ? section.previousVolumeList[menuIndex]
                                        : null,
                                    enabledForInput: true,
                                    isCollapsed: (menuIndex <
                                            section.menuCollapsedStates.length)
                                        ? section.menuCollapsedStates[menuIndex]
                                        : true,
                                    onToggleCollapse: () => _toggleMenuCollapse(
                                        secIndex, menuIndex),
                                    forceExpanded: true,
                                    timerKey:
                                        _ensureTimerKey(secIndex, menuIndex),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: const BigEarningAd(
                            androidNativeUnitId:
                                'ca-app-pub-3331079517737737/9518673738',
                            iosNativeUnitId:
                                'ca-app-pub-3331079517737737/3349399943',
                            androidBannerUnitId:
                                'ca-app-pub-3331079517737737/9588577724',
                            iosBannerUnitId:
                                'ca-app-pub-3331079517737737/6962414382',
                            factoryId: 'large_media',
                            height: 260,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final l10n = AppLocalizations.of(context)!;

    final media = MediaQuery.of(context);
    final kbInset = media.viewInsets.bottom;
    final bool keyboardVisible = kbInset > 0;
    final safeBottom = media.padding.bottom;

    final overlayStyle = isLight
        ? const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          )
        : const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          );

    const Color kBrandBlue = Color(0xFF2563EB);

    final bool showWeight = _showPersonalCard;
    final bool showBodyFat =
        (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    final bool showWaist =
        (widget.settingsBox.get('manage.waist') as bool?) ?? false;
    final bool showBMI =
        (widget.settingsBox.get('manage.bmi') as bool?) ?? false;
    final bool showBmr =
        (widget.settingsBox.get('manage.bmr') as bool?) ?? false;

// 設定：パーソナル機能が全OFFなら＋パーソナルを非表示
    final bool canShowPersonalButton = SettingsManager.showWeightInput ||
        showBodyFat ||
        showWaist ||
        showBMI ||
        showBmr;
    final bool inputOverlayActive = _memoOverlayVisible ||
        _menuOverlayVisible ||
        _mealOverlayVisible ||
        _personalOverlayVisible;
    final Widget blurLayer = inputOverlayActive
        ? Positioned.fill(
            child: _BlurExclusionLayer(
              exclusionKeys: [_kAdArea, _kStopwatchArea],
            ),
          )
        : const SizedBox.shrink();

    // ===== Body (空き領域タップでフォーカス解除) =====
    final body = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          children: [
            KeyedSubtree(
              key: _kAdArea,
              child: const AdBanner(screenName: 'record'),
            ),
            const SizedBox(height: 0.0),
            Visibility(
              visible: SettingsManager.showStopwatch,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: Padding(
                key: _kStopwatchArea,
                padding: EdgeInsets.zero,
                child: _buildStopwatchCard(),
              ),
            ),
            Expanded(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                    bottom: (kbInset > 0 ? kbInset + safeBottom + 12 : 12)),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  primary: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  // ← ドラッグで閉じる
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: (showWeight ? 1 : 0) +
                      _sections.length +
                      _mealCards.length +
                      (_showMemo ? 1 : 0) +
                      1,
                  itemBuilder: (context, index) {
                    if (showWeight && index == 0) {
                      final cs = colorScheme;
                      final l10n = AppLocalizations.of(context)!;
                      final currentUnit = SettingsManager.currentUnit;

                      // コロン揃え用
                      const double _labelColW = 92.0;

                      Widget _metricRow({
                        required String label,
                        required TextEditingController controller,
                        String? unit,
                      }) {
                        final cs = colorScheme;
                        final labelStyle = TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13.0);

                        InputDecoration _underlineDec() => InputDecoration(
                              isDense: true,
                              filled: false,
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: cs.onSurfaceVariant.withOpacity(0.4),
                                    width: 1),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: cs.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 0),
                            );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final total = constraints.maxWidth;

                              // ← 微妙に左寄せ：ラベルとフィールドの間隔を 8 → 6 に
                              final leftW = _labelColW + 6;

                              // ← 単位の有無に関係なく右側を常に確保（BMI でも確保）
                              const baseRight = _unitReserveW + 6;

                              // ← 計算は「左側だけ引いた 2/3」に統一（BMIと同じ）
                              final fieldW = ((total - leftW) * 4 / 5)
                                  .clamp(120.0, total - leftW - baseRight);
                              ; // 最小幅ガード

                              return Row(
                                children: [
                                  SizedBox(
                                    width: _labelColW,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(label, style: labelStyle),
                                        const SizedBox(width: 2),
                                        Text('：', style: labelStyle),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // ← 下線を 2/3 に縮める（幅指定）
                                  SizedBox(
                                    width: fieldW.toDouble(),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          minHeight: kUnifiedFieldMinHeight),
                                      child: TextField(
                                        controller: controller,
                                        readOnly: true,
                                        enableInteractiveSelection: false,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontFamily: kUiFont,
                                            color: cs.onSurface),
                                        decoration: _underlineDec(),
                                        onTap: _openPersonalOverlaySmooth,
                                      ),
                                    ),
                                  ),

                                  if (unit != null) ...[
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: _unitReserveW,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          unit,
                                          style: TextStyle(
                                            fontFamily: kUiFont,
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        );
                      }

                      // BMI：未計算は空欄の下線
                      final _bmiCtrl = TextEditingController(
                        text: _bmiValue?.toStringAsFixed(1) ?? '',
                      );

                      return Padding(
                        padding: EdgeInsets.zero,
                        child: Card(
                          color: cs.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: BorderSide(
                              color: _personalSelected
                                  ? (isLight ? kBrandBlue : cs.primary)
                                  : Colors.transparent,
                              width: _personalSelected ? 1.5 : 0,
                            ),
                          ),
                          elevation: _personalSelected ? 3.0 : 1.0,
                          shadowColor: _personalSelected
                              ? (isLight
                                  ? kBrandBlue.withOpacity(0.35)
                                  : cs.primary.withOpacity(0.45))
                              : Colors.black.withOpacity(0.20),
                          child: Stack(
                            children: [
                              // 全体タップでオーバーレイを開く透明レイヤー
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16.0),
                                    onTap: () {
                                      if (_personalSelected) {
                                        _openPersonalOverlaySmooth();
                                      } else {
                                        setState(() {
                                          _personalSelected = true;
                                          _currentSectionIndex = null;
                                          _currentMenuIndex = null;
                                          _currentMealIndex = null;
                                          _lastInteractionAt = DateTime.now();
                                          _closeFabDial();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // ↓ 先に中身（白いカードなど）
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ===== 白いカード =====
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      decoration: BoxDecoration(
                                        color: cs.surface,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.06),
                                              blurRadius: 8,
                                              offset: Offset(0, 2))
                                        ],
                                        border: Border.all(
                                            color: cs.onSurfaceVariant
                                                .withOpacity(0.08),
                                            width: 0.8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            6.0, 10.0, 10.0, 10.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 6.0,
                                                            right: 4.0),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      child: ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                                minHeight:
                                                                    kUnifiedFieldMinHeight),
                                                        child: Focus(
                                                          canRequestFocus:
                                                              false,
                                                          descendantsAreFocusable:
                                                              false,
                                                          child: TextField(
                                                            controller:
                                                                TextEditingController(
                                                                    text: l10n
                                                                        .weightCardTitle),
                                                            readOnly: true,
                                                            showCursor: false,
                                                            enableInteractiveSelection:
                                                                false,
                                                            onTap:
                                                                _openPersonalOverlaySmooth,
                                                            decoration:
                                                                _underlineDec()
                                                                    .copyWith(
                                                              contentPadding:
                                                                  const EdgeInsets
                                                                      .fromLTRB(
                                                                8,
                                                                6,
                                                                0,
                                                                6,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => setState(() {
                                                    _personalCollapsed =
                                                        !_personalCollapsed;
                                                  }),
                                                  tooltip: _personalCollapsed
                                                      ? l10n.expandCard
                                                      : l10n.collapseCard,
                                                  icon: Icon(
                                                    _personalCollapsed
                                                        ? Icons
                                                            .keyboard_arrow_down_rounded
                                                        : Icons
                                                            .keyboard_arrow_up_rounded,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashRadius: 20,
                                                ),
                                                IconButton(
                                                  onPressed:
                                                      _handleRemovePersonalCard,
                                                  tooltip: l10n
                                                      .removePersonalCardTooltip,
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashRadius: 18,
                                                ),
                                              ],
                                            ),
                                            AnimatedCrossFade(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              sizeCurve: Curves.easeOutCubic,
                                              crossFadeState: _personalCollapsed
                                                  ? CrossFadeState.showFirst
                                                  : CrossFadeState.showSecond,
                                              firstChild:
                                                  const SizedBox.shrink(),
                                              secondChild: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 2),
                                                  _metricRow(
                                                      label: l10n.bodyWeight,
                                                      controller:
                                                          _weightController,
                                                      unit: currentUnit == 'kg'
                                                          ? l10n.kg
                                                          : l10n.lbs),
                                                  if (showBodyFat)
                                                    _metricRow(
                                                        label: l10n.bodyFat,
                                                        controller:
                                                            _bodyFatController,
                                                        unit:
                                                            l10n.percentSymbol),
                                                  if (showWaist)
                                                    _metricRow(
                                                        label: l10n.waist,
                                                        controller:
                                                            _waistController,
                                                        unit: SettingsManager
                                                                .isWaistInch
                                                            ? l10n.unitIn
                                                            : l10n.unitCm),
                                                  if (showBMI)
                                                    _metricRow(
                                                        label: l10n.bmi,
                                                        controller: _bmiCtrl),
                                                  if (showBmr) ...[
                                                    _metricRow(
                                                      label: l10n.bmrTitleShort,
                                                      controller:
                                                          _bmrController,
                                                      unit: l10n.kcalUnit,
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 98, top: 4),
                                                      child: Text(
                                                        _formattedBmrDifference(
                                                            l10n),
                                                        style: TextStyle(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
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
                    }

                    final int mealCount = _mealCards.length;
                    final int headerCount = (showWeight ? 1 : 0);
                    final int sectionCount = _sections.length;
                    final int bodyIdx = index - headerCount;

                    if (bodyIdx < sectionCount) {
                      final secIndex = bodyIdx;
                      final section = _sections[secIndex];

                      return Padding(
                        key: section.key, // ← ensureVisible用のKeyは維持
                        padding: EdgeInsets.zero,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _touchCard(secIndex, 0),
                          child: Card(
                            color: colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0)),
                            elevation: 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainer,
                                            borderRadius:
                                                BorderRadius.circular(22.0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.04),
                                                blurRadius: 3.0,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            child: GestureDetector(
                                              key: secIndex == 0
                                                  ? _kRecordPart
                                                  : null,
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _showPartPicker(secIndex),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 20),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        section.selectedPart ??
                                                            l10n.selectTrainingPart,
                                                        style: TextStyle(
                                                          fontFamily: kUiFont,
                                                          color: (section
                                                                      .selectedPart ==
                                                                  null)
                                                              ? colorScheme
                                                                  .onSurfaceVariant
                                                              : colorScheme
                                                                  .onSurface,
                                                          fontSize: 15.0,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const Icon(
                                                        Icons.expand_more,
                                                        size: 22),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _handleRemoveSection(secIndex),
                                        tooltip: l10n.removePartCardTooltip,
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        splashRadius: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4.0),
                                  if (section.selectedPart != null)
                                    Column(
                                      children: [
                                        ReorderableListView.builder(
                                          key: ValueKey('sec-$secIndex-menus'),
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          buildDefaultDragHandles: false,
                                          itemCount:
                                              section.menuControllers.length,
                                          proxyDecorator:
                                              (child, index, animation) {
                                            return AnimatedBuilder(
                                              animation: animation,
                                              builder: (context, childParam) {
                                                final t = Curves.easeOutCubic
                                                    .transform(animation.value);
                                                return Transform.scale(
                                                  scale: 1.0 + 0.02 * t,
                                                  child: childParam,
                                                );
                                              },
                                              child: Material(
                                                elevation: 10,
                                                color: Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  child: child,
                                                ),
                                              ),
                                            );
                                          },
                                          onReorder: (oldIndex, newIndex) =>
                                              _reorderMenuItem(
                                                  secIndex, oldIndex, newIndex),
                                          itemBuilder: (context, menuIndex) {
                                            final bool isSelected =
                                                (_currentSectionIndex ==
                                                        secIndex &&
                                                    _currentMenuIndex ==
                                                        menuIndex);
                                            final borderColor = isSelected
                                                ? (isLight
                                                    ? kBrandBlue
                                                    : Colors.white)
                                                : Colors.transparent;
                                            final glowColor = isSelected
                                                ? (isLight
                                                    ? kBrandBlue
                                                        .withOpacity(0.45)
                                                    : Colors.white
                                                        .withOpacity(0.70))
                                                : Colors.black
                                                    .withOpacity(0.20);
                                            final bool isEditingThisOne = true;

                                            Widget content;
                                            if (isEditingThisOne) {
                                              content = MenuListPreview(
                                                menuController: section
                                                    .menuControllers[menuIndex],
                                                setInputDataList:
                                                    section.setInputDataList[
                                                        menuIndex],
                                                isAerobic:
                                                    section.selectedPart ==
                                                        l10n.aerobicExercise,
                                                distanceController: (menuIndex <
                                                        section
                                                            .aerobicDistanceCtrls
                                                            .length)
                                                    ? section
                                                            .aerobicDistanceCtrls[
                                                        menuIndex]
                                                    : null,
                                                durationController: (menuIndex <
                                                        section
                                                            .aerobicDurationCtrls
                                                            .length)
                                                    ? section
                                                            .aerobicDurationCtrls[
                                                        menuIndex]
                                                    : null,
                                                calorieController: (menuIndex <
                                                        section
                                                            .aerobicCaloriesCtrls
                                                            .length)
                                                    ? section
                                                            .aerobicCaloriesCtrls[
                                                        menuIndex]
                                                    : null,
                                                showCalorieField:
                                                    _shouldShowCalorieField(
                                                        section, menuIndex),
                                                showAerobicFailureHint: false,
                                                satisfaction: (menuIndex <
                                                        section.satisfactionList
                                                            .length)
                                                    ? section.satisfactionList[
                                                        menuIndex]
                                                    : null,
                                                previousVolume: (menuIndex <
                                                        section
                                                            .previousVolumeList
                                                            .length)
                                                    ? section
                                                            .previousVolumeList[
                                                        menuIndex]
                                                    : null,
                                                isCollapsed: (menuIndex <
                                                        section
                                                            .menuCollapsedStates
                                                            .length)
                                                    ? section
                                                            .menuCollapsedStates[
                                                        menuIndex]
                                                    : true,
                                                onPrepareAction: () =>
                                                    _prepareMenuQuickAction(
                                                        secIndex, menuIndex),
                                                onToggleCollapse: () =>
                                                    _toggleMenuCollapse(
                                                        secIndex, menuIndex,
                                                        suppressOverlay: true),
                                                onRemoveMenu: () =>
                                                    _removeMenuItem(
                                                        secIndex, menuIndex),
                                              );
                                            } else {
                                              content = MenuList(
                                                key: (secIndex == 0 &&
                                                        menuIndex == 0)
                                                    ? _kExerciseField
                                                    : null,
                                                nameFieldKey: section
                                                    .nameFieldKeys[menuIndex],
                                                menuController: section
                                                    .menuControllers[menuIndex],
                                                removeMenuCallback: () =>
                                                    _removeMenuItem(
                                                        secIndex, menuIndex),
                                                setInputDataList:
                                                    section.setInputDataList[
                                                        menuIndex],
                                                isAerobic:
                                                    section.selectedPart ==
                                                        l10n.aerobicExercise,
                                                distanceController: (menuIndex <
                                                        section
                                                            .aerobicDistanceCtrls
                                                            .length)
                                                    ? section
                                                            .aerobicDistanceCtrls[
                                                        menuIndex]
                                                    : TextEditingController(),
                                                durationController: (menuIndex <
                                                        section
                                                            .aerobicDurationCtrls
                                                            .length)
                                                    ? section
                                                            .aerobicDurationCtrls[
                                                        menuIndex]
                                                    : TextEditingController(),
                                                aerobicIsSuggestion: (menuIndex <
                                                        section
                                                            .aerobicSuggestFlags
                                                            .length)
                                                    ? section
                                                            .aerobicSuggestFlags[
                                                        menuIndex]
                                                    : true,
                                                calorieController: (menuIndex <
                                                        section
                                                            .aerobicCaloriesCtrls
                                                            .length)
                                                    ? section
                                                            .aerobicCaloriesCtrls[
                                                        menuIndex]
                                                    : null,
                                                showCalorieField:
                                                    _shouldShowCalorieField(
                                                        section, menuIndex),
                                                calorieIsSuggestion: (menuIndex <
                                                        section
                                                            .aerobicCalorieSuggestFlags
                                                            .length)
                                                    ? section
                                                            .aerobicCalorieSuggestFlags[
                                                        menuIndex]
                                                    : true,
                                                showAerobicFailureHint: false,
                                                onConfirmAerobic: () {
                                                  setState(() {
                                                    if (menuIndex <
                                                        section
                                                            .aerobicSuggestFlags
                                                            .length) {
                                                      section.aerobicSuggestFlags[
                                                          menuIndex] = false;
                                                    }
                                                  });
                                                },
                                                onAerobicFieldChanged: () =>
                                                    _onAerobicFieldChanged(
                                                        secIndex, menuIndex),
                                                onCalorieChanged: (value) =>
                                                    _onCaloriesChanged(secIndex,
                                                        menuIndex, value),
                                                onAerobicFailureHintTap: () =>
                                                    _dismissAerobicFailureHint(
                                                        secIndex, menuIndex),
                                                enabledForInput: isSelected,
                                                onMenuNameTap: () =>
                                                    _showExercisePicker(
                                                        secIndex, menuIndex),
                                                onNameChanged:
                                                    (prevEmpty, nowEmpty) {
                                                  if (section.selectedPart ==
                                                      l10n.aerobicExercise) {
                                                    _onAerobicFieldChanged(
                                                        secIndex, menuIndex);
                                                  }
                                                },
                                                satisfaction: (menuIndex <
                                                        section.satisfactionList
                                                            .length)
                                                    ? section.satisfactionList[
                                                        menuIndex]
                                                    : null,
                                                onSatisfactionChanged: (v) {
                                                  setState(() {
                                                    if (menuIndex <
                                                        section.satisfactionList
                                                            .length) {
                                                      section.satisfactionList[
                                                          menuIndex] = v;
                                                    }
                                                  });
                                                },
                                                previousTotalVolume: (menuIndex <
                                                        section
                                                            .previousVolumeList
                                                            .length)
                                                    ? section
                                                            .previousVolumeList[
                                                        menuIndex]
                                                    : null,
                                                isCollapsed: (menuIndex <
                                                        section
                                                            .menuCollapsedStates
                                                            .length)
                                                    ? section
                                                            .menuCollapsedStates[
                                                        menuIndex]
                                                    : true,
                                                onPrepareAction: () =>
                                                    _prepareMenuQuickAction(
                                                        secIndex, menuIndex),
                                                onToggleCollapse: () =>
                                                    _toggleMenuCollapse(
                                                        secIndex, menuIndex,
                                                        suppressOverlay: true),
                                                timerKey: _ensureTimerKey(
                                                    secIndex, menuIndex),
                                              );
                                            }

                                            return KeyedSubtree(
                                              key: section.menuKeys[menuIndex],
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 3.0),
                                                child: Card(
                                                  color: colorScheme.surface,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                    side: BorderSide(
                                                      color: borderColor,
                                                      width:
                                                          isSelected ? 1.5 : 0,
                                                    ),
                                                  ),
                                                  elevation:
                                                      isSelected ? 3.0 : 0.0,
                                                  shadowColor: glowColor,
                                                  margin: EdgeInsets.zero,
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      ReorderableDragStartListener(
                                                        index: menuIndex,
                                                        child: Container(
                                                          width: 40,
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 16.0,
                                                                  bottom: 4.0),
                                                          alignment:
                                                              AlignmentDirectional
                                                                  .topCenter,
                                                          child: Icon(
                                                            Icons
                                                                .drag_indicator_rounded,
                                                            size: 22,
                                                            color: isSelected
                                                                ? colorScheme
                                                                    .primary
                                                                : colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12.0),
                                                          splashFactory: NoSplash
                                                              .splashFactory,
                                                          highlightColor: Colors
                                                              .transparent,
                                                          onTap: () {
                                                            final bool
                                                                skipThisTap =
                                                                (_skipTapSectionIndex ==
                                                                        secIndex &&
                                                                    _skipTapMenuIndex ==
                                                                        menuIndex);
                                                            if (skipThisTap) {
                                                              _skipTapSectionIndex =
                                                                  null;
                                                              _skipTapMenuIndex =
                                                                  null;
                                                              _suppressNextMenuOverlay =
                                                                  false;
                                                              return;
                                                            }
                                                            final alreadySelected =
                                                                isSelected;
                                                            _touchCard(secIndex,
                                                                menuIndex);
                                                            final shouldOpen =
                                                                alreadySelected &&
                                                                    !_suppressNextMenuOverlay;
                                                            _suppressNextMenuOverlay =
                                                                false;
                                                            if (shouldOpen) {
                                                              _openMenuOverlaySmooth(
                                                                  secIndex,
                                                                  menuIndex);
                                                            }
                                                          },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(10.0),
                                                            child: content,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 10.0),
                                        const SizedBox.shrink(),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final int mealStart = sectionCount;
                    final int mealEnd = mealStart + mealCount;
                    if (bodyIdx >= mealStart && bodyIdx < mealEnd) {
                      if (_mealCards.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      if (bodyIdx == mealStart) {
                        final l10n = AppLocalizations.of(context)!;
                        return Padding(
                          padding: EdgeInsets.zero,
                          child: Card(
                            color: colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0)),
                            elevation: 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainer,
                                            borderRadius:
                                                BorderRadius.circular(22.0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.04),
                                                blurRadius: 3.0,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 20),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                l10n.meal,
                                                style: TextStyle(
                                                  fontFamily: kUiFont,
                                                  color: colorScheme.onSurface,
                                                  fontSize: 15.0,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: () =>
                                            _confirmRemoveAllMealCards(context),
                                        tooltip: l10n.delete,
                                        icon: const Icon(Icons.close),
                                        iconSize: 18,
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                                width: 36, height: 36),
                                        visualDensity: VisualDensity.compact,
                                        splashRadius: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4.0),
                                  ReorderableListView.builder(
                                    key: const ValueKey(
                                        'meal-cards-reorderable'),
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    buildDefaultDragHandles: false,
                                    itemCount: _mealCards.length,
                                    proxyDecorator: (child, index, animation) {
                                      return AnimatedBuilder(
                                        animation: animation,
                                        builder: (context, childParam) {
                                          final t = Curves.easeOutCubic
                                              .transform(animation.value);
                                          return Transform.scale(
                                            scale: 1.0 + 0.02 * t,
                                            child: childParam,
                                          );
                                        },
                                        child: Material(
                                          elevation: 10,
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                    onReorder: _reorderMealCards,
                                    itemBuilder: (context, mealIndex) {
                                      return KeyedSubtree(
                                        key: ValueKey(_mealCards[mealIndex]),
                                        child: _buildMealCard(mealIndex),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10.0),
                                  const SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    final int memoIndex = mealEnd;
                    if (_showMemo && bodyIdx == memoIndex) {
                      return _buildMemoCard();
                    }

                    final int mediaIndex = mealEnd + (_showMemo ? 1 : 0);
                    if (bodyIdx == mediaIndex) {
                      return KeyedSubtree(
                        key: _kPhotoCardsKey,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 0.0, bottom: 8.0),
                          child: _buildMediaCards(),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ===== FAB =====
    final fabMain = FloatingActionButton(
      key: _kFabKey,
      onPressed: _weightFocused
          ? null
          : () {
              HapticFeedback.lightImpact();
              final opening = !_fabOpen;
              setState(() => _fabOpen = opening);
              opening ? _fabCtrl.forward() : _fabCtrl.reverse();
            },
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: AnimatedBuilder(
        animation: _fabCtrl,
        builder: (_, __) => Transform.rotate(
          angle: _fabCtrl.value * (3.1415926535 / 4), // ＋→× っぽく
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      tooltip: l10n.openAddMenu,
    );

    // （もう使わないが参照があっても安全のため残置）
    bool canAddSet() {
      if (_sections.isEmpty) return false;
      final sec = _sections[_currentSectionIndex ?? 0];
      if (sec.selectedPart == null) return false;
      if (sec.selectedPart == l10n.aerobicExercise) return false;
      final menuIdx = _currentMenuIndex ?? 0;
      if (menuIdx >= sec.setInputDataList.length) return false;
      return sec.setInputDataList[menuIdx].length < 10;
    }

    Widget chipAction(String label, VoidCallback onTap, {bool enabled = true}) {
      final radius = BorderRadius.circular(22);
      return Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _fabOpen = false;
                      _fabCtrl.reverse();
                    });
                    onTap();
                  }
                : null,
            child: Ink(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 2.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final overlay = (!keyboardVisible &&
            !_memoOverlayVisible &&
            !_memoOverlayOpen &&
            !_menuOverlayVisible &&
            !_mealOverlayVisible &&
            !_personalOverlayVisible)
        ? Positioned.fill(
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _fabCtrl, curve: Curves.easeOutCubic),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _fabOpen = false);
                    _fabCtrl.reverse();
                  },
                  child: Container(color: Colors.black.withOpacity(0.25)),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    const double fabSize = 56.0;
    const double fabMargin = 14.0;
    const double gapAboveFab = 24.0;
    final double dialBottom = (safeBottom > 0 ? safeBottom : fabMargin) +
        kbInset +
        fabSize +
        fabMargin +
        gapAboveFab;

    // ＋セットはダイヤルから削除（オーバーレイのヘッダーへ移動）
    Widget _stagger(int index, Widget child) {
      final curved = CurvedAnimation(
        parent: _fabCtrl,
        curve: Interval(0.15 + index * 0.10, 1.0, curve: Curves.easeOutCubic),
        reverseCurve: const Interval(0.0, 0.70, curve: Curves.easeInCubic),
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(curved),
          child: child,
        ),
      );
    }

    final hasMealCards = _mealCards.isNotEmpty;

    final dial = Positioned(
      right: 16,
      bottom: dialBottom,
      child: (!keyboardVisible &&
              !_memoOverlayVisible &&
              !_memoOverlayOpen &&
              !_menuOverlayVisible &&
              !_mealOverlayVisible &&
              !_personalOverlayVisible)
          ? IgnorePointer(
              ignoring: !_fabOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _stagger(
                      0,
                      chipAction(l10n.addExercise, _handleAddExercise,
                          enabled: _canAddExercise())),
                  const SizedBox(height: 8),
                  _stagger(1, chipAction(l10n.addPart, _handleAddPart)),
                  const SizedBox(height: 8),
                  _stagger(
                      2,
                      chipAction(
                        l10n.mealAdd,
                        _handleAddMeal,
                        enabled: !hasMealCards,
                      )),
                  const SizedBox(height: 8),
                  _stagger(3, chipAction(l10n.addMemo, _handleAddMemo)),
                  const SizedBox(height: 8),
                  _stagger(4, chipAction(l10n.addPhoto, _handleAddPhoto)),
                  if (canShowPersonalButton) ...[
                    const SizedBox(height: 8),
                    _stagger(
                        5,
                        chipAction('＋${l10n.weightCardTitle}',
                            _handleAddPersonal,
                            enabled: !_showPersonalCard)),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );

    // もう使わないけど、参照があっても安全にするためのダミー
    final Widget doneOverlay = const SizedBox.shrink();

    final savedPillArea = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final slide =
            Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero)
                .animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: _showSavedChip
          ? _buildSavedPill(colorScheme)
          : const SizedBox(key: ValueKey('empty')),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleExit();
        },
        child: Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          backgroundColor: SettingsManager.backgroundAssetNotifier.value.isEmpty
              ? null
              : Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: !inputOverlayActive,
            leading: inputOverlayActive ? const SizedBox.shrink() : null,
            leadingWidth: inputOverlayActive ? 0 : null,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
            centerTitle: false,
            titleSpacing: 16,
            toolbarHeight: 56,
            title: Text(DateFormat('yyyy/MM/dd').format(widget.selectedDate)),
          ),
          body: Stack(
            children: [
              body,
              blurLayer,
              overlay,
              dial,
              _buildMealEditorOverlay(),
              _buildMenuEditorOverlay(),
              _buildMemoEditorOverlay(),
              _buildPersonalEditorOverlay(), // ← 追加
              doneOverlay,
            ],
          ),
          floatingActionButton: (!keyboardVisible &&
                  !_memoOverlayVisible &&
                  !_memoOverlayOpen &&
                  !_menuOverlayVisible &&
                  !_mealOverlayVisible &&
                  !_personalOverlayVisible)
              ? AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                      bottom: (kbInset > 0 ? kbInset + 10 : 14)),
                  child: fabMain,
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }

  Future<void> _scrollIntoComfortZoneAfterKeyboard(
    GlobalKey key, {
    double pivot = 0.0,
    double topExtra = 28,
  }) async {
    await _waitForKeyboardStable();
    await _scrollIntoComfortZone(key, pivot: pivot, topExtra: topExtra);
  }

  Future<void> _scrollIntoComfortZone(
    GlobalKey key, {
    double pivot = 0.5,
    double topExtra = 28,
  }) async {
    _pendingScrollKey = key;
    _scrollDebounce?.cancel();

    _scrollDebounce = Timer(const Duration(milliseconds: 120), () async {
      if (!mounted) return;

      final ctx = _pendingScrollKey?.currentContext;
      if (ctx == null) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final targetCtx = _pendingScrollKey?.currentContext;
      if (targetCtx == null) return;

      final media = MediaQuery.of(context);
      final double vh = media.size.height;
      final double kb = media.viewInsets.bottom;
      final double sb = media.padding.bottom;

      double swH = 0;
      if (SettingsManager.showStopwatch) {
        final swCtx = _kStopwatchArea.currentContext;
        if (swCtx != null) {
          final rb = swCtx.findRenderObject() as RenderBox?;
          if (rb != null) swH = rb.size.height;
        }
      }

      final double topReserve = swH + topExtra;
      final double bottomReserve = kb + sb + 16;

      final double topFrac = (topReserve / vh).clamp(0.0, 0.7);
      final double bottomFrac = (bottomReserve / vh).clamp(0.0, 0.8);
      final double visibleFrac = (1.0 - topFrac - bottomFrac).clamp(0.15, 0.85);
      final double p = pivot.clamp(0.0, 1.0);
      final double align = (topFrac + visibleFrac * p).clamp(0.02, 0.98);

      await Scrollable.ensureVisible(
        targetCtx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: align,
      );
    });
  }

  Future<void> _scheduleHintsAfterPart() async {
    final box = widget.settingsBox;
    final seen = box.get('hint_seen_record_after_part') as bool? ?? false;
    if (seen) return;

    await Future<void>.delayed(const Duration(milliseconds: 16));
    final deadline = DateTime.now().add(const Duration(milliseconds: 600));
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted) return;
      if (_kExerciseField.currentContext != null ||
          _kFabKey.currentContext != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final anchors = <GlobalKey>[];
    final messages = <String>[];

    void addIfVisible(GlobalKey k, String msg) {
      if (k.currentContext != null) {
        anchors.add(k);
        messages.add(msg);
      }
    }

    addIfVisible(_kExerciseField, l10n.hintRecordExerciseField);
    addIfVisible(_kFabKey, l10n.hintRecordFab);

    if (anchors.isEmpty) return;

    // (hint removed)
    await box.put('hint_seen_record_after_part', true);
  }
}

// ===== SectionData / SetInputData / MenuList =====

class SectionData {
  Key key;
  String? selectedPart;
  List<TextEditingController> menuControllers;
  List<List<SetInputData>> setInputDataList;
  List<GlobalKey> menuKeys; // ← GlobalKey に変更
  List<GlobalKey> nameFieldKeys;
  List<bool> menuCollapsedStates;

  // 追加：メニューごとの満足度（2=良い,1=普通,0=悪い,null=未選択）
  List<int?> satisfactionList;
  List<double?> previousVolumeList; // 追加：前回総ボリューム

  List<TextEditingController> aerobicDistanceCtrls;
  List<TextEditingController> aerobicDurationCtrls;
  List<bool> aerobicSuggestFlags;
  List<TextEditingController> aerobicCaloriesCtrls;
  List<bool> aerobicCalorieSuggestFlags;
  List<bool> aerobicCalorieHintVisible;
  List<bool> aerobicCalorieHintShown;

  SectionData({
    required this.key,
    this.selectedPart,
    required this.menuControllers,
    required this.setInputDataList,
    required this.menuKeys,
    required this.nameFieldKeys,
    List<bool>? menuCollapsedStates,
    List<int?>? satisfactionList, // 追加
    List<double?>? previousVolumeList,
    List<TextEditingController>? aerobicDistanceCtrls,
    List<TextEditingController>? aerobicDurationCtrls,
    List<bool>? aerobicSuggestFlags,
    List<TextEditingController>? aerobicCaloriesCtrls,
    List<bool>? aerobicCalorieSuggestFlags,
    List<bool>? aerobicCalorieHintVisible,
    List<bool>? aerobicCalorieHintShown,
  })  : menuCollapsedStates = menuCollapsedStates ?? <bool>[],
        satisfactionList = satisfactionList ?? <int?>[],
        previousVolumeList = previousVolumeList ?? <double?>[],
        // 追加
        aerobicDistanceCtrls =
            aerobicDistanceCtrls ?? <TextEditingController>[],
        aerobicDurationCtrls =
            aerobicDurationCtrls ?? <TextEditingController>[],
        aerobicSuggestFlags = aerobicSuggestFlags ?? <bool>[],
        aerobicCaloriesCtrls =
            aerobicCaloriesCtrls ?? <TextEditingController>[],
        aerobicCalorieSuggestFlags = aerobicCalorieSuggestFlags ?? <bool>[],
        aerobicCalorieHintVisible = aerobicCalorieHintVisible ?? <bool>[],
        aerobicCalorieHintShown = aerobicCalorieHintShown ?? <bool>[];

  factory SectionData.createEmpty(int initialSetCount,
      {required bool shouldPopulateDefaults}) {
    return SectionData(
      key: GlobalKey(),
      selectedPart: null,
      menuControllers: shouldPopulateDefaults ? [TextEditingController()] : [],
      setInputDataList: shouldPopulateDefaults
          ? [
              List.generate(
                initialSetCount,
                (_) => SetInputData(
                  weightController: TextEditingController(),
                  repController: TextEditingController(),
                  isSuggestion: true,
                ),
              )
            ]
          : [],
      menuKeys: shouldPopulateDefaults ? [GlobalKey()] : [],
      nameFieldKeys: shouldPopulateDefaults ? [GlobalKey()] : [],
      menuCollapsedStates: shouldPopulateDefaults ? [true] : [],
      satisfactionList: shouldPopulateDefaults ? [null] : [],
      previousVolumeList: shouldPopulateDefaults ? [null] : [],
      // 追加
      aerobicDistanceCtrls: [],
      aerobicDurationCtrls: [],
      aerobicSuggestFlags: [],
      aerobicCaloriesCtrls: [],
      aerobicCalorieSuggestFlags: [],
      aerobicCalorieHintVisible: [],
      aerobicCalorieHintShown: [],
    );
  }

  void dispose() {
    for (var c in menuControllers) {
      c.dispose();
    }
    for (var row in setInputDataList) {
      for (var d in row) {
        d.dispose();
      }
    }
    for (var c in aerobicDistanceCtrls) {
      c.dispose();
    }
    for (var c in aerobicDurationCtrls) {
      c.dispose();
    }
    for (var c in aerobicCaloriesCtrls) {
      c.dispose();
    }
  }
}

class SetInputData {
  TextEditingController weightController;
  TextEditingController repController;
  bool isSuggestion;
  bool checked; // ← 追加：回の右側チェックボックスの状態

  SetInputData({
    required this.weightController,
    required this.repController,
    this.isSuggestion = true,
    this.checked = false, // ← 追加：既定は未チェック
  });

  void dispose() {
    weightController.dispose();
    repController.dispose();
  }
}

double? calculateTotalVolume(List<SetInputData> sets) {
  double total = 0;
  bool hasValue = false;
  for (final set in sets) {
    if (!set.checked) {
      continue;
    }
    final weightText = set.weightController.text.trim();
    final repsText = set.repController.text.trim();
    if (weightText.isEmpty || repsText.isEmpty) {
      continue;
    }
    final double? weight = double.tryParse(weightText);
    final double? reps = double.tryParse(repsText);
    if (weight == null || reps == null) {
      continue;
    }
    hasValue = true;
    total += weight * reps;
  }
  return hasValue ? total : null;
}

class _BlurExclusionLayer extends StatefulWidget {
  final List<GlobalKey> exclusionKeys;
  final double sigma;

  const _BlurExclusionLayer({
    required this.exclusionKeys,
    this.sigma = 18,
  });

  @override
  State<_BlurExclusionLayer> createState() => _BlurExclusionLayerState();
}

class _BlurExclusionLayerState extends State<_BlurExclusionLayer> {
  List<Rect> _exclusionRects = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureRects());
  }

  @override
  void didUpdateWidget(covariant _BlurExclusionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureRects());
  }

  void _captureRects() {
    if (!mounted) return;
    final host = context.findRenderObject() as RenderBox?;
    if (host == null || !host.hasSize) return;

    final rects = <Rect>[];
    for (final key in widget.exclusionKeys) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero, ancestor: host);
      rects.add(offset & box.size);
    }

    if (!listEquals(rects, _exclusionRects)) {
      setState(() => _exclusionRects = rects);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return ClipPath(
            clipper: _ExcludeRectsClipper(rects: _exclusionRects),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.sigma,
                sigmaY: widget.sigma,
              ),
              child: Container(
                width: size.width,
                height: size.height,
                color: Colors.black.withOpacity(0.12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExcludeRectsClipper extends CustomClipper<Path> {
  final List<Rect> rects;

  _ExcludeRectsClipper({required this.rects});

  @override
  Path getClip(Size size) {
    Path combined = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final rect in rects) {
      combined = Path.combine(
        PathOperation.difference,
        combined,
        Path()..addRect(rect),
      );
    }
    return combined;
  }

  @override
  bool shouldReclip(covariant _ExcludeRectsClipper oldClipper) {
    if (rects.length != oldClipper.rects.length) return true;
    for (var i = 0; i < rects.length; i++) {
      if (rects[i] != oldClipper.rects[i]) return true;
    }
    return false;
  }
}

class MenuListPreview extends StatelessWidget {
  final TextEditingController menuController;
  final List<SetInputData> setInputDataList;
  final bool isAerobic;
  final TextEditingController? distanceController;
  final TextEditingController? durationController;
  final TextEditingController? calorieController;
  final bool showCalorieField;
  final bool showAerobicFailureHint;
  final int? satisfaction;
  final double? previousVolume;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onPrepareAction;
  final VoidCallback onRemoveMenu;

  const MenuListPreview({
    super.key,
    required this.menuController,
    required this.setInputDataList,
    required this.isAerobic,
    this.distanceController,
    this.durationController,
    this.calorieController,
    this.showCalorieField = false,
    this.showAerobicFailureHint = false,
    this.satisfaction,
    this.previousVolume,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onPrepareAction,
    required this.onRemoveMenu,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final nameStyle = TextStyle(
      fontFamily: kUiFont,
      color: cs.onSurface,
      fontSize: 15.0,
    );
    final hintStyle = TextStyle(
      color: cs.onSurfaceVariant.withOpacity(0.5),
      fontSize: 15.0,
    );

    Widget underlineBox(Widget child) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.onSurfaceVariant.withOpacity(0.35)),
          ),
        ),
        child: child,
      );
    }

    Widget buildMenuName() {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: menuController,
        builder: (_, value, __) {
          final text = value.text.trim();
          if (text.isEmpty) {
            return underlineBox(
                Text(l10n.addExercisePlaceholder, style: hintStyle));
          }
          return underlineBox(Text(text, style: nameStyle));
        },
      );
    }

    Widget buildSetRows() {
      if (setInputDataList.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Text(
            '-',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.0),
          ),
        );
      }

      final unit = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
      return Column(
        children: List.generate(setInputDataList.length, (index) {
          final set = setInputDataList[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: set.weightController,
              builder: (_, weightValue, __) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: set.repController,
                  builder: (_, repValue, __) {
                    final weightText = weightValue.text.trim();
                    final repsText = repValue.text.trim();
                    final baseStyle = TextStyle(
                      fontFamily: kUiFont,
                      color: set.isSuggestion
                          ? cs.onSurfaceVariant.withOpacity(0.55)
                          : cs.onSurface,
                      fontSize: 13.0,
                    );
                    final display = formatStrengthSetDisplay(
                      l10n: l10n,
                      weight: weightText,
                      unit: unit,
                      reps: repsText,
                    );
                    return Row(
                      children: [
                        Text(
                          '${index + 1}${l10n.sets}：',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            display,
                            style: baseStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        }),
      );
    }

    Widget buildAerobicRows() {
      final distance = distanceController;
      final duration = durationController;
      final calorie = calorieController;
      final bool useImperial = !SettingsManager.isMetric;
      final unitPrimary = useImperial ? 'mi' : l10n.km;
      final unitSecondary = useImperial ? 'yd' : l10n.m;

      Widget valueRow(String label, List<Widget> children) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(color: cs.onSurface, fontSize: 13.0),
              ),
              const SizedBox(width: 6),
              Expanded(child: Row(children: children)),
            ],
          ),
        );
      }

      Widget distanceRow() {
        if (distance == null) {
          return valueRow(l10n.distance,
              [Text('-', style: TextStyle(color: cs.onSurfaceVariant))]);
        }
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: distance,
          builder: (_, value, __) {
            final text = value.text.trim();
            if (text.isEmpty) {
              return valueRow(l10n.distance,
                  [Text('-', style: TextStyle(color: cs.onSurfaceVariant))]);
            }
            final double? distKm = double.tryParse(text);
            if (distKm == null) {
              return valueRow(l10n.distance, [
                Text(text,
                    style: TextStyle(fontFamily: kUiFont, color: cs.onSurface))
              ]);
            }
            if (useImperial) {
              final miles = distKm / 1.609344;
              final totalYd = miles * 1760.0;
              final mi = totalYd ~/ 1760;
              final yd = (totalYd - mi * 1760).round();
              final valueStyle = TextStyle(
                  fontFamily: kUiFont, color: cs.onSurface, fontSize: 13.0);
              return valueRow(l10n.distance, [
                Text('$mi $unitPrimary', style: valueStyle),
                const SizedBox(width: 8),
                Text('$yd $unitSecondary', style: valueStyle),
              ]);
            }
            final km = distKm.truncate();
            final meters = ((distKm - km) * 1000).round();
            final valueStyle = TextStyle(
                fontFamily: kUiFont, color: cs.onSurface, fontSize: 13.0);
            return valueRow(l10n.distance, [
              Text('$km $unitPrimary', style: valueStyle),
              const SizedBox(width: 8),
              Text('$meters $unitSecondary', style: valueStyle),
            ]);
          },
        );
      }

      Widget durationRow() {
        if (duration == null) {
          return valueRow(l10n.time,
              [Text('-', style: TextStyle(color: cs.onSurfaceVariant))]);
        }
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: duration,
          builder: (_, value, __) {
            final raw = value.text.trim();
            if (raw.isEmpty) {
              return valueRow(l10n.time,
                  [Text('-', style: TextStyle(color: cs.onSurfaceVariant))]);
            }
            final parts = raw.split(':');
            String hour = '0';
            String minute = '0';
            String second = '0';
            if (parts.length >= 3) {
              hour = parts[0];
              minute = parts[1];
              second = parts[2];
            } else if (parts.length == 2) {
              hour = parts[0];
              minute = parts[1];
            } else if (parts.isNotEmpty) {
              minute = parts[0];
            }
            final valueStyle = TextStyle(
                fontFamily: kUiFont, color: cs.onSurface, fontSize: 13.0);
            return valueRow(l10n.time, [
              Text('$hour ${l10n.hour}', style: valueStyle),
              const SizedBox(width: 8),
              Text('$minute ${l10n.min}', style: valueStyle),
              const SizedBox(width: 8),
              Text('$second ${l10n.sec}', style: valueStyle),
            ]);
          },
        );
      }

      Widget calorieRow() {
        if (!showCalorieField || calorie == null) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: calorie,
          builder: (_, value, __) {
            final text = value.text.trim();
            final display = text.isEmpty ? '-' : text;
            return valueRow(
              l10n.calorie,
              [
                Text(
                  '$display ${l10n.kcalUnit}',
                  style: TextStyle(
                      fontFamily: kUiFont, color: cs.onSurface, fontSize: 13.0),
                ),
              ],
            );
          },
        );
      }

      final children = <Widget>[
        distanceRow(),
        durationRow(),
      ];
      if (showCalorieField && calorie != null) {
        children.add(calorieRow());
      }
      if (showAerobicFailureHint) {
        children.add(
          Container(
            margin: const EdgeInsets.only(top: 8.0, right: 36.0, left: 8.0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aerobicCalorieUnknownHint,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Column(children: children);
    }

    Widget buildVolumeRow() {
      if (isAerobic) {
        return const SizedBox.shrink();
      }

      Widget buildContent(double? current) {
        final labelStyle = TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13.0,
        );
        final valueStyle = TextStyle(
          fontFamily: kUiFont,
          color: cs.onSurface,
          fontSize: 13.0,
        );
        final double? prevVolume = previousVolume;
        final double? diffVolume = (current != null && prevVolume != null)
            ? current - prevVolume
            : null;
        final String currentText =
            formatTotalVolumeValue(l10n, current, withSign: false);
        final String previousText =
            formatTotalVolumeValue(l10n, prevVolume, withSign: false);
        final String diffText =
            formatTotalVolumeValue(l10n, diffVolume, withSign: true);

        Widget volumeText(String label, String value) {
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label：', style: labelStyle),
                const TextSpan(text: ' '),
                TextSpan(text: value, style: valueStyle),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.totalVolume}：', style: labelStyle),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    volumeText(l10n.totalVolumeCurrent, currentText),
                    volumeText(l10n.totalVolumePrevious, previousText),
                    volumeText(l10n.totalVolumeDifference, diffText),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final listenables = <Listenable>[
        for (final set in setInputDataList) ...[
          set.weightController,
          set.repController,
        ],
      ];
      if (listenables.isEmpty) {
        return buildContent(null);
      }
      return AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (_, __) =>
            buildContent(calculateTotalVolume(setInputDataList)),
      );
    }

    Widget buildCollapsedVolumeRow() {
      if (isAerobic || !SettingsManager.showTotalVolume) {
        return const SizedBox.shrink();
      }

      Widget buildContent(double? current) {
        final labelStyle = TextStyle(
          fontFamily: kUiFont,
          color: cs.onSurfaceVariant.withOpacity(0.8),
          fontSize: 12.0,
        );
        final value = formatTotalVolumeValue(l10n, current, withSign: false);
        return Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0),
          child: Row(
            children: [
              Icon(Icons.fitness_center,
                  size: 14, color: cs.onSurfaceVariant.withOpacity(0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l10n.totalVolumeCurrent}：$value',
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }

      final listenables = <Listenable>[
        for (final set in setInputDataList) ...[
          set.weightController,
          set.repController,
        ],
      ];
      if (listenables.isEmpty) {
        return buildContent(null);
      }
      return AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (_, __) =>
            buildContent(calculateTotalVolume(setInputDataList)),
      );
    }

    Widget buildCollapsedSatisfactionRow() {
      if (!SettingsManager.showSatisfaction) {
        return const SizedBox.shrink();
      }
      final int? value = satisfaction;
      if (value == null) {
        return const SizedBox.shrink();
      }

      IconData icon;
      String label;
      switch (value) {
        case 0:
          icon = Icons.sentiment_very_dissatisfied;
          label = l10n.satisfactionBad;
          break;
        case 1:
          icon = Icons.sentiment_neutral;
          label = l10n.satisfactionOkay;
          break;
        case 2:
        default:
          icon = Icons.sentiment_very_satisfied;
          label = l10n.satisfactionGood;
          break;
      }

      final cs = Theme.of(context).colorScheme;

      return Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 2.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              '${l10n.satisfaction}：',
              style: TextStyle(
                fontFamily: kUiFont,
                color: cs.onSurfaceVariant,
                fontSize: 12.0,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: kUiFont,
                color: cs.onSurface,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildSatisfactionRow() {
      final labels = [
        Icons.sentiment_very_dissatisfied,
        Icons.sentiment_neutral,
        Icons.sentiment_very_satisfied,
      ];
      return Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 2.0),
        child: Row(
          children: [
            Text(
              '${l10n.satisfaction}：',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.0),
            ),
            const SizedBox(width: 8),
            ...List.generate(labels.length, (index) {
              final selected = satisfaction == index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? cs.primary : cs.surfaceContainer,
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : cs.onSurfaceVariant.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    labels[index],
                    size: 22,
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }

    Widget buildBody() {
      final bool showVolume = !isAerobic && SettingsManager.showTotalVolume;
      final bool showSatisfaction = SettingsManager.showSatisfaction;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (isAerobic) buildAerobicRows() else buildSetRows(),
          if (showVolume) ...[
            const SizedBox(height: 8),
            buildVolumeRow(),
          ],
          if (showSatisfaction) ...[
            const SizedBox(height: 12),
            buildSatisfactionRow(),
          ],
          const SizedBox(height: 36),
        ],
      );
    }

    final String toggleTooltip =
        isCollapsed ? l10n.expandCard : l10n.collapseCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: buildMenuName()),
            IconButton(
              onPressed: () {
                onPrepareAction();
                onToggleCollapse();
              },
              tooltip: toggleTooltip,
              icon: Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 22),
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
            ),
            IconButton(
              onPressed: () async {
                onPrepareAction();
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.deleteMenuConfirmationTitle),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.no),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.yes),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  onRemoveMenu();
                }
              },
              tooltip: l10n.deleteMenuConfirmationTitle,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: isCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: buildBody(),
        ),
      ],
    );
  }
}

class MenuList extends StatefulWidget {
  final GlobalKey nameFieldKey;
  final TextEditingController menuController;
  final VoidCallback removeMenuCallback;
  final List<SetInputData> setInputDataList;
  final bool isAerobic;
  final TextEditingController distanceController;
  final TextEditingController durationController;
  final bool aerobicIsSuggestion;
  final TextEditingController? calorieController;
  final bool showCalorieField;
  final bool calorieIsSuggestion;
  final bool showAerobicFailureHint;
  final VoidCallback? onConfirmAerobic;
  final VoidCallback? onAnyFieldFocused;
  final VoidCallback? onMenuNameTap;
  final void Function(bool prevEmpty, bool nowEmpty)? onNameChanged;
  final VoidCallback? onAerobicFieldChanged;
  final ValueChanged<String>? onCalorieChanged;
  final VoidCallback? onAerobicFailureHintTap;

  final int? satisfaction;
  final ValueChanged<int?>? onSatisfactionChanged;
  final double? previousTotalVolume;
  final bool enabledForInput;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final bool forceExpanded;
  final VoidCallback? onPrepareAction;

  const MenuList({
    required this.timerKey,
    super.key,
    required this.nameFieldKey,
    required this.menuController,
    required this.removeMenuCallback,
    required this.setInputDataList,
    required this.isAerobic,
    required this.distanceController,
    required this.durationController,
    this.aerobicIsSuggestion = false,
    this.calorieController,
    this.showCalorieField = false,
    this.calorieIsSuggestion = false,
    this.showAerobicFailureHint = false,
    this.onConfirmAerobic,
    this.onAnyFieldFocused,
    this.onMenuNameTap,
    this.onNameChanged,
    this.onAerobicFieldChanged,
    this.onCalorieChanged,
    this.onAerobicFailureHintTap,
    this.satisfaction,
    this.onSatisfactionChanged,
    this.previousTotalVolume,
    this.enabledForInput = true,
    this.isCollapsed = true,
    required this.onToggleCollapse,
    this.forceExpanded = false,
    this.onPrepareAction,
  });

  final GlobalKey<ExerciseInputTimerState> timerKey;

  @override
  State<MenuList> createState() => _MenuListState();
}

class _CustomExerciseDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final MaterialLocalizations material;

  const _CustomExerciseDialog({
    required this.l10n,
    required this.material,
  });

  @override
  State<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends State<_CustomExerciseDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.customExerciseDialogTitle),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          autofocus: true,
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          decoration:
              InputDecoration(hintText: widget.l10n.customExerciseNameHint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(widget.material.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.material.okButtonLabel),
        ),
      ],
    );
  }
}

class _MenuListState extends State<MenuList> {
  // 既存
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _mController = TextEditingController();
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minAeroCtrl = TextEditingController();
  final TextEditingController _secAeroCtrl = TextEditingController();

  static final List<int> _repPickerValues = [
    for (int i = 1; i <= 999; i++) i,
  ];

  static final List<int> _weightIntegerValues = [
    for (int i = 0; i <= 999; i++) i,
  ];

  static final List<double> _weightFractionValues = <double>[
    0.0,
    0.25,
    0.5,
    0.75
  ];

  String _formatNumber(double value, {int fractionDigits = 2}) {
    final String fixed = value.toStringAsFixed(fractionDigits);
    if (!fixed.contains('.')) {
      return fixed;
    }
    String trimmed = fixed.replaceAll(RegExp(r'0+$'), '');
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  bool _prevNameEmpty = true; // ← これを追加

  // ★追加：単位変更のローカルハンドラ
  void _onLengthUnitChangedLocal() {
    if (!mounted) return;
    // 距離の km<->mi, m<->yd 表示を即座に再パース反映
    setState(_parseDurationAndDistance);
  }

  void _onLengthUnitChanged() {
    if (!mounted) return;
    // 保存側（widget.distanceController.text）は常に km の小数なので、
    // 単位が切り替わったら表示用のフィールドを作り直すだけでよい。
    setState(() {
      _parseDurationAndDistance(); // km⇄mi, m⇄yd の表示を再計算
    });
  }

  @override
  void initState() {
    super.initState();
    _parseDurationAndDistance();
    _kmController.addListener(_updateDistanceController);
    _mController.addListener(_updateDistanceController);
    _hourController.addListener(_updateDurationController);
    _minAeroCtrl.addListener(_updateDurationController);
    _secAeroCtrl.addListener(_updateDurationController);

    // メニュー名の空/非空トラッキング
    _prevNameEmpty = widget.menuController.text.trim().isEmpty;
    widget.menuController.addListener(_handleNameChanged);

    // 単位切り替えに追従（mi/yd ⇄ km/m）
    SettingsManager.lengthUnitNotifier.addListener(_onLengthUnitChanged);
  }

  @override
  void dispose() {
    _kmController.dispose();
    _mController.dispose();
    _hourController.dispose();
    _minAeroCtrl.dispose();
    _secAeroCtrl.dispose();

    // リスナー解除を忘れずに
    widget.menuController.removeListener(_handleNameChanged);
    SettingsManager.lengthUnitNotifier.removeListener(_onLengthUnitChanged);

    super.dispose();
  }

  void _handleNameChanged() {
    final nowEmpty = widget.menuController.text.trim().isEmpty;
    if (nowEmpty != _prevNameEmpty) {
      widget.onNameChanged?.call(_prevNameEmpty, nowEmpty);
      setState(() {}); // 見た目更新（セット入力の活性/不活性など）
      _prevNameEmpty = nowEmpty;
    }
  }

  void _parseDurationAndDistance() {
    // 時間
    final t = widget.durationController.text.split(':');
    if (t.length >= 3) {
      _hourController.text = t[0];
      _minAeroCtrl.text = t[1];
      _secAeroCtrl.text = t[2];
    } else if (t.length == 2) {
      _hourController.text = t[0];
      _minAeroCtrl.text = t[1];
      _secAeroCtrl.text = '';
    } else {
      _hourController.text = '';
      _minAeroCtrl.text = widget.durationController.text;
      _secAeroCtrl.text = '';
    }

    // 距離（保存は km、小数）
    final raw = widget.distanceController.text.trim();
    if (raw.isEmpty) {
      _kmController.text = '';
      _mController.text = '';
      return;
    }
    final dKm = double.tryParse(raw) ?? 0.0;
    final useImperial = !SettingsManager.isMetric;
    if (useImperial) {
      // km → mi & yd
      final miles = dKm / 1.609344;
      final totalYd = miles * 1760.0;
      final mi = totalYd ~/ 1760;
      final yd = (totalYd - mi * 1760).round();
      _kmController.text = mi.toString();
      _mController.text = yd.toString();
    } else {
      // km → km & m
      final kmInt = dKm.floor();
      final mInt = ((dKm - kmInt) * 1000).round();
      _kmController.text = kmInt.toString();
      _mController.text = mInt.toString();
    }
  }

  void _updateDurationController() {
    final hourText = _hourController.text.trim();
    final minuteText = _minAeroCtrl.text.trim();
    final secondText = _secAeroCtrl.text.trim();
    if (hourText.isEmpty && minuteText.isEmpty && secondText.isEmpty) {
      widget.durationController.text = '';
    } else {
      final hh = hourText.isEmpty ? '0' : hourText;
      final mmRaw = minuteText.isEmpty ? '0' : minuteText;
      final mm = mmRaw.padLeft(2, '0');
      final ssRaw = secondText.isEmpty ? '0' : secondText;
      final ss = ssRaw.padLeft(2, '0');
      widget.durationController.text = '$hh:$mm:$ss';
    }
    widget.onAerobicFieldChanged?.call();
  }

  void _updateDistanceController() {
    final majorRaw = _kmController.text.trim();
    final minorRaw = _mController.text.trim();
    if (majorRaw.isEmpty && minorRaw.isEmpty) {
      widget.distanceController.text = '';
      widget.onAerobicFieldChanged?.call();
      return;
    }
    final major = int.tryParse(majorRaw) ?? 0;
    final minor = int.tryParse(minorRaw) ?? 0;
    final useImperial = !SettingsManager.isMetric;
    double dKm;
    if (useImperial) {
      // mi & yd → km（保存は km）
      final yd = minor.clamp(0, 1760);
      final miles = major.toDouble() + (yd / 1760.0);
      dKm = miles * 1.609344;
    } else {
      // km & m → km
      final m = minor.clamp(0, 999);
      dKm = major.toDouble() + (m / 1000.0);
    }

    // 小数で km を保存（グラフ互換）
    widget.distanceController.text = dKm.toStringAsFixed(3);
    widget.onAerobicFieldChanged?.call();
  }

  Future<void> _openWeightPicker(SetInputData set) async {
    FocusScope.of(context).unfocus();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);

    double currentValue =
        double.tryParse(set.weightController.text.trim()) ?? 0.0;
    if (currentValue < 0) {
      currentValue = 0.0;
    }
    if (currentValue > 999.75) {
      currentValue = 999.75;
    }

    int initialInt = currentValue.floor().clamp(0, 999);
    double fractionPart = (currentValue - initialInt).clamp(0.0, 1.0);
    int initialFraction = 0;
    double fractionDiff = double.infinity;
    for (int i = 0; i < _weightFractionValues.length; i++) {
      final diff = (fractionPart - _weightFractionValues[i]).abs();
      if (diff < fractionDiff) {
        fractionDiff = diff;
        initialFraction = i;
      }
    }

    int tempInt = initialInt;
    int tempFraction = initialFraction;

    final integerController =
        FixedExtentScrollController(initialItem: initialInt);
    final fractionController =
        FixedExtentScrollController(initialItem: initialFraction);

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final unitLabel =
            SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        '${l10n.weightUnit} ($unitLabel)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(material.cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, <int>[tempInt, tempFraction]),
                        child: Text(material.okButtonLabel),
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
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: integerController,
                          onSelectedItemChanged: (i) => tempInt = i,
                          children: [
                            for (final value in _weightIntegerValues)
                              Center(
                                child: Text(
                                  value.toString(),
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        color: cs.onSurfaceVariant.withOpacity(0.12),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: fractionController,
                          onSelectedItemChanged: (i) => tempFraction = i,
                          children: [
                            for (final fractionValue in _weightFractionValues)
                              Center(
                                child: Text(
                                  fractionValue == 0
                                      ? '.00'
                                      : fractionValue
                                          .toStringAsFixed(2)
                                          .substring(1),
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
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

    if (!mounted || result == null) {
      return;
    }

    final int selectedInt = result[0].clamp(0, 999).toInt();
    final int fractionIndex =
        result[1].clamp(0, _weightFractionValues.length - 1).toInt();
    final double combined = selectedInt + _weightFractionValues[fractionIndex];
    final String formatted = _formatNumber(combined);
    if (set.weightController.text.trim() == formatted) {
      return;
    }

    setState(() {
      set.weightController.text = formatted;
      set.isSuggestion = false;
    });
  }

  Future<void> _openRepsPicker(SetInputData set) async {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);

    int initialIndex = 0;
    final currentText = set.repController.text.trim();
    if (currentText.isNotEmpty) {
      final currentValue = int.tryParse(currentText);
      if (currentValue != null) {
        initialIndex = currentValue.clamp(1, 999).toInt() - 1;
      }
    }
    int tempIndex = initialIndex;

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        l10n.reps,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(material.cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, tempIndex),
                        child: Text(material.okButtonLabel),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    useMagnifier: true,
                    magnification: 1.08,
                    scrollController: FixedExtentScrollController(
                      initialItem: initialIndex,
                    ),
                    onSelectedItemChanged: (i) => tempIndex = i,
                    children: [
                      for (final value in _repPickerValues)
                        Center(
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                              fontFamily: kUiFont,
                              color: cs.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
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

    if (!mounted || selected == null) {
      return;
    }

    final String formatted = _repPickerValues[selected].toString();
    if (set.repController.text.trim() == formatted) {
      return;
    }

    setState(() {
      set.repController.text = formatted;
      set.isSuggestion = false;
    });
  }

  Future<void> _openDistancePicker() async {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final bool useImperial = !SettingsManager.isMetric;

    final int maxMajor = 999;
    final int maxMinor = useImperial ? 1759 : 999;

    final parsedMajor = int.tryParse(_kmController.text.trim()) ?? 0;
    final parsedMinor = int.tryParse(_mController.text.trim()) ?? 0;
    int major = parsedMajor.clamp(0, maxMajor).toInt();
    int minor = parsedMinor.clamp(0, maxMinor).toInt();
    int tempMajor = major;
    int tempMinor = minor;

    final majorController = FixedExtentScrollController(initialItem: major);
    final minorController = FixedExtentScrollController(initialItem: minor);

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final unitPrimary = useImperial ? 'mi' : l10n.km;
        final unitSecondary = useImperial ? 'yd' : l10n.m;
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        l10n.distance,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(material.cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, <int>[tempMajor, tempMinor]),
                        child: Text(material.okButtonLabel),
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
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: majorController,
                          onSelectedItemChanged: (i) => tempMajor = i,
                          children: [
                            for (int i = 0; i <= maxMajor; i++)
                              Center(
                                child: Text(
                                  '$i $unitPrimary',
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        color: cs.onSurfaceVariant.withOpacity(0.12),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: minorController,
                          onSelectedItemChanged: (i) => tempMinor = i,
                          children: [
                            for (int i = 0; i <= maxMinor; i++)
                              Center(
                                child: Text(
                                  '$i $unitSecondary',
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
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

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _kmController.text = result[0].toString();
      _mController.text = result[1].toString();
      widget.onConfirmAerobic?.call();
    });
  }

  Future<void> _openDurationPicker() async {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);

    int hour = int.tryParse(_hourController.text.trim()) ?? 0;
    hour = hour.clamp(0, 999).toInt();
    int minute = int.tryParse(_minAeroCtrl.text.trim()) ?? 0;
    minute = minute.clamp(0, 59).toInt();
    int second = int.tryParse(_secAeroCtrl.text.trim()) ?? 0;
    second = second.clamp(0, 59).toInt();
    int tempHour = hour;
    int tempMinute = minute;
    int tempSecond = second;

    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final secondController = FixedExtentScrollController(initialItem: second);

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        l10n.time,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(material.cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(
                          ctx,
                          <int>[tempHour, tempMinute, tempSecond],
                        ),
                        child: Text(material.okButtonLabel),
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
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: hourController,
                          onSelectedItemChanged: (i) => tempHour = i,
                          children: [
                            for (int i = 0; i <= 999; i++)
                              Center(
                                child: Text(
                                  '$i ${l10n.hour}',
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        color: cs.onSurfaceVariant.withOpacity(0.12),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: minuteController,
                          onSelectedItemChanged: (i) => tempMinute = i,
                          children: [
                            for (int i = 0; i < 60; i++)
                              Center(
                                child: Text(
                                  '${i.toString().padLeft(2, '0')} ${l10n.min}',
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        color: cs.onSurfaceVariant.withOpacity(0.12),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 36,
                          useMagnifier: true,
                          magnification: 1.08,
                          scrollController: secondController,
                          onSelectedItemChanged: (i) => tempSecond = i,
                          children: [
                            for (int i = 0; i < 60; i++)
                              Center(
                                child: Text(
                                  '${i.toString().padLeft(2, '0')} ${l10n.sec}',
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
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

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _hourController.text = result[0].toString();
      _minAeroCtrl.text = result[1].toString().padLeft(2, '0');
      _secAeroCtrl.text = result[2].toString().padLeft(2, '0');
      widget.onConfirmAerobic?.call();
    });
  }

  // ← picker helpersの終わり（build() の前）

  Widget _buildFaceButton({
    required int value,
    required IconData icon,
    required String tooltip,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bool selected = widget.satisfaction == value;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(), // タップ範囲は確保
        onTap: () {
          final newVal = selected ? null : value; // 再タップで解除
          widget.onSatisfactionChanged?.call(newVal);
        },
        child: Padding(
          padding: const EdgeInsets.all(6), // 見た目は小さく/ヒットエリアは広く
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 28, // ★背景を小さく（42→28等）
            height: 28, // ★背景を小さく（36→28等）
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? cs.primary : cs.surfaceContainer,
              border: Border.all(
                color: selected
                    ? cs.primary
                    : cs.onSurfaceVariant.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 25, // ★絵文字サイズはそのまま
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAerobicFailureHint(VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const ValueKey('aerobic-failure-hint'),
        margin: const EdgeInsets.only(top: 8.0, right: 36.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(14.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.aerobicCalorieUnknownHint,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalVolumeRow(bool nameFilled) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    Widget content(double? current) {
      final labelStyle = TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 13.0,
      );
      final valueStyle = TextStyle(
        fontFamily: kUiFont,
        color: cs.onSurface,
        fontSize: 13.0,
      );
      final double? prevVolume = widget.previousTotalVolume;
      final double? diffVolume =
          (current != null && prevVolume != null) ? current - prevVolume : null;
      final String currentText =
          formatTotalVolumeValue(l10n, current, withSign: false);
      final String previousText =
          formatTotalVolumeValue(l10n, prevVolume, withSign: false);
      final String diffText =
          formatTotalVolumeValue(l10n, diffVolume, withSign: true);

      Widget volumeText(String label, String value) {
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label：', style: labelStyle),
              const TextSpan(text: ' '),
              TextSpan(text: value, style: valueStyle),
            ],
          ),
        );
      }

      return Opacity(
        opacity: nameFilled ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.totalVolume}：', style: labelStyle),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    volumeText(l10n.totalVolumeCurrent, currentText),
                    volumeText(l10n.totalVolumePrevious, previousText),
                    volumeText(l10n.totalVolumeDifference, diffText),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final listenables = <Listenable>[
      for (final set in widget.setInputDataList) ...[
        set.weightController,
        set.repController,
      ],
    ];
    if (listenables.isEmpty) {
      return content(null);
    }
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (_, __) =>
          content(calculateTotalVolume(widget.setInputDataList)),
    );
  }

  Widget _buildSatisfactionControlRow(
      AppLocalizations l10n, ColorScheme colorScheme, bool nameFilled) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 2.0),
      child: Opacity(
        opacity: nameFilled ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !nameFilled,
          child: Row(
            children: [
              Text(
                '${l10n.satisfaction}：',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildFaceButton(
                value: 0,
                icon: Icons.sentiment_very_dissatisfied,
                tooltip: l10n.satisfactionBad,
              ),
              const SizedBox(width: 8),
              _buildFaceButton(
                value: 1,
                icon: Icons.sentiment_neutral,
                tooltip: l10n.satisfactionOkay,
              ),
              const SizedBox(width: 8),
              _buildFaceButton(
                value: 2,
                icon: Icons.sentiment_very_satisfied,
                tooltip: l10n.satisfactionGood,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthSetRows(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    String currentUnit,
    void Function(bool) notifyFocus,
  ) {
    return Column(
      children: List.generate(
        min(10, widget.setInputDataList.length),
        (setIndex) {
          final set = widget.setInputDataList[setIndex];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Text(
                  '${setIndex + 1}${l10n.sets}：',
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 13.0),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Focus(
                    onFocusChange: notifyFocus,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: kUnifiedFieldMinHeight),
                      child: TextField(
                        controller: set.weightController,
                        readOnly: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: kUiFont,
                          color: set.checked
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        onTap: () async {
                          notifyFocus(true);
                          await _openWeightPicker(set);
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.4),
                                width: 1),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 0),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  ' ${currentUnit == "kg" ? l10n.kg : l10n.lbs} ',
                  style: TextStyle(
                    fontFamily: kUiFont,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Focus(
                    onFocusChange: notifyFocus,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: kUnifiedFieldMinHeight),
                      child: TextField(
                        controller: set.repController,
                        readOnly: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: kUiFont,
                          color: set.checked
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        onTap: () async {
                          notifyFocus(true);
                          await _openRepsPicker(set);
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color:
                                  colorScheme.onSurfaceVariant.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 0),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(' ${l10n.reps}'),
                const SizedBox(width: 6),
                SizedBox(
                  height: kUnifiedFieldMinHeight,
                  child: Checkbox(
                    value: set.checked,
                    onChanged: (set.weightController.text.trim().isNotEmpty ||
                            set.repController.text.trim().isNotEmpty)
                        ? (v) {
                            setState(() {
                              final bool nextChecked = v ?? false;
                              set.checked = nextChecked;
                              set.isSuggestion = !nextChecked;
                            });
                            if ((v ?? false) == true) {
                              widget.timerKey.currentState?.restart();
                            }
                          }
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final String currentUnit = SettingsManager.currentUnit;
    final bool isAerobic = widget.isAerobic;
    final bool useImperialLength = !SettingsManager.isMetric;

    void notifyFocus(bool has) {
      if (has) {
        widget.onAnyFieldFocused?.call();
      }
    }

    final bool nameFilled = widget.menuController.text.trim().isNotEmpty;

    final TextStyle aerobicLabelStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 13.0,
    );
    final TextStyle aerobicUnitEmphasisStyle = TextStyle(
      fontFamily: kUiFont,
      color: colorScheme.onSurfaceVariant,
      fontSize: 13.0,
      fontWeight: FontWeight.w700,
    );
    final TextStyle aerobicUnitStyle = TextStyle(
      fontFamily: kUiFont,
      color: colorScheme.onSurfaceVariant,
      fontSize: 13.0,
    );

    final bool collapsed = widget.isCollapsed && !widget.forceExpanded;

    final headerRow = KeyedSubtree(
      key: widget.nameFieldKey,
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onFocusChange: notifyFocus,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: kUnifiedFieldMinHeight),
                  child: TextField(
                    controller: widget.menuController,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(40),
                    ],
                    readOnly: true,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: kUiFont,
                      color: colorScheme.onSurface,
                    ),
                    onTap: () {
                      notifyFocus(true);
                      widget.onMenuNameTap?.call();
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.addExercisePlaceholder,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      filled: false,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!widget.forceExpanded)
            IconButton(
              onPressed: () {
                widget.onPrepareAction?.call();
                widget.onToggleCollapse();
              },
              tooltip: collapsed ? l10n.expandCard : l10n.collapseCard,
              icon: Icon(
                collapsed
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                size: 22,
              ),
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
            ),
          TextButton(
            onPressed: () async {
              widget.onPrepareAction?.call();
              final l10n = AppLocalizations.of(context)!;
              final bool? ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteMenuConfirmationTitle),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.no),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.yes),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                widget.removeMenuCallback();
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 20),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.center,
            ),
            child: Icon(
              Icons.close,
              color: colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: collapsed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headerRow],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerRow,
                const SizedBox(height: 2.0),
                IgnorePointer(
                  ignoring: !(widget.enabledForInput || widget.isAerobic),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: widget.isAerobic
                        ? Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Text(l10n.distance,
                                        style: aerobicLabelStyle),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has &&
                                              widget.aerobicIsSuggestion) {
                                            widget.onConfirmAerobic?.call();
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: _kmController,
                                            readOnly: true,
                                            showCursor: false,
                                            enableInteractiveSelection: false,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: widget.aerobicIsSuggestion
                                                  ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                                  : colorScheme.onSurface,
                                            ),
                                            onTap: () async {
                                              notifyFocus(true);
                                              await _openDistancePicker();
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: false,
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 0),
                                              hintText:
                                                  widget.aerobicIsSuggestion
                                                      ? '0'
                                                      : null,
                                              hintStyle: TextStyle(
                                                fontFamily: kUiFont,
                                                color: colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' ${useImperialLength ? 'mi' : l10n.km} ',
                                      style: aerobicUnitEmphasisStyle,
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has &&
                                              widget.aerobicIsSuggestion) {
                                            widget.onConfirmAerobic?.call();
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: _mController,
                                            readOnly: true,
                                            showCursor: false,
                                            enableInteractiveSelection: false,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: widget.aerobicIsSuggestion
                                                  ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                                  : colorScheme.onSurface,
                                            ),
                                            onTap: () async {
                                              notifyFocus(true);
                                              await _openDistancePicker();
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: false,
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 0),
                                              hintText:
                                                  widget.aerobicIsSuggestion
                                                      ? '0'
                                                      : null,
                                              hintStyle: TextStyle(
                                                fontFamily: kUiFont,
                                                color: colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' ${useImperialLength ? 'yd' : l10n.m} ',
                                      style: aerobicUnitStyle,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Text(l10n.time, style: aerobicLabelStyle),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has &&
                                              widget.aerobicIsSuggestion) {
                                            widget.onConfirmAerobic?.call();
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: _hourController,
                                            readOnly: true,
                                            showCursor: false,
                                            enableInteractiveSelection: false,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: widget.aerobicIsSuggestion
                                                  ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                                  : colorScheme.onSurface,
                                            ),
                                            onTap: () async {
                                              notifyFocus(true);
                                              await _openDurationPicker();
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: false,
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 0),
                                              hintText:
                                                  widget.aerobicIsSuggestion
                                                      ? '0'
                                                      : null,
                                              hintStyle: TextStyle(
                                                fontFamily: kUiFont,
                                                color: colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(' ${l10n.hour} ',
                                        style: aerobicUnitStyle),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has &&
                                              widget.aerobicIsSuggestion) {
                                            widget.onConfirmAerobic?.call();
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: _minAeroCtrl,
                                            readOnly: true,
                                            showCursor: false,
                                            enableInteractiveSelection: false,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: widget.aerobicIsSuggestion
                                                  ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                                  : colorScheme.onSurface,
                                            ),
                                            onTap: () async {
                                              notifyFocus(true);
                                              await _openDurationPicker();
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: false,
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 0),
                                              hintText:
                                                  widget.aerobicIsSuggestion
                                                      ? '0'
                                                      : null,
                                              hintStyle: TextStyle(
                                                fontFamily: kUiFont,
                                                color: colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(' ${l10n.min}',
                                        style: aerobicUnitStyle),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has &&
                                              widget.aerobicIsSuggestion) {
                                            widget.onConfirmAerobic?.call();
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: _secAeroCtrl,
                                            readOnly: true,
                                            showCursor: false,
                                            enableInteractiveSelection: false,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: widget.aerobicIsSuggestion
                                                  ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                                  : colorScheme.onSurface,
                                            ),
                                            onTap: () async {
                                              notifyFocus(true);
                                              await _openDurationPicker();
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: false,
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 0),
                                              hintText:
                                                  widget.aerobicIsSuggestion
                                                      ? '0'
                                                      : null,
                                              hintStyle: TextStyle(
                                                fontFamily: kUiFont,
                                                color: colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(' ${l10n.sec}',
                                        style: aerobicUnitStyle),
                                  ],
                                ),
                              ),
                              if (widget.showCalorieField &&
                                  widget.calorieController != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(l10n.calorie,
                                              style: aerobicLabelStyle),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Focus(
                                              onFocusChange: notifyFocus,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                    minHeight:
                                                        kUnifiedFieldMinHeight),
                                                child: TextField(
                                                  controller:
                                                      widget.calorieController,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .allow(
                                                            RegExp(r'[0-9\.]')),
                                                  ],
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontFamily: kUiFont,
                                                    color: (widget.calorieIsSuggestion &&
                                                            (widget.calorieController?.text.trim().isEmpty ?? true))
                                                        ? colorScheme.onSurfaceVariant
                                                            .withOpacity(0.5)
                                                        : colorScheme.onSurface,
                                                  ),
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    filled: false,
                                                    enabledBorder:
                                                        UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.4),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: colorScheme
                                                              .primary,
                                                          width: 2),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            vertical: 6,
                                                            horizontal: 0),
                                                  ),
                                                  onChanged:
                                                      widget.onCalorieChanged,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(' ${l10n.kcalUnit}',
                                              style: aerobicUnitEmphasisStyle),
                                        ],
                                      ),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        child: widget.showAerobicFailureHint
                                            ? _buildAerobicFailureHint(
                                                widget.onAerobicFailureHintTap)
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStrengthSetRows(
                                  l10n, colorScheme, currentUnit, notifyFocus),
                              if (SettingsManager.showTotalVolume) ...[
                                const SizedBox(height: 12),
                                _buildTotalVolumeRow(nameFilled),
                              ],
                              if (SettingsManager.showSatisfaction) ...[
                                const SizedBox(height: 12),
                                _buildSatisfactionControlRow(
                                    l10n, colorScheme, nameFilled),
                              ],
                              const SizedBox(height: 40),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ===== Photo preview =====
class _PhotoPreviewPage extends StatelessWidget {
  final String imagePath;

  const _PhotoPreviewPage({required this.imagePath});

  static const Color kBrandBlue = Color(0xFF2563EB);

  Future<void> _confirmDiscard(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardPhotoConfirmTitle),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.no)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.yes)),
        ],
      ),
    );
    if (ok == true) {
      Navigator.of(context).pop(_QuickReview.discard);
    }
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    final radius = BorderRadius.circular(22);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.white.withOpacity(0.06),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: filled ? kBrandBlue : Colors.transparent,
            borderRadius: radius,
            border: filled
                ? null
                : Border.all(color: Colors.white.withOpacity(0.35)),
            boxShadow: filled
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 2,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final file = File(imagePath);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: file.existsSync()
                    ? Image.file(file, fit: BoxFit.contain)
                    : Text(l10n.photoLoadFailed,
                        style: const TextStyle(color: Colors.white)),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottom,
              child: Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      label: l10n.discard,
                      onTap: () => _confirmDiscard(context),
                      filled: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pillButton(
                      label: l10n.save,
                      onTap: () => Navigator.of(context).pop(_QuickReview.save),
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Interval Timer Widget (top-level) ===
class ExerciseInputTimer extends StatefulWidget {
  const ExerciseInputTimer({super.key});
  @override
  ExerciseInputTimerState createState() => ExerciseInputTimerState();
}

class ExerciseInputTimerState extends State<ExerciseInputTimer> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  void restart() {
    _ticker?.cancel();
    setState(() {
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  void reset() {
    _ticker?.cancel();
    setState(() {
      _elapsed = Duration.zero;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(_elapsed),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
