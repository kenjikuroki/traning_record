// lib/screens/record_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
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

void showAppSnack(BuildContext context,
    String message, {
      int milliseconds = 1800,
      String? actionLabel,
      VoidCallback? onAction,
    }) {
  final cs = Theme
      .of(context)
      .colorScheme;
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

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  static const Duration _kIdleAutoPause = Duration(hours: 5);
  static const Duration _kHardCap = Duration(hours: 5);
  static const double _bmiNudgeRight = 25.0;
  static const double _bmiUnitReserve = 25.0;
  static const double _unitReserveW  = 22.0;

  // ===== メモ・オーバーレイ（フローティング） =====
  bool _memoOverlayVisible = false; // 表示中か
  bool _memoOverlayOpening = false; // キーボード待ち中か
  bool _memoSlideIn = false; // 上からのスライド演出

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

  bool _isTopMostRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  final GlobalKey _kRecordPart = GlobalKey();
  final GlobalKey _kExerciseField = GlobalKey();
  final GlobalKey _kFabKey = GlobalKey();
  final GlobalKey _kStopwatchArea = GlobalKey();

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

  final TextEditingController _weightController = TextEditingController();

  // 体脂肪入力用
  final TextEditingController _bodyFatController = TextEditingController();
  // ウエスト入力用 ← 追加
  final TextEditingController _waistController = TextEditingController();
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

  void _onShowStopwatchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SettingsManager.showStopwatchNotifier.addListener(_onShowStopwatchChanged);

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

    _inactivityTimer =
        Timer.periodic(const Duration(minutes: 1), (_) {
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
    SettingsManager.showStopwatchNotifier.removeListener(_onShowStopwatchChanged);
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _capTimer?.cancel();
    _savedChipTimer?.cancel();
    _setCountSub?.cancel();
    _scrollDebounce?.cancel();
    _scrollCtrl.dispose();
    for (var section in _sections) { section.dispose(); }
    _sections.clear();

    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _memoController.dispose();
    _memoOverlayFocus.dispose();
    _menuOverlayFocus.dispose();
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
    while (mounted && MediaQuery
        .of(ctx)
        .viewInsets
        .bottom > 0 && DateTime.now().isBefore(deadline)) {
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
      final kb = MediaQuery
          .of(context)
          .viewInsets
          .bottom;
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

// 追加：当日分満足度のマップ
        final dynamic satAllRaw = widget.settingsBox.get(
            'satisfaction-$dateKey');
        final Map<String, dynamic> satAll =
        (satAllRaw is Map<String, dynamic>) ? satAllRaw : {};
        final Map<String, dynamic> partSat =
        (satAll[originalPart] is Map<String, dynamic>)
            ? satAll[originalPart] as Map<String, dynamic>
            : <String, dynamic>{};


        final l10n = AppLocalizations.of(context)!;
        final isAerobic = current == l10n.aerobicExercise;

        for (final name in names) {
          final rec = recBy[name];
          final lu = luBy[name];

          section.menuControllers.add(TextEditingController(text: name));
          section.menuKeys.add(GlobalKey());
          section.nameFieldKeys.add(GlobalKey());
          section.satisfactionList.add(partSat[name] as int?);

          if (isAerobic) {
            final String dist =
            (rec?.distance
                ?.trim()
                .isNotEmpty ?? false)
                ? rec!.distance!.trim()
                : (lu?.distance?.trim() ?? '');
            final String dura =
            (rec?.duration
                ?.trim()
                .isNotEmpty ?? false)
                ? rec!.duration!.trim()
                : (lu?.duration?.trim() ?? '');
            final bool isSug =
            !(rec?.distance
                ?.trim()
                .isNotEmpty == true ||
                rec?.duration
                    ?.trim()
                    .isNotEmpty == true);
            section.aerobicDistanceCtrls.add(TextEditingController(text: dist));
            section.aerobicDurationCtrls.add(TextEditingController(text: dura));
            section.aerobicSuggestFlags.add(isSug);
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
                if (w
                    .trim()
                    .isNotEmpty || r
                    .trim()
                    .isNotEmpty) {
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
        await _scrollIntoComfortZoneAfterKeyboard(
            keys[0], pivot: 0.0, topExtra: 28);
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
                          color: Theme
                              .of(context)
                              .colorScheme
                              .onSurface,
                        )),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(MaterialLocalizations
                          .of(context)
                          .cancelButtonLabel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, parts[temp]),
                      child: Text(MaterialLocalizations
                          .of(context)
                          .okButtonLabel),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(
                      initialItem: initial),
                  onSelectedItemChanged: (i) => temp = i,
                  children: parts
                      .map((p) =>
                      Center(
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
    _showMemo = _memoController.text
        .trim()
        .isNotEmpty;

    if (record == null || record.menus.isEmpty) {
      _sections.add(SectionData.createEmpty(
          _currentSetCount, shouldPopulateDefaults: false));
      _currentSectionIndex = null;
      _currentMenuIndex = null;
      setState(() {});
      return;
    }

    final Map<String, SectionData> tempSectionsMap = {};
    final partsFromRecords = record.menus.keys.toList();

    final dynamic satAllRaw = widget.settingsBox.get('satisfaction-$dateKey');
    final Map<String, dynamic> satAll =
    (satAllRaw is Map<String, dynamic>) ? satAllRaw : {};

    for (final originalPart in partsFromRecords) {
      final translatedPart = _translatePartToLocale(context, originalPart);
      final l10n = AppLocalizations.of(context)!;
      final isAerobic = translatedPart == l10n.aerobicExercise;

      final section = tempSectionsMap.putIfAbsent(
        translatedPart,
            () =>
            SectionData(
              key: GlobalKey(),
              selectedPart: translatedPart,
              menuControllers: [],
              setInputDataList: [],
              menuKeys: [],
              nameFieldKeys: [],
              aerobicDistanceCtrls: [],
              aerobicDurationCtrls: [],
              aerobicSuggestFlags: [],
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

      final Map<String, dynamic> partSat =
      (satAll[originalPart] is Map<String, dynamic>)
          ? satAll[originalPart] as Map<String, dynamic>
          : {};

      for (final name in names) {
        final rec = recBy[name];
        final lu = luBy[name];

        section.menuControllers.add(TextEditingController(text: name));
        section.menuKeys.add(GlobalKey());
        section.nameFieldKeys.add(GlobalKey());
        section.satisfactionList.add(partSat[name] as int?);

        if (isAerobic) {
          final String dist =
          (rec?.distance
              ?.trim()
              .isNotEmpty ?? false)
              ? rec!.distance!.trim()
              : (lu?.distance?.trim() ?? '');
          final String dura =
          (rec?.duration
              ?.trim()
              .isNotEmpty ?? false)
              ? rec!.duration!.trim()
              : (lu?.duration?.trim() ?? '');
          final bool isSug =
          !(rec?.distance
              ?.trim()
              .isNotEmpty == true ||
              rec?.duration
                  ?.trim()
                  .isNotEmpty == true);

          section.aerobicDistanceCtrls.add(TextEditingController(text: dist));
          section.aerobicDurationCtrls.add(TextEditingController(text: dura));
          section.aerobicSuggestFlags.add(isSug);
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
              if (w
                  .trim()
                  .isNotEmpty || r
                  .trim()
                  .isNotEmpty) {
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
  }

  String _getDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
          .toString().padLeft(2, '0')}';

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
    section.menuControllers.clear();
    section.setInputDataList.clear();
    section.aerobicDistanceCtrls.clear();
    section.aerobicDurationCtrls.clear();
    section.aerobicSuggestFlags.clear();
    section.nameFieldKeys.clear();
    // 追加
    section.satisfactionList.clear();
  }

  bool _saveAllSectionsData() {
    final dateKey = _getDateKey(widget.selectedDate);
    final Map<String, List<MenuData>> allMenusForRecord = {};
    // 追加：満足度保存用（部位→{種目名: 値}）
    final Map<String, Map<String, int>> satisfactionToStore = {};
    String? lastModifiedPart;
    bool hasAnyRecordData = false;
    final l10n = AppLocalizations.of(context)!;

    for (final section in _sections) {
      if (section.selectedPart == null) continue;
      final originalPart = _getOriginalPartName(context, section.selectedPart!);
      final isAerobic = section.selectedPart == l10n.aerobicExercise;

      final listForLastUsed = <MenuData>[];
      final listForRecord = <MenuData>[];

      for (int i = 0; i < section.menuControllers.length; i++) {
        final name = section.menuControllers[i].text.trim();
        if (name.isEmpty) continue;

        if (isAerobic) {
          final distance = i < section.aerobicDistanceCtrls.length ? section
              .aerobicDistanceCtrls[i].text : '';
          final duration = i < section.aerobicDurationCtrls.length ? section
              .aerobicDurationCtrls[i].text : '';
          final isSug = i < section.aerobicSuggestFlags.length ? section
              .aerobicSuggestFlags[i] : true;

          listForLastUsed.add(MenuData(
            name: name,
            weights: const <String>[],
            reps: const <String>[],
            distance: distance,
            duration: duration,
          ));

          if (!isSug && ((distance
              .trim()
              .isNotEmpty) || (duration
              .trim()
              .isNotEmpty))) {
            listForRecord.add(MenuData(
              name: name,
              weights: const <String>[],
              reps: const <String>[],
              distance: distance,
              duration: duration,
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
          listForLastUsed.add(
              MenuData(name: name, weights: weightsAll, reps: repsAll));

          final weightsConfirmed = <String>[];
          final repsConfirmed = <String>[];
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final set = section.setInputDataList[i][s];
            final w = set.weightController.text;
            final r = set.repController.text;
            final hasValue = w
                .trim()
                .isNotEmpty || r
                .trim()
                .isNotEmpty;
            if (!set.isSuggestion && hasValue) {
              weightsConfirmed.add(w);
              repsConfirmed.add(r);
            }
          }
          if (weightsConfirmed.isNotEmpty || repsConfirmed.isNotEmpty) {
            listForRecord.add(MenuData(
                name: name, weights: weightsConfirmed, reps: repsConfirmed));
            hasAnyRecordData = true;
            lastModifiedPart ??= originalPart;
          }
        }

        // 追加：満足度の収集（このメニューに設定されていれば保存）
        final int? sat =
        (i < section.satisfactionList.length)
            ? section.satisfactionList[i]
            : null;
        if (sat != null) {
          satisfactionToStore
              .putIfAbsent(originalPart, () => <String, int>{})[name] = sat;
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
    if (_weightController.text.isNotEmpty) {
      bodyWeight = double.tryParse(_weightController.text);
      if (bodyWeight != null) hasAnyRecordData = true;
    }

    // ▼ 追加：体脂肪率/ウエストを先に数値化（固定フィールドへ保存するため）
    final String rawBf = _bodyFatController.text.trim();
    final double? bodyFatVal = rawBf.isEmpty ? null : double.tryParse(rawBf);

    final String rawWaist = _waistController.text.trim();
    final double? waistVal = rawWaist.isEmpty ? null : double.tryParse(rawWaist);

    bool didChangeStorage = false;
    if (hasAnyRecordData || bodyFatVal != null || waistVal != null) {
      final newRecord = DailyRecord(
        date: widget.selectedDate,
        menus: allMenusForRecord,
        lastModifiedPart: lastModifiedPart,
        weight: bodyWeight,
        bodyFatPercent: bodyFatVal, // 追加
        waistCm: waistVal,          // 追加
      );

      try {
        final dyn = newRecord as dynamic;
        dyn.note = memoText;
      } catch (_) {}

      widget.recordsBox.put(dateKey, newRecord);
      didChangeStorage = true;

      widget.settingsBox.put('memo-$dateKey', {'body': memoText});
      if (satisfactionToStore.isNotEmpty) {
        widget.settingsBox.put('satisfaction-$dateKey', satisfactionToStore);
      } else {
        widget.settingsBox.delete('satisfaction-$dateKey');
      }
    } else {
      final had = widget.recordsBox.containsKey(dateKey);
      widget.recordsBox.delete(dateKey);
      widget.settingsBox.delete('memo-$dateKey');
      // 追加
      widget.settingsBox.delete('satisfaction-$dateKey');
      didChangeStorage = had;
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
      final waistVal = double.tryParse(rawWaist);
      if (waistVal != null) pmNew['waist'] = waistVal;

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

        final int keep = max(baseline, lastFilled + 1).clamp(0, row.length);
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
        section.setInputDataList.add(<SetInputData>[]);
      } else {
        final sets = _currentSetCount;
        final row = List<SetInputData>.generate(
          min(10, sets),
              (_) =>
              SetInputData(
                weightController: TextEditingController(),
                repController: TextEditingController(),
                isSuggestion: true,
              ),
        );
        while (section.setInputDataList.length <
            section.menuControllers.length) {
          section.setInputDataList.add(<SetInputData>[]);
        }
        final idx = section.menuControllers.length - 1;
        section.setInputDataList[idx] = row;
      }
    });

    _touchCard(
        sectionIndex, _sections[sectionIndex].menuControllers.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollIntoView(
            sectionIndex, _sections[sectionIndex].menuControllers.length - 1);
      }
    });
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
      final newSection = SectionData.createEmpty(
          _currentSetCount, shouldPopulateDefaults: true);
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
      if (section.menuKeys.length > menuIndex) section.menuKeys.removeAt(
          menuIndex);
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

  void _handleAddExercise() {
    final secIdx = _currentSectionIndex!;
    _addMenuItem(secIdx);
    _currentSectionIndex = secIdx;
    _currentMenuIndex = _sections[secIdx].menuControllers.length - 1;
  }

  void _handleAddPart() {
    _addTargetSection();
  }

  void _handleAddPhoto() {
    _startCaptureLoop();
  }

  // 追加：メモ追加（FABのダイヤル／メモカードから呼ぶ）
  Future<void> _handleAddMemo() async {
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

    // 先にフォーカス→キーボードを出す（レイアウトは固定高さなので縮まない）
    _memoOverlayFocus.requestFocus();
    await SystemChannels.textInput.invokeMethod('TextInput.show');

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
      _showMemo = _memoController.text
          .trim()
          .isNotEmpty;
    });

    final didSave = _saveAllSectionsData();
    if (didSave) _showSavedChipFor(const Duration(milliseconds: 900));

    await _dismissKeyboardSafely(context);
    if (!mounted) return;
    setState(() {
      _memoOverlayVisible = false;
      _memoSlideIn = false;
    });
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
      _showMemo = _memoController.text
          .trim()
          .isNotEmpty;
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

    // 先にキーボード表示（固定高さなので押し上げない）
    _menuOverlayFocus.requestFocus();
    await SystemChannels.textInput.invokeMethod('TextInput.show');

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
    setState(() {
      _menuOverlayVisible = false;
      _menuSlideIn = false;
      _menuSecIndex = null;
      _menuMenuIndex = null;
    });
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<Directory> _mediaDirFor(DateTime date) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'media', _dateKey(date)));
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
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) {
        final pth = f.path.toLowerCase();
        return pth.endsWith('.jpg') ||
            pth.endsWith('.jpeg') ||
            pth.endsWith('.png') ||
            pth.endsWith('.heic');
      })
          .toList();

      files.sort((a, b) =>
          a.lastModifiedSync().compareTo(b.lastModifiedSync()));

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
    final weightKg = (SettingsManager.currentUnit == 'lbs') ? (w * 0.45359237) : w;
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
    } catch (_) {} finally {
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
        '${DateFormat('HHmmss_SSS').format(ts)}${ext.isNotEmpty
        ? ext
        : '.jpg'}';
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
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic), child: child),
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
      builder: (ctx) =>
          AlertDialog(
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
    final cs = Theme
        .of(context)
        .colorScheme;
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
                    Icon(Icons.edit_outlined, size: 18,
                        color: cs.onSurfaceVariant),
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
                    style: TextStyle(
                        color: cs.onSurfaceVariant.withOpacity(0.6)),
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
    final cs = Theme
        .of(context)
        .colorScheme;
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
                final double cell =
                ((constraints.maxWidth - gap * 2) / 3).clamp(
                    0, constraints.maxWidth);

                Widget buildThumb(String path) =>
                    InkWell(
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
                            errorBuilder: (ctx, err, st) =>
                                Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Theme
                                        .of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                              errorBuilder: (ctx, err, st) =>
                                  Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Theme
                                          .of(ctx)
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
    final si = _currentSectionIndex;
    if (si == null) return false;
    if (si < 0 || si >= _sections.length) return false;
    return _sections[si].selectedPart != null;
  }

  Widget _buildStopwatchCard() {
    final cs = Theme
        .of(context)
        .colorScheme;
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
    final didSave = _saveAllSectionsData();

    if (didSave) {
      _showSavedChipFor(const Duration(milliseconds: 900));
      await Future<void>.delayed(const Duration(milliseconds: 360));
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ===== 記入オーバーレイ（画面内フローティングシート：上からスッ） =====
  Widget _buildMemoEditorOverlay() {
    if (!_memoOverlayVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final cs = Theme
        .of(context)
        .colorScheme;
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
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          top: topGap,
          height: overlayHeight,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
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
                          inputFormatters: [LengthLimitingTextInputFormatter(
                              400)
                          ],
                          expands: true,
                          // 固定の高さを埋める
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
      ],
    );
  }

  // 種目編集用オーバーレイ（メモと同様：上から／高さ0.4／背景薄暗）
  // 種目編集用オーバーレイ（上から／高さ0.4／背景薄暗）
  Widget _buildMenuEditorOverlay() {
    // オーバーレイ未表示 or 未選択時は描画しない
    if (!_menuOverlayVisible || _menuSecIndex == null ||
        _menuMenuIndex == null) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final cs = Theme
        .of(context)
        .colorScheme;
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
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          top: topGap,
          height: overlayHeight,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
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
                          // ＋セット（有酸素は無効）※テキストのみ表示
                          TextButton(
                            onPressed: (!isAerobic &&
                                menuIndex < section.setInputDataList.length &&
                                section.setInputDataList[menuIndex].length < 10)
                                ? () {
                              HapticFeedback.selectionClick();
                              _addOneSetAt(secIndex, menuIndex);
                            }
                                : null,
                            child: Text(l10n.addSet), // 「+セット」のみ
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

                    // 内容：MenuList を再利用（下のカード側はダブルバインド回避のためプレースホルダ）
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            child: Focus(
                              focusNode: _menuOverlayFocus,
                              child: MenuList(
                                nameFieldKey: section.nameFieldKeys[menuIndex],
                                menuController: section
                                    .menuControllers[menuIndex],
                                removeMenuCallback: () =>
                                    _removeMenuItem(secIndex, menuIndex),
                                setInputDataList: section
                                    .setInputDataList[menuIndex],
                                isAerobic: isAerobic,
                                distanceController: (menuIndex <
                                    section.aerobicDistanceCtrls.length)
                                    ? section.aerobicDistanceCtrls[menuIndex]
                                    : TextEditingController(),
                                // 念のための安全策
                                durationController: (menuIndex <
                                    section.aerobicDurationCtrls.length)
                                    ? section.aerobicDurationCtrls[menuIndex]
                                    : TextEditingController(),
                                aerobicIsSuggestion: (menuIndex <
                                    section.aerobicSuggestFlags.length)
                                    ? section.aerobicSuggestFlags[menuIndex]
                                    : true,
                                onConfirmAerobic: () {
                                  setState(() {
                                    if (menuIndex <
                                        section.aerobicSuggestFlags.length) {
                                      section.aerobicSuggestFlags[menuIndex] =
                                      false;
                                    }
                                  });
                                },
                                onAnyFieldFocused: () {},
                                // すでにオーバーレイ中
                                onNameChanged: (prevEmpty, nowEmpty) {},
                                satisfaction: (menuIndex <
                                    section.satisfactionList.length)
                                    ? section.satisfactionList[menuIndex]
                                    : null,
                                onSatisfactionChanged: (v) {
                                  setState(() {
                                    if (menuIndex <
                                        section.satisfactionList.length) {
                                      section.satisfactionList[menuIndex] = v;
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final isLight = Theme
        .of(context)
        .brightness == Brightness.light;
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

    final bool showWeight = SettingsManager.showWeightInput;
    final bool showBodyFat = (widget.settingsBox.get('manage.bodyFat') as bool?) ?? false;
    final bool showWaist   = (widget.settingsBox.get('manage.waist')   as bool?) ?? false;
    final bool showBMI     = (widget.settingsBox.get('manage.bmi')     as bool?) ?? false;


    // ===== Body (空き領域タップでフォーカス解除) =====
    final body = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          children: [
            const AdBanner(screenName: 'record'),
            const SizedBox(height: 0.0),

            Visibility(
              visible: SettingsManager.showStopwatch,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: Padding(
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior
                      .onDrag,
                  // ← ドラッグで閉じる
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: (showWeight ? 1 : 0) + _sections.length +
                      (_showMemo ? 1 : 0) + 1,
                  itemBuilder: (context, index) {
                    if (showWeight && index == 0) {
                      final bmiValue = _bmiValue;
                      return Padding(
                        padding: EdgeInsets.zero,
                        child: Card(
                          color: colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                          elevation: 1.0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                            child: Builder(
                              builder: (context) {
                                // ───────── レイアウト共通値 ─────────
                                const double labelW = 96;   // ← ラベル固定幅（右寄せ）…「若干右に」
                                const double fieldW = 184;  // ← 入力欄の固定幅（全行で統一）
                                const double rowGap = 10;

                                final labelStyle = TextStyle(
                                  fontFamily: kUiFont,
                                  color: colorScheme.onSurface,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                );

                                final inputTextStyle = TextStyle(
                                  fontFamily: kUiFont,
                                  color: colorScheme.onSurface,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                );

                                final unitStyle = TextStyle(
                                  fontFamily: kUiFont,
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700,
                                );

                                // ラベル（右寄せ・固定幅）
                                Widget label(String text) => SizedBox(
                                  width: labelW,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(text, style: labelStyle),
                                  ),
                                );

                                // 下線フィールド（共通）
                                Widget underlineField({
                                  required TextEditingController controller,
                                  required List<TextInputFormatter> formatters,
                                  required TextInputType keyboardType,
                                  String? unitSuffix,
                                  VoidCallback? onChangedBmi,                 // 体重のみBMI再計算用
                                  ValueChanged<bool>? onFocusChange,          // 体重のみFAB制御用
                                }) {
                                  final field = ConstrainedBox(
                                    constraints: const BoxConstraints(minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: keyboardType,
                                      inputFormatters: formatters,
                                      textAlign: TextAlign.right,
                                      // ★ ここを共通スタイルに変更
                                      style: inputTextStyle,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: '',
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
                                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                                      ),
                                      onChanged: (_) => onChangedBmi?.call(),
                                    ),
                                  );

                                  return SizedBox(
                                    width: fieldW,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: onFocusChange == null
                                              ? field
                                              : Focus(onFocusChange: onFocusChange, child: field),
                                        ),
                                        if (unitSuffix != null) ...[
                                          const SizedBox(width: 8),
                                          // ← 単位の実幅に依存しないよう固定幅リザーブ
                                          SizedBox(
                                            width: _unitReserveW,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(unitSuffix, style: unitStyle), // 2-2で統一したスタイル
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }

                                final decimalFmt = <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ];

                                final bmiValue = _bmiValue;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1) 体重
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        label(
                                          '${l10n.bodyWeight}'
                                              '${Localizations.of(context, MaterialLocalizations)!.formatDecimal(0).contains("0") ? "：" : ":"}',
                                        ),
                                        const SizedBox(width: 12),
                                        underlineField(
                                          controller: _weightController,
                                          formatters: decimalFmt,
                                          keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                          unitSuffix: SettingsManager.currentUnit, // kg / lbs
                                          onChangedBmi: _updateBmiDisplay, // ★ BMI再計算
                                          onFocusChange: (has) {
                                            setState(() {
                                              _weightFocused = has;
                                              if (has) _fabOpen = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),

                                    // 2) 体脂肪（%）
                                    if (showBodyFat) ...[
                                      SizedBox(height: rowGap),
                                      Row(
                                        children: [
                                          label('${l10n.bodyFat}：'),
                                          const SizedBox(width: 12),
                                          underlineField(
                                            controller: _bodyFatController,
                                            formatters: decimalFmt,
                                            keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                            unitSuffix: '%',
                                          ),
                                        ],
                                      ),
                                    ],

                                    // 3) ウエスト（cm）
                                    if (showWaist) ...[
                                      SizedBox(height: rowGap),
                                      Row(
                                        children: [
                                          label('${l10n.waist}：'),
                                          const SizedBox(width: 12),
                                          underlineField(
                                            controller: _waistController,
                                            formatters: decimalFmt,
                                            keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                            unitSuffix: 'cm',
                                          ),
                                        ],
                                      ),
                                    ],

                                    // 4) BMI（値のみ表示。フィールド列と右端合わせ）
                                    if (showBMI) ...[
                                      SizedBox(height: rowGap),
                                      Row(
                                        children: [
                                          label('${l10n.bmi}：'),
                                          const SizedBox(width: 12),
                                          // 値は他と同じ fieldW 幅で右寄せ
                                          SizedBox(
                                            width: fieldW,                              // ← 他行と同じ幅で右端を揃える
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: _bmiNudgeRight), // ← 値だけ少し左に“見せる”
                                                child: Text(
                                                  (bmiValue == null) ? '—' : bmiValue.toStringAsFixed(1),
                                                  style: inputTextStyle.copyWith(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: _bmiUnitReserve),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                    ] else ...[
                                      const SizedBox(height: 6),
                                    ]
                                  ],
                                );
                              },
                            ),
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
                                              minHeight: kUnifiedFieldMinHeight),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainer,
                                            borderRadius: BorderRadius.circular(
                                                22.0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                    0.04),
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
                                                padding: const EdgeInsets
                                                    .symmetric(vertical: 8,
                                                    horizontal: 20),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        section.selectedPart ??
                                                            l10n
                                                                .selectTrainingPart,
                                                        style: TextStyle(
                                                          fontFamily: kUiFont,
                                                          color: (section.selectedPart == null)
                                                              ? colorScheme.onSurfaceVariant
                                                              : colorScheme.onSurface,
                                                          fontSize: 15.0,
                                                          fontWeight: FontWeight.w700,
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
                                            section.menuControllers.length, (
                                            menuIndex) {
                                          final bool isSelected =
                                          (_currentSectionIndex == secIndex &&
                                              _currentMenuIndex == menuIndex);

                                          final borderColor = isSelected
                                              ? (isLight ? kBrandBlue : Colors
                                              .white)
                                              : Colors.transparent;
                                          final glowColor = isSelected
                                              ? (isLight
                                              ? kBrandBlue.withOpacity(0.45)
                                              : Colors.white.withOpacity(0.70))
                                              : Colors.black.withOpacity(0.20);

                                          final bool isEditingThisOne = _menuOverlayVisible &&
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
                                                borderRadius: BorderRadius
                                                    .circular(12.0),
                                                side: BorderSide(
                                                    color: borderColor,
                                                    width: isSelected
                                                        ? 1.5
                                                        : 0),
                                              ),
                                              elevation: isSelected ? 3.0 : 0.0,
                                              shadowColor: glowColor,
                                              margin: const EdgeInsets
                                                  .symmetric(vertical: 8.0),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                    10.0),
                                                child: isEditingThisOne
                                                // ダブルバインド防止のプレースホルダ
                                                    ? const SizedBox(height: 12)
                                                    : MenuList(
                                                  key: (secIndex == 0 && menuIndex == 0) ? _kExerciseField : null,
                                                  nameFieldKey: section.nameFieldKeys[menuIndex],
                                                  menuController: section.menuControllers[menuIndex],
                                                  removeMenuCallback: () => _removeMenuItem(secIndex, menuIndex),
                                                  setInputDataList: section.setInputDataList[menuIndex],
                                                  isAerobic: section.selectedPart == l10n.aerobicExercise,
                                                  distanceController: (menuIndex < section.aerobicDistanceCtrls.length)
                                                      ? section.aerobicDistanceCtrls[menuIndex]
                                                      : TextEditingController(),
                                                  durationController: (menuIndex < section.aerobicDurationCtrls.length)
                                                      ? section.aerobicDurationCtrls[menuIndex]
                                                      : TextEditingController(),
                                                  aerobicIsSuggestion: (menuIndex < section.aerobicSuggestFlags.length)
                                                      ? section.aerobicSuggestFlags[menuIndex]
                                                      : true,
                                                  onConfirmAerobic: () {
                                                    setState(() {
                                                      if (menuIndex < section
                                                          .aerobicSuggestFlags
                                                          .length) {
                                                        section
                                                            .aerobicSuggestFlags[menuIndex] =
                                                        false;
                                                      }
                                                    });
                                                  },
                                                  enabledForInput: false,
                                                  onNameChanged: (prevEmpty, nowEmpty) {},
                                                  satisfaction: (menuIndex < section.satisfactionList.length)
                                                      ? section.satisfactionList[menuIndex]
                                                      : null,
                                                  onSatisfactionChanged: (v){
                                                    setState(() {
                                                      if (menuIndex < section
                                                          .satisfactionList
                                                          .length) {
                                                        section
                                                            .satisfactionList[menuIndex] =
                                                            v;
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
        setState(() => _fabOpen = !_fabOpen);
      },
      backgroundColor: kBrandBlue,
      child: const Icon(Icons.add, color: Colors.white),
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
              setState(() => _fabOpen = false);
              onTap();
            }
                : null,
            child: Ink(
              decoration: BoxDecoration(
                color: kBrandBlue,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
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

    final overlay = (_fabOpen && !keyboardVisible && !_memoOverlayVisible &&
        !_memoOverlayOpen && !_menuOverlayVisible)
        ? Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _fabOpen = false),
        child: Container(color: Colors.black.withOpacity(0.25)),
      ),
    )
        : const SizedBox.shrink();

    const double fabSize = 56.0;
    const double fabMargin = 14.0;
    const double gapAboveFab = 24.0;
    final double dialBottom =
        (safeBottom > 0 ? safeBottom : fabMargin) + kbInset + fabSize +
            fabMargin + gapAboveFab;

    // ＋セットはダイヤルから削除（オーバーレイのヘッダーへ移動）
    final dial = Positioned(
      right: 16,
      bottom: dialBottom,
      child: (_fabOpen && !keyboardVisible && !_memoOverlayVisible &&
          !_memoOverlayOpen && !_menuOverlayVisible)
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          chipAction(
              l10n.addExercise, _handleAddExercise, enabled: _canAddExercise()),
          const SizedBox(height: 8),
          chipAction(l10n.addPart, _handleAddPart),
          const SizedBox(height: 8),
          chipAction(l10n.addMemo, _handleAddMemo),
          const SizedBox(height: 8),
          chipAction(l10n.addPhoto, _handleAddPhoto),
          const SizedBox(height: 8),
        ],
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
        final slide = Tween<Offset>(
            begin: const Offset(0.15, 0), end: Offset.zero).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: _showSavedChip ? _buildSavedPill(colorScheme) : const SizedBox(
          key: ValueKey('empty')),
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
            automaticallyImplyLeading: false,
            elevation: 0.0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: _handleExit,
              tooltip: MaterialLocalizations
                  .of(context)
                  .backButtonTooltip,
            ),
            title: Text(
              AppLocalizations.of(context)!.recordScreenTitle,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 19.0),
            ),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [savedPillArea],
          ),
          body: Stack(
            children: [
              body,
              overlay, // FABダイヤルのオーバーレイ
              dial, // FABダイヤル
              _buildMenuEditorOverlay(), // ← 種目のフローティング編集
              _buildMemoEditorOverlay(), // ← メモのフローティング編集
              doneOverlay, // キーボード上「完了」（ダミー）
            ],
          ),
          floatingActionButton: (!keyboardVisible && !_memoOverlayVisible &&
              !_memoOverlayOpen && !_menuOverlayVisible)
              ? AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: (kbInset > 0 ? kbInset + 10 : 14)),
            child: fabMain,
          )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }

  Future<void> _scrollIntoComfortZoneAfterKeyboard(GlobalKey key, {
    double pivot = 0.0,
    double topExtra = 28,
  }) async {
    await _waitForKeyboardStable();
    await _scrollIntoComfortZone(key, pivot: pivot, topExtra: topExtra);
  }

  Future<void> _scrollIntoComfortZone(GlobalKey key, {
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
  })
      : satisfactionList = satisfactionList ?? <int?>[],
  // 追加
        aerobicDistanceCtrls = aerobicDistanceCtrls ??
            <TextEditingController>[],
        aerobicDurationCtrls = aerobicDurationCtrls ??
            <TextEditingController>[],
        aerobicSuggestFlags = aerobicSuggestFlags ?? <bool>[];

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
              (_) =>
              SetInputData(
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

class MenuList extends StatefulWidget {
  final GlobalKey nameFieldKey;
  final TextEditingController menuController;
  final VoidCallback removeMenuCallback;
  final List<SetInputData> setInputDataList;
  final bool isAerobic;
  final TextEditingController distanceController;
  final TextEditingController durationController;
  final bool aerobicIsSuggestion;
  final VoidCallback? onConfirmAerobic;
  final VoidCallback? onAnyFieldFocused;
  final void Function(bool prevEmpty, bool nowEmpty)? onNameChanged;

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
    this.onConfirmAerobic,
    this.onAnyFieldFocused,
    this.onNameChanged,
    this.satisfaction,
    this.onSatisfactionChanged,
    this.enabledForInput = true,
  });

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  final TextEditingController _kmController   = TextEditingController();
  final TextEditingController _mController    = TextEditingController();
  final TextEditingController _hourController = TextEditingController(); // ★変更
  final TextEditingController _minAeroCtrl    = TextEditingController(); // ★変更

  bool _prevNameEmpty = true;

  @override
  void initState() {
    super.initState();
    _parseDurationAndDistance();
    _kmController.addListener(_updateDistanceController);
    _mController.addListener(_updateDistanceController);
    _hourController.addListener(_updateDurationController);
    _minAeroCtrl.addListener(_updateDurationController);

    _prevNameEmpty = widget.menuController.text
        .trim()
        .isEmpty;
    widget.menuController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _kmController.dispose();
    _mController.dispose();
    _hourController.dispose();
    _minAeroCtrl.dispose();
    widget.menuController.removeListener(_handleNameChanged);
    super.dispose();
  }

  void _handleNameChanged() {
    final nowEmpty = widget.menuController.text
        .trim()
        .isEmpty;
    if (nowEmpty != _prevNameEmpty) {
      widget.onNameChanged?.call(_prevNameEmpty, nowEmpty);
      setState(() {});
      _prevNameEmpty = nowEmpty;
    }
  }

  void _parseDurationAndDistance() {
    final t = widget.durationController.text.split(':');
    if (t.length == 2) {
      _hourController.text = t[0];
      _minAeroCtrl.text    = t[1];
    } else {
      _hourController.text = '';
      _minAeroCtrl.text    = widget.durationController.text;
    }

    final d = widget.distanceController.text.split('.');
    if (d.length == 2) {
      _kmController.text = d[0];
      _mController.text  = d[1];
    } else {
      _kmController.text = widget.distanceController.text;
      _mController.text  = '';
    }
  }

  void _updateDurationController() {
    widget.durationController.text =
    '${_hourController.text}:${_minAeroCtrl.text}';
  }

  void _updateDistanceController() {
    widget.distanceController.text =
    '${_kmController.text}.${_mController.text}';
  }

  Future<void> _openDurationPicker() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final int initHour = int.tryParse(_hourController.text) ?? 0;
    final int initMin  = int.tryParse(_minAeroCtrl.text)  ?? 0;

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
                  width: 40, height: 4,
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
                        child: Text(MaterialLocalizations.of(context).okButtonLabel),
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
      _minAeroCtrl.text    = mm.toString().padLeft(2, '0');
      _updateDurationController();
      widget.onConfirmAerobic?.call();
    });
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
        customBorder: const CircleBorder(),   // タップ範囲は確保
        onTap: () {
          final newVal = selected ? null : value; // 再タップで解除
          widget.onSatisfactionChanged?.call(newVal);
        },
        child: Padding(
          padding: const EdgeInsets.all(6),   // 見た目は小さく/ヒットエリアは広く
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 28,                        // ★背景を小さく（42→28等）
            height: 28,                       // ★背景を小さく（36→28等）
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
              size: 20,                        // ★絵文字サイズはそのまま
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final String currentUnit = SettingsManager.currentUnit;

    void notifyFocus(bool has) {
      if (has) {
        widget.onAnyFieldFocused?.call();
      }
    }

    final bool nameFilled = widget.menuController.text
        .trim()
        .isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: IgnorePointer( // ★追加：入力可否を一括制御
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
                            inputFormatters: [ LengthLimitingTextInputFormatter(25) ],
                            textAlign: TextAlign.left,
                            style: TextStyle(                        // ← 追加
                              fontFamily: kUiFont,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: l10n.addExercisePlaceholder,
                              hintStyle: TextStyle(
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(
                                      0.5)),
                              filled: false,
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(
                                      0.4),
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
                        builder: (ctx) =>
                            AlertDialog(
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
                    child: Icon(
                        Icons.close, color: colorScheme.onSurfaceVariant,
                        size: 16),
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
                  Row(
                    children: [
                      Text(
                        l10n.distance,
                        style: TextStyle(
                          fontFamily: kUiFont,
                          color: colorScheme.onSurface,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                                color: widget.aerobicIsSuggestion
                                    ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                    : colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                  BorderSide(color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.4), width: 1),
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
                      Text(' ${l10n.km} ',
                          style: TextStyle(
                            fontFamily: kUiFont,
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                          )),
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
                                color: widget.aerobicIsSuggestion
                                    ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                    : colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                  BorderSide(color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.4), width: 1),
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
                      Text(' ${l10n.m}',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // --- 距離Row（そのまま） ---
// その下の「時間Row」をこれに置換
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        l10n.time,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),

                      // 時間
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            if (widget.aerobicIsSuggestion) widget.onConfirmAerobic?.call();
                            FocusScope.of(context).unfocus();
                            await SystemChannels.textInput.invokeMethod('TextInput.hide');
                            await _openDurationPicker();
                          },
                          child: AbsorbPointer(
                            child: Focus(
                              onFocusChange: notifyFocus,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: kUnifiedFieldMinHeight),
                                child: TextField(
                                  controller: _hourController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: widget.aerobicIsSuggestion
                                        ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                        : colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true, filled: false,
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: colorScheme.onSurfaceVariant.withOpacity(0.4), width: 1),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(' ${l10n.hour} ', // ★時間ラベル（フォールバックあり）
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),

                      // 分
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            if (widget.aerobicIsSuggestion) widget.onConfirmAerobic?.call();
                            FocusScope.of(context).unfocus();
                            await SystemChannels.textInput.invokeMethod('TextInput.hide');
                            await _openDurationPicker();
                          },
                          child: AbsorbPointer(
                            child: Focus(
                              onFocusChange: notifyFocus,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: kUnifiedFieldMinHeight),
                                child: TextField(
                                  controller: _minAeroCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: kUiFont,
                                    color: widget.aerobicIsSuggestion
                                        ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                        : colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true, filled: false,
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: colorScheme.onSurfaceVariant.withOpacity(0.4), width: 1),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(' ${l10n.min}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
                    ],
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
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                                      setState(() => set.isSuggestion = false);
                                    }
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: set.weightController,
                                      keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d*'))
                                      ],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: kUiFont,
                                        color: set.isSuggestion
                                            ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                            : colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withOpacity(0.4), width: 1),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme.primary,
                                              width: 2),
                                        ),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
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
                                    fontWeight: FontWeight.w700),
                              ),
                              Expanded(
                                child: Focus(
                                  onFocusChange: (has) {
                                    notifyFocus(has);
                                    if (has && set.isSuggestion) {
                                      setState(() => set.isSuggestion = false);
                                    }
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: kUnifiedFieldMinHeight),
                                    child: TextField(
                                      controller: set.repController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: set.isSuggestion
                                            ? colorScheme.onSurfaceVariant
                                            .withOpacity(0.5)
                                            : colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withOpacity(0.4), width: 1),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                              color: colorScheme.primary,
                                              width: 2),
                                        ),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 6, horizontal: 0),
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
              padding: const EdgeInsets.only(
                  left: 8.0, right: 8.0, bottom: 2.0),
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
                          fontSize: 13,           // セットのラベルと同じサイズ感
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
      builder: (ctx) =>
          AlertDialog(
            title: Text(l10n.discardPhotoConfirmTitle),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.no)),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.yes)),
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
            border: filled ? null : Border.all(
                color: Colors.white.withOpacity(0.35)),
            boxShadow: filled
                ? [
              BoxShadow(color: Colors.black.withOpacity(0.08),
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
    final bottom = MediaQuery
        .of(context)
        .padding
        .bottom;

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
