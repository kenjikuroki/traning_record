import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart'; // To use firstWhereOrNull
import 'dart:math'; // To use the max function

import '../models/menu_data.dart';     // MenuData and DailyRecord models
import '../models/record_models.dart'; // New: Importing the data models
import '../widgets/animated_list_item.dart'; // New: Importing the animated widget
import 'settings_screen.dart'; // SettingsScreen import
import '../widgets/custom_widgets.dart'; // Custom widgets
import '../main.dart'; // To use currentThemeMode

// ignore_for_file: library_private_types_in_public_api

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox; // Correct type for the Box
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
  List<String> _filteredBodyParts = [];
  // Corrected order and names of training parts
  final List<String> _allBodyParts = [
    '有酸素運動', '腕', '胸', '背中', '肩', '足', '全身', 'その他１', 'その他２', 'その他３',
  ];

  List<SectionData> _sections = [];

  int _currentSetCount = 3;

  @override
  void initState() {
    super.initState();
    // Lock screen orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _loadSettingsAndParts();
  }

  @override
  void dispose() {
    for (var section in _sections) {
      section.dispose(); // Dispose controllers for each section
    }
    _sections.clear(); // Clear the sections list
    super.dispose();
  }

  void _loadSettingsAndParts() {
    // Build a type-safe Map<String, bool>
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
          .where((part) => savedBodyPartsSettings![part] == true)
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

    // Clear existing sections and controllers
    for (var section in _sections) {
      section.dispose();
    }
    _sections.clear();

    if (record != null && record.menus.isNotEmpty) {
      // Scenario 1: There is an existing DailyRecord for this date (confirmed data)
      Map<String, SectionData> tempSectionsMap = {};
      record.menus.forEach((part, menuList) {
        SectionData section = tempSectionsMap.putIfAbsent(part, () => SectionData(
          key: UniqueKey(),
          selectedPart: part,
          menuControllers: [],
          setInputDataList: [],
          initialSetCount: _currentSetCount, // Temporary initial value
          menuKeys: [],
        ));

        int maxSetsInThisSection = 0; // Track the maximum number of sets in this section

        for (var menuData in menuList) {
          final menuCtrl = TextEditingController(text: menuData.name);
          section.menuControllers.add(menuCtrl);
          section.menuKeys.add(UniqueKey());

          List<SetInputData> setInputDataRow = [];
          // Load all existing confirmed data
          for (int s = 0; s < menuData.weights.length; s++) {
            final weightCtrl = TextEditingController(text: menuData.weights[s]);
            final repCtrl = TextEditingController(text: menuData.reps[s]);
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: false)); // Confirmed data is not a suggestion
          }
          section.setInputDataList.add(setInputDataRow);

          // Update the maximum number of sets in the section based on this menu's sets
          maxSetsInThisSection = max(maxSetsInThisSection, setInputDataRow.length);
        }

        // After loading existing data, ensure all menus have at least _currentSetCount sets
        // Additional sets are empty and marked as suggestions
        for (var setInputDataRow in section.setInputDataList) {
          while (setInputDataRow.length < _currentSetCount) { // Pad up to the current default set count
            final weightCtrl = TextEditingController();
            final repCtrl = TextEditingController();
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: true)); // Additional empty sets are suggestions
          }
        }
        // The section's initialSetCount is the greater of the loaded max sets and the current default sets
        section.initialSetCount = max(maxSetsInThisSection, _currentSetCount);
      });
      _sections = tempSectionsMap.values.toList();

    } else {
      // Scenario 2: No DailyRecord for this date (new day)
      // Start with one empty section. Suggestions will be loaded when a part is selected
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

  // Modified to directly accept SectionData
  void _setControllersFromData(SectionData section, List<MenuData> list, bool isSuggestionData) {
    print('Loading data for part: ${section.selectedPart}, isSuggestionData: $isSuggestionData'); // Debug log
    // Dispose existing controllers
    _clearSectionControllersAndMaps(section); // Pass the entire section
    section.menuKeys.clear();

    int maxSetsInLoadedData = 0; // Track max sets in loaded data (only for confirmed data)

    // Determine the number of menus to load. Create one empty menu if the list is empty
    int itemsToCreate = list.isNotEmpty ? list.length : 1;

    for (int i = 0; i < itemsToCreate; i++) {
      final newMenuController = TextEditingController();
      if (i < list.length) {
        newMenuController.text = list[i].name;
      }
      section.menuControllers.add(newMenuController);
      section.menuKeys.add(UniqueKey());

      final newSetInputDataRow = <SetInputData>[];

      // Load all existing set data
      if (i < list.length) {
        for (int s = 0; s < list[i].weights.length; s++) {
          final newWeightController = TextEditingController(text: list[i].weights[s]);
          final newRepController = TextEditingController(text: list[i].reps[s]);
          newSetInputDataRow.add(SetInputData(weightController: newWeightController, repController: newRepController, isSuggestion: isSuggestionData));
        }
        // Update max sets in loaded data only for confirmed data
        if (!isSuggestionData) {
          maxSetsInLoadedData = max(maxSetsInLoadedData, newSetInputDataRow.length);
        }
      }

      // If less than _currentSetCount, add empty suggestion sets
      // If isSuggestionData is true, strictly match _currentSetCount
      // If isSuggestionData is false, pad up to the greater of maxSetsInLoadedData and _currentSetCount
      int targetSetCountForPadding = isSuggestionData ? _currentSetCount : max(maxSetsInLoadedData, _currentSetCount);

      while (newSetInputDataRow.length < targetSetCountForPadding) {
        final newWeightController = TextEditingController();
        final newRepController = TextEditingController();
        newSetInputDataRow.add(SetInputData(
          weightController: newWeightController,
          repController: newRepController,
          isSuggestion: true, // Padded sets are always suggestions
        ));
      }
      section.setInputDataList.add(newSetInputDataRow);
    }

    // Finally, determine the section's initialSetCount
    if (isSuggestionData) {
      // For suggestion data, display matches the current default set count
      section.initialSetCount = _currentSetCount;
    } else {
      // For confirmed data, display the greater of the loaded max sets and the current default set count
      section.initialSetCount = max(maxSetsInLoadedData, _currentSetCount);
    }
  }

  // Modified to accept SectionData as an argument
  void _clearSectionControllersAndMaps(SectionData section) {
    for (var c in section.menuControllers) {
      c.dispose();
    }
    for (var list in section.setInputDataList) {
      for (var data in list) {
        data.weightController.dispose();
        data.repController.dispose();
      }
    }
    section.menuControllers.clear();
    section.setInputDataList.clear();
  }

  void _saveAllSectionsData() {
    String dateKey = _getDateKey(widget.selectedDate);
    Map<String, List<MenuData>> allMenusForDay = {};
    String? lastModifiedPart;

    // --- Part 1: Prepare data for DailyRecord (only confirmed data) ---
    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> sectionMenuListForRecord = [];
      String? currentPart = section.selectedPart;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<String> confirmedWeights = [];
        List<String> confirmedReps = [];

        // Loop through the actual length of setInputDataList and collect only confirmed data
        for (int s = 0; s < section.setInputDataList[i].length; s++) {
          final setInputData = section.setInputDataList[i][s];

          String w = setInputData.weightController.text;
          String r = setInputData.repController.text;

          if (w.isNotEmpty || r.isNotEmpty) {
            confirmedWeights.add(w);
            confirmedReps.add(r);
          }
        }

        // Filter and save only sets that actually have data
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

        if (name.isNotEmpty && hasAnyConfirmedSetData) {
          sectionMenuListForRecord.add(MenuData(name: name, weights: finalWeights, reps: finalReps));
          lastModifiedPart = currentPart;
        }
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        allMenusForDay[currentPart!] = sectionMenuListForRecord;
      } else {
        widget.recordsBox.delete(dateKey);
      }
    }

    // --- Part 2: Save DailyRecord (only confirmed data) ---
    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey);
    }

    // --- Part 3: Update lastUsedMenusBox (all currently displayed menus, including suggestions) ---
    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> displayedMenuList = [];
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        if (name.isEmpty) continue;

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
        widget.lastUsedMenusBox.put(section.selectedPart!, displayedMenuList);
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
                .where((part) => savedBodyPartsSettings![part] == true)
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

                  if (isEmpty) {
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
                  setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: true)); // New sets are suggestions
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
    if (mounted) {
      setState(() {
        int setsForNewMenu = _currentSetCount;
        final newMenuController = TextEditingController();
        _sections[sectionIndex].menuControllers.add(newMenuController);
        _sections[sectionIndex].menuKeys.add(UniqueKey());

        while (_sections[sectionIndex].setInputDataList.length < _sections[sectionIndex].menuControllers.length) {
          _sections[sectionIndex].setInputDataList.add([]);
        }

        final newSetInputDataList = List.generate(setsForNewMenu, (_) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          return SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: true); // Newly added sets are suggestions
        });
        _sections[sectionIndex].setInputDataList[_sections[sectionIndex].menuControllers.length - 1] = newSetInputDataList;

        _sections[sectionIndex].initialSetCount = max(_sections[sectionIndex].initialSetCount ?? 0, setsForNewMenu);
      });
    }
  }

  void _addTargetSection() {
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

    String weightUnit = 'kg';
    String repUnit = '回';

    if (selectedPart == '有酸素運動') {
      weightUnit = '分';
      repUnit = '秒';
    }

    // Determine text color based on the isSuggestion flag
    final Color textColor = setInputData.isSuggestion
        ? colorScheme.onSurfaceVariant.withOpacity(0.5)
        : colorScheme.onSurface;

    return Row(
      children: [
        Text(
          '${setNumber}セット：',
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
            normalTextColor: textColor, // Modified here
            suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            textAlign: TextAlign.right,
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
            normalTextColor: textColor, // Modified here
            suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            textAlign: TextAlign.right,
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

    // Define colors for the "+ Part" button (darker in light mode)
    final Color partNormalBgColor = isLightMode ? const Color(0xFF333333) : const Color(0xFF2C2F33);
    final Color partPressedBgColor = isLightMode ? const Color(0xFF1A1A1A) : const Color(0xFF383C40);
    final Color partTextColor = isLightMode ? Colors.white : const Color(0xFFCCCCCC);
    final Color partAccentColor = isLightMode ? const Color(0xFF60A5FA) : const Color(0xFF60A5FA);

    bool isInitialEmptyState = _sections.length == 1 && _sections[0].selectedPart == null;

    return WillPopScope(
      onWillPop: () async {
        _saveAllSectionsData();
        return true;
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
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
                        hintText: 'トレーニング部位を選択',
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
                              bool isSuggestion = false;

                              if (record != null && record.menus.containsKey(actualSelectedPart)) {
                                listToLoad = record.menus[actualSelectedPart];
                                isSuggestion = false;
                              } else {
                                final dynamic rawList = widget.lastUsedMenusBox.get(actualSelectedPart);
                                if (rawList is List) {
                                  listToLoad = rawList.map((e) {
                                    if (e is Map) {
                                      return MenuData.fromJson(Map<String, dynamic>.from(e));
                                    }
                                    return e as MenuData;
                                  }).toList();
                                }
                                isSuggestion = true;
                              }

                              _setControllersFromData(_sections[0], listToLoad ?? [], isSuggestion);

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
                                label: '＋部位',
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

                        return AnimatedListItem(
                          key: section.key,
                          direction: AnimationDirection.bottomToTop,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: GlassCard(
                              borderRadius: 12.0,
                              backgroundColor: section.selectedPart == '有酸素運動' && isLightMode
                                  ? Colors.grey[400]!
                                  : colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      hintText: 'トレーニング部位を選択',
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
                                            final String actualSelectedPart = section.selectedPart!;

                                            _clearSectionControllersAndMaps(section);
                                            section.menuKeys.clear();

                                            String dateKey = _getDateKey(widget.selectedDate);
                                            DailyRecord? record = widget.recordsBox.get(dateKey);
                                            List<MenuData>? listToLoad;
                                            bool isSuggestion = false;

                                            if (record != null && record.menus.containsKey(actualSelectedPart)) {
                                              listToLoad = record.menus[actualSelectedPart];
                                              isSuggestion = false;
                                            } else {
                                              final dynamic rawList = widget.lastUsedMenusBox.get(actualSelectedPart);
                                              if (rawList is List) {
                                                listToLoad = rawList.map((e) {
                                                  if (e is Map) {
                                                    return MenuData.fromJson(Map<String, dynamic>.from(e));
                                                  }
                                                  return e as MenuData;
                                                }).toList();
                                              }
                                              isSuggestion = true;
                                            }

                                            _setControllersFromData(section, listToLoad ?? [], isSuggestion);

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
                                    child: section.selectedPart != null
                                        ? Column(
                                      children: [
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: section.menuControllers.length,
                                          itemBuilder: (context, menuIndex) {
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
                                                        hint: '種目名を記入',
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
                                              label: '＋種目',
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
