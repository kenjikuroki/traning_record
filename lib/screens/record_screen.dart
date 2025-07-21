import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/menu_data.dart';     // MenuData and DailyRecord models
import 'settings_screen.dart'; // SettingsScreen import
import '../widgets/custom_widgets.dart'; // ★カスタムウィジェットをインポート

// Helper class to hold data for each target section
class SectionData {
  String? selectedPart; // Selected target part for this section
  List<TextEditingController> menuControllers; // Controllers for exercise names in this section
  List<List<TextEditingController>> setControllers; // Controllers for sets in this section
  int? initialSetCount; // ★このセクションの初期セット数を保持

  SectionData({
    this.selectedPart,
    required this.menuControllers,
    required this.setControllers,
    this.initialSetCount, // ★コンストラクタに追加
  });

  // Factory constructor to create a new empty section data with default controllers
  static SectionData createEmpty(int setCount) { // ★setCountを引数に追加
    return SectionData(
      menuControllers: List.generate(4, (_) => TextEditingController()), // Default 4 empty exercises
      setControllers: List.generate(4, (_) => List.generate(setCount * 2, (_) => TextEditingController())), // ★setCountに応じてコントローラーを生成
      initialSetCount: setCount, // ★初期セット数を設定
    );
  }

  // Method to dispose all controllers within this section
  void dispose() {
    for (var c in menuControllers) {
      c.dispose();
    }
    for (var list in setControllers) {
      for (var c in list) {
        c.clear(); // Clear text before disposing
        c.dispose();
      }
    }
  }
}

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<DailyRecord> recordsBox; // ★Boxインスタンスを受け取る
  final Box<List<MenuData>> lastUsedMenusBox; // ★Boxインスタンスを受け取る
  final Box<Map<String, bool>> settingsBox; // ★Boxインスタンスを受け取る
  final Box<int> setCountBox; // ★Boxインスタンスを受け取る

  const RecordScreen({
    super.key,
    required this.selectedDate,
    required this.recordsBox, // ★コンストラクタに追加
    required this.lastUsedMenusBox, // ★コンストラクタに追加
    required this.settingsBox, // ★コンストラクタに追加
    required this.setCountBox, // ★コンストラクタに追加
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // List of filtered body parts based on settings screen
  List<String> _filteredBodyParts = [];
  // Full list of all body parts (source for filtering)
  final List<String> _allBodyParts = [
    '腕', '胸', '肩', '背中', '足', '全体', 'その他',
  ];

  List<SectionData> _sections = []; // List to manage multiple target sections

  // ★現在のセット数を保持する変数（設定画面からのグローバル設定）
  int _currentSetCount = 3;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndParts(); // ★設定と部位を先にロード
  }

  // ★設定と部位をロードする新しい関数
  void _loadSettingsAndParts() {
    // ★明示的な型キャストを追加
    Map<dynamic, dynamic>? savedDynamicBodyPartsSettings = widget.settingsBox.get('selectedBodyParts'); // widget.settingsBoxから取得
    Map<String, bool>? savedBodyPartsSettings;

    if (savedDynamicBodyPartsSettings != null) {
      savedBodyPartsSettings = savedDynamicBodyPartsSettings.map(
            (key, value) => MapEntry(key.toString(), value as bool),
      );
    }

    int? savedSetCount = widget.setCountBox.get('setCount'); // widget.setCountBoxから取得

    // 部位のフィルタリング設定をロード
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

    // セット数をロード
    _currentSetCount = savedSetCount ?? 3; // なければデフォルト3セット

    // setStateでUIを更新し、その後に初期セクションをロード
    setState(() {
      _loadInitialSections(); // ここで初期セクションをロード
    });
  }


  // Load initial sections (existing data or create a new empty section)
  void _loadInitialSections() {
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = widget.recordsBox.get(dateKey); // widget.recordsBoxから取得

    _sections.clear(); // 既存のセクションをクリア

    if (record != null && record.menus.isNotEmpty) {
      // 既存の記録からセクションをロード
      record.menus.forEach((part, menuList) {
        int sectionSpecificSetCount = _currentSetCount; // グローバル設定をデフォルトとする
        if (menuList.isNotEmpty) {
          // 既存のデータがあれば、そのデータのセット数を使用
          sectionSpecificSetCount = menuList[0].weights.length;
        }
        SectionData section = SectionData.createEmpty(sectionSpecificSetCount);
        section.selectedPart = part;
        section.initialSetCount = sectionSpecificSetCount; // 決定されたセット数を保持
        _setControllersFromData(section.menuControllers, section.setControllers, menuList, sectionSpecificSetCount);
        _sections.add(section);
      });
    } else {
      // 記録がなければ、デフォルトで1つの空のセクションを作成（グローバル設定を使用）
      _sections.add(SectionData.createEmpty(_currentSetCount));
      _sections[0].initialSetCount = _currentSetCount;
    }
  }

  // Helper function to generate date key
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set data to controllers (including dynamic size adjustment)
  void _setControllersFromData(List<TextEditingController> menuCtrls, List<List<TextEditingController>> setCtrls, List<MenuData> list, int actualSetCount) {
    // First, clear text content of existing controllers
    _clearControllers(menuCtrls, setCtrls);

    // 必要なコントローラーの数を調整
    while (menuCtrls.length < list.length) {
      menuCtrls.add(TextEditingController());
      setCtrls.add(List.generate(actualSetCount * 2, (_) => TextEditingController()));
    }
    while (menuCtrls.length > list.length && menuCtrls.length > 4) {
      menuCtrls.removeLast().dispose();
      setCtrls.removeLast().forEach((c) => c.dispose());
    }

    // データでコントローラーを埋める
    for (int i = 0; i < list.length; i++) {
      menuCtrls[i].text = list[i].name;
      for (int s = 0; s < actualSetCount; s++) {
        if (s < list[i].weights.length) {
          setCtrls[i][s * 2].text = list[i].weights[s].toString();
          setCtrls[i][s * 2 + 1].text = list[i].reps[s].toString();
        } else {
          setCtrls[i][s * 2].clear();
          setCtrls[i][s * 2 + 1].clear();
        }
      }
      for (int s = actualSetCount; s < setCtrls[i].length / 2; s++) {
        setCtrls[i][s * 2].clear();
        setCtrls[i][s * 2 + 1].clear();
      }
    }
  }

  // Clear text content of controllers (does not clear the lists themselves)
  void _clearControllers(List<TextEditingController> menuCtrls, List<List<TextEditingController>> setCtrls) {
    for (var c in menuCtrls) {
      c.clear();
    }
    for (var list in setCtrls) {
      for (var c in list) {
        c.clear();
      }
    }
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
        List<int> weights = [];
        List<int> reps = [];
        bool rowHasContent = false;
        for (int s = 0; s < currentSectionSetCount; s++) {
          int w = int.tryParse(section.setControllers[i][s * 2].text) ?? 0;
          int r = int.tryParse(section.setControllers[i][s * 2 + 1].text) ?? 0;
          weights.add(w);
          reps.add(r);
          if (w > 0 || r > 0 || name.isNotEmpty) rowHasContent = true;
        }

        if (name.isNotEmpty || rowHasContent) {
          sectionMenuList.add(MenuData(name: name, weights: weights, reps: reps));
          sectionHasContent = true;
        }
      }

      if (sectionMenuList.isNotEmpty) {
        allMenusForDay[section.selectedPart!] = sectionMenuList;
        lastModifiedPart = section.selectedPart;
        widget.lastUsedMenusBox.put(section.selectedPart!, sectionMenuList); // widget.lastUsedMenusBoxから取得
      } else {
        allMenusForDay.remove(section.selectedPart);
      }
    }

    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      widget.recordsBox.put(dateKey, newRecord); // widget.recordsBoxから取得
    } else {
      widget.recordsBox.delete(dateKey); // widget.recordsBoxから取得
    }
  }

  // Function to navigate to settings screen
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
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
      _loadSettingsAndParts();
      setState(() {
        for (var section in _sections) {
          String dateKey = _getDateKey(widget.selectedDate);
          DailyRecord? record = widget.recordsBox.get(dateKey); // widget.recordsBoxから取得
          List<MenuData>? existingMenuList = record?.menus[section.selectedPart!];

          int sectionSetCountToUse;
          if (existingMenuList != null && existingMenuList.isNotEmpty) {
            sectionSetCountToUse = existingMenuList[0].weights.length;
          } else {
            sectionSetCountToUse = _currentSetCount;
          }

          section.dispose();
          section.menuControllers = List.generate(4, (_) => TextEditingController());
          section.setControllers = List.generate(4, (_) => List.generate(sectionSetCountToUse * 2, (_) => TextEditingController()));
          section.initialSetCount = sectionSetCountToUse;

          _setControllersFromData(section.menuControllers, section.setControllers, existingMenuList ?? [], sectionSetCountToUse);
        }
        if (_sections.isEmpty) {
          _sections.add(SectionData.createEmpty(_currentSetCount));
          _sections[0].initialSetCount = _currentSetCount;
        }
      });
    });
  }

  // Function to add a new exercise card to a specific section
  void _addMenuItem(int sectionIndex) {
    setState(() {
      int currentSectionSetCount = _sections[sectionIndex].initialSetCount ?? _currentSetCount;
      _sections[sectionIndex].menuControllers.add(TextEditingController());
      _sections[sectionIndex].setControllers.add(List.generate(currentSectionSetCount * 2, (_) => TextEditingController()));
    });
  }

  // Function to add a new target section
  void _addTargetSection() {
    setState(() {
      _sections.add(SectionData.createEmpty(_currentSetCount));
    });
  }

  @override
  void dispose() {
    _saveAllSectionsData();
    for (var section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  // Widget to build each set input row
  Widget buildSetRow(List<List<TextEditingController>> setCtrls, int menuIndex, int setNumber, int weightIndex, int repIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          '${setNumber}セット：',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StylishInput(
            controller: setCtrls[menuIndex][weightIndex],
            hint: '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
        Text(' kg ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded(
          child: StylishInput(
            controller: setCtrls[menuIndex][repIndex],
            hint: '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
          '${widget.selectedDate.year}/${widget.selectedDate.month}/${widget.selectedDate.day} 記録',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: 24.0, color: colorScheme.onSurface), // アイコン色をテーマから取得
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
                  if (index == _sections.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: StylishButton(
                          text: 'ターゲットを追加',
                          onPressed: _addTargetSection,
                          icon: Icons.add_box_outlined,
                          // StylishButton内でprimaryカラーが使用される
                        ),
                      ),
                    );
                  }

                  final section = _sections[index];
                  final int sectionDisplaySetCount = section.initialSetCount ?? _currentSetCount;

                  return GlassCard( // GlassCardを使用
                    borderRadius: 12.0,
                    backgroundColor: colorScheme.surfaceVariant, // カード背景色をテーマから取得
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: 'ターゲットを選択',
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
                            filled: true,
                            fillColor: colorScheme.surface, // ドロップダウン背景色をテーマから取得
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          ),
                          value: section.selectedPart,
                          items: _filteredBodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: colorScheme.onSurface, fontSize: 16.0, fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (value) {
                            setState(() {
                              section.selectedPart = value;
                              if (section.selectedPart != null) {
                                String dateKey = _getDateKey(widget.selectedDate);
                                DailyRecord? record = widget.recordsBox.get(dateKey);
                                List<MenuData>? listToLoad;

                                int newSectionSetCount = _currentSetCount;

                                if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                  listToLoad = record.menus[section.selectedPart!];
                                  if (listToLoad != null && listToLoad.isNotEmpty) {
                                    newSectionSetCount = listToLoad[0].weights.length;
                                  }
                                } else {
                                  listToLoad = widget.lastUsedMenusBox.get(section.selectedPart!);
                                }

                                section.initialSetCount = newSectionSetCount;
                                section.dispose();
                                section.menuControllers = List.generate(4, (_) => TextEditingController());
                                section.setControllers = List.generate(4, (_) => List.generate(newSectionSetCount * 2, (_) => TextEditingController()));

                                _setControllersFromData(section.menuControllers, section.setControllers, listToLoad ?? [], newSectionSetCount);
                              } else {
                                _clearControllers(section.menuControllers, section.setControllers);
                                section.initialSetCount = _currentSetCount;
                              }
                            });
                          },
                          dropdownColor: colorScheme.surface, // ドロップダウンメニュー背景色をテーマから取得
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: section.menuControllers.length,
                          itemBuilder: (context, menuIndex) {
                            return GlassCard( // GlassCardを使用
                              borderRadius: 10.0,
                              backgroundColor: colorScheme.surface, // 種目カード背景色をテーマから取得
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StylishInput(
                                    controller: section.menuControllers[menuIndex],
                                    hint: '種目名',
                                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
                                    textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16.0, fontWeight: FontWeight.bold),
                                    fillColor: colorScheme.surfaceVariant, // TextField塗りつぶし色をテーマから取得
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(sectionDisplaySetCount, (setIndex) {
                                    return Padding(
                                      padding: EdgeInsets.only(top: setIndex == 0 ? 0 : 8),
                                      child: buildSetRow(
                                        section.setControllers,
                                        menuIndex,
                                        setIndex + 1,
                                        setIndex * 2,
                                        setIndex * 2 + 1,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _addMenuItem(index),
                            icon: Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 24.0), // アイコン色をテーマから取得
                            label: Text('種目を追加', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16.0)), // テキスト色をテーマから取得
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                              backgroundColor: colorScheme.primaryContainer, // ボタン背景色をテーマから取得
                              elevation: 0.0,
                            ),
                          ),
                        ),
                      ],
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
