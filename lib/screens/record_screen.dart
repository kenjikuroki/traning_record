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
    _saveAllSectionsData(); // アプリ終了時にデータを保存
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
    DailyRecord? record = widget.recordsBox.get(dateKey); // Saved data for today

    _clearAllControllersAndMaps(); // Clear existing controllers and their suggestion states
    _sections.clear();

    Map<String, SectionData> tempSectionsMap = {}; // Use this to build sections

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
      _isSuggestionDisplayMap[menuCtrl] = isSuggestionForWeightReps; // ★ 修正: 種目名もisSuggestionDataに基づいて設定 ★

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

    if (record != null && record.menus.isNotEmpty) {
      record.menus.forEach((part, menuList) {
        for (var menuData in menuList) {
          addMenuToTempMap(part, menuData, false); // Confirmed data is NOT a suggestion
        }
      });
      _sections = tempSectionsMap.values.toList();
    } else {
      _sections.add(SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false));
      _sections[0].initialSetCount = _currentSetCount;
    }

    for (var section in _sections) {
      int maxSetsInSection = _currentSetCount;
      for (var menuInputDataList in section.setInputDataList) {
        if (menuInputDataList.isNotEmpty) {
          maxSetsInSection = maxSetsInSection > menuInputDataList.length ? maxSetsInSection : menuInputDataList.length;
        }
      }
      section.initialSetCount = maxSetsInSection > _currentSetCount ? maxSetsInSection : _currentSetCount;

      for (var setInputDataRow in section.setInputDataList) {
        while (setInputDataRow.length < section.initialSetCount!) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          _isSuggestionDisplayMap[weightCtrl] = true;
          _isSuggestionDisplayMap[repCtrl] = true;
          setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
        }
      }
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

  void _setControllersFromData(List<TextEditingController> menuCtrls, List<List<SetInputData>> setInputDataList, List<Key> menuKeys, List<MenuData> list, int actualSetCount, bool isSuggestionData) {
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

    int itemsToCreate = list.isNotEmpty ? list.length : 1;

    for (int i = 0; i < itemsToCreate; i++) {
      final newMenuController = TextEditingController();
      if (i < list.length) {
        newMenuController.text = list[i].name;
        _isSuggestionDisplayMap[newMenuController] = isSuggestionData; // ★ 修正: 種目名もisSuggestionDataに基づいて設定 ★
      } else {
        _isSuggestionDisplayMap[newMenuController] = false; // 新規追加の種目名は確定状態
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

    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> sectionMenuListForRecord = [];
      String? currentPart = section.selectedPart;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<String> confirmedWeights = [];
        List<String> confirmedReps = [];
        bool menuHasConfirmedContent = false; // この種目全体に確定済みデータがあるか

        // 種目名が確定済みであれば、menuHasConfirmedContentをtrueにする
        if (!(_isSuggestionDisplayMap[section.menuControllers[i]] ?? false) && name.isNotEmpty) {
          menuHasConfirmedContent = true;
        }

        int currentSectionSetCount = section.initialSetCount ?? _currentSetCount;
        for (int s = 0; s < currentSectionSetCount; s++) {
          final setInputData = (section.setInputDataList.length > i && section.setInputDataList[i].length > s)
              ? section.setInputDataList[i][s]
              : null;

          String w = '';
          String r = '';

          if (setInputData != null) {
            if (!(_isSuggestionDisplayMap[setInputData.weightController] ?? false)) {
              w = setInputData.weightController.text;
              if (w.isNotEmpty) menuHasConfirmedContent = true; // 重量も確定済みならtrue
            }
            if (!(_isSuggestionDisplayMap[setInputData.repController] ?? false)) {
              r = setInputData.repController.text;
              if (r.isNotEmpty) menuHasConfirmedContent = true; // 回数も確定済みならtrue
            }
          }
          confirmedWeights.add(w);
          confirmedReps.add(r);
        }

        // ★ 修正: この種目全体に確定済みデータがある場合のみ、記録として保存 ★
        if (menuHasConfirmedContent) {
          sectionMenuListForRecord.add(MenuData(name: name, weights: confirmedWeights, reps: confirmedReps));
          lastModifiedPart = currentPart;
        }
      }

      if (sectionMenuListForRecord.isNotEmpty) {
        allMenusForDay[currentPart!] = sectionMenuListForRecord;
      } else {
        allMenusForDay.remove(currentPart);
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

      List<MenuData> displayedMenuList = [];
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
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

          for (var section in _sections) {
            if (section.initialSetCount != null && section.initialSetCount! < _currentSetCount) {
              section.initialSetCount = _currentSetCount;
              for (var setInputDataRow in section.setInputDataList) {
                while (setInputDataRow.length < _currentSetCount) {
                  final weightCtrl = TextEditingController();
                  final repCtrl = TextEditingController();
                  _isSuggestionDisplayMap[weightCtrl] = true;
                  _isSuggestionDisplayMap[repCtrl] = true;
                  setInputDataRow.add(SetInputData(weightController: weightCtrl, repController: repCtrl));
                }
              }
            }
          }
        });
      }
    });
  }

  void _addMenuItem(int sectionIndex) {
    if (mounted) {
      setState(() {
        int currentSectionSetCount = _sections[sectionIndex].initialSetCount ?? _currentSetCount;
        final newMenuController = TextEditingController();
        _sections[sectionIndex].menuControllers.add(newMenuController);
        _sections[sectionIndex].menuKeys.add(UniqueKey());

        _isSuggestionDisplayMap[newMenuController] = false;
        final newSetInputDataList = List.generate(currentSectionSetCount, (_) {
          final weightCtrl = TextEditingController();
          final repCtrl = TextEditingController();
          _isSuggestionDisplayMap[weightCtrl] = true;
          _isSuggestionDisplayMap[repCtrl] = true;
          return SetInputData(weightController: weightCtrl, repController: repCtrl);
        });
        _sections[sectionIndex].setInputDataList.add(newSetInputDataList);
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
                            _clearSectionControllersAndMaps(_sections[0].menuControllers, _sections[0].setInputDataList);
                            _sections[0].menuKeys.clear();

                            String dateKey = _getDateKey(widget.selectedDate);
                            DailyRecord? record = widget.recordsBox.get(dateKey);
                            List<MenuData>? listToLoad;
                            bool isSuggestion = false;

                            if (record != null && record.menus.containsKey(value)) {
                              listToLoad = record.menus[value];
                              isSuggestion = false;
                            } else {
                              final dynamic rawList = widget.lastUsedMenusBox.get(value);
                              if (rawList is List) {
                                listToLoad = rawList.map((e) {
                                  if (e is Map) {
                                    return MenuData.fromJson(e);
                                  }
                                  return e as MenuData;
                                }).toList();
                              }
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
                                  if (mounted) {
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
                                          final dynamic rawList = widget.lastUsedMenusBox.get(section.selectedPart!);
                                          if (rawList is List) {
                                            listToLoad = rawList.map((e) {
                                              if (e is Map) {
                                                return MenuData.fromJson(e);
                                              }
                                              return e as MenuData;
                                            }).toList();
                                          }
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
                                                  hint: '種目名',
                                                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                                  textStyle: TextStyle(
                                                    color: (section.selectedPart == '有酸素運動' && isLightMode) ? Colors.black : colorScheme.onSurface,
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  fillColor: colorScheme.surfaceContainer,
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                  isSuggestionDisplay: _isSuggestionDisplayMap[section.menuControllers[menuIndex]] ?? false,
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
                                                  itemCount: section.setInputDataList[menuIndex].length,
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
      // FloatingActionButton は削除済み
    );
  }
}
