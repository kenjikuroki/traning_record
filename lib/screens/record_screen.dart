// lib/screens/record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/custom_widgets.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import 'calendar_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';
import '../widgets/coach_bubble.dart';

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

class _RecordScreenState extends State<RecordScreen> {
  // CoachBubble anchors
  final GlobalKey _kRecordPart = GlobalKey();      // 部位ドロップダウン（初回ヒント用）
  final GlobalKey _kExerciseField = GlobalKey();   // 種目TextField（選択後ヒント）
  final GlobalKey _kOpenSettingsBtn = GlobalKey(); // 設定へボタン
  final GlobalKey _kFabKey = GlobalKey();          // FAB

  bool _firstBuildDone = false;

  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];
  List<SectionData> _sections = [];
  int _currentSetCount = 3;

  // FAB 対象
  int? _currentSectionIndex;
  int? _currentMenuIndex;

  bool _fabOpen = false;

  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // 初回ビルド完了フラグ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _firstBuildDone = true);
    });

    // 初回表示ヒント：部位だけ（FABヒントは出さない）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final box = widget.settingsBox;
      final seen = box.get('hint_seen_record') as bool? ?? false;
      if (seen) return;

      final l10n = AppLocalizations.of(context)!;
      await CoachBubbleController.showSequence(
        context: context,
        anchors: [_kRecordPart],
        messages: [l10n.hintRecordSelectPart],
        semanticsPrefix: l10n.coachBubbleSemantic,
      );
      await box.put('hint_seen_record', true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  @override
  void dispose() {
    for (var section in _sections) {
      section.dispose();
    }
    _sections.clear();
    _weightController.dispose();
    super.dispose();
  }

  // 共通：遷移前にキーボードを完全に閉じる
  Future<void> _closeKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 16));
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

    if (record == null || record.menus.isEmpty) {
      _sections.add(SectionData.createEmpty(_currentSetCount,
          shouldPopulateDefaults: false));
      _sections[0].initialSetCount = _currentSetCount;
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
          key: UniqueKey(),
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
        section.menuKeys.add(UniqueKey());
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
          section.initialSetCount =
              max(section.initialSetCount ?? 0, mergedLen);
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

    setState(() {});
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

          // lastUsed には常に保存
          listForLastUsed.add(MenuData(
            name: name,
            weights: const <String>[],
            reps: const <String>[],
            distance: distance,
            duration: duration,
          ));

          // Record は未確定を除外
          if (!isSug &&
              ((distance.trim().isNotEmpty) || (duration.trim().isNotEmpty))) {
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
            listForRecord.add(MenuData(
                name: name, weights: weightsConfirmed, reps: repsConfirmed));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.exerciseLimitReached)));
      return;
    }

    setState(() {
      final nameCtrl = TextEditingController();
      section.menuControllers.add(nameCtrl);
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

  // 有酸素：同名行をもう1本（最大10本）
  void _addAerobicSetRow(int sectionIndex, int menuIndex) {
    final section = _sections[sectionIndex];
    if (menuIndex < 0 || menuIndex >= section.menuControllers.length) return;
    final currentName = section.menuControllers[menuIndex].text;

    int sameCount = 0;
    for (final ctrl in section.menuControllers) {
      if (ctrl.text == currentName) sameCount++;
    }
    if (sameCount >= 10) return;

    final insertAt = menuIndex + 1;
    setState(() {
      section.menuControllers.insert(insertAt, TextEditingController(text: currentName));
      section.menuKeys.insert(insertAt, UniqueKey());
      section.menuIds.insert(insertAt, section.nextMenuId++);

      section.aerobicDistanceCtrls.insert(insertAt, TextEditingController());
      section.aerobicDurationCtrls.insert(insertAt, TextEditingController());
      section.aerobicSuggestFlags.insert(insertAt, true);

      if (section.setInputDataList.length < section.menuControllers.length) {
        section.setInputDataList.insert(insertAt, <SetInputData>[]);
      }
    });
  }

  void _addTargetSection() {
    final l10n = AppLocalizations.of(context)!;

    if (_sections.length >= 10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.partLimitReached)));
      return;
    }

    setState(() {
      final newSection = SectionData.createEmpty(_currentSetCount,
          shouldPopulateDefaults: true);
      _sections.add(newSection);
      _currentSectionIndex = _sections.length - 1;
      _currentMenuIndex = 0;
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
              child:
              Text(l10n.delete, style: const TextStyle(color: Colors.red))),
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

  // タップ/フォーカスで対象更新
  void _touchCard(int sectionIndex, int menuIndex) {
    _currentSectionIndex = sectionIndex;
    _currentMenuIndex = menuIndex;
  }

  // FAB アクション
  void _handleAddSet(AppLocalizations l10n) {
    if (_sections.isEmpty) return;
    final secIdx = _currentSectionIndex ?? 0;
    final menuIdx = _currentMenuIndex ?? 0;
    final section = _sections[secIdx];

    if (section.selectedPart == l10n.aerobicExercise) {
      _addAerobicSetRow(secIdx, menuIdx);
    } else {
      _addOneSetAt(secIdx, menuIdx);
    }
  }

  void _handleAddExercise() {
    if (_sections.isEmpty) {
      _addTargetSection();
      return;
    }
    final secIdx = _currentSectionIndex ?? 0;
    _addMenuItem(secIdx);
    _currentSectionIndex = secIdx;
    _currentMenuIndex = _sections[secIdx].menuControllers.length - 1;
  }

  void _handleAddPart() {
    _addTargetSection();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final l10n = AppLocalizations.of(context)!;
    final formattedDate = DateFormat('yyyy/MM/dd').format(widget.selectedDate);

    final Color partNormalBgColor =
    isLight ? const Color(0xFF333333) : const Color(0xFF2C2F33);
    final Color partPressedBgColor =
    isLight ? const Color(0xFF1A1A1A) : const Color(0xFF383C40);
    final Color partTextColor =
    isLight ? Colors.white : const Color(0xFFCCCCCC);
    final Color partAccentColor = const Color(0xFF60A5FA);

    final bool isInitialEmptyState =
        _sections.length == 1 && _sections[0].selectedPart == null;

    final bool showWeight = SettingsManager.showWeightInput;
    final int headerCount = showWeight ? 1 : 0;

    final body = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const AdBanner(screenName: 'record'),
          const SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              primary: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount:
              headerCount + _sections.length + (isInitialEmptyState ? 0 : 1),
              itemBuilder: (context, index) {
                if (showWeight && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${l10n.enterYourWeight}${Localizations.localeOf(context).languageCode == "ja" ? "：" : ":"}',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 160,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: StylishInput(
                                      controller: _weightController,
                                      hint: '',
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d*')),
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
                                  const SizedBox(width: 8),
                                  Text(
                                    SettingsManager.currentUnit,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13.0,
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
                  direction:
                  _firstBuildDone ? AnimationDirection.bottomToTop : AnimationDirection.none,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _currentSectionIndex = secIndex;
                        _currentMenuIndex = 0;
                      },
                      child: Card(
                        color: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      key: _kRecordPart,
                                      decoration: InputDecoration(
                                        hintText: l10n.selectTrainingPart,
                                        hintStyle: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 14.0),
                                        filled: true,
                                        fillColor: colorScheme.surfaceContainer,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(25.0),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(25.0),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(25.0),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 20),
                                      ),
                                      initialValue: section.selectedPart,
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
                                        setState(() {
                                          section.selectedPart = value;
                                          section.menuKeys.clear();
                                          section.menuIds.clear();
                                          section.nextMenuId = 0;
                                          _clearSectionControllersAndMaps(section);

                                          if (section.selectedPart != null) {
                                            final current = section.selectedPart!;
                                            final originalPart =
                                            _getOriginalPartName(context, current);
                                            final dateKey = _getDateKey(widget.selectedDate);
                                            final record =
                                            widget.recordsBox.get(dateKey);

                                            final recList =
                                                record?.menus[originalPart] ?? <MenuData>[];
                                            final rawLU =
                                            widget.lastUsedMenusBox.get(originalPart);
                                            final luList = (rawLU is List)
                                                ? rawLU.whereType<MenuData>().toList()
                                                : <MenuData>[];

                                            final Map<String, MenuData> recBy = {
                                              for (final m in recList) m.name: m
                                            };
                                            final Map<String, MenuData> luBy = {
                                              for (final m in luList) m.name: m
                                            };

                                            final List<String> names = [
                                              ...recList.map((m) => m.name),
                                              ...luList
                                                  .where((m) => !recBy.containsKey(m.name))
                                                  .map((m) => m.name),
                                            ];
                                            if (names.isEmpty) names.add('');

                                            final l10n = AppLocalizations.of(context)!;
                                            final isAerobic =
                                                current == l10n.aerobicExercise;

                                            for (final name in names) {
                                              final rec = recBy[name];
                                              final lu = luBy[name];

                                              section.menuControllers
                                                  .add(TextEditingController(text: name));
                                              section.menuKeys.add(UniqueKey());
                                              section.menuIds.add(section.nextMenuId++);

                                              if (isAerobic) {
                                                final String dist =
                                                (rec?.distance?.trim().isNotEmpty ?? false)
                                                    ? rec!.distance!.trim()
                                                    : (lu?.distance?.trim() ?? '');
                                                final String dura =
                                                (rec?.duration?.trim().isNotEmpty ?? false)
                                                    ? rec!.duration!.trim()
                                                    : (lu?.duration?.trim() ?? '');
                                                final bool isSug = !(rec?.distance
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                    true ||
                                                    rec?.duration?.trim().isNotEmpty == true);

                                                section.aerobicDistanceCtrls.add(
                                                    TextEditingController(text: dist));
                                                section.aerobicDurationCtrls.add(
                                                    TextEditingController(text: dura));
                                                section.aerobicSuggestFlags.add(isSug);
                                                section.setInputDataList.add(<SetInputData>[]);
                                              } else {
                                                final int recLen = rec == null
                                                    ? 0
                                                    : min(rec.weights.length, rec.reps.length);
                                                final int luLen = lu == null
                                                    ? 0
                                                    : min(lu.weights.length, lu.reps.length);
                                                final int mergedLen =
                                                max(_currentSetCount, max(recLen, luLen));

                                                final row = <SetInputData>[];
                                                for (int i = 0; i < mergedLen; i++) {
                                                  String w = '';
                                                  String r = '';
                                                  bool isSuggestion = true;

                                                  if (i < recLen) {
                                                    w = rec!.weights[i];
                                                    r = rec.reps[i];
                                                    if (w.trim().isNotEmpty ||
                                                        r.trim().isNotEmpty) {
                                                      isSuggestion = false;
                                                    }
                                                  } else if (i < luLen) {
                                                    w = lu!.weights[i];
                                                    r = lu.reps[i];
                                                    isSuggestion = true;
                                                  }
                                                  row.add(SetInputData(
                                                    weightController:
                                                    TextEditingController(text: w),
                                                    repController:
                                                    TextEditingController(text: r),
                                                    isSuggestion: isSuggestion,
                                                  ));
                                                }
                                                section.setInputDataList.add(row);
                                                section.initialSetCount =
                                                    max(section.initialSetCount ?? 0, mergedLen);
                                              }
                                            }
                                          } else {
                                            section.initialSetCount = _currentSetCount;
                                          }
                                        });
                                        _scheduleHintsAfterPart(); // ここでFABヒントを含めて案内
                                      },
                                      dropdownColor: colorScheme.surfaceContainer,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16.0),
                              if (section.selectedPart != null)
                                Column(
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: section.menuControllers.length,
                                      itemBuilder: (context, menuIndex) {
                                        return AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 250),
                                          switchInCurve: Curves.easeOut,
                                          switchOutCurve: Curves.easeIn,
                                          transitionBuilder: (child, animation) {
                                            if (!_firstBuildDone) return child;
                                            final offset = Tween<Offset>(
                                              begin: const Offset(0, -0.12),
                                              end: Offset.zero,
                                            ).animate(animation);
                                            return FadeTransition(
                                              opacity: animation,
                                              child:
                                              SlideTransition(position: offset, child: child),
                                            );
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _touchCard(secIndex, menuIndex),
                                            child: Card(
                                              key: ValueKey(
                                                  'menu_${section.menuIds[menuIndex]}'),
                                              color: colorScheme.surface,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(12.0)),
                                              elevation: 2,
                                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: MenuList(
                                                  key: menuIndex == 0 ? _kExerciseField : null,
                                                  menuController:
                                                  section.menuControllers[menuIndex],
                                                  removeMenuCallback: () =>
                                                      _removeMenuItem(secIndex, menuIndex),
                                                  setCount: section
                                                      .setInputDataList[menuIndex].length,
                                                  setInputDataList:
                                                  section.setInputDataList[menuIndex],
                                                  isAerobic: section.selectedPart ==
                                                      l10n.aerobicExercise,
                                                  distanceController: (menuIndex <
                                                      section.aerobicDistanceCtrls.length)
                                                      ? section.aerobicDistanceCtrls[menuIndex]
                                                      : TextEditingController(),
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
                                                  onAnyFieldFocused: () =>
                                                      _touchCard(secIndex, menuIndex),
                                                  // 追加：種目名の変化通知（空→非空で保存）
                                                  onNameChanged: (prevEmpty, nowEmpty) {
                                                    if (prevEmpty && !nowEmpty) {
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
                                    const SizedBox(height: 16.0),
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
        ],
      ),
    );

    // FAB（スピードダイヤル：テキストのみ）
    final fabMain = FloatingActionButton(
      key: _kFabKey,
      onPressed: () => setState(() => _fabOpen = !_fabOpen),
      backgroundColor: colorScheme.primary,
      child: AnimatedRotation(
        turns: _fabOpen ? .125 : 0,
        duration: const Duration(milliseconds: 180),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      tooltip: l10n.openAddMenu,
    );

    // テキストだけのチップボタン
    Widget chipAction(String label, VoidCallback onTap, {bool enabled = true}) {
      return Opacity(
        opacity: enabled ? 1 : 0.4,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled
              ? () {
            setState(() => _fabOpen = false);
            onTap();
          }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    bool canAddSet() {
      if (_sections.isEmpty) return false;
      final sec = _sections[_currentSectionIndex ?? 0];
      final l10n = AppLocalizations.of(context)!;
      if (sec.selectedPart == l10n.aerobicExercise) {
        final menuIdx = _currentMenuIndex ?? 0;
        if (menuIdx >= sec.menuControllers.length) return false;
        final name = sec.menuControllers[menuIdx].text;
        int same = 0;
        for (final c in sec.menuControllers) {
          if (c.text == name) same++;
        }
        return same < 10;
      } else {
        final menuIdx = _currentMenuIndex ?? 0;
        if (menuIdx >= sec.setInputDataList.length) return false;
        return sec.setInputDataList[menuIdx].length < 10;
      }
    }

    final overlay = _fabOpen
        ? Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _fabOpen = false),
        child: Container(color: Colors.black.withOpacity(0.25)),
      ),
    )
        : const SizedBox.shrink();

    final dial = _fabOpen
        ? Positioned(
      right: 16,
      bottom: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          chipAction(l10n.addSet, () => _handleAddSet(l10n), enabled: canAddSet()),
          chipAction(l10n.addExercise, _handleAddExercise),
          chipAction(l10n.addPart, _handleAddPart),
        ],
      ),
    )
        : const SizedBox.shrink();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_fabOpen) {
          setState(() => _fabOpen = false);
          return;
        }
        await _closeKeyboard();
        if (!context.mounted) return;
        _saveAllSectionsData();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            formattedDate,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          actions: [
            IconButton(
              key: _kOpenSettingsBtn,
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await _closeKeyboard();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      recordsBox: widget.recordsBox,
                      lastUsedMenusBox: widget.lastUsedMenusBox,
                      settingsBox: widget.settingsBox,
                      setCountBox: widget.setCountBox,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            body,
            overlay,
            dial,
          ],
        ),
        floatingActionButton: fabMain,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
          _kOpenSettingsBtn.currentContext != null ||
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

    // 表示順：種目入力 → FAB → 設定
    addIfVisible(_kExerciseField, l10n.hintRecordExerciseField);
    addIfVisible(_kFabKey, l10n.hintRecordFab);
    addIfVisible(_kOpenSettingsBtn, l10n.hintRecordOpenSettings);

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
        aerobicDistanceCtrls = aerobicDistanceCtrls ?? <TextEditingController>[],
        aerobicDurationCtrls = aerobicDurationCtrls ?? <TextEditingController>[],
        aerobicSuggestFlags = aerobicSuggestFlags ?? <bool>[];

  factory SectionData.createEmpty(int initialSetCount,
      {required bool shouldPopulateDefaults}) {
    return SectionData(
      key: UniqueKey(),
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
      menuKeys: shouldPopulateDefaults ? [UniqueKey()] : [],
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

  // 追加：種目名の空⇔非空遷移を親に通知
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          const SizedBox(height: 12.0),

          // 入力群
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
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
                    const SizedBox(width: 8),
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
                const SizedBox(height: 8),
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
                    const SizedBox(width: 8),
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
                ignoring: !nameFilled, // ★ 種目名が空の間は操作不可
                child: Column(
                  children: List.generate(
                    min(10, widget.setInputDataList.length),
                        (setIndex) {
                      final set = widget.setInputDataList[setIndex];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Text(
                              '${setIndex + 1}${l10n.sets}：',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 14.0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Focus(
                                onFocusChange: (has) {
                                  notifyFocus(has);
                                  if (has && set.isSuggestion) {
                                    setState(() => set.isSuggestion = false);
                                  }
                                },
                                child: StylishInput(
                                  controller: set.weightController,
                                  hint: '',
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  textAlign: TextAlign.right,
                                  onChanged: (text) {
                                    setState(() {
                                      if (text.isNotEmpty && set.isSuggestion) {
                                        set.isSuggestion = false;
                                      } else if (text.isEmpty &&
                                          !set.isSuggestion &&
                                          set.repController.text.isEmpty) {
                                        final anyOther = widget.setInputDataList.any(
                                              (s) =>
                                          s != set &&
                                              (s.weightController.text.isNotEmpty ||
                                                  s.repController.text.isNotEmpty),
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
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Focus(
                                onFocusChange: (has) {
                                  notifyFocus(has);
                                  if (has && set.isSuggestion) {
                                    setState(() => set.isSuggestion = false);
                                  }
                                },
                                child: StylishInput(
                                  controller: set.repController,
                                  hint: '',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  normalTextColor: set.isSuggestion
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
                                  onChanged: (text) {
                                    setState(() {
                                      if (text.isNotEmpty && set.isSuggestion) {
                                        set.isSuggestion = false;
                                      } else if (text.isEmpty &&
                                          !set.isSuggestion &&
                                          set.weightController.text.isEmpty) {
                                        final anyOther = widget.setInputDataList.any(
                                              (s) =>
                                          s != set &&
                                              (s.weightController.text.isNotEmpty ||
                                                  s.repController.text.isNotEmpty),
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
                                fontSize: 14.0,
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
