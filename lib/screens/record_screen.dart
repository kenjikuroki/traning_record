// lib/screens/record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'dart:async';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/custom_widgets.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import '../widgets/stopwatch_widget.dart';
import 'calendar_screen.dart';
import 'graph_screen.dart';
import '../widgets/coach_bubble.dart';
import '../widgets/ui_feedback.dart';
import 'package:flutter/cupertino.dart';


// ignore_for_file: library_private_types_in_public_api

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

class _RecordScreenState extends State<RecordScreen> with WidgetsBindingObserver {
  // ====== 自動一時停止の基準 ======
  static const Duration _kIdleAutoPause = Duration(hours: 5); // 無操作
  static const Duration _kHardCap      = Duration(hours: 5); // 連続稼働上限
  // =================================

  final ScrollController _scrollCtrl = ScrollController();
  bool _initialized = false;

  // 体重入力にフォーカス中フラグ（フォーカス中は＋FABを無効化）
  bool _weightFocused = false;

  bool _isTopMostRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  // CoachBubble anchors
  final GlobalKey _kRecordPart = GlobalKey(); // 部位ドロップダウン（初回ヒント用）
  final GlobalKey _kExerciseField = GlobalKey(); // 種目TextField（選択後ヒント）
  final GlobalKey _kFabKey = GlobalKey(); // FAB

