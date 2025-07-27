import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull を使用するためにインポート
import 'dart:math'; // max関数を使用するためにインポート

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
  int? initialSetCount; // このセクションの表示セット数を保持 (max(実際のセット数, デフォルトセット数))
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
  final Box<dynamic> lastUsedMenusBox;
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
    // 画面の向きを縦向きに固定
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _loadSettingsAndParts();
  }

  @override
  void dispose() {
    // _saveAllSectionsData() は WillPopScope で呼び出すため、ここから削除
    _clearAllControllersAndMaps();
    super.dispose();
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

    _clearAllControllersAndMaps(); // Always clear existing controllers
    _sections.clear();

    if (record != null && record.menus.isNotEmpty) {
      // シナリオ1: この日付に既存のDailyRecordがある場合
      Map<String, SectionData> tempSectionsMap = {};
      record.menus.forEach((part, menuList) {
        SectionData section = tempSectionsMap.putIfAbsent(part, () => SectionData(
          key: UniqueKey(),
          selectedPart: part,
          menuControllers: [],
          setInputDataList: [],
          initialSetCount: _currentSetCount, // 仮の初期値
          menuKeys: [],
        ));

        int maxSetsInThisSection = 0; // このセクション内の最大セット数を追跡

        for (var menuData in menuList) {
          final menuCtrl = TextEditingController(text: menuData.name);
          section.menuControllers.add(menuCtrl);
          section.menuKeys.add(UniqueKey());
          _isSuggestionDisplayMap[menuCtrl] = false; // 確定済みデータ

          List<SetInputData> setInputDataRow = [];
          // 既存のデータをすべてロード
          for (int s = 0; s < menuData.weights.length; s++) {
            final weightCtrl = TextEditingController(text: menuData.weights[s]);
            final repCtrl = TextEditingController(text: menuData.reps[s]);
            _isSuggestionDisplayMap[weightCtrl] = false; // 確定済みデータ
            _isSuggestionDisplayMap[repCtrl] = false; // 確定済みデータ
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
          }
          section.setInputDataList.add(setInputDataRow);

          // このメニューのセット数を考慮して、セクションの最大セット数を更新
          maxSetsInThisSection = max(maxSetsInThisSection, setInputDataRow.length);
        }

        // 既存データをロードした後、すべてのメニューが少なくとも_currentSetCountのセット数を持つことを保証
        // 追加されるセットは空で、提案としてマークされる
        for (var setInputDataRow in section.setInputDataList) {
          while (setInputDataRow.length < _currentSetCount) { // 現在のデフォルトセット数までパディング
            final weightCtrl = TextEditingController();
            final repCtrl = TextEditingController();
            _isSuggestionDisplayMap[weightCtrl] = true; // 提案としてマーク
            _isSuggestionDisplayMap[repCtrl] = true; // 提案としてマーク
            setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
          }
        }
        // セクションのinitialSetCountは、ロードされた最大セット数と現在のデフォルトセット数の大きい方
        section.initialSetCount = max(maxSetsInThisSection, _currentSetCount);
      });
      _sections = tempSectionsMap.values.toList();

    } else {
      // シナリオ2: この日付にDailyRecordがない場合（新規の日）
      // 1つの空のセクションから開始。部位が選択されたときに提案がロードされる
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

  // SectionDataを直接受け取るように変更
  void _setControllersFromData(SectionData section, List<MenuData> list, bool isSuggestionData) {
    // 既存のコントローラーを破棄
    _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
    section.menuKeys.clear();

    int maxSetsInLoadedData = 0; // ロードされたデータ内の最大セット数を追跡 (確定データの場合のみ使用)

    // ロードするメニューの数を決定。リストが空の場合は1つ（空のメニュー）を作成
    int itemsToCreate = list.isNotEmpty ? list.length : 1;

    for (int i = 0; i < itemsToCreate; i++) {
      final newMenuController = TextEditingController();
      if (i < list.length) {
        newMenuController.text = list[i].name;
        _isSuggestionDisplayMap[newMenuController] = isSuggestionData; // 種目名もisSuggestionDataに基づいて設定
      } else {
        _isSuggestionDisplayMap[newMenuController] = false; // 新規追加の種目名は確定状態
      }
      section.menuControllers.add(newMenuController);
      section.menuKeys.add(UniqueKey());

      final newSetInputDataRow = <SetInputData>[];

      // 既存のセットデータをすべてロード
      if (i < list.length) {
        for (int s = 0; s < list[i].weights.length; s++) {
          final newWeightController = TextEditingController(text: list[i].weights[s]);
          final newRepController = TextEditingController(text: list[i].reps[s]);
          _isSuggestionDisplayMap[newWeightController] = isSuggestionData;
          _isSuggestionDisplayMap[newRepController] = isSuggestionData;
          newSetInputDataRow.add(SetInputData(weightController: newWeightController, repController: newRepController));
        }
        // 確定データの場合のみ、ロードされたデータ内の最大セット数を更新
        if (!isSuggestionData) {
          maxSetsInLoadedData = max(maxSetsInLoadedData, list[i].weights.length);
        }
      }

      // _currentSetCount に満たない場合は、空の提案セットを追加
      // isSuggestionDataがtrueの場合は_currentSetCountに厳密に合わせる
      // isSuggestionDataがfalseの場合は、maxSetsInLoadedDataと_currentSetCountの大きい方までパディング
      int targetSetCountForPadding = isSuggestionData ? _currentSetCount : max(maxSetsInLoadedData, _currentSetCount);

      while (newSetInputDataRow.length < targetSetCountForPadding) {
        final newWeightController = TextEditingController();
        final newRepController = TextEditingController();
        _isSuggestionDisplayMap[newWeightController] = true; // 新しいセットは提案としてマーク
        _isSuggestionDisplayMap[newRepController] = true;
        newSetInputDataRow.add(SetInputData(
          weightController: newWeightController,
          repController: newRepController,
        ));
      }
      section.setInputDataList.add(newSetInputDataRow);
    }

    // セクションのinitialSetCountを最終的に決定
    if (isSuggestionData) {
      // 提案データの場合、表示は現在のデフォルトセット数に合わせる
      section.initialSetCount = _currentSetCount;
    } else {
      // 確定データの場合、ロードされた最大セット数と現在のデフォルトセット数の大きい方を表示
      section.initialSetCount = max(maxSetsInLoadedData, _currentSetCount);
    }
  }

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

  void _clearAllControllersAndMaps() {
    for (var section in _sections) {
      _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
    }
    _isSuggestionDisplayMap.clear();
  }

  void _confirmInput(TextEditingController controller) {
    if (mounted) {
      setState(() {
        _isSuggestionDisplayMap[controller] = false;
      });
    }
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

        // setInputDataList の実際の長さまでループし、確定済みデータのみを収集
        // ここでは、表示されている全てのセットをチェックするが、保存するのは確定データのみ
        for (int s = 0; s < section.setInputDataList[i].length; s++) {
          final setInputData = section.setInputDataList[i][s];

          String w = '';
          String r = '';

          // 重量と回数が確定済み（提案ではない）場合のみ、その値を採用
          if (!(_isSuggestionDisplayMap[setInputData.weightController] ?? false)) {
            w = setInputData.weightController.text;
          }
          if (!(_isSuggestionDisplayMap[setInputData.repController] ?? false)) {
            r = setInputData.repController.text;
          }
          confirmedWeights.add(w);
          confirmedReps.add(r);
        }

        // 実際にデータがあるセットだけをフィルタリングして保存
        List<String> finalWeights = [];
        List<String> finalReps = [];
        for (int k = 0; k < confirmedWeights.length; k++) {
          // 重量または回数に値がある場合のみ追加
          if (confirmedWeights[k].isNotEmpty || confirmedReps[k].isNotEmpty) {
            finalWeights.add(confirmedWeights[k]);
            finalReps.add(confirmedReps[k]);
          }
        }

        // 種目名が確定済み（提案ではない）かつ空でない場合、またはセットに確定データがある場合
        bool menuNameConfirmedAndNotEmpty = !(_isSuggestionDisplayMap[section.menuControllers[i]] ?? false) && name.isNotEmpty;
        bool hasAnyConfirmedSetData = finalWeights.isNotEmpty || finalReps.isNotEmpty;

        if (menuNameConfirmedAndNotEmpty || hasAnyConfirmedSetData) {
          sectionMenuListForRecord.add(MenuData(name: name, weights: finalWeights, reps: finalReps));
          lastModifiedPart = currentPart; // 最後に編集された部位を更新
        }
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        allMenusForDay[currentPart!] = sectionMenuListForRecord;
      } else {
        // その部位に確定済みデータがなければ、その日の記録からその部位を削除する
        allMenusForDay.remove(currentPart);
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
    // lastUsedMenusBoxには、現在画面に表示されている（入力されている、または提案として表示されている）
    // 各部位のメニューを保存します。これは、次回の提案のために使用されます。
    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> displayedMenuList = [];
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        // 種目名が空の場合は、lastUsedMenusBoxに保存しない
        if (name.isEmpty) continue;

        List<String> weights = [];
        List<String> reps = [];
        // ここでは setInputDataList の実際の長さを基準にする
        for (int s = 0; s < section.setInputDataList[i].length; s++) {
          final setInputData = section.setInputDataList[i][s];

          String w = setInputData.weightController.text;
          String r = setInputData.repController.text;

          weights.add(w);
          reps.add(r);
        }
        displayedMenuList.add(MenuData(name: name, weights: weights, reps: reps));
      }

      // 表示されているメニューリストが空でなければ、lastUsedMenusBoxを更新
      if (displayedMenuList.isNotEmpty) {
        widget.lastUsedMenusBox.put(section.selectedPart!, displayedMenuList);
      }
      // もしdisplayedMenuListが空の場合、その部位のlastUsedMenusBoxは更新しない（既存の提案を保持）
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

          // 設定変更後、既存のセクションのセット数を調整
          for (var section in _sections) {
            // まず、このセクションに確定データがあるかを確認
            bool hasConfirmedData = false;
            int maxConfirmedSets = 0;
            for (var menuCtrl in section.menuControllers) {
              if (!(_isSuggestionDisplayMap[menuCtrl] ?? false) && menuCtrl.text.isNotEmpty) {
                hasConfirmedData = true;
                break;
              }
            }
            if (!hasConfirmedData) { // 種目名に確定データがない場合
              for (var setInputDataRow in section.setInputDataList) {
                for (var setInputData in setInputDataRow) {
                  if (!(_isSuggestionDisplayMap[setInputData.weightController] ?? false) && setInputData.weightController.text.isNotEmpty) {
                    hasConfirmedData = true;
                    break;
                  }
                  if (!(_isSuggestionDisplayMap[setInputData.repController] ?? false) && setInputData.repController.text.isNotEmpty) {
                    hasConfirmedData = true;
                    break;
                  }
                }
                if (hasConfirmedData) break;
              }
            }


            // 各メニューのセット数を調整
            for (int menuIndex = 0; menuIndex < section.menuControllers.length; menuIndex++) {
              List<SetInputData> setInputDataRow = section.setInputDataList[menuIndex];

              // _currentSetCountよりも多いセットを、それが「提案データ」（空の入力フィールド）であれば削除
              // 後ろからイテレートすることで安全に要素を削除
              for (int s = setInputDataRow.length - 1; s >= _currentSetCount; s--) {
                final setInputData = setInputDataRow[s];
                // 重量と回数コントローラーの両方が提案としてマークされており、かつ両方のテキストが空の場合のみ削除
                if ((_isSuggestionDisplayMap[setInputData.weightController] ?? false) &&
                    (_isSuggestionDisplayMap[setInputData.repController] ?? false) &&
                    setInputData.weightController.text.isEmpty &&
                    setInputData.repController.text.isEmpty) {
                  setInputData.dispose(); // コントローラーを破棄してから削除
                  setInputDataRow.removeAt(s);
                } else {
                  // 確定データであるか、内容がある場合は保持する。
                  // 空の提案セットを末尾からのみ削除するため、ループを抜ける。
                  break;
                }
              }

              // 不足しているセットを追加
              while (setInputDataRow.length < _currentSetCount) {
                final weightCtrl = TextEditingController();
                final repCtrl = TextEditingController();
                _isSuggestionDisplayMap[weightCtrl] = true; // 新しく追加されるセットは提案としてマーク
                _isSuggestionDisplayMap[repCtrl] = true;
                setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
              }

              // このメニューの確定セット数を計算
              int confirmedSetsInThisMenu = 0;
              for (var data in setInputDataRow) {
                if (!(_isSuggestionDisplayMap[data.weightController] ?? false) || !(_isSuggestionDisplayMap[data.repController] ?? false) || data.weightController.text.isNotEmpty || data.repController.text.isNotEmpty) {
                  confirmedSetsInThisMenu++;
                }
              }
              maxConfirmedSets = max(maxConfirmedSets, confirmedSetsInThisMenu);
            }

            // セクションのinitialSetCountを最終的に決定
            // 確定データがある場合は、その最大セット数とデフォルトの大きい方
            // 確定データがない場合は、デフォルトセット数
            section.initialSetCount = hasConfirmedData ? max(maxConfirmedSets, _currentSetCount) : _currentSetCount;
          }
        });
      }
    });
  }

  void _addMenuItem(int sectionIndex) {
    if (mounted) {
      setState(() {
        // 新しいメニューアイテムには、現在のデフォルトセット数分のセットを追加
        int setsForNewMenu = _currentSetCount;
        final newMenuController = TextEditingController();
        _sections[sectionIndex].menuControllers.add(newMenuController);
        _sections[sectionIndex].menuKeys.add(UniqueKey());

        _isSuggestionDisplayMap[newMenuController] = false; // 新規追加の種目名は確定状態
        final newSetInputDataList = List.generate(setsForNewMenu, (_) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          _isSuggestionDisplayMap[weightCtrl] = true; // 新規追加の入力は提案としてマーク
          _isSuggestionDisplayMap[repCtrl] = true;
          return SetInputData(weightController: weightCtrl, repController: repCtrl);
        });
        _sections[sectionIndex].setInputDataList.add(newSetInputDataList);

        // 新しいメニューが追加されたことで、セクションの表示セット数が変わる可能性がある
        // ここでは、デフォルトセット数に合わせて追加されるため、max(_currentSetCount, ...) でOK
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

  Widget _buildSetRow(BuildContext context, List<List<SetInputData>> setInputDataList, int menuIndex, int setNumber, int setIndex, String? selectedPart, Map<TextEditingController, bool> isSuggestionDisplayMap, VoidCallback triggerSetState) {
    final colorScheme = Theme.of(context).colorScheme;
    // setInputDataList[menuIndex][setIndex] が存在することを前提とする
    // itemCount が section.initialSetCount に制限されているため、このインデックスは常に有効
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
            hint: '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(
              color: (isSuggestionDisplayMap[setInputData.weightController] ?? false) ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.onSurface,
              fontSize: 16.0,
            ),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isSuggestionDisplay: isSuggestionDisplayMap[setInputData.weightController] ?? false,
            textAlign: TextAlign.right,
            onChanged: (value) {
              isSuggestionDisplayMap[setInputData.weightController] = false;
              triggerSetState();
            },
            onTap: () {
              isSuggestionDisplayMap[setInputData.weightController] = false;
              triggerSetState();
            },
          ),
        ),
        Text(' $weightUnit ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded(
          child: StylishInput(
            controller: setInputData.repController,
            hint: '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(
              color: (isSuggestionDisplayMap[setInputData.repController] ?? false) ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.onSurface,
              fontSize: 16.0,
            ),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isSuggestionDisplay: isSuggestionDisplayMap[setInputData.repController] ?? false,
            textAlign: TextAlign.right,
            onChanged: (value) {
              isSuggestionDisplayMap[setInputData.repController] = false;
              triggerSetState();
            },
            onTap: () {
              isSuggestionDisplayMap[setInputData.repController] = false;
              triggerSetState();
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

    bool isInitialEmptyState = _sections.length == 1 && _sections[0].selectedPart == null;

    return WillPopScope( // WillPopScope を追加
      onWillPop: () async {
        _saveAllSectionsData(); // 画面を離れる際にデータを保存
        return true; // true を返すと画面がポップされる
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

                              _clearSectionControllersAndMaps(_sections[0].menuControllers, _sections[0].setInputDataList);
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

                              // _setControllersFromDataにSectionDataを直接渡す
                              _setControllersFromData(_sections[0], listToLoad ?? [], isSuggestion);

                            } else {
                              _clearSectionControllersAndMaps(_sections[0].menuControllers, _sections[0].setInputDataList);
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
                              child: StylishButton(
                                text: '＋部位',
                                onPressed: _addTargetSection,
                                fontSize: 12.0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                buttonColor: Colors.blue.shade700,
                              ),
                            ),
                          );
                        }

                        final section = _sections[index];

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
                                    if (mounted) {
                                      setState(() {
                                        section.selectedPart = value;
                                        if (section.selectedPart != null) {
                                          final String actualSelectedPart = section.selectedPart!;

                                          _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
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

                                          // _setControllersFromDataにSectionDataを直接渡す
                                          _setControllersFromData(section, listToLoad ?? [], isSuggestion);

                                        } else {
                                          _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
                                          section.menuKeys.clear();
                                          section.initialSetCount = _currentSetCount;
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
                                            child: GlassCard(
                                              borderRadius: 10.0,
                                              backgroundColor: colorScheme.surface,
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  StylishInput(
                                                    controller: section.menuControllers[menuIndex],
                                                    hint: '種目名を記入', // ヒントテキスト
                                                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                                    textStyle: TextStyle(
                                                      color: (_isSuggestionDisplayMap[section.menuControllers[menuIndex]] ?? false) ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.onSurface,
                                                      fontSize: 16.0,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    fillColor: colorScheme.surfaceContainer,
                                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                    isSuggestionDisplay: _isSuggestionDisplayMap[section.menuControllers[menuIndex]] ?? false,
                                                    textAlign: TextAlign.left, // 左寄せ
                                                    onChanged: (value) {
                                                      if (mounted) {
                                                        setState(() {
                                                          _isSuggestionDisplayMap[section.menuControllers[menuIndex]] = false;
                                                        });
                                                      }
                                                    },
                                                    onTap: () {
                                                      if (mounted) {
                                                        setState(() {
                                                          _isSuggestionDisplayMap[section.menuControllers[menuIndex]] = false;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ListView.separated(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    // ここを修正: section.initialSetCount を使用して表示されるセット数を制限
                                                    itemCount: section.initialSetCount ?? _currentSetCount,
                                                    separatorBuilder: (context, s) => const SizedBox(height: 8),
                                                    itemBuilder: (context, s) => _buildSetRow(
                                                        context,
                                                        section.setInputDataList,
                                                        menuIndex,
                                                        s + 1,
                                                        s,
                                                        section.selectedPart,
                                                        _isSuggestionDisplayMap,
                                                            () {
                                                          if (mounted) {
                                                            setState(() {});
                                                          }
                                                        }
                                                    ),
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
                                            text: '＋種目',
                                            onPressed: () => _addMenuItem(index),
                                            fontSize: 12.0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            buttonColor: Colors.blue.shade400,
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
      ),
    );
  }
}
