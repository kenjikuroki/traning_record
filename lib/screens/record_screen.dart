import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull を使用するためにインポート

import '../models/menu_data.dart';     // MenuData and DailyRecord models
import 'settings_screen.dart'; // SettingsScreen import
import '../widgets/custom_widgets.dart'; // カスタムウィジェットをインポート
import '../main.dart'; // currentThemeMode を使用するためにインポート

// ignore_for_file: library_private_types_in_public_api

// SetInputDataクラスを定義
class SetInputData {
  final TextEditingController weightController;
  final TextEditingController repController;

  SetInputData({
    required this.weightController,
    required this.repController,
  });

  void dispose() {
    weightController.dispose();
    repController.dispose();
  }
}

// アニメーションの方向を定義するenum
enum AnimationDirection {
  topToBottom,
  bottomToTop,
}

// アニメーション付きリストアイテムウィジェット
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final AnimationDirection direction; // 追加：アニメーションの方向

  const AnimatedListItem({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    this.direction = AnimationDirection.bottomToTop, // デフォルトは下から上
  }) : super(key: key);

  @override
  _AnimatedListItemState createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    Offset beginOffset;
    if (widget.direction == AnimationDirection.topToBottom) {
      beginOffset = const Offset(0.0, -0.5); // 上から下へスライド
    } else {
      beginOffset = const Offset(0.0, 0.5); // 下から上へスライド
    }

    _offsetAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }
}

// Helper class to hold data for each target section
class SectionData {
  final Key key; // セクションのキー
  String? selectedPart; // Selected training part for this section
  List<TextEditingController> menuControllers; // Controllers for exercise names in this section
  List<List<SetInputData>> setInputDataList; // SetInputDataのリストに変更
  int? initialSetCount; // このセクションの初期セット数を保持
  List<Key> menuKeys; // 各メニューアイテムのキーを保持

  SectionData({
    Key? key,
    this.selectedPart,
    required this.menuControllers,
    required this.setInputDataList,
    this.initialSetCount,
    required this.menuKeys,
  }) : this.key = key ?? UniqueKey();

  // Factory constructor to create a new empty section data with default controllers
  static SectionData createEmpty(int setCount, {bool shouldPopulateDefaults = true}) {
    return SectionData(
      menuControllers: shouldPopulateDefaults ? List.generate(1, (_) => TextEditingController()) : [],
      setInputDataList: shouldPopulateDefaults ? List.generate(1, (_) => List.generate(setCount, (_) => SetInputData(weightController: TextEditingController(), repController: TextEditingController()))) : [],
      initialSetCount: setCount,
      menuKeys: shouldPopulateDefaults ? List.generate(1, (_) => UniqueKey()) : [],
    );
  }

