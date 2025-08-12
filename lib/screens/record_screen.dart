import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:ttraining_record/screens/graph_screen.dart';
import 'package:intl/intl.dart';

import '../models/menu_data.dart';
import '../models/record_models.dart';
import '../widgets/animated_list_item.dart';
import 'settings_screen.dart';
import '../widgets/custom_widgets.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import 'calendar_screen.dart';

// ignore_for_file: library_private_types_in_public_api

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox;
  final Box<List> lastUsedMenusBox; // ← 修正
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
  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];
  List<SectionData> _sections = [];
  int _currentSetCount = 3;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  @override
  void dispose() {
    _saveAllSectionsData(); // ★追加：ルート置換や破棄でも確実に保存
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
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = widget.recordsBox.get(dateKey);
    Set<String> partsInRecord = {};
    if (record != null) {
      partsInRecord = record.menus.keys.toSet();
    }
    _filteredBodyParts = [];
    if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
      _filteredBodyParts = _allBodyParts.where((translatedPart) {
        final originalPart = _getOriginalPartName(context, translatedPart);
        return savedBodyPartsSettings![originalPart] == true;
      }).toList();
    } else {
      _filteredBodyParts = List.from(_allBodyParts);
    }
    for (String originalPart in partsInRecord) {
      final translatedPart = _translatePartToLocale(context, originalPart);
      if (!_filteredBodyParts.contains(translatedPart)) {
        _filteredBodyParts.add(translatedPart);
      }
    }
    _filteredBodyParts.sort((a, b) {
      int indexA = _allBodyParts.indexOf(a);
      int indexB = _allBodyParts.indexOf(b);
      return indexA.compareTo(indexB);
    });
    _currentSetCount = savedSetCount ?? 3;

    if (mounted) {
      setState(() {
        _loadInitialSections();
      });
    }
  }

  void _loadInitialSections() {
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = widget.recordsBox.get(dateKey);

    for (var section in _sections) {
      section.dispose();
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
      if (mounted) {
        setState(() {});
      }
      return;
    }

    Map<String, List<MenuData>> dataToLoad = {};
    Set<String> partsFromRecords = {};

    record.menus.forEach((part, menuList) {
      dataToLoad[part] = List.from(menuList);
      partsFromRecords.add(part);
    });

    final List<String> lastUsedParts =
        widget.lastUsedMenusBox.keys.cast<String>().toList();
    for (var part in lastUsedParts) {
      final dynamic rawList = widget.lastUsedMenusBox.get(part);
      if (rawList is List) {
        final List<MenuData> lastUsedMenus =
            rawList.whereType<MenuData>().toList();

        if (partsFromRecords.contains(part)) {
          List<MenuData> combinedMenus = List.from(dataToLoad[part] ?? []);

          for (var lastUsedMenu in lastUsedMenus) {
            if (!combinedMenus.any((m) => m.name == lastUsedMenu.name)) {
              combinedMenus.add(lastUsedMenu);
            }
          }
          dataToLoad[part] = combinedMenus;
        }
      }
    }

    Map<String, SectionData> tempSectionsMap = {};
    dataToLoad.forEach((part, menuList) {
      final translatedPart = _translatePartToLocale(context, part);

      SectionData section = tempSectionsMap.putIfAbsent(
          translatedPart,
          () => SectionData(
                key: UniqueKey(),
                selectedPart: translatedPart,
                menuControllers: [],
                setInputDataList: [],
                initialSetCount: _currentSetCount,
                menuKeys: [],
              ));

      int maxSetsInThisSection = 0;

      for (var menuData in menuList) {
        final menuCtrl = TextEditingController(text: menuData.name);
        section.menuControllers.add(menuCtrl);
        section.menuKeys.add(UniqueKey());

        List<SetInputData> setInputDataRow = [];
        for (int s = 0; s < menuData.weights.length; s++) {
          final weightCtrl = TextEditingController(text: menuData.weights[s]);
          final repCtrl = TextEditingController(text: menuData.reps[s]);

          bool isSuggestion = true;
          if (record != null && record.menus.containsKey(part)) {
            if (record.menus[part]!.any((m) => m.name == menuData.name)) {
              if (weightCtrl.text.isNotEmpty || repCtrl.text.isNotEmpty) {
                isSuggestion = false;
              }
            }
          }
          setInputDataRow.add(SetInputData(
              weightController: weightCtrl,
              repController: repCtrl,
              isSuggestion: isSuggestion));
        }
        section.setInputDataList.add(setInputDataRow);
        maxSetsInThisSection =
            max(maxSetsInThisSection, setInputDataRow.length);
      }

      for (var setInputDataRow in section.setInputDataList) {
        while (setInputDataRow.length < _currentSetCount) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          setInputDataRow.add(SetInputData(
              weightController: weightCtrl,
              repController: repCtrl,
              isSuggestion: true));
        }
      }
      section.initialSetCount = max(maxSetsInThisSection, _currentSetCount);
    });
    _sections = tempSectionsMap.values.toList();
    _sections.sort((a, b) {
      if (a.selectedPart == null && b.selectedPart == null) return 0;
      if (a.selectedPart == null) return 1;
      if (b.selectedPart == null) return -1;
      int indexA = _allBodyParts.indexOf(a.selectedPart!);
      int indexB = _allBodyParts.indexOf(b.selectedPart!);
      return indexA.compareTo(indexB);
    });
    if (mounted) {
      setState(() {});
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _setControllersFromData(
      SectionData section, List<MenuData> list, bool isMenuNameSuggestion) {
    _clearSectionControllersAndMaps(section);
    section.menuKeys.clear();
    int itemsToCreate = list.isNotEmpty ? list.length : 1;

    for (int i = 0; i < itemsToCreate; i++) {
      final newMenuController = TextEditingController();
      if (i < list.length) {
        newMenuController.text = list[i].name;
      }
      section.menuControllers.add(newMenuController);
      section.menuKeys.add(UniqueKey());

      final newSetInputDataRow = <SetInputData>[];
      if (i < list.length) {
        for (int s = 0; s < list[i].weights.length; s++) {
          final newWeightController =
              TextEditingController(text: list[i].weights[s]);
          final newRepController = TextEditingController(text: list[i].reps[s]);
          bool isSuggestionSet =
              newWeightController.text.isEmpty && newRepController.text.isEmpty;
          newSetInputDataRow.add(SetInputData(
              weightController: newWeightController,
              repController: newRepController,
              isSuggestion: isMenuNameSuggestion || isSuggestionSet));
        }
      }
      int targetSetCountForThisMenu;
      targetSetCountForThisMenu =
          max(newSetInputDataRow.length, _currentSetCount);

      while (newSetInputDataRow.length < targetSetCountForThisMenu) {
        final newWeightController = TextEditingController();
        final newRepController = TextEditingController();
        newSetInputDataRow.add(SetInputData(
          weightController: newWeightController,
          repController: newRepController,
          isSuggestion: true,
        ));
      }
      section.setInputDataList.add(newSetInputDataRow);
    }
    int maxSetsInLoadedMenus = 0;
    for (var menuSets in section.setInputDataList) {
      maxSetsInLoadedMenus = max(maxSetsInLoadedMenus, _currentSetCount);
    }
    section.initialSetCount = max(maxSetsInLoadedMenus, _currentSetCount);
  }

  void _clearSectionControllersAndMaps(SectionData section) {
    for (var c in section.menuControllers) {
      c.dispose();
    }
    for (var list in section.setInputDataList) {
      for (var data in list) {
        data.dispose();
      }
    }
    section.menuControllers.clear();
    section.setInputDataList.clear();
  }

  void _saveAllSectionsData() {
    String dateKey = _getDateKey(widget.selectedDate);
    Map<String, List<MenuData>> allMenusForRecord = {};
    String? lastModifiedPart;
    bool hasAnyRecordData = false;
    final l10n = AppLocalizations.of(context)!;

    for (var section in _sections) {
      if (section.selectedPart == null) continue;
      final originalPartName =
          _getOriginalPartName(context, section.selectedPart!);

      List<MenuData> sectionMenuListForLastUsed = [];
      List<MenuData> sectionMenuListForRecord = [];

      final isAerobic = section.selectedPart == l10n.aerobicExercise;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        if (name.isEmpty) {
          continue;
        }

        List<String> weights = [];
        List<String> reps = [];
        String? distance;
        String? duration;
        bool hasConfirmedSet = false;

        if (isAerobic) {
          distance = _distanceController.text;
          duration = _durationController.text;
          if (distance.isNotEmpty || duration.isNotEmpty) {
            hasConfirmedSet = true;
          }
        } else {
          for (int s = 0; s < section.setInputDataList[i].length; s++) {
            final setInputData = section.setInputDataList[i][s];
            String w = setInputData.weightController.text;
            String r = setInputData.repController.text;
            weights.add(w);
            reps.add(r);
            if (w.isNotEmpty || r.isNotEmpty) {
              hasConfirmedSet = true;
            }
          }
        }

        if (isAerobic) {
          sectionMenuListForLastUsed.add(MenuData(
            name: name,
            weights: weights,
            reps: reps,
            distance: distance,
            duration: duration,
          ));
        } else {
          sectionMenuListForLastUsed
              .add(MenuData(name: name, weights: weights, reps: reps));
        }

        if (hasConfirmedSet) {
          if (isAerobic) {
            sectionMenuListForRecord.add(MenuData(
              name: name,
              weights: weights,
              reps: reps,
              distance: distance,
              duration: duration,
            ));
          } else {
            sectionMenuListForRecord
                .add(MenuData(name: name, weights: weights, reps: reps));
          }
          hasAnyRecordData = true;
          lastModifiedPart = originalPartName;
        }
      }

      if (sectionMenuListForLastUsed.isNotEmpty) {
        widget.lastUsedMenusBox
            .put(originalPartName, sectionMenuListForLastUsed);
      } else {
        widget.lastUsedMenusBox.delete(originalPartName);
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        allMenusForRecord[originalPartName] = sectionMenuListForRecord;
      }
    }

    double? weightValue;
    if (_weightController.text.isNotEmpty) {
      weightValue = double.tryParse(_weightController.text);
      if (weightValue != null) {
        hasAnyRecordData = true;
      }
    }

    if (hasAnyRecordData) {
      DailyRecord newRecord = DailyRecord(
        date: widget.selectedDate,
        menus: allMenusForRecord,
        lastModifiedPart: lastModifiedPart,
        weight: weightValue,
      );
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey);
    }
  }

  void _addMenuItem(int sectionIndex) {
    final l10n = AppLocalizations.of(context)!;

    if (_sections[sectionIndex].menuControllers.length >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exerciseLimitReached)),
      );
      return;
    }

    if (mounted) {
      setState(() {
        int setsForNewMenu = _currentSetCount;
        final newMenuController = TextEditingController();
        _sections[sectionIndex].menuControllers.add(newMenuController);
        _sections[sectionIndex].menuKeys.add(UniqueKey());

        while (_sections[sectionIndex].menuControllers.length >
            _sections[sectionIndex].setInputDataList.length) {
          _sections[sectionIndex].setInputDataList.add([]);
        }

        final newSetInputDataList = List.generate(setsForNewMenu, (_) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          return SetInputData(
              weightController: weightCtrl,
              repController: repCtrl,
              isSuggestion: true);
        });
        _sections[sectionIndex].setInputDataList[
                _sections[sectionIndex].menuControllers.length - 1] =
            newSetInputDataList;

        _sections[sectionIndex].initialSetCount =
            max(_sections[sectionIndex].initialSetCount ?? 0, setsForNewMenu);
      });
    }
  }

  void _addTargetSection() {
    final l10n = AppLocalizations.of(context)!;

    if (_sections.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.partLimitReached)),
      );
      return;
    }

    if (mounted) {
      setState(() {
        final newSection = SectionData.createEmpty(_currentSetCount,
            shouldPopulateDefaults: true);
        _sections.add(newSection);
      });
    }
  }

  void _removeMenuItem(int sectionIndex, int menuIndex) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteMenuConfirmationTitle),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      if (mounted) {
        setState(() {
          _sections[sectionIndex].menuControllers[menuIndex].dispose();
          for (var setInputData
              in _sections[sectionIndex].setInputDataList[menuIndex]) {
            setInputData.dispose();
          }
          _sections[sectionIndex].menuControllers.removeAt(menuIndex);
          _sections[sectionIndex].setInputDataList.removeAt(menuIndex);
          _sections[sectionIndex].menuKeys.removeAt(menuIndex);

          if (_sections[sectionIndex].menuControllers.isEmpty) {
            _removeSection(sectionIndex);
          }
        });
      }
    }
  }

  void _removeSection(int sectionIndex) {
    if (mounted) {
      setState(() {
        _sections[sectionIndex].dispose();
        _sections.removeAt(sectionIndex);

        if (_sections.isEmpty) {
          _sections.add(SectionData.createEmpty(_currentSetCount,
              shouldPopulateDefaults: false));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final l10n = AppLocalizations.of(context)!;
    final formattedDate = DateFormat('yyyy/MM/dd').format(widget.selectedDate);

    final Color partNormalBgColor =
        isLightMode ? const Color(0xFF333333) : const Color(0xFF2C2F33);
    final Color partPressedBgColor =
        isLightMode ? const Color(0xFF1A1A1A) : const Color(0xFF383C40);
    final Color partTextColor =
        isLightMode ? Colors.white : const Color(0xFFCCCCCC);
    final Color partAccentColor =
        isLightMode ? const Color(0xFF60A5FA) : const Color(0xFF60A5FA);

    bool isInitialEmptyState =
        _sections.length == 1 && _sections[0].selectedPart == null;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _saveAllSectionsData();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
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
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.showWeightInputNotifier,
                builder: (context, show, _) {
                  if (!show) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 8.0),
                      Card(
                        color: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                l10n.bodyWeight,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              Expanded(
                                child: StylishInput(
                                  controller: _weightController,
                                  hint: '',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  normalTextColor: colorScheme.onSurface,
                                  suggestionTextColor: colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.5),
                                  fillColor: colorScheme.surfaceContainer,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  textAlign: TextAlign.right,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                ),
                              ),
                              Text(
                                ' ${SettingsManager.currentUnit}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                    ],
                  );
                },
              ),
              Expanded(
                child: ListView.builder(
                  primary: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _sections.length + (isInitialEmptyState ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (index == _sections.length && !isInitialEmptyState) {
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

                    final section = _sections[index];
                    final String? actualSelectedPart = section.selectedPart;

                    return AnimatedListItem(
                      key: section.key,
                      direction: AnimationDirection.rightToLeft,
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
                                            .map((p) => DropdownMenuItem(
                                                value: p,
                                                child: Text(p,
                                                    style: TextStyle(
                                                        color: colorScheme
                                                            .onSurface,
                                                        fontSize: 14.0,
                                                        fontWeight:
                                                            FontWeight.bold))))
                                            .toList(),
                                        onChanged: (value) {
                                          if (mounted) {
                                            setState(() {
                                              section.selectedPart = value;
                                              if (section.selectedPart !=
                                                  null) {
                                                final String
                                                    currentSelectedPart =
                                                    section.selectedPart!;

                                                _clearSectionControllersAndMaps(
                                                    section);
                                                section.menuKeys.clear();

                                                String dateKey = _getDateKey(
                                                    widget.selectedDate);
                                                DailyRecord? record = widget
                                                    .recordsBox
                                                    .get(dateKey);
                                                List<MenuData>? listToLoad;

                                                bool isMenuNameSuggestion;
                                                final originalPartName =
                                                    _getOriginalPartName(
                                                        context,
                                                        currentSelectedPart);

                                                if (record != null &&
                                                    record.menus.containsKey(
                                                        originalPartName)) {
                                                  listToLoad = record
                                                      .menus[originalPartName];
                                                  isMenuNameSuggestion = false;
                                                } else {
                                                  final dynamic rawList = widget
                                                      .lastUsedMenusBox
                                                      .get(originalPartName);
                                                  if (rawList is List) {
                                                    listToLoad = rawList
                                                        .whereType<MenuData>()
                                                        .toList();
                                                  } else {
                                                    listToLoad = [];
                                                  }
                                                  isMenuNameSuggestion = true;
                                                }
                                                _setControllersFromData(
                                                    section,
                                                    listToLoad ?? [],
                                                    isMenuNameSuggestion);
                                              } else {
                                                _clearSectionControllersAndMaps(
                                                    section);
                                                section.menuKeys.clear();
                                                section.initialSetCount =
                                                    _currentSetCount;
                                              }
                                            });
                                          }
                                        },
                                        dropdownColor:
                                            colorScheme.surfaceContainer,
                                        style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold),
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
                                          return AnimatedListItem(
                                            key: section.menuKeys[menuIndex],
                                            direction:
                                                AnimationDirection.rightToLeft,
                                            child: Card(
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
                                                  key: section
                                                      .menuKeys[menuIndex],
                                                  menuController:
                                                      section.menuControllers[
                                                          menuIndex],
                                                  removeMenuCallback: () =>
                                                      _removeMenuItem(
                                                          index, menuIndex),
                                                  setCount:
                                                      section.initialSetCount ??
                                                          _currentSetCount,
                                                  setInputDataList:
                                                      section.setInputDataList[
                                                          menuIndex],
                                                  isAerobic:
                                                      section.selectedPart ==
                                                          l10n.aerobicExercise,
                                                  distanceController:
                                                      _distanceController,
                                                  durationController:
                                                      _durationController,
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
                                          onPressed: () => _addMenuItem(index),
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
              icon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: 'Record',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Graph',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: 1,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          onTap: (index) {
            if (index == 0) {
              _saveAllSectionsData();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    selectedDate: DateTime.now(),
                  ),
                ),
                (route) => false,
              );
            } else if (index == 2) {
              _saveAllSectionsData();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => GraphScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
                (route) => false,
              );
            } else if (index == 3) {
              _saveAllSectionsData();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
                (route) => false,
              );
            }
          },
        ),
      ),
    );
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
    final parts = widget.durationController.text.split(':');
    if (parts.length == 2) {
      _minController.text = parts[0];
      _secController.text = parts[1];
    } else {
      _minController.text = widget.durationController.text;
    }

    final distParts = widget.distanceController.text.split('.');
    if (distParts.length == 2) {
      _kmController.text = distParts[0];
      _mController.text = distParts[1];
    } else {
      _kmController.text = widget.distanceController.text;
    }
  }

  void _updateDurationController() {
    final min = _minController.text;
    final sec = _secController.text;
    widget.durationController.text = '$min:$sec';
  }

  void _updateDistanceController() {
    final km = _kmController.text;
    final m = _mController.text;
    widget.distanceController.text = '$km.$m';
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
                      colorScheme.onSurfaceVariant.withOpacity(0.5),
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
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: widget.isAerobic
                ? Column(
                    children: [
                      Row(
                        children: [
                          Text(l10n.distance,
                              style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: StylishInput(
                              controller: _kmController,
                              hint: '例: 5',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              normalTextColor: colorScheme.onSurface,
                              suggestionTextColor:
                                  colorScheme.onSurfaceVariant.withOpacity(0.5),
                              fillColor: colorScheme.surfaceContainer,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Text(' ${l10n.km} ',
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            flex: 2,
                            child: StylishInput(
                              controller: _mController,
                              hint: '例: 00',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              normalTextColor: colorScheme.onSurface,
                              suggestionTextColor:
                                  colorScheme.onSurfaceVariant.withOpacity(0.5),
                              fillColor: colorScheme.surfaceContainer,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Text(' ${l10n.m}',
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(l10n.time,
                              style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: StylishInput(
                              controller: _minController,
                              hint: '例: 30',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              normalTextColor: colorScheme.onSurface,
                              suggestionTextColor:
                                  colorScheme.onSurfaceVariant.withOpacity(0.5),
                              fillColor: colorScheme.surfaceContainer,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Text(' ${l10n.min} ',
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            flex: 2,
                            child: StylishInput(
                              controller: _secController,
                              hint: '例: 00',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              normalTextColor: colorScheme.onSurface,
                              suggestionTextColor:
                                  colorScheme.onSurfaceVariant.withOpacity(0.5),
                              fillColor: colorScheme.surfaceContainer,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Text(' ${l10n.sec}',
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: List.generate(widget.setCount, (setIndex) {
                      final setInputData = widget.setInputDataList[setIndex];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Text('${setIndex + 1}${l10n.sets}：',
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14.0)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StylishInput(
                                controller: setInputData.weightController,
                                hint: '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true), // ★小数許可
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // ★小数点入力可
                                ],
                                normalTextColor: setInputData.isSuggestion
                                    ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                    : colorScheme.onSurface,
                                suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                fillColor: colorScheme.surfaceContainer,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                textAlign: TextAlign.right,
                                onChanged: (text) {
                                  setState(() {
                                    if (text.isNotEmpty && setInputData.isSuggestion) {
                                      setInputData.isSuggestion = false;
                                    } else if (text.isEmpty &&
                                        !setInputData.isSuggestion &&
                                        setInputData.repController.text.isEmpty) {
                                      bool anyOtherSetHasInput = widget.setInputDataList.any(
                                            (s) =>
                                        s != setInputData &&
                                            (s.weightController.text.isNotEmpty ||
                                                s.repController.text.isNotEmpty),
                                      );
                                      if (!anyOtherSetHasInput) {
                                        setInputData.isSuggestion = true;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                            Text(
                                ' ${currentUnit == 'kg' ? l10n.kg : l10n.lbs} ',
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: StylishInput(
                                controller: setInputData.repController,
                                hint: '',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                normalTextColor: setInputData.isSuggestion
                                    ? colorScheme.onSurfaceVariant
                                        .withOpacity(0.5)
                                    : colorScheme.onSurface,
                                suggestionTextColor: colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.5),
                                fillColor: colorScheme.surfaceContainer,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                textAlign: TextAlign.right,
                                onChanged: (text) {
                                  setState(() {
                                    if (text.isNotEmpty &&
                                        setInputData.isSuggestion) {
                                      setInputData.isSuggestion = false;
                                    } else if (text.isEmpty &&
                                        !setInputData.isSuggestion &&
                                        setInputData
                                            .weightController.text.isEmpty) {
                                      bool anyOtherSetHasInput =
                                          widget.setInputDataList.any((s) =>
                                              s != setInputData &&
                                              (s.weightController.text
                                                      .isNotEmpty ||
                                                  s.repController.text
                                                      .isNotEmpty));
                                      if (!anyOtherSetHasInput) {
                                        setInputData.isSuggestion = true;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                            Text(' ${l10n.reps}',
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold)),
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
