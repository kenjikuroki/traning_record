// lib/screens/record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/custom_widgets.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import 'calendar_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';

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
  bool _firstBuildDone = false;

  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];
  List<SectionData> _sections = [];
  int _currentSetCount = 3;

  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _firstBuildDone = true);
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

  // ★ 共通：遷移前にキーボードを完全に閉じる
  Future<void> _closeKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    // 一瞬だけ待ってレイアウトの跳ね返りを回避（1フレーム相当）
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

      // 少なくとも1行は作る
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
          // 有酸素：距離・時間
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
          // 筋トレ用の配列は空1件（未使用だが整合のため）
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
          // ★ 種目名が空なら何も保存しない（距離/時間が入っていても無視）
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
        // ★ 種目が空の新規行 → 距離・時間も空（未確定）
        section.aerobicDistanceCtrls.add(TextEditingController());
        section.aerobicDurationCtrls.add(TextEditingController());
        section.aerobicSuggestFlags.add(true);
        section.setInputDataList.add(<SetInputData>[]);
      } else {
        final sets = _currentSetCount;
        final row = List<SetInputData>.generate(
          sets,
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
        section.initialSetCount = max(section.initialSetCount ?? 0, sets);
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

        // 有酸素の per menu も同期削除
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
    });
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

    return PopScope(
      // ★ 物理/ジェスチャーバックもここで一旦捕まえて、先にキーボードを閉じる
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _closeKeyboard();
        if (!context.mounted) return;
        _saveAllSectionsData();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          // ★ AppBarの戻るもフックして、先にキーボードを閉じる
          leading: BackButton(
            onPressed: () async {
              await _closeKeyboard();
              if (!context.mounted) return;
              _saveAllSectionsData();
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            formattedDate,
            style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20.0),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const AdBanner(screenName: 'record'),
              const SizedBox(height: 8.0),
              Expanded(
                child: ListView.builder(
                  primary: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: headerCount +
                      _sections.length +
                      (isInitialEmptyState ? 0 : 1),
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
                              mainAxisAlignment:
                                  MainAxisAlignment.center, // カード内を中央寄せ
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
                                          normalTextColor:
                                              colorScheme.onSurface,
                                          suggestionTextColor: colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                          fillColor:
                                              colorScheme.surfaceContainer,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 8, horizontal: 10),
                                          textAlign: TextAlign.right, // 入力値は右寄せ
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

                    if (!isInitialEmptyState && secIndex == _sections.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: CircularAddButtonWithText(
                            label: l10n.addPart,
                            onPressed: _addTargetSection,
                            normalBgColorOverride: partNormalBgColor,
                            pressedBgColorOverride: partPressedBgColor,
                            textColorOverride: partTextColor,
                            accentColorOverride: partAccentColor,
                          ),
                        ),
                      );
                    }

                    final section = _sections[secIndex];

                    return AnimatedListItem(
                      key: section.key,
                      direction: _firstBuildDone
                          ? AnimationDirection.bottomToTop
                          : AnimationDirection.none,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                                        decoration: InputDecoration(
                                          hintText: l10n.selectTrainingPart,
                                          hintStyle: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 14.0),
                                          filled: true,
                                          fillColor:
                                              colorScheme.surfaceContainer,
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
                                        value: section.selectedPart,
                                        items: _filteredBodyParts
                                            .map(
                                              (p) => DropdownMenuItem(
                                                value: p,
                                                child: Text(
                                                  p,
                                                  style: TextStyle(
                                                    color:
                                                        colorScheme.onSurface,
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
                                            _clearSectionControllersAndMaps(
                                                section);

                                            if (section.selectedPart != null) {
                                              final current =
                                                  section.selectedPart!;
                                              final originalPart =
                                                  _getOriginalPartName(
                                                      context, current);
                                              final dateKey = _getDateKey(
                                                  widget.selectedDate);
                                              final record = widget.recordsBox
                                                  .get(dateKey);

                                              final recList =
                                                  record?.menus[originalPart] ??
                                                      <MenuData>[];
                                              final rawLU = widget
                                                  .lastUsedMenusBox
                                                  .get(originalPart);
                                              final luList = (rawLU is List)
                                                  ? rawLU
                                                      .whereType<MenuData>()
                                                      .toList()
                                                  : <MenuData>[];

                                              final Map<String, MenuData>
                                                  recBy = {
                                                for (final m in recList)
                                                  m.name: m
                                              };
                                              final Map<String, MenuData> luBy =
                                                  {
                                                for (final m in luList)
                                                  m.name: m
                                              };

                                              final List<String> names = [
                                                ...recList.map((m) => m.name),
                                                ...luList
                                                    .where((m) => !recBy
                                                        .containsKey(m.name))
                                                    .map((m) => m.name),
                                              ];
                                              if (names.isEmpty) names.add('');

                                              final l10n =
                                                  AppLocalizations.of(context)!;
                                              final isAerobic = current ==
                                                  l10n.aerobicExercise;

                                              for (final name in names) {
                                                final rec = recBy[name];
                                                final lu = luBy[name];

                                                section.menuControllers.add(
                                                    TextEditingController(
                                                        text: name));
                                                section.menuKeys
                                                    .add(UniqueKey());
                                                section.menuIds
                                                    .add(section.nextMenuId++);

                                                if (isAerobic) {
                                                  final String dist = (rec
                                                              ?.distance
                                                              ?.trim()
                                                              .isNotEmpty ??
                                                          false)
                                                      ? rec!.distance!.trim()
                                                      : (lu?.distance?.trim() ??
                                                          '');
                                                  final String dura = (rec
                                                              ?.duration
                                                              ?.trim()
                                                              .isNotEmpty ??
                                                          false)
                                                      ? rec!.duration!.trim()
                                                      : (lu?.duration?.trim() ??
                                                          '');
                                                  final bool isSug = !(rec
                                                              ?.distance
                                                              ?.trim()
                                                              .isNotEmpty ==
                                                          true ||
                                                      rec?.duration
                                                              ?.trim()
                                                              .isNotEmpty ==
                                                          true);

                                                  section.aerobicDistanceCtrls
                                                      .add(
                                                          TextEditingController(
                                                              text: dist));
                                                  section.aerobicDurationCtrls
                                                      .add(
                                                          TextEditingController(
                                                              text: dura));
                                                  section.aerobicSuggestFlags
                                                      .add(isSug);
                                                  section.setInputDataList
                                                      .add(<SetInputData>[]);
                                                } else {
                                                  final int recLen = rec == null
                                                      ? 0
                                                      : min(rec.weights.length,
                                                          rec.reps.length);
                                                  final int luLen = lu == null
                                                      ? 0
                                                      : min(lu.weights.length,
                                                          lu.reps.length);
                                                  final int mergedLen = max(
                                                      _currentSetCount,
                                                      max(recLen, luLen));

                                                  final row = <SetInputData>[];
                                                  for (int i = 0;
                                                      i < mergedLen;
                                                      i++) {
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
                                                          TextEditingController(
                                                              text: w),
                                                      repController:
                                                          TextEditingController(
                                                              text: r),
                                                      isSuggestion:
                                                          isSuggestion,
                                                    ));
                                                  }
                                                  section.setInputDataList
                                                      .add(row);
                                                  section.initialSetCount = max(
                                                      section.initialSetCount ??
                                                          0,
                                                      mergedLen);
                                                }
                                              }
                                            } else {
                                              section.initialSetCount =
                                                  _currentSetCount;
                                            }
                                          });
                                        },
                                        dropdownColor:
                                            colorScheme.surfaceContainer,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(15.0),
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
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount:
                                            section.menuControllers.length,
                                        itemBuilder: (context, menuIndex) {
                                          return AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            switchInCurve: Curves.easeOut,
                                            switchOutCurve: Curves.easeIn,
                                            transitionBuilder:
                                                (child, animation) {
                                              if (!_firstBuildDone) {
                                                return child;
                                              }
                                              final offset = Tween<Offset>(
                                                      begin: const Offset(
                                                          0, -0.12),
                                                      end: Offset.zero)
                                                  .animate(animation);
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                    position: offset,
                                                    child: child),
                                              );
                                            },
                                            child: Card(
                                              key: ValueKey(
                                                  'menu_${section.menuIds[menuIndex]}'),
                                              color: colorScheme.surface,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0)),
                                              elevation: 2,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: MenuList(
                                                  menuController:
                                                      section.menuControllers[
                                                          menuIndex],
                                                  removeMenuCallback: () =>
                                                      _removeMenuItem(
                                                          secIndex, menuIndex),
                                                  setCount: section
                                                      .setInputDataList[
                                                          menuIndex]
                                                      .length,
                                                  setInputDataList:
                                                      section.setInputDataList[
                                                          menuIndex],
                                                  isAerobic:
                                                      section.selectedPart ==
                                                          l10n.aerobicExercise,
                                                  // 有酸素は per menu のコントローラを渡す
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
                                                            menuIndex] = false;
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16.0),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: CircularAddButtonWithText(
                                          label: l10n.addExercise,
                                          onPressed: () =>
                                              _addMenuItem(secIndex),
                                          normalBgColorOverride:
                                              partNormalBgColor,
                                          pressedBgColorOverride:
                                              partPressedBgColor,
                                          textColorOverride: partTextColor,
                                          accentColorOverride: partAccentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
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
        ),
        bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today), label: 'Calendar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.edit_note), label: 'Record'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart), label: 'Graph'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings), label: 'Settings'),
            ],
            currentIndex: 1,
            selectedItemColor: colorScheme.primary,
            unselectedItemColor: colorScheme.onSurfaceVariant,
            backgroundColor: colorScheme.surface,
            onTap: (index) async {
              if (index == 1) return;
              // ★ 遷移前に必ずキーボードを閉じる

              final nav = Navigator.of(context);

              await _closeKeyboard();
              _saveAllSectionsData();

              // ★ await 後に context を使う前にチェック（lint対策）
              if (!context.mounted) return;

              switch (index) {
                case 0: // Calendar
                  nav.push(
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
                  break;

                case 2: // Graph
                  nav.push(
                    MaterialPageRoute(
                      builder: (context) => GraphScreen(
                        recordsBox: widget.recordsBox,
                        lastUsedMenusBox: widget.lastUsedMenusBox,
                        settingsBox: widget.settingsBox,
                        setCountBox: widget.setCountBox,
                      ),
                    ),
                  );
                  break;

                case 3: // Settings
                  nav.push(
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        recordsBox: widget.recordsBox,
                        lastUsedMenusBox: widget.lastUsedMenusBox,
                        settingsBox: widget.settingsBox,
                        setCountBox: widget.setCountBox,
                      ),
                    ),
                  );
                  break;
              }
            }),
      ),
    );
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

  // ★ 有酸素はメニューごとにコントローラ
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
  });

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _mController = TextEditingController();
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _secController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _parseDurationAndDistance();
    _kmController.addListener(_updateDistanceController);
    _mController.addListener(_updateDistanceController);
    _minController.addListener(_updateDurationController);
    _secController.addListener(_updateDurationController);
  }

  @override
  void dispose() {
    _kmController.dispose();
    _mController.dispose();
    _minController.dispose();
    _secController.dispose();
    super.dispose();
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 種目名
          Row(
            children: [
              Expanded(
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
              TextButton(
                onPressed: widget.removeMenuCallback,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                ),
                child: Icon(Icons.close,
                    color: colorScheme.onSurfaceVariant, size: 16),
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
                      Row(
                        children: [
                          Text(
                            l10n.distance,
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Focus(
                              onFocusChange: (has) {
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
                                fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            flex: 2,
                            child: Focus(
                              onFocusChange: (has) {
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
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            l10n.time,
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Focus(
                              onFocusChange: (has) {
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
                                fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            flex: 2,
                            child: Focus(
                              onFocusChange: (has) {
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
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: List.generate(
                      min(widget.setCount, widget.setInputDataList.length),
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
                                    fontSize: 14.0),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Focus(
                                  onFocusChange: (has) {
                                    if (has && set.isSuggestion) {
                                      setState(() => set.isSuggestion = false);
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
                                          RegExp(r'^\d*\.?\d*')),
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
                                        if (text.isNotEmpty &&
                                            set.isSuggestion) {
                                          set.isSuggestion = false;
                                        } else if (text.isEmpty &&
                                            !set.isSuggestion &&
                                            set.repController.text.isEmpty) {
                                          final anyOther =
                                              widget.setInputDataList.any(
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
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Focus(
                                  onFocusChange: (has) {
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
                                        if (text.isNotEmpty &&
                                            set.isSuggestion) {
                                          set.isSuggestion = false;
                                        } else if (text.isEmpty &&
                                            !set.isSuggestion &&
                                            set.weightController.text.isEmpty) {
                                          final anyOther =
                                              widget.setInputDataList.any(
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
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