  bool _firstBuildDone = false;

  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];
  List<SectionData> _sections = [];
  int _currentSetCount = 3;

  // FAB 対象
  int? _currentSectionIndex;
  int? _currentMenuIndex;

  void _onBackPressed() {
    // FABが開いていたらまず閉じるだけ
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      return;
    }
    // データ保存してから閉じる
    _saveAllSectionsData();
    if (mounted) Navigator.of(context).pop();
  }

  bool _fabOpen = false;

  final TextEditingController _weightController = TextEditingController();

  // ==== ストップウォッチ：常時固定＆制御 ====
  static final StopwatchController _swController = StopwatchController();

  DateTime _lastInteractionAt = DateTime.now();
  Timer? _inactivityTimer; // 無操作監視
  Timer? _capTimer;        // 連続稼働上限監視
  DateTime? _backgroundedAt;

  bool _wasRunning = false;
  DateTime? _resumedAt; // 直近で走り始めた時刻
  // ===================================

    // 設定変更通知で再ビルド（表示/非表示の分岐は build 内で読む）
    void _onShowStopwatchChanged() {
        if (!mounted) return;
        setState(() {});
      }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SettingsManager.showStopwatchNotifier.addListener(_onShowStopwatchChanged);

    // 設定「ストップウォッチ表示」変更を監視して即時反映

    // 初回ビルド完了フラグ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _firstBuildDone = true);
    });

    // 初回表示ヒント：部位だけ（FABヒントは出さない）
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

    // 無操作監視（5時間で一時停止）
    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final idle = DateTime.now().difference(_lastInteractionAt);
      if (idle >= _kIdleAutoPause && _swController.isRunning) {
        _pauseWithSnack('無操作が5時間続いたため一時停止しました');
      }
    });

    // 連続稼働5時間で一時停止（elapsed が無いので自前で判定）
    _capTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final running = _swController.isRunning;

      // 状態遷移を検出
      if (running && !_wasRunning) {
        // 走り始め
        _resumedAt = DateTime.now();
      } else if (!running && _wasRunning) {
        // 停止したら連続稼働ストリークはクリア
        _resumedAt = null;
      }

      // 連続稼働の判定
      if (running && _resumedAt != null) {
        final runFor = DateTime.now().difference(_resumedAt!);
        if (runFor >= _kHardCap) {
          _pauseWithSnack('5時間を超えたため一時停止しました', withResume: true);
          _resumedAt = null;
        }
      }

      _wasRunning = running;
    });

    // スクロール＝操作扱い
    _scrollCtrl.addListener(() => _lastInteractionAt = DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _scrollCtrl.dispose();
    for (var section in _sections) {
      section.dispose();
    }
    _sections.clear();
    _weightController.dispose();
    super.dispose();
  }

  // Appライフサイクル（バックグラウンド30分で自動一時停止）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedAt != null) {
        final away = DateTime.now().difference(_backgroundedAt!);
        if (away.inMinutes >= 30 && _swController.isRunning) {
          _pauseWithSnack('アプリが30分以上バックグラウンドのため一時停止しました', withResume: true);
        }
      }
      _backgroundedAt = null;
      _lastInteractionAt = DateTime.now();
    }
  }

  void _pauseWithSnack(String message, {bool withResume = false}) {
    _swController.pause();
    if (!mounted || !_isTopMostRoute(context)) return;
    final action = withResume
        ? SnackBarAction(
      label: '再開',
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

  // 指定のカードを画面内にスクロールして見えるようにする
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
         // フォールバック：セクションカード自体へスクロール
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

  // 追加：セクションカードへ確実にスクロール
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

    // 追加：部位選択の適用（Dropdown onChanged の処理を関数化）
    void _applySelectedPart(int secIndex, String? value) {
        final section = _sections[secIndex];
        setState(() {
          section.selectedPart = value;
          section.menuKeys.clear();
          section.menuIds.clear();
          section.nextMenuId = 0;
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

            final Map<String, MenuData> recBy = {for (final m in recList) m.name: m};
            final Map<String, MenuData> luBy  = {for (final m in luList) m.name: m};

            final List<String> names = [
              ...recList.map((m) => m.name),
              ...luList.where((m) => !recBy.containsKey(m.name)).map((m) => m.name),
            ];
            if (names.isEmpty) names.add('');

            final l10n = AppLocalizations.of(context)!;
            final isAerobic = current == l10n.aerobicExercise;

            for (final name in names) {
              final rec = recBy[name];
              final lu  = luBy[name];

              section.menuControllers.add(TextEditingController(text: name));
              section.menuKeys.add(GlobalKey());
              section.menuIds.add(section.nextMenuId++);

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
                section.setInputDataList.add(<SetInputData>[]);
              } else {
                final int recLen = rec == null ? 0 : min(rec.weights.length, rec.reps.length);
                final int luLen  = lu  == null ? 0 : min(lu.weights.length,  lu.reps.length);
                final int mergedLen = max(_currentSetCount, max(recLen, luLen));

                final row = <SetInputData>[];
                for (int i = 0; i < mergedLen; i++) {
                  String w = '';
                  String r = '';
                  bool isSuggestion = true;
                  if (i < recLen) {
                    w = rec!.weights[i];
                    r = rec.reps[i];
                    if (w.trim().isNotEmpty || r.trim().isNotEmpty) isSuggestion = false;
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
                section.initialSetCount = max(section.initialSetCount ?? 0, mergedLen);
              }
            }

            // 先頭の種目カードを選択状態に
            _currentSectionIndex = secIndex;
            _currentMenuIndex = 0;
          } else {
            section.initialSetCount = _currentSetCount;
          }
        });

        // 先頭カードへスクロール & ヒント
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollIntoView(secIndex, 0);
          }
        });
        _scheduleHintsAfterPart();
      }

    // 追加：iOS風ピッカーで部位を選択
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
                 const SizedBox(height: 8),
                 Container(
                   width: 40, height: 4,
                   decoration: BoxDecoration(
                     color: cs.onSurfaceVariant.withOpacity(0.4),
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 8.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       TextButton(
                         onPressed: () => Navigator.pop(ctx, null),
                         child: Text(AppLocalizations.of(context)!.cancel),
                       ),
                       TextButton(
                         onPressed: () => Navigator.pop(ctx, parts[temp]),
                         child: const Text('OK'),
                       ),
                     ],
                   ),
                 ),
                 Expanded(
                   child: CupertinoPicker(
                     itemExtent: 36,
                     scrollController: FixedExtentScrollController(initialItem: initial),
                     onSelectedItemChanged: (i) => temp = i,
                     children: parts.map((p) => Center(
                       child: Text(
                         p,
                         style: TextStyle(
                           color: cs.onSurface,
                           fontWeight: FontWeight.w600,
                           fontSize: 16,
                         ),
                       ),
                     )).toList(),
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

    // 既存セクション破棄
    for (var s in _sections) {
      s.dispose();
    }
    _sections.clear();

    // 体重を復元
    if (record?.weight != null) {
      _weightController.text = record!.weight.toString();
    } else {
      _weightController.clear();
    }

    // 記録なし（日の新規）
    if (record == null || record.menus.isEmpty) {
      _sections.add(
        SectionData.createEmpty(
          _currentSetCount,
          shouldPopulateDefaults: false,
        ),
      );
      _sections[0].initialSetCount = _currentSetCount;

      // 既存記録なし → 選択なし
      _currentSectionIndex = null;
      _currentMenuIndex = null;

      setState(() {});
      return;
    }

    // 記録あり → セクション生成
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
          initialSetCount: _currentSetCount,
          menuKeys: [],
          // 有酸素用 per menu
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

      if (names.isEmpty) {
        names.add('');
      }

      for (final name in names) {
        final rec = recBy[name];
        final lu = luBy[name];

        section.menuControllers.add(TextEditingController(text: name));
        section.menuKeys.add(GlobalKey());
        section.menuIds.add(section.nextMenuId++);

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
          section.initialSetCount = max(section.initialSetCount ?? 0, mergedLen);
        }
      }
    }

    // 並び替え
    _sections = tempSectionsMap.values.toList();
    _sections.sort((a, b) {
      if (a.selectedPart == null && b.selectedPart == null) return 0;
      if (a.selectedPart == null) return 1;
      if (b.selectedPart == null) return -1;
      final ia = _allBodyParts.indexOf(a.selectedPart!);
      final ib = _allBodyParts.indexOf(b.selectedPart!);
      return ia.compareTo(ib);
    });

    // ★ 実績がある日は、先頭の種目カードを選択状態に（安全ガード付き）
    if (_sections.isNotEmpty &&
        _sections.first.selectedPart != null &&
        _sections.first.menuControllers.isNotEmpty) {
      _currentSectionIndex = 0;
      _currentMenuIndex = 0;
      setState(() {}); // ハイライト反映
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
    section.menuControllers.clear();
    section.setInputDataList.clear();
    section.aerobicDistanceCtrls.clear();
    section.aerobicDurationCtrls.clear();
    section.aerobicSuggestFlags.clear();
  }

  void _saveAllSectionsData() {
    final dateKey = _getDateKey(widget.selectedDate);
    final Map<String, List<MenuData>> allMenusForRecord = {};
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
        if (name.isEmpty) {
          continue;
        }

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

          listForLastUsed.add(MenuData(
            name: name,
            weights: const <String>[],
            reps: const <String>[],
            distance: distance,
            duration: duration,
          ));

          if (!isSug &&
              ((distance.trim().isNotEmpty) ||
                  (duration.trim().isNotEmpty))) {
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
          listForLastUsed
              .add(MenuData(name: name, weights: weightsAll, reps: repsAll));

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
            listForRecord.add(
                MenuData(name: name, weights: weightsConfirmed, reps: repsConfirmed));
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

    double? bodyWeight;
    if (_weightController.text.isNotEmpty) {
      bodyWeight = double.tryParse(_weightController.text);
      if (bodyWeight != null) hasAnyRecordData = true;
    }

    if (hasAnyRecordData) {
      final newRecord = DailyRecord(
        date: widget.selectedDate,
        menus: allMenusForRecord,
        lastModifiedPart: lastModifiedPart,
        weight: bodyWeight,
      );
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey);
    }
  }

  // 追加ユーティリティ
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
      final newId = section.nextMenuId++;
      section.menuIds.add(newId);
      section.recentlyAdded.add(newId);

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
              (_) => SetInputData(
            weightController: TextEditingController(),
            repController: TextEditingController(),
            isSuggestion: true,
          ),
        );
        while (section.setInputDataList.length < section.menuControllers.length) {
          section.setInputDataList.add(<SetInputData>[]);
        }
        final idx = section.menuControllers.length - 1;
        section.setInputDataList[idx] = row;
        section.initialSetCount = max(section.initialSetCount ?? 0, sets);
      }
    });

    // 追加直後にそのカードを選択状態に
    _touchCard(sectionIndex, _sections[sectionIndex].menuControllers.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollIntoView(sectionIndex,
            _sections[sectionIndex].menuControllers.length - 1);
      }
    });
  }

  // 無酸素：1セット追加（最大10）
  void _addOneSetAt(int sectionIndex, int menuIndex) {
    final section = _sections[sectionIndex];
    if (menuIndex < 0 || menuIndex >= section.setInputDataList.length) return;
    final list = section.setInputDataList[menuIndex];
    if (list.length >= 10) return;
    setState(() {
      list.add(
        SetInputData(
          weightController: TextEditingController(),
          repController: TextEditingController(),
          isSuggestion: true,
        ),
      );
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

    // 追加直後に新しい「部位カード」へスクロール
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollSectionCardIntoView(_sections.length - 1);
            }
          });
  }

  void _removeMenuItem(int sectionIndex, int menuIndex) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMenuConfirmationTitle),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      setState(() {
        _sections[sectionIndex].menuControllers[menuIndex].dispose();
        for (var s in _sections[sectionIndex].setInputDataList[menuIndex]) {
          s.dispose();
        }
        _sections[sectionIndex].menuControllers.removeAt(menuIndex);
        _sections[sectionIndex].setInputDataList.removeAt(menuIndex);
        if (_sections[sectionIndex].menuKeys.length > menuIndex) {
          _sections[sectionIndex].menuKeys.removeAt(menuIndex);
        }

        if (_sections[sectionIndex].aerobicDistanceCtrls.length > menuIndex) {
          _sections[sectionIndex].aerobicDistanceCtrls[menuIndex].dispose();
          _sections[sectionIndex].aerobicDistanceCtrls.removeAt(menuIndex);
        }
        if (_sections[sectionIndex].aerobicDurationCtrls.length > menuIndex) {
          _sections[sectionIndex].aerobicDurationCtrls[menuIndex].dispose();
          _sections[sectionIndex].aerobicDurationCtrls.removeAt(menuIndex);
        }
        if (_sections[sectionIndex].aerobicSuggestFlags.length > menuIndex) {
          _sections[sectionIndex].aerobicSuggestFlags.removeAt(menuIndex);
        }

        if (_sections[sectionIndex].menuIds.length > menuIndex) {
          _sections[sectionIndex].menuIds.removeAt(menuIndex);
        }
      });

      if (_sections[sectionIndex].menuControllers.isEmpty) {
        _removeSection(sectionIndex);
      }
    }
  }

  void _removeSection(int sectionIndex) {
    setState(() {
      _sections[sectionIndex].dispose();
      _sections.removeAt(sectionIndex);
      if (_sections.isEmpty) {
        _sections.add(SectionData.createEmpty(_currentSetCount,
            shouldPopulateDefaults: false));
      }
      _currentSectionIndex = null;
      _currentMenuIndex = null;
    });
  }

  // タップ/フォーカスで対象更新（即ハイライト）
  void _touchCard(int sectionIndex, int menuIndex) {
    setState(() {
      _currentSectionIndex = sectionIndex;
      _currentMenuIndex = menuIndex;
      _lastInteractionAt = DateTime.now();
    });
  }

  // FAB アクション（有酸素にはセット追加しない）
  void _handleAddSet(AppLocalizations l10n) {
    if (_sections.isEmpty) return;
    final secIdx = _currentSectionIndex ?? 0;
    final menuIdx = _currentMenuIndex ?? 0;
    final section = _sections[secIdx];

    if (section.selectedPart == l10n.aerobicExercise) return; // 有酸素は無視
    _addOneSetAt(secIdx, menuIdx);
  }

  void _handleAddExercise() {
    // 前提：canAddExercise() が true のときのみ呼ばれる
    final secIdx = _currentSectionIndex!;
    _addMenuItem(secIdx);
    _currentSectionIndex = secIdx;
    _currentMenuIndex = _sections[secIdx].menuControllers.length - 1;
  }

  void _handleAddPart() {
    _addTargetSection();
  }

  // 「＋種目」を押せる条件：セクションが選ばれていて、部位が選択済み
  bool _canAddExercise() {
    if (_sections.isEmpty) return false;
    final si = _currentSectionIndex;
    if (si == null) return false;
    if (si < 0 || si >= _sections.length) return false;
    return _sections[si].selectedPart != null;
  }

  // ストップウォッチカード（コンパクト）
  Widget _buildStopwatchCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: StopwatchWidget(
          compact: true,
          controller: _swController, // static で保持
          triangleOnlyStart: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final l10n = AppLocalizations.of(context)!;
    final formattedDate = DateFormat('yyyy/MM/dd').format(widget.selectedDate);

    final media = MediaQuery.of(context);
    final kbInset = media.viewInsets.bottom;   // キーボード高さ
    final safeBottom = media.padding.bottom;   // セーフエリア

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

    final bool isInitialEmptyState =
        _sections.length == 1 && _sections[0].selectedPart == null;

    final bool showWeight = SettingsManager.showWeightInput;
    final int headerCount = (showWeight ? 1 : 0); //  ストップウォッチはリスト外（広告直下）
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        children: [
          const AdBanner(screenName: 'record'),
          const SizedBox(height: 4.0),

          // ストップウォッチ（設定ONのときのみ広告直下に表示）
          Visibility(
            visible: SettingsManager.showStopwatch,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: _buildStopwatchCard(),
            ),
          ),

          Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: (kbInset > 0 ? kbInset + safeBottom + 12 : 12),
              ),
              child: ListView.builder(
                controller: _scrollCtrl,
                primary: false,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                headerCount + _sections.length + (isInitialEmptyState ? 0 : 1),
                itemBuilder: (context, index) {
                  // ① 体重カード
                  if (showWeight && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Card(
                        color: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${l10n.enterYourWeight}${Localizations.localeOf(context).languageCode == "ja" ? "：" : ":"}',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 150,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Focus(
                                        onFocusChange: (has) {
                                          setState(() {
                                            _weightFocused = has;
                                            if (has) _fabOpen = false;
                                          });
                                          _lastInteractionAt = DateTime.now();
                                        },
                                        child: StylishInput(
                                          controller: _weightController,
                                          hint: '',
                                          keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*'),
                                            ),
                                          ],
                                          normalTextColor: colorScheme.onSurface,
                                          suggestionTextColor: colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                          fillColor: colorScheme.surfaceContainer,
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 10),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      SettingsManager.currentUnit,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final secIndex = index - headerCount;

                  // 旧：＋部位のプレース → FAB統合で非表示
                  if (!isInitialEmptyState && secIndex == _sections.length) {
                    return const SizedBox.shrink();
                  }

                  final section = _sections[secIndex];

                  return AnimatedListItem(
                    key: section.key,
                    direction: _firstBuildDone
                        ? AnimationDirection.bottomToTop
                        : AnimationDirection.none,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _touchCard(secIndex, 0);
                        },
                        child: Card(
                          color: colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0), // ゆとりを戻す
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // 部位選択：角丸背景（アニメーションOFF）
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainer,
                                          borderRadius: BorderRadius.circular(22.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                            child: GestureDetector(
                                                                                           key: secIndex == 0 ? _kRecordPart : null,
                                                                                           behavior: HitTestBehavior.opaque,
                                                                                           onTap: () => _showPartPicker(secIndex),
                                                                 child: Padding(
                                                               padding: const EdgeInsets.symmetric(
                                                                     vertical: 14, horizontal: 20),
                                                                 child: Row(
                                                               children: [
                                                                 Expanded(
                                                                   child: Text(
                                                                     section.selectedPart ?? l10n.selectTrainingPart,
                                                                         style: TextStyle(
                                                                       color: (section.selectedPart == null)
                                                                             ? colorScheme.onSurfaceVariant
                                                                             : colorScheme.onSurface,
                                                                         fontSize: 15.0,
                                                                         fontWeight: FontWeight.bold,
                                                                       ),
                                                                     overflow: TextOverflow.ellipsis,
                                                                   ),
                                                      ),
                                                  const Icon(Icons.expand_more, size: 22),
                                                ],
                                              ),
                                            ),
                                          ),


                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16.0), // 間隔を戻す
                                if (section.selectedPart != null)
                                  Column(
                                    children: [
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                        const NeverScrollableScrollPhysics(),
                                        itemCount:
                                        section.menuControllers.length,
                                        itemBuilder: (context, menuIndex) {
                                          final bool isSelected =
                                          (_currentSectionIndex == secIndex &&
                                              _currentMenuIndex ==
                                                  menuIndex);

                                          final borderColor = isSelected
                                              ? (isLight ? kBrandBlue : Colors.white)
                                              : Colors.transparent;
                                          final glowColor = isSelected
                                              ? (isLight
                                              ? kBrandBlue.withOpacity(0.45)
                                              : Colors.white.withOpacity(0.70))
                                              : Colors.black.withOpacity(0.20);

                                          return AnimatedSwitcher(
                                            duration:
                                            const Duration(milliseconds: 220),
                                            switchInCurve: Curves.easeOut,
                                            switchOutCurve: Curves.easeIn,
                                            transitionBuilder:
                                                (child, animation) {
                                              if (!_firstBuildDone) {
                                                return child;
                                              }
                                              final offset = Tween<Offset>(
                                                begin: const Offset(0, -0.10),
                                                end: Offset.zero,
                                              ).animate(animation);
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                    position: offset,
                                                    child: child),
                                              );
                                            },
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _touchCard(
                                                  secIndex, menuIndex),
                                              child: Card(
                                                key: section.menuKeys[menuIndex],
                                                color: colorScheme.surface,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(12.0),
                                                  side: BorderSide(
                                                    color: borderColor,
                                                    width: isSelected ? 1.5 : 0,
                                                  ),
                                                ),
                                                elevation: isSelected ? 10 : 2,
                                                shadowColor: glowColor,
                                                margin:
                                                const EdgeInsets.symmetric(
                                                    vertical: 4.0),
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets.all(10.0),
                                                  child: MenuList(
                                                    key: (secIndex == 0 &&
                                                        menuIndex == 0)
                                                        ? _kExerciseField
                                                        : null,
                                                    menuController: section
                                                        .menuControllers[
                                                    menuIndex],
                                                    removeMenuCallback: () =>
                                                        _removeMenuItem(secIndex,
                                                            menuIndex),
                                                    setCount: section
                                                        .setInputDataList[
                                                    menuIndex]
                                                        .length,
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
                                                    aerobicIsSuggestion: (menuIndex <
                                                        section
                                                            .aerobicSuggestFlags
                                                            .length)
                                                        ? section
                                                        .aerobicSuggestFlags[
                                                    menuIndex]
                                                        : true,
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
                                                    onAnyFieldFocused: () {
                                                      _touchCard(
                                                          secIndex, menuIndex);
                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback(
                                                              (_) {
                                                            if (mounted) {
                                                              _scrollIntoView(
                                                                  secIndex,
                                                                  menuIndex);
                                                            }
                                                          });
                                                    },
                                                    onNameChanged: (prevEmpty,
                                                        nowEmpty) {
                                                      if (prevEmpty &&
                                                          !nowEmpty) {
                                                        _saveAllSectionsData();
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 10.0),
                                      const SizedBox.shrink(), // 旧＋種目ボタンは非表示
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    // ===== ここから “＋” 周り：アニメーションOFF版 =====

    // FAB（体重フォーカス中は無効）※拡大/回転アニメ無し
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

    // セット追加可否（部位未選択は常に不可）
    bool canAddSet() {
      if (_sections.isEmpty) return false;
      final sec = _sections[_currentSectionIndex ?? 0];
      if (sec.selectedPart == null) return false;
      if (sec.selectedPart == l10n.aerobicExercise) return false;
      final menuIdx = _currentMenuIndex ?? 0;
      if (menuIdx >= sec.setInputDataList.length) return false;
      return sec.setInputDataList[menuIdx].length < 10;
    }

    // テキストだけのミニFAB風チップ（アニメなし・赤四角対策でMaterial+Ink）
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
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

    // オーバーレイ（アニメなし）
    final overlay = _fabOpen
        ? Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _fabOpen = false),
        child: Container(color: Colors.black.withOpacity(0.25)),
      ),
    )
        : const SizedBox.shrink();

    // ダイヤル位置
    const double fabSize = 56.0;
    const double fabMargin = 14.0;
    const double gapAboveFab = 24.0;
    final double dialBottom = (safeBottom > 0 ? safeBottom : fabMargin) +
        kbInset +
        fabSize +
        fabMargin +
        gapAboveFab;

    // ダイヤル（アニメなし）
    final dial = Positioned(
      right: 16,
      bottom: dialBottom,
      child: _fabOpen
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          chipAction(l10n.addSet, () => _handleAddSet(l10n), enabled: canAddSet()),
          const SizedBox(height: 8),
          chipAction(l10n.addExercise, _handleAddExercise, enabled: _canAddExercise()),
          const SizedBox(height: 8),
          chipAction(l10n.addPart, _handleAddPart),
        ],
      )
          : const SizedBox.shrink(),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_fabOpen) {
            setState(() => _fabOpen = false);
            return;
          }
          if (!context.mounted) return;
          _saveAllSectionsData();
          Navigator.of(context).pop();
        },
        child: Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              color: colorScheme.onSurface,
              onPressed: _onBackPressed,   // ← さっき追加したやつ
              tooltip: '戻る',
            ),
            title: Text(
              formattedDate,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 19.0,
              ),
            ),
            backgroundColor: colorScheme.surface,
            elevation: 0.0,
            iconTheme: IconThemeData(color: colorScheme.onSurface),
            actions: const [],
          ),
          body: Stack(
            children: [
              body,
              overlay,
              dial,
            ],
          ),
          floatingActionButton: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
              bottom: (kbInset > 0 ? kbInset + 10 : 14),
            ),
            child: fabMain,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
    );
  }

  // 部位選択後のヒント（ここで FAB も案内）
  Future<void> _scheduleHintsAfterPart() async {
    final box = widget.settingsBox;
    final seen = box.get('hint_seen_record_after_part') as bool? ?? false;
    if (seen) return;

    await Future<void>.delayed(const Duration(milliseconds: 16));
    final deadline = DateTime.now().add(const Duration(milliseconds: 600));
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted) return;
      if (_kExerciseField.currentContext != null ||
          _kFabKey.currentContext != null) {
        break;
      }
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

    // 表示順：種目入力 → FAB
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
  int? initialSetCount;

  List<int> menuIds;
  int nextMenuId;

  // 有酸素 per menu
  List<TextEditingController> aerobicDistanceCtrls;
  List<TextEditingController> aerobicDurationCtrls;
  List<bool> aerobicSuggestFlags;

  final Set<int> recentlyAdded = <int>{};

  SectionData({
    required this.key,
    this.selectedPart,
    required this.menuControllers,
    required this.setInputDataList,
    required this.menuKeys,
    this.initialSetCount,
    List<int>? menuIds,
    int? nextMenuId,
    List<TextEditingController>? aerobicDistanceCtrls,
    List<TextEditingController>? aerobicDurationCtrls,
    List<bool>? aerobicSuggestFlags,
  })  : menuIds = menuIds ?? <int>[],
        nextMenuId = nextMenuId ?? 0,
        aerobicDistanceCtrls =
            aerobicDistanceCtrls ?? <TextEditingController>[],
        aerobicDurationCtrls =
            aerobicDurationCtrls ?? <TextEditingController>[],
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
              (_) => SetInputData(
            weightController: TextEditingController(),
            repController: TextEditingController(),
            isSuggestion: true,
          ),
        )
      ]
          : [],
      menuKeys: shouldPopulateDefaults ? [GlobalKey()] : [],
      initialSetCount: initialSetCount,
      menuIds: shouldPopulateDefaults ? [0] : [],
      nextMenuId: shouldPopulateDefaults ? 1 : 0,
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
  final TextEditingController menuController;
  final VoidCallback removeMenuCallback;
  final int setCount;
  final List<SetInputData> setInputDataList;
  final bool isAerobic;
  final TextEditingController distanceController;
  final TextEditingController durationController;
  final bool aerobicIsSuggestion;
  final VoidCallback? onConfirmAerobic;
  final VoidCallback? onAnyFieldFocused;

  // 種目名の空⇔非空遷移を親に通知
  final void Function(bool prevEmpty, bool nowEmpty)? onNameChanged;

  const MenuList({
    super.key,
    required this.menuController,
    required this.removeMenuCallback,
    required this.setCount,
    required this.setInputDataList,
    required this.isAerobic,
    required this.distanceController,
    required this.durationController,
    this.aerobicIsSuggestion = false,
    this.onConfirmAerobic,
    this.onAnyFieldFocused,
    this.onNameChanged,
  });

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _mController = TextEditingController();
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _secController = TextEditingController();

  bool _prevNameEmpty = true;

  @override
  void initState() {
    super.initState();
    _parseDurationAndDistance();
    _kmController.addListener(_updateDistanceController);
    _mController.addListener(_updateDistanceController);
    _minController.addListener(_updateDurationController);
    _secController.addListener(_updateDurationController);

    _prevNameEmpty = widget.menuController.text.trim().isEmpty;
    widget.menuController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _kmController.dispose();
    _mController.dispose();
    _minController.dispose();
    _secController.dispose();
    widget.menuController.removeListener(_handleNameChanged);
    super.dispose();
  }

  void _handleNameChanged() {
    final nowEmpty = widget.menuController.text.trim().isEmpty;
    if (nowEmpty != _prevNameEmpty) {
      widget.onNameChanged?.call(_prevNameEmpty, nowEmpty);
      setState(() {}); // フィールド活性/不活性の見た目更新
      _prevNameEmpty = nowEmpty;
    }
  }

  void _parseDurationAndDistance() {
    final t = widget.durationController.text.split(':');
    if (t.length == 2) {
      _minController.text = t[0];
      _secController.text = t[1];
    } else {
      _minController.text = widget.durationController.text;
      _secController.text = '';
    }

    final d = widget.distanceController.text.split('.');
    if (d.length == 2) {
      _kmController.text = d[0];
      _mController.text = d[1];
    } else {
      _kmController.text = widget.distanceController.text;
      _mController.text = '';
    }
  }

  void _updateDurationController() {
    widget.durationController.text =
    '${_minController.text}:${_secController.text}';
  }

  void _updateDistanceController() {
    widget.distanceController.text =
    '${_kmController.text}.${_mController.text}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final String currentUnit = SettingsManager.currentUnit;

    void notifyFocus(bool has) {
      if (has) widget.onAnyFieldFocused?.call();
    }

    final bool nameFilled = widget.menuController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 種目名
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: notifyFocus,
                  child: StylishInput(
                    controller: widget.menuController,
                    hint: l10n.addExercisePlaceholder,
                    keyboardType: TextInputType.text,
                    inputFormatters: [LengthLimitingTextInputFormatter(25)],
                    normalTextColor: colorScheme.onSurface,
                    suggestionTextColor:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fillColor: colorScheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.removeMenuCallback,
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
          const SizedBox(height: 12.0), // ゆとりを戻す（種目⇔セット）

          // 入力群
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: widget.isAerobic
                ? Column(
              children: [
                // 距離
                Row(
                  children: [
                    Text(
                      l10n.distance,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
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
                        child: StylishInput(
                          controller: _kmController,
                          hint: '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          normalTextColor: widget.aerobicIsSuggestion
                              ? colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                          suggestionTextColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                          fillColor: colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    Text(
                      ' ${l10n.km} ',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
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
                        child: StylishInput(
                          controller: _mController,
                          hint: '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          normalTextColor: widget.aerobicIsSuggestion
                              ? colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                          suggestionTextColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                          fillColor: colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    Text(
                      ' ${l10n.m}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // ゆとりを戻す
                // 時間
                Row(
                  children: [
                    Text(
                      l10n.time,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
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
                        child: StylishInput(
                          controller: _minController,
                          hint: '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          normalTextColor: widget.aerobicIsSuggestion
                              ? colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                          suggestionTextColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                          fillColor: colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    Text(
                      ' ${l10n.min} ',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
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
                        child: StylishInput(
                          controller: _secController,
                          hint: '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          normalTextColor: widget.aerobicIsSuggestion
                              ? colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                          suggestionTextColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                          fillColor: colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    Text(
                      ' ${l10n.sec}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            )
                : Opacity(
              opacity: nameFilled ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !nameFilled, // 種目名が空の間は操作不可
                child: Column(
                  children: List.generate(
                    min(10, widget.setInputDataList.length),
                        (setIndex) {
                      final set = widget.setInputDataList[setIndex];
                      return Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 6.0), // ゆとりを戻す
                        child: Row(
                          children: [
                            Text(
                              '${setIndex + 1}${l10n.sets}：',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13.0,
                              ),
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
                                child: StylishInput(
                                  controller: set.weightController,
                                  hint: '',
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  normalTextColor: set.isSuggestion
                                      ? colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5)
                                      : colorScheme.onSurface,
                                  suggestionTextColor: colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fillColor: colorScheme.surfaceContainer,
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  textAlign: TextAlign.right,
                                  onChanged: (text) {
                                    setState(() {
                                      if (text.isNotEmpty &&
                                          set.isSuggestion) {
                                        set.isSuggestion = false;
                                      } else if (text.isEmpty &&
                                          !set.isSuggestion &&
                                          set.repController.text
                                              .isEmpty) {
                                        final anyOther = widget
                                            .setInputDataList
                                            .any(
                                              (s) =>
                                          s != set &&
                                              (s.weightController.text
                                                  .isNotEmpty ||
                                                  s.repController.text
                                                      .isNotEmpty),
                                        );
                                        if (!anyOther) {
                                          set.isSuggestion = true;
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                            Text(
                              ' ${currentUnit == 'kg' ? l10n.kg : l10n.lbs} ',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
                              ),
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
                                child: StylishInput(
                                  controller: set.repController,
                                  hint: '',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter
                                        .digitsOnly
                                  ],
                                  normalTextColor: set.isSuggestion
                                      ? colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5)
                                      : colorScheme.onSurface,
                                  suggestionTextColor: colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                  fillColor: colorScheme.surfaceContainer,
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  textAlign: TextAlign.right,
                                  onChanged: (text) {
                                    setState(() {
                                      if (text.isNotEmpty &&
                                          set.isSuggestion) {
                                        set.isSuggestion = false;
                                      } else if (text.isEmpty &&
                                          !set.isSuggestion &&
                                          set.weightController.text
                                              .isEmpty) {
                                        final anyOther = widget
                                            .setInputDataList
                                            .any(
                                              (s) =>
                                          s != set &&
                                              (s.weightController.text
                                                  .isNotEmpty ||
                                                  s.repController.text
                                                      .isNotEmpty),
                                        );
                                        if (!anyOther) {
                                          set.isSuggestion = true;
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                            Text(
                              ' ${l10n.reps}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13.0,
                                fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
