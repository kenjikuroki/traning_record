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
      // シナリオ1: 選択された日付にDailyRecordがある場合 (確定データ)
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

        int maxSetsInThisSection = 0;

        for (var menuData in menuList) {
          final menuCtrl = TextEditingController(text: menuData.name);
          section.menuControllers.add(menuCtrl);
          section.menuKeys.add(UniqueKey());

          List<SetInputData> setInputDataRow = [];
          // DailyRecordからのロードは確定データなので isSuggestion: false
          for (int s = 0; s < menuData.weights.length; s++) {
            final weightCtrl = TextEditingController(text: menuData.weights[s]);
            final repCtrl = TextEditingController(text: menuData.reps[s]);
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: false));
          }
          section.setInputDataList.add(setInputDataRow);

          maxSetsInThisSection = max(maxSetsInThisSection, setInputDataRow.length);
        }

        // 既存のデータをロードした後、全てのメニューが少なくとも _currentSetCount のセット数を持つようにする
        // 追加のセットは空で、提案としてマークされる
        for (var setInputDataRow in section.setInputDataList) {
          while (setInputDataRow.length < _currentSetCount) {
            final weightCtrl = TextEditingController();
            final repCtrl = TextEditingController();
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: true)); // 追加される空のセットは提案
          }
        }
        section.initialSetCount = max(maxSetsInThisSection, _currentSetCount);
      });
      _sections = tempSectionsMap.values.toList();

    } else {
      // シナリオ2: 選択された日付にDailyRecordがない場合 (新しい日)
      // まずは空のセクションを1つ追加し、部位選択時にlastUsedMenusBoxから提案をロードする
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
      setState(() {
      });
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Modified to directly accept SectionData
  void _setControllersFromData(SectionData section, List<MenuData> list, bool isMenuNameSuggestion) {
    _clearSectionControllersAndMaps(section); // Pass the entire section
    section.menuKeys.clear();

    // ロードするメニューの数を決定。リストが空の場合は1つの空のメニューを作成
    int itemsToCreate = list.isNotEmpty ? list.length : 1;

    for (int i = 0; i < itemsToCreate; i++) {
      final newMenuController = TextEditingController();
      if (i < list.length) {
        newMenuController.text = list[i].name;
      }
      section.menuControllers.add(newMenuController);
      section.menuKeys.add(UniqueKey());

      final newSetInputDataRow = <SetInputData>[];

      // lastUsedMenusBoxからのロードは提案なので isSetsSuggestion は true
      // DailyRecordからのロードの場合、このメソッドに渡されるisMenuNameSuggestionがfalseになり、その際はセットも確定扱いになる
      // このisSetsSuggestionはあくまでlastUsedMenusBoxからのロード時のデフォルト挙動を定義
      bool isSetsSuggestion = isMenuNameSuggestion; // メニュー名が提案なら、セットも提案

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
          isSuggestion: true, // 追加される空のセットは常に提案
        ));
      }
      section.setInputDataList.add(newSetInputDataRow);
    }

    // ロードされたメニューの最大セット数とデフォルトの大きい方で初期化
    int maxSetsInLoadedMenus = 0;
    for (var menuSets in section.setInputDataList) {
      maxSetsInLoadedMenus = max(maxSetsInLoadedMenus, menuSets.length);
    }
    section.initialSetCount = max(maxSetsInLoadedMenus, _currentSetCount);
  }


  // Modified to accept SectionData as an argument
  void _clearSectionControllersAndMaps(SectionData section) {
    for (var c in section.menuControllers) {
      c.dispose();
    }
    for (var list in section.setInputDataList) {
      for (var data in list) {
        data.dispose(); // SetInputData の dispose を呼び出す
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
        List<String> confirmedReps = []; // <-- ここは confirmedReps に修正済み

        // Loop through the actual length of setInputDataList and collect only confirmed data
        for (int s = 0; s < section.setInputDataList[i].length; s++) {
          final setInputData = section.setInputDataList[i][s];

          String w = setInputData.weightController.text;
          String r = setInputData.repController.text;

          // isSuggestion: false のセットのみ、確定データとして保存
          // isSuggestion: true の場合は、値が入っていても保存しない
          if (!setInputData.isSuggestion) {
            confirmedWeights.add(w);
            confirmedReps.add(r); // <-- ここも confirmedReps に修正済み
          } else {
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

        // 種目名があり、かつ確定セットデータが存在する場合のみ保存
        if (name.isNotEmpty && hasAnyConfirmedSetData) {
          sectionMenuListForRecord.add(MenuData(name: name, weights: finalWeights, reps: finalReps));
          lastModifiedPart = currentPart;
        } else {
        }
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        allMenusForDay[currentPart!] = sectionMenuListForRecord;
      } else {
        widget.recordsBox.delete(dateKey); // その部位の確定メニューが空の場合、DailyRecordからその部位を削除
      }
    }

    // --- Part 2: Save DailyRecord (only confirmed data) ---
    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey); // 全てのメニューが空の場合、日付の記録を削除
    }

    // --- Part 3: Update lastUsedMenusBox (all currently displayed menus, including suggestions) ---
    // lastUsedMenusBoxには、画面に表示されている全てのメニューの現在の状態を保存する
    // (種目名と、各セットの現在の入力値。isSuggestionの状態は考慮しない)
    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> displayedMenuList = [];
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        if (name.isEmpty) {
          continue; // 種目名が空の場合は保存しない
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
        widget.lastUsedMenusBox.put(section.selectedPart!, displayedMenuList);
      } else {
        widget.lastUsedMenusBox.delete(section.selectedPart!); // その部位のlastUsedMenusBoxも削除
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
              // 実際に値が入力されているセット数（isSuggestionに関わらず）を把握
              for (int s = 0; s < setInputDataRow.length; s++) {
                final setInputData = setInputDataRow[s];
                if (setInputData.weightController.text.isNotEmpty ||
                    setInputData.repController.text.isNotEmpty) {
                  actualMaxSetsInThisMenu = s + 1;
                }
              }

              // 表示ターゲットは、現在の入力状況とデフォルトセット数の大きい方
              int targetSetCountForThisMenu = max(actualMaxSetsInThisMenu, _currentSetCount);

              // ターゲットより多い不要な空のセットを削除
              if (setInputDataRow.length > targetSetCountForThisMenu) {
                for (int s = setInputDataRow.length - 1; s >= targetSetCountForThisMenu; s--) {
                  final setInputData = setInputDataRow[s];
                  bool isEmpty = setInputData.weightController.text.isEmpty &&
                      setInputData.repController.text.isEmpty;

                  // 空の提案セットのみ削除対象とする
                  if (isEmpty && setInputData.isSuggestion) {
                    setInputData.dispose();
                    setInputDataRow.removeAt(s);
                  } else {
                    // 空でない、または確定のセットは残す
                    break;
                  }
                }
              } else if (setInputDataRow.length < targetSetCountForThisMenu) {
                // ターゲットより少ない場合に空の提案セットを追加
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
    // 種目の上限チェック
    if (_sections[sectionIndex].menuControllers.length >= 15) { // MAXを15とする
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目は15個までしか追加できません。')),
      );
      return; // ここで処理を終了し、新しい種目を追加しない
    }

    if (mounted) {
      setState(() {
        int setsForNewMenu = _currentSetCount; // コメントアウトを解除

        final newMenuController = TextEditingController();
        _sections[sectionIndex].menuControllers.add(newMenuController);
        _sections[sectionIndex].menuKeys.add(UniqueKey());

        // このwhileループは既存のロジックで必要であれば残します。
        // 新しいメニューが追加された際に、対応するsetInputDataListが不足しないようにするためです。
        while (_sections[sectionIndex].menuControllers.length > _sections[sectionIndex].setInputDataList.length) {
          _sections[sectionIndex].setInputDataList.add([]);
        }

        final newSetInputDataList = List.generate(setsForNewMenu, (_) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          // 新規追加されるセットは「確定」とするため、isSuggestion: false に変更
          return SetInputData(weightController: weightCtrl, repController: repCtrl, isSuggestion: false);
        });
        _sections[sectionIndex].setInputDataList[_sections[sectionIndex].menuControllers.length - 1] = newSetInputDataList;

        _sections[sectionIndex].initialSetCount = max(_sections[sectionIndex].initialSetCount ?? 0, setsForNewMenu);
      });
    }
  }

  void _addTargetSection() {
    // 部位の上限チェック
    if (_sections.length >= 10) { // MAXを10とする
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('部位は10個までしか追加できません。')),
      );
      return; // ここで処理を終了し、新しい部位を追加しない
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
            hint: '', // このhintは使用されないので空でOK
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            normalTextColor: textColor, // isSuggestionに応じて変わる色
            suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            textAlign: TextAlign.right,
            onChanged: (text) {
              // 値が入力され、かつisSuggestionがtrueの場合にisSuggestionをfalseに
              if (text.isNotEmpty && setInputData.isSuggestion) {
                setState(() {
                  setInputData.isSuggestion = false;
                });
              } else if (text.isEmpty && !setInputData.isSuggestion) {
                // 値が空になり、かつisSuggestionがfalseの場合にisSuggestionをtrueに（元に戻す）
                // ただし、DailyRecordからロードされたものは戻さないロジックも検討が必要
                // 現在のロジックでは、一度確定されると手動で値を消してもSuggestionには戻らない
                // このロジックはDailyRecordとlastUsedMenusBoxの区別を考慮する必要があります
                // 現状維持で、一度確定したら薄くならない、で良いでしょう
              }
            },
          ),
        ),
        Text(' $weightUnit ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded(
          child: StylishInput(
            key: ValueKey('${setInputData.repController.hashCode}_rep_${menuIndex}_$setIndex'),
            controller: setInputData.repController,
            hint: '', // このhintは使用されないので空でOK
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            normalTextColor: textColor, // isSuggestionに応じて変わる色
            suggestionTextColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            textAlign: TextAlign.right,
            onChanged: (text) {
              // 値が入力され、かつisSuggestionがtrueの場合にisSuggestionをfalseに
              if (text.isNotEmpty && setInputData.isSuggestion) {
                setState(() {
                  setInputData.isSuggestion = false;
                });
              } else if (text.isEmpty && !setInputData.isSuggestion) {
                // 上記と同様に、一度確定したら薄くならない現状維持で良いでしょう
              }
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

    // Define colors for the "+ Part" button (darker in light mode)
    final Color partNormalBgColor = isLightMode ? const Color(0xFF333333) : const Color(0xFF2C2F33);
    final Color partPressedBgColor = isLightMode ? const Color(0xFF1A1A1A) : const Color(0xFF383C40);
    final Color partTextColor = isLightMode ? Colors.white : const Color(0xFFCCCCCC);
    final Color partAccentColor = isLightMode ? const Color(0xFF60A5FA) : const Color(0xFF60A5FA);

    bool isInitialEmptyState = _sections.length == 1 && _sections[0].selectedPart == null;

    return PopScope( // WillPopScope は PopScope に置き換えられました
      canPop: true, // ポップ可能
      onPopInvoked: (didPop) {
        if (didPop) {
          _saveAllSectionsData();
        }
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

                              // メニュー名のヒント表示を制御するフラグ
                              // DailyRecordにデータがある場合は種目名は確定（false）、なければ提案（true）
                              bool isMenuNameSuggestion;

                              if (record != null && record.menus.containsKey(actualSelectedPart)) {
                                listToLoad = record.menus[actualSelectedPart];
                                isMenuNameSuggestion = false; // DailyRecordからなので確定
                              } else {
                                final dynamic rawList = widget.lastUsedMenusBox.get(actualSelectedPart);
                                // ★ここを修正しました★
                                if (rawList is List) {
                                  listToLoad = rawList.whereType<MenuData>().toList();
                                } else {
                                  listToLoad = []; // rawListがListでない場合もlistToLoadを初期化
                                }
                                isMenuNameSuggestion = true; // lastUsedMenusBoxからなので提案
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
                                            final String currentSelectedPart = section.selectedPart!;

                                            _clearSectionControllersAndMaps(section);
                                            section.menuKeys.clear();

                                            String dateKey = _getDateKey(widget.selectedDate);
                                            DailyRecord? record = widget.recordsBox.get(dateKey);
                                            List<MenuData>? listToLoad;

                                            bool isMenuNameSuggestion;
                                            if (record != null && record.menus.containsKey(currentSelectedPart)) {
                                              listToLoad = record.menus[currentSelectedPart];
                                              isMenuNameSuggestion = false; // DailyRecordからなので確定
                                            } else {
                                              final dynamic rawList = widget.lastUsedMenusBox.get(currentSelectedPart);
                                              // ★ここを修正しました★
                                              if (rawList is List) {
                                                listToLoad = rawList.whereType<MenuData>().toList();
                                              } else {
                                                listToLoad = []; // rawListがListでない場合もlistToLoadを初期化
                                              }
                                              isMenuNameSuggestion = true; // lastUsedMenusBoxからなので提案
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
                                            // この時点での isMenuNameSuggestion を決定
                                            bool isCurrentMenuNameSuggestion = (record == null || !record.menus.containsKey(actualSelectedPart));

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
                                                        // hint を isCurrentMenuNameSuggestion に応じて設定
                                                        hint: isCurrentMenuNameSuggestion ? '種目名を記入' : null,
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