  // Method to dispose all controllers within this section
  void dispose() {
    for (var c in menuControllers) {
      c.dispose();
    }
    for (var list in setInputDataList) {
      for (var data in list) {
        data.dispose();
      }
    }
  }
}

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox;
  final Box<List<MenuData>> lastUsedMenusBox;
  final Box<Map<String, bool>> settingsBox;
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
  // トレーニング部位の順番と名称を修正
  final List<String> _allBodyParts = [
    '有酸素運動', '腕', '胸', '背中', '肩', '足', '全身', 'その他１', 'その他２', 'その他３',
  ];

  List<SectionData> _sections = [];

  int _currentSetCount = 3;

  // 各コントローラーが「提案データ（未確定）」であるかを管理するマップ
  final Map<TextEditingController, bool> _isSuggestionDisplayMap = {};

  @override
  void initState() {
    super.initState();
    _loadSettingsAndParts();
  }

  void _loadSettingsAndParts() {
    Map<dynamic, dynamic>? savedDynamicBodyPartsSettings = widget.settingsBox.get('selectedBodyParts');
    Map<String, bool>? savedBodyPartsSettings;

    if (savedDynamicBodyPartsSettings != null) {
      savedBodyPartsSettings = {}; // 明示的に新しいマップを初期化
      savedDynamicBodyPartsSettings.forEach((key, value) {
        // キーがString、値がboolであることを確認してから追加
        if (key is String && value is bool) {
          savedBodyPartsSettings![key] = value;
        } else {
          // ログ出力などでデバッグ情報を残すことも可能
          // print('Warning: Invalid type for body part setting - Key: $key, Value: $value');
        }
      });
    }

    int? savedSetCount = widget.setCountBox.get('setCount');

    // savedBodyPartsSettings が null または空の場合に _allBodyParts を使用するように修正
    if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
      _filteredBodyParts = _allBodyParts
          .where((part) => savedBodyPartsSettings![part] == true)
          .toList();
      // 全ての部位がfalseでフィルタリングされた場合もデフォルトに戻す
      if (_filteredBodyParts.isEmpty) {
        _filteredBodyParts = List.from(_allBodyParts);
      }
    } else {
      _filteredBodyParts = List.from(_allBodyParts);
    }

    _currentSetCount = savedSetCount ?? 3;

    setState(() {
      _loadInitialSections();
    });
  }

  // Load initial sections (existing data or create a new empty section)
  void _loadInitialSections() {
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = widget.recordsBox.get(dateKey); // Saved data for today
    Box<List<MenuData>> lastUsedMenusBox = widget.lastUsedMenusBox; // Last used menus (suggestions)

    _clearAllControllersAndMaps(); // Clear existing controllers and their suggestion states
    _sections.clear();

    Map<String, SectionData> tempSectionsMap = {}; // Use this to build sections

    // Helper to add a menu to tempSectionsMap
    void addMenuToTempMap(String part, MenuData menuData, bool isSuggestionForWeightReps) {
      SectionData section = tempSectionsMap.putIfAbsent(part, () => SectionData(
        key: UniqueKey(),
        selectedPart: part,
        menuControllers: [],
        setInputDataList: [],
        initialSetCount: _currentSetCount,
        menuKeys: [],
      ));

      final menuCtrl = TextEditingController(text: menuData.name);
      section.menuControllers.add(menuCtrl);
      section.menuKeys.add(UniqueKey());
      _isSuggestionDisplayMap[menuCtrl] = false; // Exercise name is always confirmed (dark text)

      List<SetInputData> setInputDataRow = [];
      int currentMenuSetCount = menuData.weights.length;
      for (int s = 0; s < currentMenuSetCount; s++) {
        final weightCtrl = TextEditingController(text: menuData.weights[s]);
        final repCtrl = TextEditingController(text: menuData.reps[s]);
        _isSuggestionDisplayMap[weightCtrl] = isSuggestionForWeightReps; // Mark as suggestion if it is
        _isSuggestionDisplayMap[repCtrl] = isSuggestionForWeightReps; // Mark as suggestion if it is
        setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
      }
      section.setInputDataList.add(setInputDataRow);
    }

    // Check if there is ANY confirmed data for the selected date.
    // If not, immediately set to initial empty state and return.
    if (record == null || record.menus.isEmpty) {
      _sections.add(SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false));
      _sections[0].initialSetCount = _currentSetCount;
      setState(() {});
      return; // Crucial: Exit here if no confirmed data for this specific date
    }

    // If we reached here, there IS confirmed data for the selected date.
    // Proceed to load confirmed data first.
    record.menus.forEach((part, menuList) {
      for (var menuData in menuList) {
        addMenuToTempMap(part, menuData, false); // Confirmed data is NOT a suggestion for weight/reps
      }
    });

    // Then, overlay with suggestion data from lastUsedMenusBox.
    // This ensures that thin values persist if they are not overwritten by confirmed data.
    for (String part in _allBodyParts) {
      List<MenuData>? lastUsedMenuList = lastUsedMenusBox.get(part);

      if (lastUsedMenuList != null && lastUsedMenuList.isNotEmpty) {
        SectionData section = tempSectionsMap.putIfAbsent(part, () => SectionData(
          key: UniqueKey(),
          selectedPart: part,
          menuControllers: [],
          setInputDataList: [],
          initialSetCount: _currentSetCount,
          menuKeys: [],
        ));

        for (var suggestionMenuData in lastUsedMenuList) {
          // Try to find an existing menu with the same name in this section
          int existingMenuIndex = section.menuControllers.indexWhere((ctrl) => ctrl.text == suggestionMenuData.name);

          if (existingMenuIndex == -1) {
            // Menu does not exist, add it as a new item (with suggestion status for weights/reps)
            final menuCtrl = TextEditingController(text: suggestionMenuData.name);
            section.menuControllers.add(menuCtrl);
            section.menuKeys.add(UniqueKey());
            _isSuggestionDisplayMap[menuCtrl] = false; // Menu name is always confirmed

            List<SetInputData> setInputDataRow = [];
            int currentMenuSetCount = suggestionMenuData.weights.length;
            for (int s = 0; s < currentMenuSetCount; s++) {
              final weightCtrl = TextEditingController(text: suggestionMenuData.weights[s]);
              final repCtrl = TextEditingController(text: suggestionMenuData.reps[s]);
              _isSuggestionDisplayMap[weightCtrl] = true; // Mark as suggestion
              _isSuggestionDisplayMap[repCtrl] = true; // Mark as suggestion
              setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
            }
            section.setInputDataList.add(setInputDataRow);
          } else {
            // Menu already exists. Update its weight/rep values if they are currently suggestions or empty.
            // Do NOT overwrite if they are already confirmed (from recordsBox).
            List<SetInputData> existingSetInputDataRow = section.setInputDataList[existingMenuIndex];
            int suggestionMenuSetCount = suggestionMenuData.weights.length;

            // Adjust size of existingSetInputDataRow to match suggestionMenuSetCount
            while (existingSetInputDataRow.length < suggestionMenuSetCount) {
              final weightCtrl = TextEditingController();
              final repCtrl = TextEditingController();
              _isSuggestionDisplayMap[weightCtrl] = true; // New sets are suggestions
              _isSuggestionDisplayMap[repCtrl] = true;
              existingSetInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
            }
            while (existingSetInputDataRow.length > suggestionMenuSetCount) {
              existingSetInputDataRow.removeLast().dispose();
            }

            for (int s = 0; s < suggestionMenuSetCount; s++) {
              final existingWeightCtrl = existingSetInputDataRow[s].weightController;
              final existingRepCtrl = existingSetInputDataRow[s].repController;

              // If the existing value is confirmed (not marked as suggestion) AND not empty, leave it.
              // Otherwise, update with suggestion and mark as suggestion.
              if (!(_isSuggestionDisplayMap[existingWeightCtrl] ?? false) && existingWeightCtrl.text.isNotEmpty) {
                // Existing weight is confirmed and not empty, do nothing.
              } else {
                existingWeightCtrl.text = suggestionMenuData.weights[s];
                _isSuggestionDisplayMap[existingWeightCtrl] = true; // Mark as suggestion
              }

              if (!(_isSuggestionDisplayMap[existingRepCtrl] ?? false) && existingRepCtrl.text.isNotEmpty) {
                // Existing rep is confirmed and not empty, do nothing.
              } else {
                existingRepCtrl.text = suggestionMenuData.reps[s];
                _isSuggestionDisplayMap[existingRepCtrl] = true; // Mark as suggestion
              }
            }
          }
        }
      }
    }

    _sections = tempSectionsMap.values.toList();

    // 各セクションの初期セット数を調整し、不足しているセットを追加
    for (var section in _sections) {
      int maxSetsInSection = _currentSetCount; // デフォルトのセット数で初期化
      for (var menuInputDataList in section.setInputDataList) {
        if (menuInputDataList.isNotEmpty) {
          maxSetsInSection = maxSetsInSection > menuInputDataList.length ? maxSetsInSection : menuInputDataList.length;
        }
      }
      // 設定のセット数と読み込んだデータの最大セット数の大きい方を使用
      section.initialSetCount = maxSetsInSection > _currentSetCount ? maxSetsInSection : _currentSetCount;

      for (var setInputDataRow in section.setInputDataList) {
        while (setInputDataRow.length < section.initialSetCount!) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          _isSuggestionDisplayMap[weightCtrl] = true; // 新しく追加されるセットは提案としてマーク
          _isSuggestionDisplayMap[repCtrl] = true;
          setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
        }
      }
    }

    // 部位の順序でセクションをソート
    _sections.sort((a, b) {
      if (a.selectedPart == null && b.selectedPart == null) return 0;
      if (a.selectedPart == null) return 1; // nullは最後に
      if (b.selectedPart == null) return -1; // nullは最後に
      int indexA = _allBodyParts.indexOf(a.selectedPart!);
      int indexB = _allBodyParts.indexOf(b.selectedPart!);
      return indexA.compareTo(indexB);
    });

    setState(() {}); // UIを更新
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set data to controllers (including dynamic size adjustment)
  // このメソッドは_loadInitialSectionsの内部ロジックに置き換えられたため、直接呼び出されることはなくなりますが、
  // 他の箇所でまだ使われている可能性を考慮し、修正は最小限に留めます。
  void _setControllersFromData(List<TextEditingController> menuCtrls, List<List<SetInputData>> setInputDataList, List<Key> menuKeys, List<MenuData> list, int actualSetCount, bool isSuggestionData) {
    // 既存のコントローラーを破棄し、マップのエントリをクリア
    for (int i = 0; i < menuCtrls.length; i++) {
      menuCtrls[i].dispose();
      _isSuggestionDisplayMap.remove(menuCtrls[i]);
      if (i < setInputDataList.length) {
        for (var data in setInputDataList[i]) {
          data.weightController.dispose();
          data.repController.dispose();
          _isSuggestionDisplayMap.remove(data.weightController);
          _isSuggestionDisplayMap.remove(data.repController);
        }
      }
    }
    menuCtrls.clear();
    setInputDataList.clear();
    menuKeys.clear();

    int itemsToCreate = list.isNotEmpty ? list.length : 1; // データがない場合は1つの空の入力行を作成

    for (int i = 0; i < itemsToCreate; i++) {
      final newMenuController = TextEditingController();
      if (i < list.length) {
        newMenuController.text = list[i].name;
        _isSuggestionDisplayMap[newMenuController] = false; // 種目名は常に確定状態
      } else {
        _isSuggestionDisplayMap[newMenuController] = false; // 新規追加の種目名も確定状態
      }
      menuCtrls.add(newMenuController);
      menuKeys.add(UniqueKey());

      final newSetInputDataRow = <SetInputData>[];
      for (int s = 0; s < actualSetCount; s++) {
        final newWeightController = TextEditingController();
        final newRepController = TextEditingController();

        String loadedWeight = '';
        String loadedRep = '';

        if (i < list.length && s < list[i].weights.length) {
          loadedWeight = list[i].weights[s];
          loadedRep = list[i].reps[s];
        }

        newWeightController.text = loadedWeight;
        newRepController.text = loadedRep;

        // isSuggestionDataがtrueの場合、重量と回数を提案としてマーク
        _isSuggestionDisplayMap[newWeightController] = isSuggestionData;
        _isSuggestionDisplayMap[newRepController] = isSuggestionData;

        newSetInputDataRow.add(SetInputData(
          weightController: newWeightController,
          repController: newRepController,
        ));
      }
      setInputDataList.add(newSetInputDataRow);
    }
  }

  // セクション内のコントローラーとマップエントリをクリアするヘルパー
  void _clearSectionControllersAndMaps(List<TextEditingController> menuCtrls, List<List<SetInputData>> setInputDataList) {
    for (var c in menuCtrls) {
      c.dispose();
      _isSuggestionDisplayMap.remove(c);
    }
    for (var list in setInputDataList) {
      for (var data in list) {
        data.weightController.dispose();
        data.repController.dispose();
        _isSuggestionDisplayMap.remove(data.weightController);
        _isSuggestionDisplayMap.remove(data.repController);
      }
    }
    menuCtrls.clear();
    setInputDataList.clear();
  }

  // すべてのセクションのコントローラーとマップエントリをクリアするヘルパー
  void _clearAllControllersAndMaps() {
    for (var section in _sections) {
      _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
    }
    _isSuggestionDisplayMap.clear();
  }

  // テキスト変更またはタップを処理するハンドラー
  void _confirmInput(TextEditingController controller) {
    setState(() {
      // ユーザーが入力内容を変更またはタップしたら、提案表示状態を解除（確定）
      _isSuggestionDisplayMap[controller] = false;
    });
  }

  // Save data for all sections
  void _saveAllSectionsData() {
    String dateKey = _getDateKey(widget.selectedDate);
    Map<String, List<MenuData>> allMenusForDay = {};
    String? lastModifiedPart;

    // --- Part 1: Prepare data for DailyRecord (only confirmed data) ---
    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> sectionMenuListForRecord = [];
      bool sectionHasConfirmedContent = false;
      int currentSectionSetCount = section.initialSetCount ?? _currentSetCount;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<String> weights = [];
        List<String> reps = [];
        bool rowHasConfirmedContent = false;

        // 種目名は常に確定状態なので、_isSuggestionDisplayMapはチェックしない
        // ただし、空の種目名は記録として保存しない
        if (name.isEmpty) {
          name = '';
        }

        for (int s = 0; s < currentSectionSetCount; s++) {
          final setInputData = (section.setInputDataList.length > i && section.setInputDataList[i].length > s)
              ? section.setInputDataList[i][s]
              : null;

          String w = '';
          String r = '';

          if (setInputData != null) {
            // 重量と回数が未確定の提案データ（色が薄い状態）であれば、記録として保存しない（空文字列として扱う）
            if (!(_isSuggestionDisplayMap[setInputData.weightController] ?? false)) {
              w = setInputData.weightController.text;
            }
            if (!(_isSuggestionDisplayMap[setInputData.repController] ?? false)) {
              r = setInputData.repController.text;
            }

            if (w.isNotEmpty || r.isNotEmpty) {
              rowHasConfirmedContent = true;
            }
          }

          weights.add(w);
          reps.add(r);
        }

        // 種目名があるか、または少なくとも1つのセットに有効な入力があれば、その種目を記録として保存
        if (name.isNotEmpty || rowHasConfirmedContent) {
          sectionMenuListForRecord.add(MenuData(name: name, weights: weights, reps: reps));
          sectionHasConfirmedContent = true;
        }
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        allMenusForDay[section.selectedPart!] = sectionMenuListForRecord;
        lastModifiedPart = section.selectedPart; // この部分はそのまま維持
      } else {
        allMenusForDay.remove(section.selectedPart);
      }
    }

    // --- Part 2: Save DailyRecord (確定済みデータのみ) ---
    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey); // その日の記録が空になったら削除
    }

    // --- Part 3: Update lastUsedMenusBox (現在表示されているすべてのメニュー、提案データも含む) ---
    // This box stores the last used menus for suggestion purposes.
    // It should only be updated if there's actual content for a part on the current screen.
    // It should NOT be cleared if a part is currently empty on screen.

    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> displayedMenuList = [];
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        // Only consider non-empty menu names for suggestions
        if (name.isEmpty) continue;

        List<String> weights = [];
        List<String> reps = [];
        int currentSectionSetCount = section.initialSetCount ?? _currentSetCount;

        for (int s = 0; s < currentSectionSetCount; s++) {
          final setInputData = (section.setInputDataList.length > i && section.setInputDataList[i].length > s)
              ? section.setInputDataList[i][s]
              : null;

          String w = setInputData?.weightController.text ?? '';
          String r = setInputData?.repController.text ?? '';

          weights.add(w);
          reps.add(r);
        }
        displayedMenuList.add(MenuData(name: name, weights: weights, reps: reps));
      }

      // Only update lastUsedMenusBox for this part if there's actual data to save.
      // If displayedMenuList is empty, it means this part has no current entries,
      // so we should NOT overwrite any existing suggestions in lastUsedMenusBox for this part.
      if (displayedMenuList.isNotEmpty) {
        widget.lastUsedMenusBox.put(section.selectedPart!, displayedMenuList);
      }
      // If displayedMenuList IS empty, we do nothing. This preserves previous suggestions for this part.
      // If the user wants to explicitly clear suggestions for a part, they would need a specific "clear suggestions" button.
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
      setState(() {
        _currentSetCount = widget.setCountBox.get('setCount') ?? 3;

        Map<dynamic, dynamic>? savedDynamicBodyPartsSettings = widget.settingsBox.get('selectedBodyParts');
        Map<String, bool>? savedBodyPartsSettings;

        if (savedDynamicBodyPartsSettings != null) {
          savedBodyPartsSettings = {};
          savedDynamicBodyPartsSettings.forEach((key, value) {
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

        // 設定画面から戻った際、各セクションのセット数を更新し、不足しているセットを追加
        for (var section in _sections) {
          if (section.initialSetCount != null && section.initialSetCount! < _currentSetCount) {
            section.initialSetCount = _currentSetCount;
            for (var setInputDataRow in section.setInputDataList) {
              while (setInputDataRow.length < _currentSetCount) {
                final weightCtrl = TextEditingController();
                final repCtrl = TextEditingController();
                _isSuggestionDisplayMap[weightCtrl] = true; // 新しく追加されるセットは提案としてマーク
                _isSuggestionDisplayMap[repCtrl] = true;
                setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
              }
            }
          }
        }
      });
    });
  }

  void _addMenuItem(int sectionIndex) {
    setState(() {
      int currentSectionSetCount = _sections[sectionIndex].initialSetCount ?? _currentSetCount;
      final newMenuController = TextEditingController();
      _sections[sectionIndex].menuControllers.add(newMenuController);
      _sections[sectionIndex].menuKeys.add(UniqueKey());

      _isSuggestionDisplayMap[newMenuController] = false; // 新規追加の種目名は確定状態
      final newSetInputDataList = List.generate(currentSectionSetCount, (_) {
        final weightCtrl = TextEditingController();
        final repCtrl = TextEditingController();
        _isSuggestionDisplayMap[weightCtrl] = true; // 新規追加の入力は提案としてマーク
        _isSuggestionDisplayMap[repCtrl] = true;
        return SetInputData(weightController: weightCtrl, repController: repCtrl); // Corrected: repController to repCtrl
      });
      _sections[sectionIndex].setInputDataList.add(newSetInputDataList);
    });
  }

  void _addTargetSection() {
    setState(() {
      final newSection = SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false);
      _sections.add(newSection);
      // 新しいセクションには初期の種目名コントローラーやセット入力データは追加しない
      // それらは部位が選択された時に_setControllersFromDataによって追加される
    });
  }

  @override
  void dispose() {
    _saveAllSectionsData(); // アプリ終了時にデータを保存
    _clearAllControllersAndMaps();
    super.dispose();
  }

  // Widget to build each set input row
  Widget buildSetRow(List<List<SetInputData>> setInputDataList, int menuIndex, int setNumber, int setIndex, String? selectedPart) {
    final colorScheme = Theme.of(context).colorScheme;
    final setInputData = setInputDataList[menuIndex][setIndex];

    String weightUnit = 'kg';
    String repUnit = '回';

    if (selectedPart == '有酸素運動') {
      weightUnit = '分';
      repUnit = '秒';
    }

    return Row(
      children: [
        Text(
          '${setNumber}セット：',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StylishInput(
            controller: setInputData.weightController,
            hint: '', // プレースホルダーは空文字列に設定
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isSuggestionDisplay: _isSuggestionDisplayMap[setInputData.weightController] ?? false, // 提案表示状態を渡す
            textAlign: TextAlign.right, // 重量入力は右寄せ
            onChanged: (value) => _confirmInput(setInputData.weightController), // 入力で確定
            onTap: () => _confirmInput(setInputData.weightController), // タップで確定
          ),
        ),
        Text(' $weightUnit ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded(
          child: StylishInput(
            controller: setInputData.repController,
            hint: '', // プレースホルダーは空文字列に設定
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isSuggestionDisplay: _isSuggestionDisplayMap[setInputData.repController] ?? false, // 提案表示状態を渡す
            textAlign: TextAlign.right, // 回数入力は右寄せ
            onChanged: (value) => _confirmInput(setInputData.repController), // 入力で確定
            onTap: () => _confirmInput(setInputData.repController), // タップで確定
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

    // Check for the initial state: only one section and its part is null
    bool isInitialEmptyState = _sections.length == 1 && _sections[0].selectedPart == null;

    return Scaffold(
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
            // Conditionally render the single dropdown or the ListView of sections
            if (isInitialEmptyState)
              Padding(
                padding: const EdgeInsets.only(top: 20.0), // Consistent padding
                child: GlassCard( // GlassCardで囲む
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
                      setState(() {
                        _sections[0].selectedPart = value;
                        if (_sections[0].selectedPart != null) {
                          _clearSectionControllersAndMaps(_sections[0].menuControllers, _sections[0].setInputDataList);
                          _sections[0].menuKeys.clear();

                          String dateKey = _getDateKey(widget.selectedDate);
                          DailyRecord? record = widget.recordsBox.get(dateKey);
                          List<MenuData>? listToLoad;
                          bool isSuggestion = false;

                          if (record != null && record.menus.containsKey(_sections[0].selectedPart!)) {
                            listToLoad = record.menus[_sections[0].selectedPart!];
                            isSuggestion = false;
                          } else {
                            listToLoad = widget.lastUsedMenusBox.get(_sections[0].selectedPart!);
                            isSuggestion = true;
                          }

                          int newSectionSetCount = _currentSetCount;
                          if (listToLoad != null && listToLoad.isNotEmpty) {
                            newSectionSetCount = listToLoad[0].weights.length;
                          }
                          _sections[0].initialSetCount = newSectionSetCount;

                          _setControllersFromData(_sections[0].menuControllers, _sections[0].setInputDataList, _sections[0].menuKeys, listToLoad ?? [], newSectionSetCount, isSuggestion);
                        } else {
                          _clearSectionControllersAndMaps(_sections[0].menuControllers, _sections[0].setInputDataList);
                          _sections[0].menuKeys.clear();
                          _sections[0].initialSetCount = _currentSetCount;
                        }
                      });
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
                    itemCount: _sections.length + 1, // Add 1 for "部位を追加" button
                    itemBuilder: (context, index) {
                      // This handles the "部位を追加" button as the last item in the list
                      if (index == _sections.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: StylishButton(
                              text: '部位を追加',
                              onPressed: _addTargetSection,
                              icon: Icons.add_circle_outline,
                              fontSize: 12.0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            ),
                          ),
                        );
                      }

                      final section = _sections[index];
                      final int sectionDisplaySetCount = section.initialSetCount ?? _currentSetCount;

                      return AnimatedListItem(
                        key: section.key,
                        direction: AnimationDirection.bottomToTop,
                        child: GlassCard(
                          borderRadius: 12.0,
                          backgroundColor: section.selectedPart == '有酸素運動' && isLightMode
                              ? Colors.grey[400]!
                              : colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(20.0),
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
                                  setState(() {
                                    section.selectedPart = value;
                                    if (section.selectedPart != null) {
                                      _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
                                      section.menuKeys.clear();

                                      String dateKey = _getDateKey(widget.selectedDate);
                                      DailyRecord? record = widget.recordsBox.get(dateKey);
                                      List<MenuData>? listToLoad;
                                      bool isSuggestion = false;

                                      if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                        listToLoad = record.menus[section.selectedPart!];
                                        isSuggestion = false;
                                      } else {
                                        listToLoad = widget.lastUsedMenusBox.get(section.selectedPart!);
                                        isSuggestion = true;
                                      }

                                      int newSectionSetCount = _currentSetCount;
                                      if (listToLoad != null && listToLoad.isNotEmpty) {
                                        newSectionSetCount = listToLoad[0].weights.length;
                                      }
                                      section.initialSetCount = newSectionSetCount;

                                      _setControllersFromData(section.menuControllers, section.setInputDataList, section.menuKeys, listToLoad ?? [], newSectionSetCount, isSuggestion);
                                    } else {
                                      _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
                                      section.menuKeys.clear();
                                      section.initialSetCount = _currentSetCount;
                                    }
                                  });
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
                                child: section.selectedPart != null
                                    ? Column(
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: section.menuControllers.length,
                                      itemBuilder: (context, menuIndex) {
                                        return AnimatedListItem(
                                          key: section.menuKeys[menuIndex],
                                          direction: AnimationDirection.topToBottom,
                                          child: GlassCard(
                                            borderRadius: 10.0,
                                            backgroundColor: colorScheme.surface,
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                StylishInput(
                                                  controller: section.menuControllers[menuIndex],
                                                  hint: '種目名',
                                                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                                  textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0, fontWeight: FontWeight.bold),
                                                  fillColor: colorScheme.surfaceContainer,
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                  isSuggestionDisplay: _isSuggestionDisplayMap[section.menuControllers[menuIndex]] ?? false,
                                                  onChanged: (value) => _confirmInput(section.menuControllers[menuIndex]),
                                                  onTap: () => _confirmInput(section.menuControllers[menuIndex]),
                                                ),
                                                const SizedBox(height: 8),
                                                ListView.separated(
                                                  shrinkWrap: true,
                                                  itemCount: section.setInputDataList[menuIndex].length,
                                                  separatorBuilder: (context, s) => const SizedBox(height: 8),
                                                  itemBuilder: (context, s) => buildSetRow(
                                                      section.setInputDataList, menuIndex, s + 1, s, section.selectedPart),
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: StylishButton(
                                          text: '種目を追加',
                                          onPressed: () => _addMenuItem(index),
                                          icon: Icons.add_circle_outline,
                                          fontSize: 12.0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      );
                    }
                ),
              ),
          ],
        ),
      ),
    );
  }
}
