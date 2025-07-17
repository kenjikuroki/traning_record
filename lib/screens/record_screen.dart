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

  SectionData({
    this.selectedPart,
    required this.menuControllers,
    required this.setControllers,
  });

  // Factory constructor to create a new empty section data with default controllers
  static SectionData createEmpty() {
    return SectionData(
      menuControllers: List.generate(4, (_) => TextEditingController()), // Default 4 empty exercises
      setControllers: List.generate(4, (_) => List.generate(6, (_) => TextEditingController())),
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
  late final Box<Map<String, bool>> _settingsBox; // Box to read settings

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox');
    lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');
    _settingsBox = Hive.box<Map<String, bool>>('settingsBox'); // Initialize settings Box
    _loadFilteredBodyParts(); // Load body parts from settings
    _loadInitialSections(); // Load initial sections (existing data or new)
  }

  // Function to load filtered body parts from settings
  void _loadFilteredBodyParts() {
    Map<String, bool>? savedSettings = _settingsBox.get('selectedBodyParts');
    if (savedSettings != null) {
      setState(() {
        _filteredBodyParts = _allBodyParts
            .where((part) => savedSettings[part] == true)
            .toList();
        // Fallback: if no filtered parts, show all parts
        if (_filteredBodyParts.isEmpty) {
          _filteredBodyParts = List.from(_allBodyParts);
        }
      });
    } else {
      // If no settings saved yet, show all parts
      setState(() {
        _filteredBodyParts = List.from(_allBodyParts);
      });
    }
  }

  // Load initial sections (existing data or create a new empty section)
  void _loadInitialSections() {
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = recordsBox.get(dateKey);

    if (record != null && record.menus.isNotEmpty) {
      // Load sections from existing records
      record.menus.forEach((part, menuList) {
        SectionData section = SectionData.createEmpty();
        section.selectedPart = part;
        _setControllersFromData(section.menuControllers, section.setControllers, menuList);
        _sections.add(section);
      });
    } else {
      // If no records, create one empty section by default
      _sections.add(SectionData.createEmpty());
    }
    // setState is handled by _loadFilteredBodyParts's setState
  }

  // Helper function to generate date key
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set data to controllers (including dynamic size adjustment)
  void _setControllersFromData(List<TextEditingController> menuCtrls, List<List<TextEditingController>> setCtrls, List<MenuData> list) {
    // First, clear text content of existing controllers
    _clearControllers(menuCtrls, setCtrls);

    // Adjust the number of required controllers
    // If the list to load is larger than current controller count, add new ones
    while (menuCtrls.length < list.length) {
      menuCtrls.add(TextEditingController());
      setCtrls.add(List.generate(6, (_) => TextEditingController()));
    }
    // If the list to load is smaller, remove excess controllers
    // But keep at least 4 for initial display
    while (menuCtrls.length > list.length && menuCtrls.length > 4) {
      menuCtrls.removeLast().dispose();
      setCtrls.removeLast().forEach((c) => c.dispose());
    }

    // Populate controllers with data
    for (int i = 0; i < list.length; i++) {
      menuCtrls[i].text = list[i].name;
      for (int s = 0; s < 3; s++) {
        setCtrls[i][s * 2].text = list[i].weights[s].toString();
        setCtrls[i][s * 2 + 1].text = list[i].reps[s].toString();
      }
    }
    // setState is handled by the caller, not needed here
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
      for (int i = 0; i < section.menuControllers.length; i++) {
        String name = section.menuControllers[i].text.trim();
        List<int> weights = [];
        List<int> reps = [];
        bool rowHasContent = false;
        for (int s = 0; s < 3; s++) {
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
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      // Reload filtered body parts when returning from settings screen
      _loadFilteredBodyParts();
      // Re-evaluate current section selection and display if needed
      setState(() {});
    });
  }

  // Function to add a new exercise card to a specific section
  void _addMenuItem(int sectionIndex) {
    setState(() {
      _sections[sectionIndex].menuControllers.add(TextEditingController());
      _sections[sectionIndex].setControllers.add(List.generate(6, (_) => TextEditingController()));
    });
  }

  // Function to add a new target section
  void _addTargetSection() {
    setState(() {
      _sections.add(SectionData.createEmpty());
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
          style: TextStyle(color: Colors.grey[700], fontSize: 14.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
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
            style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
          ),
        ),
        Text(' kg ', style: TextStyle(color: Colors.grey[700], fontSize: 14.0, fontWeight: FontWeight.normal)), // フォントの太さをnormalに
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
            style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
          ),
        ),
        Text(' 回', style: TextStyle(color: Colors.grey[700], fontSize: 14.0, fontWeight: FontWeight.normal)), // フォントの太さをnormalに
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
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
                              filled: true,
                              fillColor: Colors.grey[100], // Background color to light grey
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0), // More pill-like rounded corners
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Adjusted padding for pill shape
                            ),
                            value: section.selectedPart,
                            items: _filteredBodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.normal)))).toList(), // フォントの太さをnormalに
                            onChanged: (value) {
                              setState(() {
                                section.selectedPart = value;
                                if (section.selectedPart != null) {
                                  String dateKey = _getDateKey(widget.selectedDate);
                                  DailyRecord? record = recordsBox.get(dateKey);
                                  List<MenuData>? listToLoad;

                                  if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                    listToLoad = record.menus[section.selectedPart!];
                                  } else {
                                    listToLoad = lastUsedMenusBox.get(section.selectedPart!);
                                  }
                                  _setControllersFromData(section.menuControllers, section.setControllers, listToLoad ?? []);
                                } else {
                                  _clearControllers(section.menuControllers, section.setControllers);
                                }
                              });
                            },
                            dropdownColor: Colors.white, // Dropdown menu background color
                            style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
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
                                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
                                          filled: true,
                                          fillColor: Colors.grey[50], // TextField background color to Colors.grey[50]
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10.0),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        ),
                                        style: TextStyle(color: Colors.grey[800], fontSize: 16.0, fontWeight: FontWeight.normal), // フォントの太さをnormalに
                                      ),
                                      const SizedBox(height: 10), // スペーシング調整
                                      buildSetRow(section.setControllers, menuIndex, 1, 0, 1),
                                      const SizedBox(height: 8),
                                      buildSetRow(section.setControllers, menuIndex, 2, 2, 3),
                                      const SizedBox(height: 8),
                                      buildSetRow(section.setControllers, menuIndex, 3, 4, 5),
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
                              label: Text('種目を追加', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.normal, fontSize: 16.0)), // フォントの太さをnormalに
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
            // ★「ターゲットを追加」ボタンはListView.builderの中に移動したのでここからは削除
          ],
        ),
      ),
    );
  }
}
