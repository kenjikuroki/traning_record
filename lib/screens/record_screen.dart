import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/menu_data.dart';     // MenuData and DailyRecord models
import 'settings_screen.dart'; // SettingsScreen import

// Helper class to hold data for each target section
class SectionData {
  String? selectedPart; // Selected target part for this section
  List<TextEditingController> menuControllers; // Controllers for exercise names in this section
  List<List<TextEditingController>> setControllers; // Controllers for sets in this section (current input)
  List<List<String>> previousSetValues; // ★前回の重量・回数を文字列として保持 (プレースホルダー用)
  int? actualSetCount; // ★このセクションの実際のセット数を保持

  SectionData({
    this.selectedPart,
    required this.menuControllers,
    required this.setControllers,
    required this.previousSetValues, // ★コンストラクタに追加
    this.actualSetCount, // ★コンストラクタに追加
  });

  // Factory constructor to create a new empty section data with default controllers
  static SectionData createEmpty(int setCount) { // ★setCountを引数に追加
    return SectionData(
      menuControllers: List.generate(4, (_) => TextEditingController()), // Default 4 empty exercises
      setControllers: List.generate(4, (_) => List.generate(setCount * 2, (_) => TextEditingController())), // ★setCountに応じてコントローラーを生成
      previousSetValues: List.generate(4, (_) => List.generate(setCount * 2, (_) => '')), // ★空文字列で初期化
      actualSetCount: setCount, // ★初期セット数を設定
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

  const RecordScreen({super.key, required this.selectedDate});

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

  // Hive Box instances
  late final Box<DailyRecord> recordsBox;
  late final Box<List<MenuData>> lastUsedMenusBox;
  late final Box<Map<String, bool>> _bodyPartsSettingsBox; // 部位選択用Box
  late final Box<int> _setCountBox; // ★セット数設定用Box

  // ★現在のセット数を保持する変数（設定画面からのグローバル設定）
  int _globalSetCount = 3;

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox');
    lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');
    _bodyPartsSettingsBox = Hive.box<Map<String, bool>>('settingsBox'); // 部位選択用Boxを初期化
    _setCountBox = Hive.box<int>('setCountBox'); // ★セット数用Boxを初期化

    _loadSettingsAndParts(); // ★設定と部位を先にロード
  }

  // ★設定と部位をロードする新しい関数
  void _loadSettingsAndParts() {
    // ★明示的な型キャストを追加
    Map<String, bool>? savedBodyPartsSettings = _bodyPartsSettingsBox.get('selectedBodyParts') as Map<String, bool>?;
    int? savedSetCount = _setCountBox.get('setCount'); // ★セット数用Boxからロード

    // 部位のフィルタリング設定をロード
    if (savedBodyPartsSettings != null) {
      _filteredBodyParts = _allBodyParts
          .where((part) => savedBodyPartsSettings[part] == true)
          .toList();
      if (_filteredBodyParts.isEmpty) {
        _filteredBodyParts = List.from(_allBodyParts);
      }
    } else {
      _filteredBodyParts = List.from(_allBodyParts);
    }

    // セット数をロード
    _globalSetCount = savedSetCount ?? 3; // なければデフォルト3セット

    // setStateでUIを更新し、その後に初期セクションをロード
    setState(() {
      _loadInitialSections(); // ここで初期セクションをロード
    });
  }


  // Load initial sections (existing data or create a new empty section)
  void _loadInitialSections() {
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = recordsBox.get(dateKey);

    _sections.clear(); // 既存のセクションをクリア

    if (record != null && record.menus.isNotEmpty) {
      // 既存の記録からセクションをロード
      record.menus.forEach((part, menuList) {
        // 既存の記録がある場合、その記録のセット数を優先
        int sectionSpecificSetCount = menuList.isNotEmpty ? menuList[0].weights.length : _globalSetCount;

        SectionData section = SectionData.createEmpty(sectionSpecificSetCount);
        section.selectedPart = part;
        section.actualSetCount = sectionSpecificSetCount; // 決定されたセット数を保持
        _setControllersFromData(section, menuList, false); // false: 実際のデータ
        _sections.add(section);
      });
    } else {
      // 記録がなければ、デフォルトで1つの空のセクションを作成（グローバル設定を使用）
      _sections.add(SectionData.createEmpty(_globalSetCount));
      _sections[0].actualSetCount = _globalSetCount;
    }
    // setStateは_loadSettingsAndParts()のsetStateで処理されるため、ここでは不要
  }

  // Helper function to generate date key
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set data to controllers or previous values
  void _setControllersFromData(SectionData section, List<MenuData> list, bool isPreviousData) {
    // First, clear text content of existing controllers and previous values
    _clearControllers(section);

    // Adjust the number of required controllers
    // If the list to load is larger than current controller count, add new ones
    while (section.menuControllers.length < list.length) {
      section.menuControllers.add(TextEditingController());
      section.setControllers.add(List.generate(section.actualSetCount! * 2, (_) => TextEditingController()));
      section.previousSetValues.add(List.generate(section.actualSetCount! * 2, (_) => ''));
    }
    // If the list to load is smaller, remove excess controllers
    // But keep at least 4 for initial display
    while (section.menuControllers.length > list.length && section.menuControllers.length > 4) {
      section.menuControllers.removeLast().dispose();
      section.setControllers.removeLast().forEach((c) => c.dispose());
      section.previousSetValues.removeLast();
    }

    // Populate controllers or previous values with data
    for (int i = 0; i < list.length; i++) {
      section.menuControllers[i].text = list[i].name;
      for (int s = 0; s < section.actualSetCount!; s++) {
        String weight = (s < list[i].weights.length) ? list[i].weights[s].toString() : '';
        String rep = (s < list[i].reps.length) ? list[i].reps[s].toString() : '';

        if (isPreviousData) {
          section.previousSetValues[i][s * 2] = weight;
          section.previousSetValues[i][s * 2 + 1] = rep;
          section.setControllers[i][s * 2].clear(); // 現在の入力はクリア
          section.setControllers[i][s * 2 + 1].clear(); // 現在の入力はクリア
        } else {
          section.setControllers[i][s * 2].text = weight;
          section.setControllers[i][s * 2 + 1].text = rep;
          section.previousSetValues[i][s * 2] = ''; // プレースホルダーはクリア
          section.previousSetValues[i][s * 2 + 1] = ''; // プレースホルダーはクリア
        }
      }
    }
    // setStateは呼び出し元で処理されるため、ここでは不要
  }

  // Clear text content of controllers and previous values
  void _clearControllers(SectionData section) {
    for (var c in section.menuControllers) {
      c.clear();
    }
    for (var list in section.setControllers) {
      for (var c in list) {
        c.clear();
      }
    }
    for (var list in section.previousSetValues) {
      for (int i = 0; i < list.length; i++) {
        list[i] = '';
      }
    }
  }

  // Save data for all sections
  void _saveAllSectionsData() {
    String dateKey = _getDateKey(widget.selectedDate);
    Map<String, List<MenuData>> allMenusForDay = {};

    for (var section in _sections) {
      if (section.selectedPart == null) continue; // Skip sections where no part is selected

      List<MenuData> sectionMenuList = [];
      // このセクションの実際のセット数を使用
      int currentSectionSetCount = section.actualSetCount ?? _globalSetCount;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<int> weights = [];
        List<int> reps = [];
        bool rowHasContent = false;
        // 現在のセクションのセット数に応じてループ
        for (int s = 0; s < currentSectionSetCount; s++) {
          int w = int.tryParse(section.setControllers[i][s * 2].text) ?? 0;
          int r = int.tryParse(section.setControllers[i][s * 2 + 1].text) ?? 0;
          weights.add(w);
          reps.add(r);
          if (w > 0 || r > 0 || name.isNotEmpty) rowHasContent = true; // Also consider exercise name
        }

        if (name.isNotEmpty || rowHasContent) {
          sectionMenuList.add(MenuData(name: name, weights: weights, reps: reps));
        }
      }

      // Save only if the section has content
      if (sectionMenuList.isNotEmpty) {
        allMenusForDay[section.selectedPart!] = sectionMenuList;
        lastUsedMenusBox.put(section.selectedPart!, sectionMenuList); // Update last used values
      } else {
        // If section becomes empty, remove that part from the existing map
        allMenusForDay.remove(section.selectedPart);
      }
    }

    // Save or delete DailyRecord
    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay);
      recordsBox.put(dateKey, newRecord);
    } else {
      recordsBox.delete(dateKey); // Delete DailyRecord if all menus are empty
    }
  }

  // Function to navigate to settings screen
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      // 設定画面から戻ってきたら、グローバル設定を再ロードし、UIを更新
      _loadSettingsAndParts();
    });
  }

  // Function to add a new exercise card to a specific section
  void _addMenuItem(int sectionIndex) {
    setState(() {
      // このセクションの現在のセット数を使用
      int currentSectionSetCount = _sections[sectionIndex].actualSetCount ?? _globalSetCount;
      _sections[sectionIndex].menuControllers.add(TextEditingController());
      _sections[sectionIndex].setControllers.add(List.generate(currentSectionSetCount * 2, (_) => TextEditingController()));
      _sections[sectionIndex].previousSetValues.add(List.generate(currentSectionSetCount * 2, (_) => '')); // 新しい行のプレースホルダーも初期化
    });
  }

  // Function to add a new target section
  void _addTargetSection() {
    setState(() {
      _sections.add(SectionData.createEmpty(_globalSetCount)); // グローバル設定のsetCountを渡す
    });
  }

  @override
  void dispose() {
    _saveAllSectionsData(); // Save all data on dispose
    // Dispose all controllers
    for (var section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  // 数値入力ダイアログを表示する関数
  Future<String?> _showNumberInputDialog(BuildContext context, String initialValue, String unit) async {
    TextEditingController dialogController = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('値を入力 ($unit)'),
          content: TextField(
            controller: dialogController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              hintText: '数値を入力',
              suffixText: unit,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('確定'),
              onPressed: () {
                Navigator.of(context).pop(dialogController.text);
              },
            ),
          ],
        );
      },
    );
  }

  // Widget to build each set input row
  Widget buildSetRow(SectionData section, int menuIndex, int setNumber, int weightIndex, int repIndex) {
    // 現在の入力値があるか、前回値があるか
    String currentWeight = section.setControllers[menuIndex][weightIndex].text;
    String currentRep = section.setControllers[menuIndex][repIndex].text;
    String previousWeight = section.previousSetValues[menuIndex][weightIndex];
    String previousRep = section.previousSetValues[menuIndex][repIndex];

    return Row(
      children: [
        Text(
          '${setNumber}セット：',
          style: TextStyle(color: Colors.grey[700], fontSize: 14.0),
        ),
        const SizedBox(width: 8), // Spacing adjustment
        Expanded(
          child: GestureDetector(
            onTap: () async {
              // タップ時に数値入力ダイアログを表示
              String? newWeight = await _showNumberInputDialog(context, currentWeight.isNotEmpty ? currentWeight : previousWeight, 'kg');
              if (newWeight != null) {
                setState(() {
                  section.setControllers[menuIndex][weightIndex].text = newWeight;
                  section.previousSetValues[menuIndex][weightIndex] = ''; // 入力確定でプレースホルダーをクリア
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                currentWeight.isNotEmpty ? currentWeight : previousWeight,
                style: TextStyle(
                  color: currentWeight.isNotEmpty ? Colors.grey[800] : Colors.grey[500], // 入力値があれば濃く、なければ薄く
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
        ),
        Text(' kg ', style: TextStyle(color: Colors.grey[700], fontSize: 14.0)),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              String? newRep = await _showNumberInputDialog(context, currentRep.isNotEmpty ? currentRep : previousRep, '回');
              if (newRep != null) {
                setState(() {
                  section.setControllers[menuIndex][repIndex].text = newRep;
                  section.previousSetValues[menuIndex][repIndex] = ''; // 入力確定でプレースホルダーをクリア
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                currentRep.isNotEmpty ? currentRep : previousRep,
                style: TextStyle(
                  color: currentRep.isNotEmpty ? Colors.grey[800] : Colors.grey[500], // 入力値があれば濃く、なければ薄く
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
        ),
        Text(' 回', style: TextStyle(color: Colors.grey[700], fontSize: 14.0)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Overall background color to a slightly darker grey
      appBar: AppBar(
        title: Text(
          '${widget.selectedDate.year}/${widget.selectedDate.month}/${widget.selectedDate.day} 記録',
          style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 20.0), // Title text color and boldness
        ),
        backgroundColor: Colors.white, // AppBar background to white
        elevation: 0.0, // No AppBar shadow for a flatter look
        iconTheme: IconThemeData(color: Colors.grey[700]), // Icon color
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 24.0), // Settings icon size
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Overall padding increased
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _sections.length + 1, // ★セクション数 + 1 (最後のボタン用)
                itemBuilder: (context, index) {
                  // ★最後のアイテムが「ターゲットを追加」ボタン
                  if (index == _sections.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20.0, bottom: 12.0), // 上下の余白を調整
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addTargetSection,
                          icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 28.0), // Icon color and size
                          label: const Text('ターゲットを追加', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.0)), // Text color and size
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700], // Button background color to a vibrant blue
                            padding: const EdgeInsets.symmetric(vertical: 18.0), // Increased button padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0), // Larger rounded corners
                            ),
                            elevation: 4.0, // Moderate button shadow
                            shadowColor: Colors.blue[300], // Shadow color
                          ),
                        ),
                      ),
                    );
                  }

                  // 通常のターゲットセクションカード
                  final section = _sections[index];
                  // このセクションのセット数を決定
                  final int sectionDisplaySetCount = section.actualSetCount ?? _globalSetCount;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0.0), // Vertical margin for cards
                    elevation: 1.0, // Lighter card shadow
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Slightly smaller rounded corners
                    color: Colors.grey[200], // Target card background color to Colors.grey[200]
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), // Increased inner padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Target body part selection dropdown (per section)
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'ターゲットを選択',
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16.0),
                              filled: true,
                              fillColor: Colors.grey[100], // Background color to light grey
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0), // More pill-like rounded corners
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Adjusted padding for pill shape
                            ),
                            value: section.selectedPart,
                            items: _filteredBodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.bold)))).toList(), // Text style adjustment
                            onChanged: (value) {
                              setState(() {
                                section.selectedPart = value;
                                if (section.selectedPart != null) {
                                  String dateKey = _getDateKey(widget.selectedDate);
                                  DailyRecord? record = recordsBox.get(dateKey);
                                  List<MenuData>? listToLoad;

                                  int newSectionSetCount = _globalSetCount; // デフォルトはグローバル設定

                                  // その日付にその部位の記録があるかチェック
                                  if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                    listToLoad = record.menus[section.selectedPart!];
                                    if (listToLoad != null && listToLoad.isNotEmpty) {
                                      // 既存の記録があれば、その記録のセット数を使用
                                      newSectionSetCount = listToLoad[0].weights.length;
                                      // 実際のデータをコントローラーにロード
                                      section.actualSetCount = newSectionSetCount;
                                      _setControllersFromData(section, listToLoad, false);
                                    } else {
                                      // 記録はあるが空の場合、前回値もロードしない
                                      section.actualSetCount = newSectionSetCount;
                                      _setControllersFromData(section, [], false);
                                    }
                                  } else {
                                    // その日付にその部位の記録がなければ、lastUsedMenusBoxから内容をロード
                                    listToLoad = lastUsedMenusBox.get(section.selectedPart!);
                                    section.actualSetCount = newSectionSetCount; // セット数はグローバル設定
                                    _setControllersFromData(section, listToLoad ?? [], true); // true: 前回値としてロード
                                  }
                                } else {
                                  _clearControllers(section);
                                  section.actualSetCount = _globalSetCount; // 部位が選択されなければグローバル設定
                                }
                              });
                            },
                            dropdownColor: Colors.white, // Dropdown menu background color
                            style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.bold), // Selected item text style
                          ),
                          const SizedBox(height: 20), // Spacing adjustment
                          // 各セクション内の種目リスト
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: section.menuControllers.length,
                            itemBuilder: (context, menuIndex) {
                              return Card( // 各種目をCardで囲む
                                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0), // 種目カードの垂直マージン
                                elevation: 0.5, // 種目カードの影をさらに控えめに
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), // 種目カードの角丸
                                color: Colors.white, // Exercise card background color to Colors.white
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0), // 種目カード内のパディング
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: section.menuControllers[menuIndex],
                                        inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: '種目名',
                                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16.0),
                                          filled: true,
                                          fillColor: Colors.grey[50], // TextField background color to Colors.grey[50]
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10.0),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        ),
                                        style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10), // スペーシング調整
                                      // ★セット数に応じて動的にSetRowを生成
                                      ...List.generate(sectionDisplaySetCount, (setIndex) { // ★sectionDisplaySetCountを使用
                                        return Padding(
                                          padding: EdgeInsets.only(top: setIndex == 0 ? 0 : 8), // 最初のセット以外は上部に余白
                                          child: buildSetRow(
                                            section, // SectionDataを渡す
                                            menuIndex,
                                            setIndex + 1, // セット番号 (1から始まる)
                                            setIndex * 2, // 重量インデックス
                                            setIndex * 2 + 1, // 回数インデックス
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12), // Spacing above the button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _addMenuItem(index), // ★ここを修正
                              icon: Icon(Icons.add_circle_outline, color: Colors.blue[600], size: 24.0), // Icon color
                              label: Text('種目を追加', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold, fontSize: 16.0)), // Text color and boldness
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                backgroundColor: Colors.blue[50], // Button background color
                                elevation: 0.0, // No shadow for a flatter look
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
