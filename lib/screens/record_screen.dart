// lib/screens/record_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'dart:async';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import '../widgets/stopwatch_widget.dart';
import '../widgets/coach_bubble.dart';
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
      Theme.of(c).floatingActionButtonTheme.backgroundColor
          ?? Theme.of(c).colorScheme.primary;

  Color _fabFg(BuildContext c) =>
      Theme.of(c).floatingActionButtonTheme.foregroundColor
          ?? Theme.of(c).colorScheme.onPrimary;


  late final AnimationController _fabCtrl;

  // ===== メモ・オーバーレイ（フローティング） =====
  bool _memoOverlayVisible = false; // 表示中か
  bool _memoOverlayOpening = false; // キーボード待ち中か
  bool _memoSlideIn = false; // 上からのスライド演出
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

  // 共通の下線InputDecoration（見出しやメトリクスで使い回し）
  InputDecoration _underlineDec() {
    final cs = Theme.of(context).colorScheme;
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

  final TextEditingController _weightController = TextEditingController();

  // 体脂肪入力用
  final TextEditingController _bodyFatController = TextEditingController();
  // ウエスト入力用 ← 追加
  final TextEditingController _waistController = TextEditingController();

  // パーソナルカード表示フラグ（1枚だけ）
  bool _showPersonalCard = false;
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

    // ★追加：単位切替（inch/cm 等）のUI反映
    SettingsManager.lengthUnitNotifier.addListener(_onLengthUnitChanged);
    SettingsManager.aerobicCalorieNotifier
        .addListener(_onAerobicCalorieSettingChanged);
    SettingsManager.personalWeightNotifier
        .addListener(_onPersonalWeightSettingChanged);
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
      await CoachBubbleController.showSequence(
        context: context,
        anchors: [_kRecordPart],
        messages: [l10n.hintRecordSelectPart],
        semanticsPrefix: l10n.coachBubbleSemantic,
      );
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
    WidgetsBinding.instance.removeObserver(this);

    _inactivityTimer?.cancel();
    _capTimer?.cancel();
    _savedChipTimer?.cancel();
    _setCountSub?.cancel();
    _scrollDebounce?.cancel();

    _scrollCtrl.dispose();
    for (var section in _sections) {
      section.dispose();
    }
    _sections.clear();

    _weightController.removeListener(_handleWeightChanged);
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _memoController.dispose();
    _memoOverlayFocus.dispose();
    _menuOverlayFocus.dispose();

    // ★ 重要：リスナー解除は super.dispose() の前に
    SettingsManager.lengthUnitNotifier.removeListener(_onLengthUnitChanged);
    SettingsManager.aerobicCalorieNotifier
        .removeListener(_onAerobicCalorieSettingChanged);
    SettingsManager.personalWeightNotifier
        .removeListener(_onPersonalWeightSettingChanged);

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

        final List<String> names = [
          ...recList.map((m) => m.name),
          ...luList.where((m) => !recBy.containsKey(m.name)).map((m) => m.name),
        ];
        if (names.isEmpty) names.add('');

        final l10n = AppLocalizations.of(context)!;
        final isAerobic = current == l10n.aerobicExercise;

        for (final name in names) {
          final rec = recBy[name];
          final lu = luBy[name];

          section.menuControllers.add(TextEditingController(text: name));
          section.menuKeys.add(GlobalKey());
          section.nameFieldKeys.add(GlobalKey());
          // 満足度は MenuData から復元（記録優先、なければ LastUsed）
          section.satisfactionList.add(rec?.satisfaction ?? lu?.satisfaction);

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
              if (i < recLen) {
                w = rec!.weights[i];
                r = rec.reps[i];
                if (w.trim().isNotEmpty || r.trim().isNotEmpty) {
                  isSuggestion = false;
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
              ));
            }
            section.setInputDataList.add(row);
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

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              const SizedBox(height: 2),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.selectTrainingPart,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, parts[temp]),
                      child:
                          Text(MaterialLocalizations.of(context).okButtonLabel),
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
                      .map((p) => Center(
                            child: Text(
                              p,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
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
    if (translatedPart == l10n.fullBody) return '全身';
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
      case '全身':
        return l10n.fullBody;
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
    final l10n = AppLocalizations.of(context)!;

    _allBodyParts = [
      l10n.aerobicExercise,
      l10n.arm,
      l10n.chest,
      l10n.back,
      l10n.shoulder,
      l10n.leg,
      l10n.fullBody,
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

  void _loadInitialSections() {
    final dateKey = _getDateKey(widget.selectedDate);
    final record = widget.recordsBox.get(dateKey);

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
      _sections.add(SectionData.createEmpty(_currentSetCount,
          shouldPopulateDefaults: false));
      _currentSectionIndex = null;
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
          satisfactionList: [],
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
        section.satisfactionList.add(rec?.satisfaction ?? lu?.satisfaction);

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

            if (i < recLen) {
              w = rec!.weights[i];
              r = rec.reps[i];
              if (w.trim().isNotEmpty || r.trim().isNotEmpty) {
                isSuggestion = false;
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
            ));
          }
          section.setInputDataList.add(row);
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
_showPersonalCard =
    _weightController.text.trim().isNotEmpty ||
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
    section.satisfactionList.clear();
  }

  bool _saveAllSectionsData({bool showHint = true}) {
    final dateKey = _getDateKey(widget.selectedDate);
    final Map<String, List<MenuData>> allMenusForRecord = {};
    // 追加：満足度保存用（部位→{種目名: 値}）
    String? lastModifiedPart;
    bool hasAnyRecordData = false;
    final l10n = AppLocalizations.of(context)!;

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
            ));
            hasAnyRecordData = true;
            lastModifiedPart ??= originalPart;
          }
        } else {
          final weightsAll = <String>[];
          final repsAll = <String>[];
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final set = section.setInputDataList[i][s];
            weightsAll.add(set.weightController.text);
            repsAll.add(set.repController.text);
          }
          listForLastUsed.add(MenuData(
            name: name,
            weights: weightsAll,
            reps: repsAll,
            calories: null,
            satisfaction: sat,
          ));

          final weightsConfirmed = <String>[];
          final repsConfirmed = <String>[];
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final set = section.setInputDataList[i][s];
            final w = set.weightController.text;
            final r = set.repController.text;
            final hasValue = w.trim().isNotEmpty || r.trim().isNotEmpty;
            if (!set.isSuggestion && hasValue) {
              weightsConfirmed.add(w);
              repsConfirmed.add(r);
            }
          }
          if (weightsConfirmed.isNotEmpty || repsConfirmed.isNotEmpty) {
            listForRecord.add(MenuData(
              name: name,
              weights: weightsConfirmed,
              reps: repsConfirmed,
              calories: null,
              satisfaction: sat,
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
        bodyFatPercent: bodyFatVal, // 追加
        waistCm: waistVal, // 追加
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

  double _parseDurationMinutes(String text) {
    if (text.isEmpty) return 0;
    final parts = text.split(':');
    if (parts.length >= 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      return (hours * 60 + minutes).toDouble();
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
    final bool newSuggestion = trimmed.isEmpty;
    final bool oldSuggestion = section.aerobicCalorieSuggestFlags[menuIndex];
    if (oldSuggestion == newSuggestion && !newSuggestion) return;
    section.aerobicCalorieSuggestFlags[menuIndex] = newSuggestion;
    if (newSuggestion) {
      if (_updateCalorieSuggestion(sectionIndex, menuIndex)) {
        if (mounted) setState(() {});
      }
    } else {
      if (menuIndex < section.aerobicCalorieHintVisible.length) {
        section.aerobicCalorieHintVisible[menuIndex] = false;
      }
      if (mounted) setState(() {});
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
// 追加
      section.satisfactionList.add(null);

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
// 追加
      if (section.satisfactionList.length > menuIndex) {
        section.satisfactionList.removeAt(menuIndex);
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

  void _touchCard(int sectionIndex, int menuIndex) {
    setState(() {
      _currentSectionIndex = sectionIndex;
      _currentMenuIndex = menuIndex;
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
      setState(() => _bmiValue = null);
      return;
    }
    // lbs の場合は kg に変換
    final weightKg =
        (SettingsManager.currentUnit == 'lbs') ? (w * 0.45359237) : w;
    final hMeters = (_heightCm! / 100.0);
    final bmi = weightKg / (hMeters * hMeters);
    setState(() => _bmiValue = bmi);
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

    final double topGap = media.padding.top + kToolbarHeight + 8;
    final double overlayHeight = media.size.height * 0.4;

    // ラベル右側の入力域で「下線 2/3」を実現する版
    Widget underlineField({
      required TextEditingController controller,
      required List<TextInputFormatter> formatters,
      required TextInputType keyboardType,
      String? unitSuffix,
      VoidCallback? onChanged,
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

          return Row(
            children: [
              SizedBox(
                width: fieldW,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: kUnifiedFieldMinHeight),
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: formatters,
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
                    onChanged: (_) => onChanged?.call(),
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

    final decimalFmt = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
    ];

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
                                label: Text(l10n.save),
                                style: TextButton.styleFrom(
                                    foregroundColor: cs.primary),
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
                                          formatters: decimalFmt,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          unitSuffix:
                                              SettingsManager.currentUnit,
                                          onChanged: _updateBmiDisplay,
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
                                            formatters: decimalFmt,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            unitSuffix: l10n.percentSymbol,
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
                                            formatters: decimalFmt,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            unitSuffix:
                                                SettingsManager.isWaistInch
                                                    ? l10n.unitIn
                                                    : l10n.unitCm,
                                          ),
                                        ),
                                      ],
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

  // ===== 記入オーバーレイ（画面内フローティングシート：上からスッ） =====
  Widget _buildMemoEditorOverlay() {
    if (!_memoOverlayVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // AppBar 直下に固定
    final double topGap = media.padding.top + kToolbarHeight + 8;
    // 高さは 0.4（ユーザー指定）
    final double overlayHeight = media.size.height * 0.4;

    return Stack(
      children: [
        // 半透明スクリーン（タップで保存して閉じる）
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
          top: topGap,
          height: overlayHeight,
          child: AnimatedSlide(
            duration: _overlaySlideDuration,
            curve: _overlayInCurve,
            offset: _memoSlideIn ? Offset.zero : const Offset(0, -0.08),
            // 上からシュッ
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
                // ▼ フォーム全体をふわっと（フェード＋わずかにスケール）
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
                        // ヘッダー（右上は「保存」）
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
                                label: Text(l10n.save),
                                style: TextButton.styleFrom(
                                    foregroundColor: cs.primary),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 本文（固定領域内で伸縮）
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: TextField(
                              focusNode: _memoOverlayFocus,
                              controller: _memoController,
                              autofocus: true,
                              keyboardType: TextInputType.multiline,
                              maxLength: 400,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(400)
                              ],
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              style: TextStyle(color: cs.onSurface),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l10n.memoBodyPlaceholder,
                                hintStyle: TextStyle(
                                  color: cs.onSurfaceVariant.withOpacity(0.6),
                                ),
                                border: InputBorder.none,
                                counterStyle: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 2),
                              ),
                              onChanged: (_) {
                                if (_fabOpen) setState(() => _fabOpen = false);
                              },
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

    final double topGap = media.padding.top + kToolbarHeight + 8;
    final double overlayHeight = media.size.height * 0.4; // メモと同じ高さ

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
          height: overlayHeight,
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
                              TextButton(
                                onPressed: (!isAerobic &&
                                        menuIndex <
                                            section.setInputDataList.length &&
                                        section.setInputDataList[menuIndex]
                                                .length <
                                            10)
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        _addOneSetAt(secIndex, menuIndex);
                                      }
                                    : null,
                                child: Text(l10n.addSet),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _saveMenuAndClose,
                                icon: const Icon(Icons.check_rounded),
                                label: Text(l10n.save),
                                style: TextButton.styleFrom(
                                    foregroundColor: cs.primary),
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
                                    showAerobicFailureHint: (menuIndex <
                                            section.aerobicCalorieHintVisible
                                                .length)
                                        ? section.aerobicCalorieHintVisible[
                                            menuIndex]
                                        : false,
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
                                    enabledForInput: true,
                                  ),
                                ),
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

    
    // 設定：パーソナル機能が全OFFなら＋パーソナルを非表示
    final bool canShowPersonalButton = SettingsManager.showWeightInput || showBodyFat || showWaist || showBMI;
final bool inputOverlayActive =
        _memoOverlayVisible || _menuOverlayVisible || _personalOverlayVisible;
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
                              borderRadius: BorderRadius.circular(16.0)),
                          elevation: 1.0,
                          child: Stack(
                            children: [
                              // ↓ 先に中身（白いカードなど）
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 見出し（下線）
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 6.0),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  minHeight:
                                                      kUnifiedFieldMinHeight),
                                              child: Focus(
                                                // ← 後述の「編集禁止」もここで
                                                canRequestFocus: false,
                                                descendantsAreFocusable: false,
                                                child: TextField(
                                                  controller:
                                                      TextEditingController(
                                                          text: l10n.personal),
                                                  readOnly: true,
                                                  showCursor: false,
                                                  enableInteractiveSelection:
                                                      false,
                                                  decoration: _underlineDec(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4.0),

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
                                          children: [
                                            _metricRow(
                                                label: l10n.bodyWeight,
                                                controller: _weightController,
                                                unit: currentUnit == 'kg'
                                                    ? l10n.kg
                                                    : l10n.lbs),
                                            if ((widget.settingsBox
                                                        .get('manage.bodyFat')
                                                    as bool?) ??
                                                false)
                                              _metricRow(
                                                  label: l10n.bodyFat,
                                                  controller:
                                                      _bodyFatController,
                                                  unit: l10n.percentSymbol),
                                            if ((widget.settingsBox
                                                        .get('manage.waist')
                                                    as bool?) ??
                                                false)
                                              _metricRow(
                                                  label: l10n.waist,
                                                  controller: _waistController,
                                                  unit: SettingsManager
                                                          .isWaistInch
                                                      ? l10n.unitIn
                                                      : l10n.unitCm),
                                            if ((widget.settingsBox
                                                        .get('manage.bmi')
                                                    as bool?) ??
                                                false)
                                              _metricRow(
                                                  label: l10n.bmi,
                                                  controller: _bmiCtrl),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ← これを最後に置く（最上面）。白いカードも含めてどこでもタップOK
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16.0),
                                    onTap: _openPersonalOverlaySmooth,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

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
                                    ],
                                  ),
                                  const SizedBox(height: 4.0),
                                  if (section.selectedPart != null)
                                    Column(
                                      children: [
                                        ...List.generate(
                                            section.menuControllers.length,
                                            (menuIndex) {
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
                                                  ? kBrandBlue.withOpacity(0.45)
                                                  : Colors.white
                                                      .withOpacity(0.70))
                                              : Colors.black.withOpacity(0.20);

                                          final bool isEditingThisOne =
                                              _menuOverlayVisible &&
                                                  _menuSecIndex == secIndex &&
                                                  _menuMenuIndex == menuIndex;

                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              _touchCard(secIndex, menuIndex);
                                              _openMenuOverlaySmooth(
                                                  secIndex, menuIndex);
                                            },
                                            child: Card(
                                              key: section.menuKeys[menuIndex],
                                              color: colorScheme.surface,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                side: BorderSide(
                                                    color: borderColor,
                                                    width:
                                                        isSelected ? 1.5 : 0),
                                              ),
                                              elevation: isSelected ? 3.0 : 0.0,
                                              shadowColor: glowColor,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                child: isEditingThisOne
                                                    ? MenuListPreview(
                                                        menuController: section
                                                                .menuControllers[
                                                            menuIndex],
                                                        setInputDataList: section
                                                                .setInputDataList[
                                                            menuIndex],
                                                        isAerobic: section
                                                                .selectedPart ==
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
                                                                section,
                                                                menuIndex),
                                                        showAerobicFailureHint:
                                                            (menuIndex <
                                                                    section
                                                                        .aerobicCalorieHintVisible
                                                                        .length)
                                                                ? section
                                                                        .aerobicCalorieHintVisible[
                                                                    menuIndex]
                                                                : false,
                                                        satisfaction: (menuIndex <
                                                                section
                                                                    .satisfactionList
                                                                    .length)
                                                            ? section
                                                                    .satisfactionList[
                                                                menuIndex]
                                                            : null,
                                                      )
                                                    : MenuList(
                                                        key: (secIndex == 0 &&
                                                                menuIndex == 0)
                                                            ? _kExerciseField
                                                            : null,
                                                        nameFieldKey: section
                                                                .nameFieldKeys[
                                                            menuIndex],
                                                        menuController: section
                                                                .menuControllers[
                                                            menuIndex],
                                                        removeMenuCallback:
                                                            () =>
                                                                _removeMenuItem(
                                                                    secIndex,
                                                                    menuIndex),
                                                        setInputDataList: section
                                                                .setInputDataList[
                                                            menuIndex],
                                                        isAerobic: section
                                                                .selectedPart ==
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
                                                        aerobicIsSuggestion:
                                                            (menuIndex <
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
                                                                section,
                                                                menuIndex),
                                                        calorieIsSuggestion:
                                                            (menuIndex <
                                                                    section
                                                                        .aerobicCalorieSuggestFlags
                                                                        .length)
                                                                ? section
                                                                        .aerobicCalorieSuggestFlags[
                                                                    menuIndex]
                                                                : true,
                                                        showAerobicFailureHint:
                                                            (menuIndex <
                                                                    section
                                                                        .aerobicCalorieHintVisible
                                                                        .length)
                                                                ? section
                                                                        .aerobicCalorieHintVisible[
                                                                    menuIndex]
                                                                : false,
                                                        onConfirmAerobic: () {
                                                          setState(() {
                                                            if (menuIndex <
                                                                section
                                                                    .aerobicSuggestFlags
                                                                    .length) {
                                                              section.aerobicSuggestFlags[
                                                                      menuIndex] =
                                                                  false;
                                                            }
                                                          });
                                                        },
                                                        onAerobicFieldChanged: () =>
                                                            _onAerobicFieldChanged(
                                                                secIndex,
                                                                menuIndex),
                                                        onCalorieChanged:
                                                            (value) =>
                                                                _onCaloriesChanged(
                                                                    secIndex,
                                                                    menuIndex,
                                                                    value),
                                                        onAerobicFailureHintTap:
                                                            () =>
                                                                _dismissAerobicFailureHint(
                                                                    secIndex,
                                                                    menuIndex),
                                                        enabledForInput: false,
                                                        onNameChanged:
                                                            (prevEmpty,
                                                                nowEmpty) {
                                                          if (section
                                                                  .selectedPart ==
                                                              l10n.aerobicExercise) {
                                                            _onAerobicFieldChanged(
                                                                secIndex,
                                                                menuIndex);
                                                          }
                                                        },
                                                        satisfaction: (menuIndex <
                                                                section
                                                                    .satisfactionList
                                                                    .length)
                                                            ? section
                                                                    .satisfactionList[
                                                                menuIndex]
                                                            : null,
                                                        onSatisfactionChanged:
                                                            (v) {
                                                          setState(() {
                                                            if (menuIndex <
                                                                section
                                                                    .satisfactionList
                                                                    .length) {
                                                              section.satisfactionList[
                                                                  menuIndex] = v;
                                                            }
                                                          });
                                                        },
                                                      ),
                                              ),
                                            ),
                                          );
                                        }),
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

                    if (bodyIdx == sectionCount && _showMemo) {
                      return _buildMemoCard();
                    }

                    final afterMemoOffset = sectionCount + (_showMemo ? 1 : 0);
                    if (bodyIdx == afterMemoOffset) {
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

    final dial = Positioned(
      right: 16,
      bottom: dialBottom,
      child: (!keyboardVisible &&
              !_memoOverlayVisible &&
              !_memoOverlayOpen &&
              !_menuOverlayVisible &&
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
                  _stagger(2, chipAction(l10n.addMemo, _handleAddMemo)),
                  const SizedBox(height: 8),
                  _stagger(3, chipAction(l10n.addPhoto, _handleAddPhoto)),
    if (canShowPersonalButton) ...[
      const SizedBox(height: 8),
      _stagger(4, chipAction('＋パーソナル', _handleAddPersonal, enabled: !_showPersonalCard)),
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
            automaticallyImplyLeading: true,
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

    await CoachBubbleController.showSequence(
      context: context,
      anchors: anchors,
      messages: messages,
      semanticsPrefix: l10n.coachBubbleSemantic,
    );

    await box.put('hint_seen_record_after_part', true);
  }
}

// ===== SectionData / SetInputData / MenuList =====

class SectionData {
  Key key;
  String? selectedPart;
  List<TextEditingController> menuControllers;
  List<List<SetInputData>> setInputDataList;
  List<Key> menuKeys;
  List<GlobalKey> nameFieldKeys;

  // 追加：メニューごとの満足度（2=良い,1=普通,0=悪い,null=未選択）
  List<int?> satisfactionList;

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
    List<int?>? satisfactionList, // 追加
    List<TextEditingController>? aerobicDistanceCtrls,
    List<TextEditingController>? aerobicDurationCtrls,
    List<bool>? aerobicSuggestFlags,
    List<TextEditingController>? aerobicCaloriesCtrls,
    List<bool>? aerobicCalorieSuggestFlags,
    List<bool>? aerobicCalorieHintVisible,
    List<bool>? aerobicCalorieHintShown,
  })  : satisfactionList = satisfactionList ?? <int?>[],
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
      satisfactionList: shouldPopulateDefaults ? [null] : [],
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

  SetInputData({
    required this.weightController,
    required this.repController,
    this.isSuggestion = true,
  });

  void dispose() {
    weightController.dispose();
    repController.dispose();
  }
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
                    return Row(
                      children: [
                        Text(
                          '${index + 1}${l10n.sets}：',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${weightText.isEmpty ? '-' : weightText} $unit  /  ${repsText.isEmpty ? '-' : repsText} ${l10n.reps}',
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
      final unitPrimary =
          SettingsManager.currentLengthUnit == 'mi' ? 'mi' : l10n.km;
      final unitSecondary =
          SettingsManager.currentLengthUnit == 'mi' ? 'yd' : l10n.m;

      Widget valueRow(String label, List<Widget> children) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.0),
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
            if (SettingsManager.currentLengthUnit == 'mi') {
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
            String minute = raw;
            if (parts.length == 2) {
              hour = parts[0];
              minute = parts[1];
            }
            final valueStyle = TextStyle(
                fontFamily: kUiFont, color: cs.onSurface, fontSize: 13.0);
            return valueRow(l10n.time, [
              Text('$hour ${l10n.hour}', style: valueStyle),
              const SizedBox(width: 8),
              Text('$minute ${l10n.min}', style: valueStyle),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildMenuName(),
        const SizedBox(height: 12),
        if (isAerobic) buildAerobicRows() else buildSetRows(),
        const SizedBox(height: 12),
        buildSatisfactionRow(),
        const SizedBox(height: 36),
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
  final void Function(bool prevEmpty, bool nowEmpty)? onNameChanged;
  final VoidCallback? onAerobicFieldChanged;
  final ValueChanged<String>? onCalorieChanged;
  final VoidCallback? onAerobicFailureHintTap;

  final int? satisfaction;
  final ValueChanged<int?>? onSatisfactionChanged;
  final bool enabledForInput;

  const MenuList({
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
    this.onNameChanged,
    this.onAerobicFieldChanged,
    this.onCalorieChanged,
    this.onAerobicFailureHintTap,
    this.satisfaction,
    this.onSatisfactionChanged,
    this.enabledForInput = true,
  });

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  // 既存
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _mController = TextEditingController();
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minAeroCtrl = TextEditingController();

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
    if (t.length == 2) {
      _hourController.text = t[0];
      _minAeroCtrl.text = t[1];
    } else {
      _hourController.text = '';
      _minAeroCtrl.text = widget.durationController.text;
    }

    // 距離（保存は km、小数）
    final raw = widget.distanceController.text.trim();
    if (raw.isEmpty) {
      _kmController.text = '';
      _mController.text = '';
      return;
    }
    final dKm = double.tryParse(raw) ?? 0.0;
    final useImperial = (SettingsManager.currentLengthUnit == 'mi');
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
    if (hourText.isEmpty && minuteText.isEmpty) {
      widget.durationController.text = '';
    } else {
      final hh = hourText.isEmpty ? '0' : hourText;
      final mmRaw = minuteText.isEmpty ? '0' : minuteText;
      final mm = mmRaw.padLeft(2, '0');
      widget.durationController.text = '$hh:$mm';
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
    final useImperial = (SettingsManager.currentLengthUnit == 'mi');
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

  Future<void> _openDurationPicker() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final int initHour = int.tryParse(_hourController.text) ?? 0;
    final int initMin = int.tryParse(_minAeroCtrl.text) ?? 0;

    Duration current = Duration(hours: initHour, minutes: initMin);
    Duration temp = current;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 260,
            child: Column(
              children: [
                const SizedBox(height: 2),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        l10n.time, // 見出しはそのまま
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                            MaterialLocalizations.of(context).okButtonLabel),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm, // ★時間・分
                    initialTimerDuration: current,
                    onTimerDurationChanged: (d) => temp = d,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    setState(() {
      final hh = temp.inHours;
      final mm = (temp.inMinutes % 60);
      _hourController.text = hh.toString();
      _minAeroCtrl.text = mm.toString().padLeft(2, '0');
      _updateDurationController();
      widget.onConfirmAerobic?.call();
    });
    widget.onAerobicFieldChanged?.call();
  }

  // ← _openDurationPicker() の終わりの直後に追加（build() の前）

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final String currentUnit = SettingsManager.currentUnit;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: IgnorePointer(
        // ★追加：入力可否を一括制御
        ignoring: !widget.enabledForInput,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeyedSubtree(
              key: widget.nameFieldKey,
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: notifyFocus,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              minHeight: kUnifiedFieldMinHeight),
                          child: TextField(
                            controller: widget.menuController,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(25)
                            ],
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              // ← 追加
                              fontFamily: kUiFont,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: l10n.addExercisePlaceholder,
                              hintStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.5)),
                              filled: false,
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.4),
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
                  ),
                  // × ボタン（削除確認ダイアログを出す）
                  TextButton(
                    onPressed: () async {
                      final l10n = AppLocalizations.of(context)!;
                      final bool? ok = await showDialog<bool>(
                        context: context, // ← 必須
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.deleteMenuConfirmationTitle),
                          // 「種目を削除しますか？」
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.no),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.yes), // 「はい」
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        // 親に削除を依頼
                        widget.removeMenuCallback();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.center,
                    ),
                    child: Icon(Icons.close,
                        color: colorScheme.onSurfaceVariant, size: 16),
                  )
                ],
              ),
            ),
            const SizedBox(height: 2.0),
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: widget.isAerobic
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Text(l10n.distance, style: aerobicLabelStyle),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Focus(
                                  onFocusChange: (has) {
                                    notifyFocus(has);
                                    if (has && widget.aerobicIsSuggestion) {
                                      widget.onConfirmAerobic?.call();
                                    }
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: _kmController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: kUiFont,
                                        color: colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme.primary,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 0),
                                        hintText: widget.aerobicIsSuggestion
                                            ? '0'
                                            : null,
                                        hintStyle: TextStyle(
                                          fontFamily: kUiFont,
                                          color: colorScheme.onSurfaceVariant
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                ' ${SettingsManager.currentLengthUnit == "mi" ? "mi" : l10n.km} ',
                                style: aerobicUnitEmphasisStyle,
                              ),
                              Expanded(
                                flex: 2,
                                child: Focus(
                                  onFocusChange: (has) {
                                    notifyFocus(has);
                                    if (has && widget.aerobicIsSuggestion) {
                                      widget.onConfirmAerobic?.call();
                                    }
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: _mController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: kUiFont,
                                        color: colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme.primary,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 0),
                                        hintText: widget.aerobicIsSuggestion
                                            ? '0'
                                            : null,
                                        hintStyle: TextStyle(
                                          fontFamily: kUiFont,
                                          color: colorScheme.onSurfaceVariant
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                ' ${SettingsManager.currentLengthUnit == "mi" ? "yd" : l10n.m} ',
                                style: aerobicUnitStyle,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Text(l10n.time, style: aerobicLabelStyle),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Focus(
                                  onFocusChange: (has) {
                                    notifyFocus(has);
                                    if (has && widget.aerobicIsSuggestion) {
                                      widget.onConfirmAerobic?.call();
                                    }
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: _hourController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: kUiFont,
                                        color: colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme.primary,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 0),
                                        hintText: widget.aerobicIsSuggestion
                                            ? '0'
                                            : null,
                                        hintStyle: TextStyle(
                                          fontFamily: kUiFont,
                                          color: colorScheme.onSurfaceVariant
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(' ${l10n.hour} ', style: aerobicUnitStyle),
                              Expanded(
                                flex: 2,
                                child: Focus(
                                  onFocusChange: (has) {
                                    notifyFocus(has);
                                    if (has && widget.aerobicIsSuggestion) {
                                      widget.onConfirmAerobic?.call();
                                    }
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: _minAeroCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: kUiFont,
                                        color: colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme.primary,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 0),
                                        hintText: widget.aerobicIsSuggestion
                                            ? '0'
                                            : null,
                                        hintStyle: TextStyle(
                                          fontFamily: kUiFont,
                                          color: colorScheme.onSurfaceVariant
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(' ${l10n.min}', style: aerobicUnitStyle),
                            ],
                          ),
                        ),
                        if (widget.showCalorieField &&
                            widget.calorieController != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(r'[0-9\.]')),
                                            ],
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: widget.calorieIsSuggestion
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
                                                    color: colorScheme.primary,
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 0),
                                            ),
                                            onChanged: widget.onCalorieChanged,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(' ${l10n.kcalUnit}',
                                        style: aerobicUnitEmphasisStyle),
                                  ],
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
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
                  : Opacity(
                      opacity: nameFilled ? 1.0 : 0.5,
                      child: IgnorePointer(
                        ignoring: !nameFilled,
                        child: Column(
                          children: List.generate(
                            min(10, widget.setInputDataList.length),
                            (setIndex) {
                              final set = widget.setInputDataList[setIndex];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Text(
                                      '${setIndex + 1}${l10n.sets}：',
                                      style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 13.0),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has && set.isSuggestion) {
                                            setState(
                                                () => set.isSuggestion = false);
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: set.weightController,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(r'^\d*\.?\d*'))
                                            ],
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: set.isSuggestion
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
                                                    width: 1),
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
                                          fontWeight: FontWeight.w700),
                                    ),
                                    Expanded(
                                      child: Focus(
                                        onFocusChange: (has) {
                                          notifyFocus(has);
                                          if (has && set.isSuggestion) {
                                            setState(
                                                () => set.isSuggestion = false);
                                          }
                                        },
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight:
                                                  kUnifiedFieldMinHeight),
                                          child: TextField(
                                            controller: set.repController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: kUiFont,
                                              color: set.isSuggestion
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
                                                    width: 1),
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
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' ${l10n.reps}',
                                      style: TextStyle(
                                        fontFamily: kUiFont,
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 13,
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
            const SizedBox(height: 12),
            Padding(
              padding:
                  const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 2.0),
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
                          fontSize: 13, // セットのラベルと同じサイズ感
                          // fontWeight を外して標準の太さに
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
            ),
            const SizedBox(height: 40),
          ],
        ),
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
