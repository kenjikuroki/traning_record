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
  late final Box<Map<String, bool>> _bodyPartsSettingsBox; // ★部位選択用Box
  late final Box<int> _setCountBox; // ★セット数設定用Box

  // ★現在のセット数を保持する変数（設定画面からのグローバル設定）
  int _currentSetCount = 3;

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox');
    lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');
    _bodyPartsSettingsBox = Hive.box<Map<String, bool>>('settingsBox'); // 部位選択用Boxを初期化
    _setCountBox = Hive.box<int>('setCountBox'); // ★セット数用Boxを初期化

    _loadSettingsAndParts(); // ★設定と部位を先にロード
    // _loadInitialSections() は _loadSettingsAndParts() の setState() の後に実行される
  }

  // ★設定と部位をロードする新しい関数
  void _loadSettingsAndParts() {
    // ★明示的な型キャストを追加
    Map<dynamic, dynamic>? savedDynamicBodyPartsSettings = _bodyPartsSettingsBox.get('selectedBodyParts');
    Map<String, bool>? savedBodyPartsSettings;

    if (savedDynamicBodyPartsSettings != null) {
      savedBodyPartsSettings = savedDynamicBodyPartsSettings.map(
            (key, value) => MapEntry(key.toString(), value as bool),
      );
    }

    int? savedSetCount = _setCountBox.get('setCount'); // ★セット数用Boxからロード

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
    DailyRecord? record = recordsBox.get(dateKey);

    _sections.clear(); // 既存のセクションをクリア

    if (record != null && record.menus.isNotEmpty) {
      // 既存の記録からセクションをロード
      record.menus.forEach((part, menuList) {
        int sectionSpecificSetCount = _currentSetCount; // グローバル設定をデフォルトとする
        if (menuList.isNotEmpty) {
          // 既存のデータがあれば、そのデータのセット数を使用
          sectionSpecificSetCount = menuList[0].weights.length;
          // もし異なるメニューでセット数が異なる可能性があるなら、最大値を取る
          // sectionSpecificSetCount = menuList.map((m) => m.weights.length).fold(0, (prev, current) => prev > current ? prev : current);
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
    // setStateは_loadSettingsAndParts()のsetStateで処理されるため、ここでは不要
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
    // もし読み込むリストのサイズが現在のコントローラー数より多ければ追加
    while (menuCtrls.length < list.length) {
      menuCtrls.add(TextEditingController());
      setCtrls.add(List.generate(actualSetCount * 2, (_) => TextEditingController())); // ★actualSetCountに応じてコントローラーを生成
    }
    // もし読み込むリストのサイズが現在のコントローラー数より少なければ、余分なコントローラーを削除
    // ただし、最低4つは残す（初期表示のため）
    while (menuCtrls.length > list.length && menuCtrls.length > 4) {
      menuCtrls.removeLast().dispose();
      setCtrls.removeLast().forEach((c) => c.dispose());
    }

    // データでコントローラーを埋める
    for (int i = 0; i < list.length; i++) {
      menuCtrls[i].text = list[i].name;
      // ★actualSetCountに応じてループ
      for (int s = 0; s < actualSetCount; s++) {
        // データのリストがセット数より短い場合を考慮
        if (s < list[i].weights.length) {
          setCtrls[i][s * 2].text = list[i].weights[s].toString();
          setCtrls[i][s * 2 + 1].text = list[i].reps[s].toString();
        } else {
          // データがない場合はクリア
          setCtrls[i][s * 2].clear();
          setCtrls[i][s * 2 + 1].clear();
        }
      }
      // actualSetCountよりも多いセットのコントローラーがあればクリア
      for (int s = actualSetCount; s < setCtrls[i].length / 2; s++) {
        setCtrls[i][s * 2].clear();
        setCtrls[i][s * 2 + 1].clear();
      }
    }
    // setStateは呼び出し元で処理されるため、ここでは不要
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
    String? lastModifiedPart; // Track the last modified part for the day

    for (var section in _sections) {
      if (section.selectedPart == null) continue; // Skip sections where no part is selected

      List<MenuData> sectionMenuList = [];
      bool sectionHasContent = false;
      // ★このセクションの実際のセット数を使用
      int currentSectionSetCount = section.initialSetCount ?? _currentSetCount;

      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<int> weights = [];
        List<int> reps = [];
        bool rowHasContent = false;
        // ★現在のセクションのセット数に応じてループ
        for (int s = 0; s < currentSectionSetCount; s++) {
          int w = int.tryParse(section.setControllers[i][s * 2].text) ?? 0;
          int r = int.tryParse(section.setControllers[i][s * 2 + 1].text) ?? 0;
          weights.add(w);
          reps.add(r);
          if (w > 0 || r > 0 || name.isNotEmpty) rowHasContent = true; // Also consider exercise name
        }

        if (name.isNotEmpty || rowHasContent) {
          sectionMenuList.add(MenuData(name: name, weights: weights, reps: reps));
          sectionHasContent = true;
        }
      }

      // Save only if the section has content
      if (sectionMenuList.isNotEmpty) {
        allMenusForDay[section.selectedPart!] = sectionMenuList;
        lastModifiedPart = section.selectedPart; // Record the last part with content
        lastUsedMenusBox.put(section.selectedPart!, sectionMenuList); // Update last used values
      } else {
        // If section becomes empty, remove that part from the existing map
        allMenusForDay.remove(section.selectedPart);
      }
    }

    // Save or delete DailyRecord
    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      recordsBox.put(dateKey, newRecord);
    } else {
      recordsBox.delete(dateKey); // Delete DailyRecord if all menus are empty
    }
  }

  // Function to navigate to settings screen
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder( // ★PageRouteBuilderを追加
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // 画面の下から開始
          const end = Offset.zero; // 画面の元の位置へ
          const curve = Curves.easeOut; // アニメーションのカーブ

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300), // アニメーションの時間
      ),
    ).then((_) {
      // Reload filtered body parts and set count when returning from settings screen
      _loadSettingsAndParts(); // ★設定画面から戻ったら設定を再ロード
      // Re-evaluate current section selection and display if needed
      setState(() {
        // 現在のセクションのコントローラーを新しいセット数に合わせて再初期化・再ロード
        // ただし、既存のデータを保持するように注意深く処理する
        for (var section in _sections) {
          String dateKey = _getDateKey(widget.selectedDate);
          DailyRecord? record = recordsBox.get(dateKey);
          List<MenuData>? existingMenuList = record?.menus[section.selectedPart!];

          int sectionSetCountToUse;
          if (existingMenuList != null && existingMenuList.isNotEmpty) {
            // 既存のデータがあれば、そのデータのセット数を使用
            sectionSetCountToUse = existingMenuList[0].weights.length;
          } else {
            // 既存データがなければ、グローバル設定の_currentSetCountを使用
            sectionSetCountToUse = _currentSetCount;
          }

          // Dispose old controllers
          section.dispose();

          // Re-create controllers with the determined set count
          section.menuControllers = List.generate(4, (_) => TextEditingController());
          section.setControllers = List.generate(4, (_) => List.generate(sectionSetCountToUse * 2, (_) => TextEditingController()));
          section.initialSetCount = sectionSetCountToUse; // initialSetCountを更新

          // Load data back into the new controllers
          _setControllersFromData(section.menuControllers, section.setControllers, existingMenuList ?? [], sectionSetCountToUse);
        }
        // もしセクションが一つもなければ、新しいグローバル設定で空のセクションを追加
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
      // ★このセクションの現在のセット数を使用
      int currentSectionSetCount = _sections[sectionIndex].initialSetCount ?? _currentSetCount;
      _sections[sectionIndex].menuControllers.add(TextEditingController());
      _sections[sectionIndex].setControllers.add(List.generate(currentSectionSetCount * 2, (_) => TextEditingController())); // ★setCountに応じてコントローラーを生成
    });
  }

  // Function to add a new target section
  void _addTargetSection() {
    setState(() {
      _sections.add(SectionData.createEmpty(_currentSetCount)); // ★グローバル設定のsetCountを渡す
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

  // Widget to build each set input row
  Widget buildSetRow(List<List<TextEditingController>> setCtrls, int menuIndex, int setNumber, int weightIndex, int repIndex) {
    return Row(
      children: [
        Text(
          '${setNumber}セット：',
          style: TextStyle(color: Colors.grey[700], fontSize: 14.0),
        ),
        const SizedBox(width: 8), // Spacing adjustment
        Expanded( // Wrap TextField with Expanded for flexible width
          child: TextField(
            controller: setCtrls[menuIndex][weightIndex],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: true,
              hintText: '', // Empty hint text
              filled: true,
              fillColor: Colors.grey[50], // Background color to light grey (slightly lighter than target card)
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none, // No border
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // Padding adjustment
            ),
            style: TextStyle(color: Colors.grey[800], fontSize: 16.0),
          ),
        ),
        // ★ 'kg' テキストを太字に
        Text(' kg ', style: TextStyle(color: Colors.grey[800], fontSize: 14.0, fontWeight: FontWeight.bold)),
        Expanded( // Wrap TextField with Expanded for flexible width
          child: TextField(
            controller: setCtrls[menuIndex][repIndex],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: true,
              hintText: '', // Empty hint text
              filled: true,
              fillColor: Colors.grey[50], // Background color to light grey (slightly lighter than target card)
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            style: TextStyle(color: Colors.grey[800], fontSize: 16.0),
          ),
        ),
        // ★ '回' テキストを太字に
        Text(' 回', style: TextStyle(color: Colors.grey[800], fontSize: 14.0, fontWeight: FontWeight.bold)),
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
                  final int sectionDisplaySetCount = section.initialSetCount ?? _currentSetCount;

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

                                  int newSectionSetCount = _currentSetCount; // デフォルトはグローバル設定

                                  // その日付にその部位の記録があるかチェック
                                  if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                    listToLoad = record.menus[section.selectedPart!];
                                    if (listToLoad != null && listToLoad.isNotEmpty) {
                                      // 既存の記録があれば、その記録のセット数を使用
                                      newSectionSetCount = listToLoad[0].weights.length;
                                    }
                                  } else {
                                    // その日付にその部位の記録がなければ、lastUsedMenusBoxから内容をロード
                                    // ただし、セット数は_currentSetCount（グローバル設定）を使用
                                    listToLoad = lastUsedMenusBox.get(section.selectedPart!);
                                    // newSectionSetCountは_currentSetCountのまま
                                  }

                                  section.initialSetCount = newSectionSetCount; // セクションのセット数を更新
                                  // コントローラーを新しいセット数で再生成
                                  section.dispose();
                                  section.menuControllers = List.generate(4, (_) => TextEditingController());
                                  section.setControllers = List.generate(4, (_) => List.generate(newSectionSetCount * 2, (_) => TextEditingController()));

                                  _setControllersFromData(section.menuControllers, section.setControllers, listToLoad ?? [], newSectionSetCount);
                                } else {
                                  _clearControllers(section.menuControllers, section.setControllers);
                                  section.initialSetCount = _currentSetCount; // 部位が選択されなければグローバル設定
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
                                            section.setControllers,
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
