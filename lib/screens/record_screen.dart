import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  final List<String> _allBodyParts = [
    '腕', '胸', '肩', '背中', '足', '全体', 'その他',
  ];

  List<SectionData> _sections = [];

  int _currentSetCount = 3;

  // 各コントローラーのプレースホルダー状態を管理するマップ
  final Map<TextEditingController, bool> _isPlaceholderMap = {};
  // 各コントローラーの初期状態がプレースホルダーだったかを管理するマップ（ユーザーがクリアした時に元に戻すため）
  final Map<TextEditingController, bool> _initialSuggestionStatusMap = {};

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
    DailyRecord? record = widget.recordsBox.get(dateKey);

    _clearAllControllersAndMaps();

    _sections.clear();

    if (record != null && record.menus.isNotEmpty) {
      record.menus.forEach((part, menuList) {
        int sectionSpecificSetCount = _currentSetCount;
        if (menuList.isNotEmpty) {
          // Changed to check weights.length as it's now List<String>
          sectionSpecificSetCount = menuList[0].weights.length;
        }
        SectionData section = SectionData(
          key: UniqueKey(),
          selectedPart: part,
          menuControllers: [],
          setInputDataList: [],
          initialSetCount: sectionSpecificSetCount,
          menuKeys: [],
        );
        // isSuggestionDataをfalseに設定して、DailyRecordからの読み込みであることを示す
        _setControllersFromData(section.menuControllers, section.setInputDataList, section.menuKeys, menuList, sectionSpecificSetCount, false);
        _sections.add(section);
      });
    } else {
      // 初期状態では1つの空のセクションを追加し、種目名とセット入力は表示しない
      // 部位が選択された時に初めて種目名とセット入力を追加する
      _sections.add(SectionData.createEmpty(_currentSetCount, shouldPopulateDefaults: false));
      _sections[0].initialSetCount = _currentSetCount;
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set data to controllers (including dynamic size adjustment)
  void _setControllersFromData(List<TextEditingController> menuCtrls, List<List<SetInputData>> setInputDataList, List<Key> menuKeys, List<MenuData> list, int actualSetCount, bool isSuggestionData) {
    // 既存のコントローラーを破棄し、マップのエントリをクリア
    for (int i = 0; i < menuCtrls.length; i++) {
      menuCtrls[i].dispose();
      _isPlaceholderMap.remove(menuCtrls[i]); // 種目名コントローラーのマップエントリを削除
      _initialSuggestionStatusMap.remove(menuCtrls[i]);

      if (i < setInputDataList.length) {
        for (var data in setInputDataList[i]) {
          data.weightController.dispose();
          data.repController.dispose();
          _isPlaceholderMap.remove(data.weightController);
          _isPlaceholderMap.remove(data.repController);
          _initialSuggestionStatusMap.remove(data.weightController);
          _initialSuggestionStatusMap.remove(data.repController);
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
        _isPlaceholderMap[newMenuController] = newMenuController.text.isEmpty; // 種目名が空ならプレースホルダー
      } else {
        _isPlaceholderMap[newMenuController] = true; // 新規追加はプレースホルダー
      }
      _initialSuggestionStatusMap[newMenuController] = _isPlaceholderMap[newMenuController]!;
      newMenuController.addListener(() => _handleInputChanged(newMenuController));
      menuCtrls.add(newMenuController);
      menuKeys.add(UniqueKey());

      final newSetInputDataRow = <SetInputData>[];
      for (int s = 0; s < actualSetCount; s++) {
        final newWeightController = TextEditingController();
        final newRepController = TextEditingController();

        // Weights and reps are now List<String>
        String loadedWeight = '';
        String loadedRep = '';

        if (i < list.length && s < list[i].weights.length) {
          loadedWeight = list[i].weights[s];
          loadedRep = list[i].reps[s];
        }

        newWeightController.text = loadedWeight;
        _isPlaceholderMap[newWeightController] = loadedWeight.isEmpty; // 空文字列ならプレースホルダー
        newRepController.text = loadedRep;
        _isPlaceholderMap[newRepController] = loadedRep.isEmpty; // 空文字列ならプレースホルダー

        // _initialSuggestionStatusMapを_isPlaceholderMapの初期値で設定
        _initialSuggestionStatusMap[newWeightController] = _isPlaceholderMap[newWeightController]!;
        _initialSuggestionStatusMap[newRepController] = _isPlaceholderMap[newRepController]!;

        newSetInputDataRow.add(SetInputData(
          weightController: newWeightController,
          repController: newRepController,
        ));

        // リスナーを追加
        newWeightController.addListener(() => _handleInputChanged(newWeightController));
        newRepController.addListener(() => _handleInputChanged(newRepController));
      }
      setInputDataList.add(newSetInputDataRow);
    }
  }

  // セクション内のコントローラーとマップエントリをクリアするヘルパー
  void _clearSectionControllersAndMaps(List<TextEditingController> menuCtrls, List<List<SetInputData>> setInputDataList) {
    for (var c in menuCtrls) {
      c.dispose();
      _isPlaceholderMap.remove(c); // 種目名コントローラーのマップエントリを削除
      _initialSuggestionStatusMap.remove(c);
    }
    for (var list in setInputDataList) {
      for (var data in list) {
        data.weightController.dispose();
        data.repController.dispose();
        _isPlaceholderMap.remove(data.weightController);
        _isPlaceholderMap.remove(data.repController);
        _initialSuggestionStatusMap.remove(data.repController);
        _initialSuggestionStatusMap.remove(data.repController);
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
    _isPlaceholderMap.clear();
    _initialSuggestionStatusMap.clear();
  }

  // テキスト変更を処理する新しいハンドラー
  void _handleInputChanged(TextEditingController controller) {
    setState(() {
      // ユーザーが入力内容をクリアした場合、プレースホルダー状態に戻す
      // （StylishInputがヒントを表示するかどうかを制御するため）
      _isPlaceholderMap[controller] = controller.text.isEmpty;
    });
  }

  // Save data for all sections
  void _saveAllSectionsData() {
    String dateKey = _getDateKey(widget.selectedDate);
    Map<String, List<MenuData>> allMenusForDay = {};
    String? lastModifiedPart;

    for (var section in _sections) {
      if (section.selectedPart == null) continue;

      List<MenuData> sectionMenuList = [];
      bool sectionHasContent = false;
      int currentSectionSetCount = section.initialSetCount ?? _currentSetCount;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<String> weights = []; // List<String> に変更
        List<String> reps = []; // List<String> に変更
        bool rowHasContent = false; // この行（種目）に何らかの有効な入力があるか

        for (int s = 0; s < currentSectionSetCount; s++) {
          final setInputData = (section.setInputDataList.length > i && section.setInputDataList[i].length > s)
              ? section.setInputDataList[i][s]
              : null;

          String w = ''; // String に変更
          String r = ''; // String に変更

          if (setInputData != null) {
            w = setInputData.weightController.text; // 直接テキストを取得
            r = setInputData.repController.text; // 直接テキストを取得

            // このセットに有効な入力があるかを判定 (空でないテキストがあれば有効な入力とする)
            if (w.isNotEmpty || r.isNotEmpty) {
              rowHasContent = true;
            }
          }

          weights.add(w);
          reps.add(r);
        }

        // 種目名があるか、または少なくとも1つのセットに有効な入力があれば、その種目を保存
        if (name.isNotEmpty || rowHasContent) {
          sectionMenuList.add(MenuData(name: name, weights: weights, reps: reps));
          sectionHasContent = true;
        }
      }

      if (sectionMenuList.isNotEmpty) {
        allMenusForDay[section.selectedPart!] = sectionMenuList;
        lastModifiedPart = section.selectedPart;
        widget.lastUsedMenusBox.put(section.selectedPart!, sectionMenuList);
      } else {
        allMenusForDay.remove(section.selectedPart);
      }
    }

    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      widget.recordsBox.put(dateKey, newRecord);
    } else {
      widget.recordsBox.delete(dateKey);
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

        for (var section in _sections) {
          if (section.initialSetCount != null && section.initialSetCount! < _currentSetCount) {
            section.initialSetCount = _currentSetCount;
            for (var setInputDataRow in section.setInputDataList) {
              while (setInputDataRow.length < _currentSetCount) {
                final weightCtrl = TextEditingController();
                final repCtrl = TextEditingController();
                _isPlaceholderMap[weightCtrl] = true; // 新しく追加されるセットもプレースホルダーとして開始
                _isPlaceholderMap[repCtrl] = true;
                _initialSuggestionStatusMap[weightCtrl] = true;
                _initialSuggestionStatusMap[repCtrl] = true;
                weightCtrl.addListener(() => _handleInputChanged(weightCtrl));
                repCtrl.addListener(() => _handleInputChanged(repCtrl));
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

      _isPlaceholderMap[newMenuController] = true; // 新規追加の種目名はプレースホルダー
      _initialSuggestionStatusMap[newMenuController] = true;
      newMenuController.addListener(() => _handleInputChanged(newMenuController));

      final newSetInputDataList = List.generate(currentSectionSetCount, (_) {
        final weightCtrl = TextEditingController();
        final repCtrl = TextEditingController();
        _isPlaceholderMap[weightCtrl] = true; // 新規追加の入力はプレースホルダー
        _isPlaceholderMap[repCtrl] = true;
        _initialSuggestionStatusMap[weightCtrl] = true;
        _initialSuggestionStatusMap[repCtrl] = true;
        weightCtrl.addListener(() => _handleInputChanged(weightCtrl));
        repCtrl.addListener(() => _handleInputChanged(repCtrl));
        return SetInputData(weightController: weightCtrl, repController: repCtrl);
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
    _saveAllSectionsData();
    _clearAllControllersAndMaps();
    super.dispose();
  }

  // Widget to build each set input row
  Widget buildSetRow(List<List<SetInputData>> setInputDataList, int menuIndex, int setNumber, int setIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final setInputData = setInputDataList[menuIndex][setIndex];

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
            hint: '', // 空欄の場合に表示するヒントテキスト（今回は空）
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isPlaceholder: _isPlaceholderMap[setInputData.weightController] ?? false, // プレースホルダー状態をStylishInputに伝える
            textAlign: TextAlign.right, // 重量入力は右寄せ
          ),
        ),
        Text(' kg ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded(
          child: StylishInput(
            controller: setInputData.repController,
            hint: '', // 空欄の場合に表示するヒントテキスト（今回は空）
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
            fillColor: colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isPlaceholder: _isPlaceholderMap[setInputData.repController] ?? false, // プレースホルダー状態をStylishInputに伝える
            textAlign: TextAlign.right, // 回数入力は右寄せ
          ),
        ),
        Text(' 回', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            Expanded(
              child: ListView.builder(
                itemCount: _sections.length + 1,
                itemBuilder: (context, index) {
                  // 「部位を追加」ボタンの表示制御
                  if (index == _sections.length) {
                    return Visibility(
                      visible: _sections.any((s) => s.selectedPart != null), // いずれかの部位が選択されていれば表示
                      child: Padding(
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
                      ),
                    );
                  }

                  final section = _sections[index];
                  final int sectionDisplaySetCount = section.initialSetCount ?? _currentSetCount;

                  return AnimatedListItem(
                    key: section.key,
                    direction: AnimationDirection.bottomToTop, // トレーニング部位追加時は下から上
                    child: GlassCard(
                      borderRadius: 12.0,
                      backgroundColor: colorScheme.surfaceContainerHighest,
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                            value: section.selectedPart,
                            items: _filteredBodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold)))).toList(),
                            onChanged: (value) {
                              setState(() {
                                section.selectedPart = value;
                                if (section.selectedPart != null) {
                                  String dateKey = _getDateKey(widget.selectedDate);
                                  DailyRecord? record = widget.recordsBox.get(dateKey);
                                  List<MenuData>? listToLoad;
                                  bool isSuggestion = false; // 提案データかどうかを判断するフラグ

                                  int newSectionSetCount = _currentSetCount;

                                  if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                    listToLoad = record.menus[section.selectedPart!];
                                    if (listToLoad != null && listToLoad.isNotEmpty) {
                                      // Changed to check weights.length as it's now List<String>
                                      newSectionSetCount = listToLoad[0].weights.length;
                                    }
                                    isSuggestion = false; // DailyRecordからの読み込みは提案ではない
                                  } else {
                                    listToLoad = widget.lastUsedMenusBox.get(section.selectedPart!);
                                    isSuggestion = true; // lastUsedMenusBoxからの読み込みは提案
                                  }

                                  section.initialSetCount = newSectionSetCount;

                                  _setControllersFromData(section.menuControllers, section.setInputDataList, section.menuKeys, listToLoad ?? [], newSectionSetCount, isSuggestion);
                                } else {
                                  // 部位が選択解除された場合、コントローラーをクリアして非表示状態に戻す
                                  _clearSectionControllersAndMaps(section.menuControllers, section.setInputDataList);
                                  section.menuKeys.clear();
                                  section.initialSetCount = _currentSetCount;
                                }
                              });
                            },
                            dropdownColor: colorScheme.surfaceContainer,
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 14.0, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          // 部位が選択されている場合にのみ種目名とセット入力を表示
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              final offsetAnimation = Tween<Offset>(
                                begin: const Offset(0.0, -0.2), // トレーニング部位選択時は上から下へ
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
                            child: section.selectedPart != null // ここを修正: 部位が選択されていれば表示
                                ? ListView.builder(
                              key: ValueKey(section.selectedPart), // 部位が変わったらアニメーションを再トリガー
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: section.menuControllers.length,
                              itemBuilder: (context, menuIndex) {
                                return AnimatedListItem(
                                  key: section.menuKeys[menuIndex],
                                  direction: AnimationDirection.topToBottom, // 種目追加時は上から下へ
                                  child: GlassCard(
                                    borderRadius: 10.0,
                                    backgroundColor: colorScheme.surface,
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        StylishInput(
                                          controller: section.menuControllers[menuIndex],
                                          hint: '種目名', // 種目名のヒントテキスト
                                          inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                          textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0, fontWeight: FontWeight.bold),
                                          fillColor: colorScheme.surfaceContainer,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                          isPlaceholder: _isPlaceholderMap[section.menuControllers[menuIndex]] ?? false, // 種目名のプレースホルダー状態を適用
                                          textAlign: TextAlign.left, // 種目名は左寄せ
                                        ),
                                        const SizedBox(height: 10),
                                        ...List.generate(sectionDisplaySetCount, (setIndex) {
                                          return Padding(
                                            padding: EdgeInsets.only(top: setIndex == 0 ? 0 : 8),
                                            child: buildSetRow(
                                              section.setInputDataList,
                                              menuIndex,
                                              setIndex + 1,
                                              setIndex,
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                                : const SizedBox.shrink(key: ValueKey('empty')), // 部位が選択されていなければ非表示
                          ),
                          const SizedBox(height: 12),
                          // 「種目を追加」ボタンの表示制御
                          Visibility(
                            visible: section.selectedPart != null, // 部位が選択されていれば表示
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _addMenuItem(index),
                                icon: Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 20.0),
                                label: Text('種目を追加', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12.0)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                  backgroundColor: colorScheme.primaryContainer,
                                  elevation: 0.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
