import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:ttraining_record/l10n/app_localizations.dart'; // ★追加: 多言語化対応のため

import '../models/menu_data.dart';
import '../models/record_models.dart';
import '../widgets/animated_list_item.dart';
import 'settings_screen.dart';
import '../widgets/custom_widgets.dart';
import '../main.dart';

// ignore_for_file: library_private_types_in_public_api

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;
  final Box<int> themeModeBox;

  const RecordScreen({
    super.key,
    required this.selectedDate,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // ★修正: リストをfinalから動的に変更できるようにする
  List<String> _filteredBodyParts = [];
  List<String> _allBodyParts = [];

  List<SectionData> _sections = [];

  int _currentSetCount = 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // ★修正: didChangeDependenciesで多言語対応のリストを構築
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
    super.dispose();
  }

  // ★追加: 翻訳された部位名から元の日本語キーに変換するヘルパー関数
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

  // ★追加: Hiveキー（日本語）を翻訳された文字列に変換するヘルパー関数
  String _translatePartToLocale(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
      case '有酸素運動': return l10n.aerobicExercise;
      case '腕': return l10n.arm;
      case '胸': return l10n.chest;
      case '背中': return l10n.back;
      case '肩': return l10n.shoulder;
      case '足': return l10n.leg;
      case '全身': return l10n.fullBody;
      case 'その他１': return l10n.other1;
      case 'その他２': return l10n.other2;
      case 'その他３': return l10n.other3;
      default: return part;
    }
  }


  // ★修正: _loadSettingsAndParts
  void _loadSettingsAndParts() {
    final l10n = AppLocalizations.of(context)!;

    _allBodyParts = [
      l10n.aerobicExercise, l10n.arm, l10n.chest, l10n.back, l10n.shoulder, l10n.leg,
      l10n.fullBody, l10n.other1, l10n.other2, l10n.other3,
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

    if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
      _filteredBodyParts = _allBodyParts
          .where((translatedPart) {
        final originalPart = _getOriginalPartName(context, translatedPart);
        return savedBodyPartsSettings![originalPart] == true;
      })
          .toList();
      if (_filteredBodyParts.isEmpty) {
        _filteredBodyParts = List.from(_allBodyParts);
      }
    } else {
      _filteredBodyParts = List.from(_allBodyParts);
    }

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

    if (record != null && record.menus.isNotEmpty) {
      Map<String, SectionData> tempSectionsMap = {};
      record.menus.forEach((part, menuList) {
        final translatedPart = _translatePartToLocale(context, part);

        SectionData section = tempSectionsMap.putIfAbsent(translatedPart, () => SectionData(
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
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: false));
          }
          section.setInputDataList.add(setInputDataRow);
          maxSetsInThisSection = max(maxSetsInThisSection, setInputDataRow.length);
        }

        for (var setInputDataRow in section.setInputDataList) {
          while (setInputDataRow.length < _currentSetCount) {
            final weightCtrl = TextEditingController();
            final repCtrl = TextEditingController();
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: true));
          }
        }
        section.initialSetCount = max(maxSetsInThisSection, _currentSetCount);
      });
      _sections = tempSectionsMap.values.toList();
    } else {
      _sections.add(SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false));
      _sections[0].initialSetCount = _currentSetCount;
    }

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

  void _setControllersFromData(SectionData section, List<MenuData> list, bool isMenuNameSuggestion) {
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
      bool isSetsSuggestion = isMenuNameSuggestion;

      if (i < list.length) {
        for (int s = 0; s < list[i].weights.length; s++) {
          final newWeightController = TextEditingController(text: list[i].weights[s]);
          final newRepController = TextEditingController(text: list[i].reps[s]);
          newSetInputDataRow.add(SetInputData(weightController: newWeightController, repController: newRepController, isSuggestion: isSetsSuggestion));
        }
      }

      int targetSetCountForThisMenu;
      targetSetCountForThisMenu = max(newSetInputDataRow.length, _currentSetCount);

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
      maxSetsInLoadedMenus = max(maxSetsInLoadedMenus, menuSets.length);
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
    Map<String, List<MenuData>> allMenusForDay = {};
    String? lastModifiedPart;
    final l10n = AppLocalizations.of(context)!;

    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> sectionMenuListForRecord = [];
      String? currentPart = section.selectedPart;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<String> confirmedWeights = [];
        List<String> confirmedReps = [];

        for (int s = 0; s < section.setInputDataList[i].length; s++) {
          final setInputData = section.setInputDataList[i][s];
          String w = setInputData.weightController.text;
          String r = setInputData.repController.text;

          if (!setInputData.isSuggestion) {
            confirmedWeights.add(w);
            confirmedReps.add(r);
          }
        }

        List<String> finalWeights = [];
        List<String> finalReps = [];
        bool hasAnyConfirmedSetData = false;

        for (int k = 0; k < confirmedWeights.length; k++) {
          if (confirmedWeights[k].isNotEmpty || confirmedReps[k].isNotEmpty) {
            finalWeights.add(confirmedWeights[k]);
            finalReps.add(confirmedReps[k]);
            hasAnyConfirmedSetData = true;
          }
        }

        // ★修正: 保存するキーは日本語のまま
        final originalPartName = _getOriginalPartName(context, currentPart!);

        if (name.isNotEmpty && hasAnyConfirmedSetData) {
          sectionMenuListForRecord.add(MenuData(name: name, weights: finalWeights, reps: finalReps));
          lastModifiedPart = originalPartName; // 保存するキーは日本語
        } else {
          // その部位の確定メニューが空の場合、DailyRecordからその部位を削除
          widget.recordsBox.delete(dateKey);
        }
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        final originalPartName = _getOriginalPartName(context, currentPart!);
        allMenusForDay[originalPartName] = sectionMenuListForRecord; // 保存するキーは日本語
      } else {
        widget.recordsBox.delete(dateKey);
      }
    }

    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey);
    }

    for (var section in _sections) {
      if (section.selectedPart == null) continue;
      final originalPartName = _getOriginalPartName(context, section.selectedPart!);

      List<MenuData> displayedMenuList = [];
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        if (name.isEmpty) {
          continue;
        }

        List<String> weights = [];
        List<String> reps = [];
        for (int s = 0; s < section.setInputDataList[i].length; s++) {
          final setInputData = section.setInputDataList[i][s];
          String w = setInputData.weightController.text;
          String r = setInputData.repController.text;
          weights.add(w);
          reps.add(r);
        }
        displayedMenuList.add(MenuData(name: name, weights: weights, reps: reps));
      }

      if (displayedMenuList.isNotEmpty) {
        widget.lastUsedMenusBox.put(originalPartName, displayedMenuList); // 保存するキーは日本語
      } else {
        widget.lastUsedMenusBox.delete(originalPartName);
      }
    }
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
          settingsBox: widget.settingsBox,
          setCountBox: widget.setCountBox,
          themeModeBox: widget.themeModeBox,
          onThemeModeChanged: (newMode) {
            currentThemeMode.value = newMode;
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _currentSetCount = widget.setCountBox.get('setCount') ?? 3;

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

          if (savedBodyPartsSettings != null) {
            _filteredBodyParts = _allBodyParts
                .where((translatedPart) {
              final originalPart = _getOriginalPartName(context, translatedPart);
              return savedBodyPartsSettings![originalPart] == true;
            })
                .toList();
            if (_filteredBodyParts.isEmpty) {
              _filteredBodyParts = List.from(_allBodyParts);
            }
          } else {
            _filteredBodyParts = List.from(_allBodyParts);
          }

          for (var section in _sections) {
            int maxSetsForSectionDisplay = _currentSetCount;

            for (int menuIndex = 0; menuIndex < section.menuControllers.length; menuIndex++) {
              List<SetInputData> setInputDataRow = section.setInputDataList[menuIndex];
              int actualMaxSetsInThisMenu = 0;
              for (int s = 0; s < setInputDataRow.length; s++) {
                final setInputData = setInputDataRow[s];
                if (setInputData.weightController.text.isNotEmpty ||
                    setInputData.repController.text.isNotEmpty) {
                  actualMaxSetsInThisMenu = s + 1;
                }
              }

              int targetSetCountForThisMenu = max(actualMaxSetsInThisMenu, _currentSetCount);

              if (setInputDataRow.length > targetSetCountForThisMenu) {
                for (int s = setInputDataRow.length - 1; s >= targetSetCountForThisMenu; s--) {
                  final setInputData = setInputDataRow[s];
                  bool isEmpty = setInputData.weightController.text.isEmpty &&
                      setInputData.repController.text.isEmpty;

                  if (isEmpty && setInputData.isSuggestion) {
                    setInputData.dispose();
                    setInputDataRow.removeAt(s);
                  } else {
                    break;
                  }
                }
              } else if (setInputDataRow.length < targetSetCountForThisMenu) {
                while (setInputDataRow.length < targetSetCountForThisMenu) {
                  final weightCtrl = TextEditingController();
                  final repCtrl = TextEditingController();
                  setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: true));
                }
              }
              maxSetsForSectionDisplay = max(maxSetsForSectionDisplay, setInputDataRow.length);
            }
            section.initialSetCount = maxSetsForSectionDisplay;
          }
        });
      }
    });
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

        while (_sections[sectionIndex].menuControllers.length > _sections[sectionIndex].setInputDataList.length) {
          _sections[sectionIndex].setInputDataList.add([]);
        }

        final newSetInputDataList = List.generate(setsForNewMenu, (_) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          return SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: false);
        });
        _sections[sectionIndex].setInputDataList[_sections[sectionIndex].menuControllers.length - 1] = newSetInputDataList;

        _sections[sectionIndex].initialSetCount = max(_sections[sectionIndex].initialSetCount ?? 0, setsForNewMenu);
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
        final newSection = SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false);
        _sections.add(newSection);
      });
    }
  }

  Widget _buildSetRow(BuildContext context, List<List<SetInputData>> setInputDataList, int menuIndex, int setNumber, int setIndex, String? selectedPart) {
    final colorScheme = Theme.of(context).colorScheme;
    final setInputData = setInputDataList[menuIndex][setIndex];
    final l10n = AppLocalizations.of(context)!;

    String weightUnit = l10n.kg;
    String repUnit = l10n.reps;

    // ★修正: 部位名の比較を多言語化
    if (selectedPart == l10n.aerobicExercise) {
      weightUnit = l10n.min;
      repUnit = l10n.sec;
    }

    final Color textColor = setInputData.isSuggestion
        ? colorScheme.onSurfaceVariant.withOpacity(0.5)
        : colorScheme.onSurface;

    return Row(
      children: [
        // ★修正: セット数を多言語化
        Text(
          '${setNumber}${l10n.sets}：',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StylishInput(
            key: ValueKey('${setInputData.weightController.hashCode}_weight_${menuIndex}_$setIndex'),
            controller: setInputData.weightController,
            hint: '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            normalTextColor: textColor,
            suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            textAlign: TextAlign.right,
            onChanged: (text) {
              if (text.isNotEmpty && setInputData.isSuggestion) {
                setState(() {
                  setInputData.isSuggestion = false;
                });
              } else if (text.isEmpty && !setInputData.isSuggestion) {}
            },
          ),
        ),
        Text(' $weightUnit ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded(
          child: StylishInput(
            key: ValueKey('${setInputData.repController.hashCode}_rep_${menuIndex}_$setIndex'),
            controller: setInputData.repController,
            hint: '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            normalTextColor: textColor,
            suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            textAlign: TextAlign.right,
            onChanged: (text) {
              if (text.isNotEmpty && setInputData.isSuggestion) {
                setState(() {
                  setInputData.isSuggestion = false;
                });
              } else if (text.isEmpty && !setInputData.isSuggestion) {}
            },
          ),
        ),
        Text(' $repUnit', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final l10n = AppLocalizations.of(context)!; // ★追加: l10nインスタンスを取得

    final Color partNormalBgColor = isLightMode ? const Color(0xFF333333) : const Color(0xFF2C2F33);
    final Color partPressedBgColor = isLightMode ? const Color(0xFF1A1A1A) : const Color(0xFF383C40);
    final Color partTextColor = isLightMode ? Colors.white : const Color(0xFFCCCCCC);
    final Color partAccentColor = isLightMode ? const Color(0xFF60A5FA) : const Color(0xFF60A5FA);

    bool isInitialEmptyState = _sections.length == 1 && _sections[0].selectedPart == null;

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
          // ★修正: アプリバーのタイトルを日付表示に
          title: Text(
            '${widget.selectedDate.year}/${widget.selectedDate.month}/${widget.selectedDate.day}',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.0, color: colorScheme.onSurface),
              // ★修正: SettingsScreenのタイトルを多言語化
              tooltip: l10n.settings,
              onPressed: () => _navigateToSettings(context),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (isInitialEmptyState)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: GlassCard(
                    borderRadius: 12.0,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(20.0),
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        // ★修正: ヒントテキストを多言語化
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
                      value: _sections[0].selectedPart,
                      items: _filteredBodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _sections[0].selectedPart = value;
                            if (value != null) {
                              final String actualSelectedPart = value;
                              _clearSectionControllersAndMaps(_sections[0]);
                              _sections[0].menuKeys.clear();
                              String dateKey = _getDateKey(widget.selectedDate);
                              DailyRecord? record = widget.recordsBox.get(dateKey);
                              List<MenuData>? listToLoad;
                              bool isMenuNameSuggestion;

                              // ★修正: Hiveのキーは日本語
                              final originalPartName = _getOriginalPartName(context, actualSelectedPart);

                              if (record != null && record.menus.containsKey(originalPartName)) {
                                listToLoad = record.menus[originalPartName];
                                isMenuNameSuggestion = false;
                              } else {
                                final dynamic rawList = widget.lastUsedMenusBox.get(originalPartName);
                                if (rawList is List) {
                                  listToLoad = rawList.whereType<MenuData>().toList();
                                } else {
                                  listToLoad = [];
                                }
                                isMenuNameSuggestion = true;
                              }
                              _setControllersFromData(_sections[0], listToLoad ?? [], isMenuNameSuggestion);
                            } else {
                              _clearSectionControllersAndMaps(_sections[0]);
                              _sections[0].menuKeys.clear();
                              _sections[0].initialSetCount = _currentSetCount;
                            }
                          });
                        }
                      },
                      dropdownColor: colorScheme.surfaceContainer,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                      primary: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _sections.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _sections.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: CircularAddButtonWithText(
                                // ★修正: ラベルを多言語化
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
                        final String dateKey = _getDateKey(widget.selectedDate);
                        final DailyRecord? record = widget.recordsBox.get(dateKey);
                        final String? actualSelectedPart = section.selectedPart;

                        return AnimatedListItem(
                          key: section.key,
                          direction: AnimationDirection.bottomToTop,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: GlassCard(
                              borderRadius: 12.0,
                              backgroundColor: section.selectedPart == l10n.aerobicExercise && isLightMode
                                  ? Colors.grey[400]!
                                  : colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      // ★修正: ヒントテキストを多言語化
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
                                    items: _filteredBodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold)))).toList(),
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() {
                                          section.selectedPart = value;
                                          if (section.selectedPart != null) {
                                            final String currentSelectedPart = section.selectedPart!;

                                            _clearSectionControllersAndMaps(section);
                                            section.menuKeys.clear();

                                            String dateKey = _getDateKey(widget.selectedDate);
                                            DailyRecord? record = widget.recordsBox.get(dateKey);
                                            List<MenuData>? listToLoad;

                                            bool isMenuNameSuggestion;
                                            // ★修正: Hiveのキーは日本語
                                            final originalPartName = _getOriginalPartName(context, currentSelectedPart);

                                            if (record != null && record.menus.containsKey(originalPartName)) {
                                              listToLoad = record.menus[originalPartName];
                                              isMenuNameSuggestion = false;
                                            } else {
                                              final dynamic rawList = widget.lastUsedMenusBox.get(originalPartName);
                                              if (rawList is List) {
                                                listToLoad = rawList.whereType<MenuData>().toList();
                                              } else {
                                                listToLoad = [];
                                              }
                                              isMenuNameSuggestion = true;
                                            }
                                            _setControllersFromData(section, listToLoad ?? [], isMenuNameSuggestion);
                                          } else {
                                            _clearSectionControllersAndMaps(section);
                                            section.menuKeys.clear();
                                            _sections[index].initialSetCount = _currentSetCount;
                                          }
                                        });
                                      }
                                    },
                                    dropdownColor: colorScheme.surfaceContainer,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  const SizedBox(height: 20),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                      final offsetAnimation = Tween<Offset>(
                                        begin: const Offset(0.0, -0.2),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: offsetAnimation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    key: ValueKey(section.selectedPart),
                                    child: section.selectedPart != null && actualSelectedPart != null
                                        ? Column(
                                      children: [
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: section.menuControllers.length,
                                          itemBuilder: (context, menuIndex) {
                                            final originalPartName = _getOriginalPartName(context, actualSelectedPart);
                                            bool isCurrentMenuNameSuggestion = (record == null || !record.menus.containsKey(originalPartName));

                                            return AnimatedListItem(
                                              key: section.menuKeys[menuIndex],
                                              direction: AnimationDirection.topToBottom,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: GlassCard(
                                                  borderRadius: 10.0,
                                                  backgroundColor: colorScheme.surface,
                                                  padding: const EdgeInsets.all(16.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      StylishInput(
                                                        key: ValueKey('${section.menuControllers[menuIndex].hashCode}_menuName'),
                                                        controller: section.menuControllers[menuIndex],
                                                        // ★修正: ヒントを多言語化
                                                        hint: isCurrentMenuNameSuggestion ? l10n.menuName : null,
                                                        inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                                        normalTextColor: colorScheme.onSurface,
                                                        suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                        fillColor: colorScheme.surfaceContainer,
                                                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                        textAlign: TextAlign.left,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      ListView.separated(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: section.setInputDataList[menuIndex].length,
                                                        separatorBuilder: (context, s) => const SizedBox(height: 8),
                                                        itemBuilder: (context, s) => _buildSetRow(
                                                            context,
                                                            section.setInputDataList,
                                                            menuIndex,
                                                            s + 1,
                                                            s,
                                                            section.selectedPart
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: CircularAddButtonWithText(
                                              // ★修正: ラベルを多言語化
                                              label: l10n.addExercise,
                                              onPressed: () => _addMenuItem(index),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}