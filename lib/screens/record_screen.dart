// lib/screens/record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../models/record_models.dart';
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
  // 入場時はアニメ無しにするためのフラグ
  bool _firstBuildDone = false;

  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];
  List<SectionData> _sections = [];
  int _currentSetCount = 3;

  final TextEditingController _weightController = TextEditingController();
  // 有酸素（距離・時間）は簡易対応（1セクション想定）
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初回フレーム終了後に true にして入場時アニメを抑制
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
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
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

    // 記録にある部位は必ず候補に含める
    for (final originalPart in partsInRecord) {
      final translated = _translatePartToLocale(context, originalPart);
      if (!_filteredBodyParts.contains(translated)) {
        _filteredBodyParts.add(translated);
      }
    }

    // 本来の順に並べる
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

    // 体重の復元
    if (record?.weight != null) {
      _weightController.text = record!.weight.toString();
    } else {
      _weightController.clear();
    }

    if (record == null || record.menus.isEmpty) {
      // 空のセクション1つ（ドロップダウンのみ）
      _sections.add(SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false));
      _sections[0].initialSetCount = _currentSetCount;
      setState(() {});
      return;
    }

    // 記録 + lastUsed をマージして表示
    final Map<String, List<MenuData>> dataToLoad = {};
    final Set<String> partsFromRecords = {};

    record.menus.forEach((part, list) {
      dataToLoad[part] = List.from(list);
      partsFromRecords.add(part);
    });

    final List<String> lastUsedParts = widget.lastUsedMenusBox.keys.cast<String>().toList();
    for (final part in lastUsedParts) {
      final dynamic rawList = widget.lastUsedMenusBox.get(part);
      if (rawList is List) {
        final lastUsedMenus = rawList.whereType<MenuData>().toList();
        if (partsFromRecords.contains(part)) {
          final combined = List<MenuData>.from(dataToLoad[part] ?? []);
          for (final m in lastUsedMenus) {
            if (!combined.any((x) => x.name == m.name)) {
              combined.add(m);
            }
          }
          dataToLoad[part] = combined;
        }
      }
    }

    final Map<String, SectionData> tempSectionsMap = {};
    dataToLoad.forEach((originalPart, menuList) {
      final translatedPart = _translatePartToLocale(context, originalPart);

      final section = tempSectionsMap.putIfAbsent(
        translatedPart,
            () => SectionData(
          key: UniqueKey(),
          selectedPart: translatedPart,
          menuControllers: [],
          setInputDataList: [],
          initialSetCount: _currentSetCount,
          menuKeys: [],
        ),
      );

      int maxSets = 0;

      for (final menuData in menuList) {
        final menuCtrl = TextEditingController(text: menuData.name);
        section.menuControllers.add(menuCtrl);
        section.menuKeys.add(UniqueKey());
        // ★ ID 付与（新規 or 復元でも一意）
        section.menuIds.add(section.nextMenuId++);

        final row = <SetInputData>[];
        for (int s = 0; s < menuData.weights.length; s++) {
          final w = TextEditingController(text: menuData.weights[s]);
          final r = TextEditingController(text: menuData.reps[s]);

          bool isSuggestion = true;
          if (record != null && record.menus.containsKey(originalPart)) {
            if (record.menus[originalPart]!.any((m) => m.name == menuData.name)) {
              if (w.text.isNotEmpty || r.text.isNotEmpty) {
                isSuggestion = false;
              }
            }
          }
          row.add(SetInputData(weightController: w, repController: r, isSuggestion: isSuggestion));
        }
        section.setInputDataList.add(row);
        maxSets = max(maxSets, row.length);
      }

      // 足りないセットは空で埋める
      for (final row in section.setInputDataList) {
        while (row.length < _currentSetCount) {
          row.add(SetInputData(
            weightController: TextEditingController(),
            repController: TextEditingController(),
            isSuggestion: true,
          ));
        }
      }
      section.initialSetCount = max(maxSets, _currentSetCount);
    });

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

  void _setControllersFromData(SectionData section, List<MenuData> list, bool isMenuNameSuggestion) {
    _clearSectionControllersAndMaps(section);
    section.menuKeys.clear();
    section.menuIds.clear();
    section.nextMenuId = 0;

    final itemsToCreate = list.isNotEmpty ? list.length : 1;

    for (int i = 0; i < itemsToCreate; i++) {
      final nameCtrl = TextEditingController();
      if (i < list.length) nameCtrl.text = list[i].name;
      section.menuControllers.add(nameCtrl);
      section.menuKeys.add(UniqueKey());
      // ★ ID 付与
      section.menuIds.add(section.nextMenuId++);

      final newRow = <SetInputData>[];
      if (i < list.length) {
        for (int s = 0; s < list[i].weights.length; s++) {
          final w = TextEditingController(text: list[i].weights[s]);
          final r = TextEditingController(text: list[i].reps[s]);
          final isSug = w.text.isEmpty && r.text.isEmpty;
          newRow.add(SetInputData(
            weightController: w,
            repController: r,
            isSuggestion: isMenuNameSuggestion || isSug,
          ));
        }
      }

      final targetSets = max(newRow.length, _currentSetCount);
      while (newRow.length < targetSets) {
        newRow.add(SetInputData(
          weightController: TextEditingController(),
          repController: TextEditingController(),
          isSuggestion: true,
        ));
      }
      section.setInputDataList.add(newRow);
    }

    int maxSetsInLoadedMenus = 0;
    for (final row in section.setInputDataList) {
      maxSetsInLoadedMenus = max(maxSetsInLoadedMenus, row.length);
    }
    section.initialSetCount = max(maxSetsInLoadedMenus, _currentSetCount);
  }

  void _clearSectionControllersAndMaps(SectionData section) {
    for (var c in section.menuControllers) {
      c.dispose();
    }
    for (var list in section.setInputDataList) {
      for (var d in list) {
        d.dispose();
      }
    }
    section.menuControllers.clear();
    section.setInputDataList.clear();
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

      final listForLastUsed = <MenuData>[];
      final listForRecord = <MenuData>[];
      final isAerobic = section.selectedPart == l10n.aerobicExercise;

      for (int i = 0; i < section.menuControllers.length; i++) {
        final name = section.menuControllers[i].text.trim();
        if (name.isEmpty) continue;

        final weights = <String>[];
        final reps = <String>[];
        String? distance;
        String? duration;
        bool confirmed = false;

        if (isAerobic) {
          distance = _distanceController.text;
          duration = _durationController.text;
          if (distance.isNotEmpty || duration.isNotEmpty) confirmed = true;
        } else {
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final set = section.setInputDataList[i][s];
            final w = set.weightController.text;
            final r = set.repController.text;
            weights.add(w);
            reps.add(r);
            if (!set.isSuggestion && (w.isNotEmpty || r.isNotEmpty)) {
              confirmed = true;
            }
          }
        }

        // lastUsed には常に保存
        if (isAerobic) {
          listForLastUsed.add(MenuData(name: name, weights: weights, reps: reps, distance: distance, duration: duration));
        } else {
          listForLastUsed.add(MenuData(name: name, weights: weights, reps: reps));
        }

        // 記録は入力が確定しているものだけ
        if (confirmed) {
          if (isAerobic) {
            listForRecord.add(MenuData(name: name, weights: weights, reps: reps, distance: distance, duration: duration));
          } else {
            listForRecord.add(MenuData(name: name, weights: weights, reps: reps));
          }
          hasAnyRecordData = true;
          lastModifiedPart = originalPart;
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

  // ＋種目
  void _addMenuItem(int sectionIndex) {
    final l10n = AppLocalizations.of(context)!;
    final section = _sections[sectionIndex];

    if (section.selectedPart == null) return;

    if (section.menuControllers.length >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exerciseLimitReached)));
      return;
    }

    setState(() {
      final nameCtrl = TextEditingController();
      section.menuControllers.add(nameCtrl);

      // 一意IDを採番
      final newId = section.nextMenuId++;
      section.menuIds.add(newId);

      section.recentlyAdded.add(newId);

      // セット行追加
      final sets = _currentSetCount;
      final row = List<SetInputData>.generate(
        sets,
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
    });
  }

  // ＋部位
  void _addTargetSection() {
    final l10n = AppLocalizations.of(context)!;

    if (_sections.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.partLimitReached)));
      return;
    }

    setState(() {
      final newSection = SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: true);
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
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
        // ★ ID も同期して削除
        if (_sections[sectionIndex].menuIds.length > menuIndex) {
          _sections[sectionIndex].menuIds.removeAt(menuIndex);
        }
      });

      // セクション内が空ならセクションも削除
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
        _sections.add(SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final l10n = AppLocalizations.of(context)!;
    final formattedDate = DateFormat('yyyy/MM/dd').format(widget.selectedDate);

    final Color partNormalBgColor = isLight ? const Color(0xFF333333) : const Color(0xFF2C2F33);
    final Color partPressedBgColor = isLight ? const Color(0xFF1A1A1A) : const Color(0xFF383C40);
    final Color partTextColor = isLight ? Colors.white : const Color(0xFFCCCCCC);
    final Color partAccentColor = const Color(0xFF60A5FA);

    final bool isInitialEmptyState = _sections.length == 1 && _sections[0].selectedPart == null;

    // 体重カードをヘッダーとしてリストに含める
    final bool showWeight = SettingsManager.showWeightInput;
    final int headerCount = showWeight ? 1 : 0;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) _saveAllSectionsData();
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(
            formattedDate,
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
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

              // ↓↓↓ ここからスクロール領域（体重カードはヘッダーとしてリスト内に入れる）
              Expanded(
                child: ListView.builder(
                  primary: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: headerCount + _sections.length + (isInitialEmptyState ? 0 : 1),
                  itemBuilder: (context, index) {
                    // 0: 体重カード（ON時）
                    if (showWeight && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Card(
                          color: colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${l10n.bodyWeight}${Localizations.localeOf(context).languageCode == "ja" ? "：" : ":"}',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 160,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: StylishInput(
                                          controller: _weightController,
                                          hint: '',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                          ],
                                          normalTextColor: colorScheme.onSurface,
                                          suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                          fillColor: colorScheme.surfaceContainer,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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

                    // 以降はセクション & 「＋部位」
                    final secIndex = index - headerCount;

                    // 末尾に「＋部位」ボタン
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

                    // セクションカード：入場時はアニメ無し、＋部位で増えた分だけ下→上
                    return AnimatedListItem(
                      key: section.key,
                      direction: _firstBuildDone ? AnimationDirection.bottomToTop : AnimationDirection.none,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Card(
                          color: colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
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
                                          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                                          filled: true,
                                          fillColor: colorScheme.surfaceContainer,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(25.0),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(25.0),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(25.0),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                        ),
                                        value: section.selectedPart,
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
                                            if (section.selectedPart != null) {
                                              final current = section.selectedPart!;
                                              _clearSectionControllersAndMaps(section);
                                              section.menuKeys.clear();
                                              section.menuIds.clear();
                                              section.nextMenuId = 0;

                                              final dateKey = _getDateKey(widget.selectedDate);
                                              final record = widget.recordsBox.get(dateKey);
                                              List<MenuData> listToLoad = [];

                                              bool isMenuNameSuggestion;
                                              final originalPart = _getOriginalPartName(context, current);

                                              if (record != null && record.menus.containsKey(originalPart)) {
                                                listToLoad = record.menus[originalPart]!;
                                                isMenuNameSuggestion = false;
                                              } else {
                                                final dynamic rawList = widget.lastUsedMenusBox.get(originalPart);
                                                if (rawList is List) {
                                                  listToLoad = rawList.whereType<MenuData>().toList();
                                                }
                                                isMenuNameSuggestion = true;
                                              }
                                              _setControllersFromData(section, listToLoad, isMenuNameSuggestion);
                                            } else {
                                              _clearSectionControllersAndMaps(section);
                                              section.menuKeys.clear();
                                              section.menuIds.clear();
                                              section.nextMenuId = 0;
                                              section.initialSetCount = _currentSetCount;
                                            }
                                          });
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
                                      // 種目カード一覧（＋種目で増えたものは AnimatedSwitcher で上→下入場）
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
                                              if (!_firstBuildDone) return child; // 入場時はアニメ無し
                                              final offset = Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero).animate(animation);
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(position: offset, child: child),
                                              );
                                            },
                                            child: Card(
                                              key: ValueKey('menu_${section.menuIds[menuIndex]}'),
                                              color: colorScheme.surface,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                              elevation: 2,
                                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: MenuList(
                                                  menuController: section.menuControllers[menuIndex],
                                                  removeMenuCallback: () => _removeMenuItem(secIndex, menuIndex),
                                                  setCount: section.initialSetCount ?? _currentSetCount,
                                                  setInputDataList: section.setInputDataList[menuIndex],
                                                  isAerobic: section.selectedPart == l10n.aerobicExercise,
                                                  distanceController: _distanceController,
                                                  durationController: _durationController,
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
                                          onPressed: () => _addMenuItem(secIndex),
                                          normalBgColorOverride: partNormalBgColor,
                                          pressedBgColorOverride: partPressedBgColor,
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
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
            BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Record'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Graph'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
          currentIndex: 1,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          onTap: (index) {
            if (index == 1) return; // 自分
            _saveAllSectionsData(); // どこへ行くにも保存

            if (index == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalendarScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    selectedDate: DateTime.now(),
                  ),
                ),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GraphScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              );
            }
          },
        ),
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

  // ★ 追加：各メニューの一意ID（アニメ・キー安定化に使用）
  List<int> menuIds;
  int nextMenuId;

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
  })  : menuIds = menuIds ?? <int>[],
        nextMenuId = nextMenuId ?? 0;

  factory SectionData.createEmpty(int initialSetCount, {required bool shouldPopulateDefaults}) {
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
      // 初期1件あれば ID=0 を付与
      menuIds: shouldPopulateDefaults ? [0] : [],
      nextMenuId: shouldPopulateDefaults ? 1 : 0,
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

  const MenuList({
    super.key,
    required this.menuController,
    required this.removeMenuCallback,
    required this.setCount,
    required this.setInputDataList,
    required this.isAerobic,
    required this.distanceController,
    required this.durationController,
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
    }

    final d = widget.distanceController.text.split('.');
    if (d.length == 2) {
      _kmController.text = d[0];
      _mController.text = d[1];
    } else {
      _kmController.text = widget.distanceController.text;
    }
  }

  void _updateDurationController() {
    widget.durationController.text = '${_minController.text}:${_secController.text}';
  }

  void _updateDistanceController() {
    widget.distanceController.text = '${_kmController.text}.${_mController.text}';
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
                  suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fillColor: colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                child: Icon(Icons.close, color: colorScheme.onSurfaceVariant, size: 16),
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
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: StylishInput(
                        controller: _kmController,
                        hint: '例: 5',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        normalTextColor: colorScheme.onSurface,
                        suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Text(
                      ' ${l10n.km} ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      flex: 2,
                      child: StylishInput(
                        controller: _mController,
                        hint: '例: 00',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        normalTextColor: colorScheme.onSurface,
                        suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Text(
                      ' ${l10n.m}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      l10n.time,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: StylishInput(
                        controller: _minController,
                        hint: '例: 30',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        normalTextColor: colorScheme.onSurface,
                        suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Text(
                      ' ${l10n.min} ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      flex: 2,
                      child: StylishInput(
                        controller: _secController,
                        hint: '例: 00',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        normalTextColor: colorScheme.onSurface,
                        suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Text(
                      ' ${l10n.sec}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            )
                : Column(
              children: List.generate(widget.setCount, (setIndex) {
                final set = widget.setInputDataList[setIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Text(
                        '${setIndex + 1}${l10n.sets}：',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StylishInput(
                          controller: set.weightController,
                          hint: '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          normalTextColor:
                          set.isSuggestion ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.onSurface,
                          suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          fillColor: colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          textAlign: TextAlign.right,
                          onChanged: (text) {
                            setState(() {
                              if (text.isNotEmpty && set.isSuggestion) {
                                set.isSuggestion = false;
                              } else if (text.isEmpty &&
                                  !set.isSuggestion &&
                                  set.repController.text.isEmpty) {
                                final anyOther = widget.setInputDataList.any(
                                      (s) => s != set && (s.weightController.text.isNotEmpty || s.repController.text.isNotEmpty),
                                );
                                if (!anyOther) {
                                  set.isSuggestion = true;
                                }
                              }
                            });
                          },
                        ),
                      ),
                      Text(
                        ' ${currentUnit == 'kg' ? l10n.kg : l10n.lbs} ',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: StylishInput(
                          controller: set.repController,
                          hint: '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          normalTextColor:
                          set.isSuggestion ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.onSurface,
                          suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                          fillColor: colorScheme.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          textAlign: TextAlign.right,
                          onChanged: (text) {
                            setState(() {
                              if (text.isNotEmpty && set.isSuggestion) {
                                set.isSuggestion = false;
                              } else if (text.isEmpty &&
                                  !set.isSuggestion &&
                                  set.weightController.text.isEmpty) {
                                final anyOther = widget.setInputDataList.any(
                                      (s) => s != set && (s.weightController.text.isNotEmpty || s.repController.text.isNotEmpty),
                                );
                                if (!anyOther) {
                                  set.isSuggestion = true;
                                }
                              }
                            });
                          },
                        ),
                      ),
                      Text(
                        ' ${l10n.reps}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
