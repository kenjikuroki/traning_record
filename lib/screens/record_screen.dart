import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/menu_data.dart';     // MenuDataとDailyRecordをインポート
import 'settings_screen.dart'; // SettingsScreenをインポート

// 各ターゲットセクションのデータを保持するヘルパークラス
class SectionData {
  String? selectedPart; // このセクションで選択されているターゲット部位
  List<TextEditingController> menuControllers; // このセクションの種目名コントローラー
  List<List<TextEditingController>> setControllers; // このセクションのセットコントローラー

  SectionData({
    this.selectedPart,
    required this.menuControllers,
    required this.setControllers,
  });

  // 空のコントローラーを持つ新しいセクションデータを生成するファクトリコンストラクタ
  static SectionData createEmpty() {
    return SectionData(
      menuControllers: List.generate(4, (_) => TextEditingController()), // デフォルトで4つの空の種目
      setControllers: List.generate(4, (_) => List.generate(6, (_) => TextEditingController())),
    );
  }

  // このセクション内のすべてのコントローラーを破棄するメソッド
  void dispose() {
    for (var c in menuControllers) {
      c.dispose();
    }
    for (var list in setControllers) {
      for (var c in list) {
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
  final _bodyParts = ['腕', '胸', '肩', '背中', '足', '全体', 'その他'];
  List<SectionData> _sections = []; // 複数のターゲットセクションを管理するリスト

  // Boxの型をDailyRecordに変更
  late final Box<DailyRecord> recordsBox;
  late final Box<List<MenuData>> lastUsedMenusBox;

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox');
    lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');
    _loadInitialSections(); // 初期セクションのロード（既存データまたは新規）
  }

  // 初期セクションのロード（既存データがあればそれらを、なければ空のセクションを1つ作成）
  void _loadInitialSections() {
    String dateKey = _getDateKey(widget.selectedDate);
    DailyRecord? record = recordsBox.get(dateKey);

    if (record != null && record.menus.isNotEmpty) {
      // 既存の記録からセクションをロード
      record.menus.forEach((part, menuList) {
        SectionData section = SectionData.createEmpty();
        section.selectedPart = part;
        _setControllersFromData(section.menuControllers, section.setControllers, menuList);
        _sections.add(section);
      });
    } else {
      // 記録がなければ、デフォルトで1つの空のセクションを作成
      _sections.add(SectionData.createEmpty());
    }
    setState(() {}); // UIを更新
  }

  // 日付キーを生成するヘルパー関数
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // コントローラーにデータをセット（動的なサイズ調整を含む）
  void _setControllersFromData(List<TextEditingController> menuCtrls, List<List<TextEditingController>> setCtrls, List<MenuData> list) {
    // まず既存のコントローラーのテキストをクリア
    for (var c in menuCtrls) c.clear();
    for (var list in setCtrls) { for (var c in list) c.clear(); }

    // 必要なコントローラーの数を調整
    // もし読み込むリストのサイズが現在のコントローラー数より多ければ追加
    while (menuCtrls.length < list.length) {
      menuCtrls.add(TextEditingController());
      setCtrls.add(List.generate(6, (_) => TextEditingController()));
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
      for (int s = 0; s < 3; s++) {
        setCtrls[i][s * 2].text = list[i].weights[s].toString();
        setCtrls[i][s * 2 + 1].text = list[i].reps[s].toString();
      }
    }
    // setStateは呼び出し元で処理されるため、ここでは不要
  }

  // コントローラーのテキスト内容をクリア（リスト自体はクリアしない）
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

  // 全てのセクションのデータを保存
  void _saveAllSectionsData() {
    String dateKey = _getDateKey(widget.selectedDate);
    Map<String, List<MenuData>> allMenusForDay = {};
    String? lastModifiedPart; // その日に最後に変更された部位を追跡

    for (var section in _sections) {
      if (section.selectedPart == null) continue; // 部位が選択されていないセクションはスキップ

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
          if (w > 0 || r > 0 || name.isNotEmpty) rowHasContent = true; // 種目名も考慮
        }

        if (name.isNotEmpty || rowHasContent) {
          sectionMenuList.add(MenuData(name: name, weights: weights, reps: reps));
          sectionHasContent = true;
        }
      }

      // セクションに内容がある場合のみ保存
      if (sectionMenuList.isNotEmpty) {
        allMenusForDay[section.selectedPart!] = sectionMenuList;
        lastModifiedPart = section.selectedPart; // 最後に内容があった部位を記録
        lastUsedMenusBox.put(section.selectedPart!, sectionMenuList); // 前回値も更新
      } else {
        // セクションが空になった場合、既存のマップからその部位を削除
        allMenusForDay.remove(section.selectedPart);
      }
    }

    // DailyRecord を保存または削除
    if (allMenusForDay.isNotEmpty) {
      DailyRecord newRecord = DailyRecord(menus: allMenusForDay, lastModifiedPart: lastModifiedPart);
      recordsBox.put(dateKey, newRecord);
    } else {
      recordsBox.delete(dateKey); // 全てのメニューが空になったらDailyRecordを削除
    }
  }

  // 設定画面へ遷移する関数
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  // 新しいメニューカードを特定のセクションに追加する関数
  void _addMenuItem(int sectionIndex) {
    setState(() {
      _sections[sectionIndex].menuControllers.add(TextEditingController());
      _sections[sectionIndex].setControllers.add(List.generate(6, (_) => TextEditingController()));
    });
  }

  // 新しいターゲットセクションを追加する関数
  void _addTargetSection() {
    setState(() {
      _sections.add(SectionData.createEmpty());
    });
  }

  @override
  void dispose() {
    _saveAllSectionsData(); // dispose時に全てのデータを保存
    // すべてのコントローラーを破棄
    for (var section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  // 各セットの入力行を構築するウィジェット
  Widget buildSetRow(List<List<TextEditingController>> setCtrls, int menuIndex, int setNumber, int weightIndex, int repIndex) {
    return Row(
      children: [
        Text('${setNumber}セット：'),
        SizedBox(
          width: 60,
          child: TextField(
            controller: setCtrls[menuIndex][weightIndex],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 数字のみを許可
            decoration: const InputDecoration(isDense: true, hintText: 'kg'),
          ),
        ),
        const Text(' kg '),
        SizedBox(
          width: 60,
          child: TextField(
            controller: setCtrls[menuIndex][repIndex],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 数字のみを許可
            decoration: const InputDecoration(isDense: true, hintText: '回'),
          ),
        ),
        const Text(' 回'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.selectedDate.year}/${widget.selectedDate.month}/${widget.selectedDate.day} 記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings), // 設定アイコン
            onPressed: () => _navigateToSettings(context), // 設定画面へ遷移
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _sections.length, // セクションの数に基づいてアイテム数を決定
                itemBuilder: (context, sectionIndex) {
                  final section = _sections[sectionIndex];
                  return Card( // 各セクションをCardウィジェットで囲む
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // カード間の余白
                    elevation: 2.0, // カードの影
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // 角丸
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // カード内のパディング
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ターゲット部位選択ドロップダウン (セクションごと)
                          DropdownButton<String>(
                            hint: const Text('ターゲットを選択'),
                            value: section.selectedPart,
                            items: _bodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (value) {
                              setState(() {
                                // 部位変更前に現在のセクションのデータを保存 (全体保存ロジックで処理されるため、ここでは不要)
                                section.selectedPart = value;
                                if (section.selectedPart != null) {
                                  // 新しい部位のデータをロード
                                  String dateKey = _getDateKey(widget.selectedDate);
                                  DailyRecord? record = recordsBox.get(dateKey);
                                  List<MenuData>? listToLoad;

                                  if (record != null && record.menus.containsKey(section.selectedPart!)) {
                                    // その日のその部位の記録があればそれをロード
                                    listToLoad = record.menus[section.selectedPart!];
                                  } else {
                                    // その日のその部位の記録がなければ、前回使用したメニューをロード
                                    listToLoad = lastUsedMenusBox.get(section.selectedPart!);
                                  }
                                  _setControllersFromData(section.menuControllers, section.setControllers, listToLoad ?? []);
                                } else {
                                  // 部位が選択解除されたらコントローラーをクリア
                                  _clearControllers(section.menuControllers, section.setControllers);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          // 各セクション内の種目リスト
                          ListView.builder(
                            shrinkWrap: true, // 親のListView内で子ListViewがスクロールしないように
                            physics: const NeverScrollableScrollPhysics(), // 自身のスクロールを無効化
                            itemCount: section.menuControllers.length, // このセクションの種目数
                            itemBuilder: (context, menuIndex) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: section.menuControllers[menuIndex],
                                    inputFormatters: [LengthLimitingTextInputFormatter(50)], // 最大50文字
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: '種目名',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  buildSetRow(section.setControllers, menuIndex, 1, 0, 1),
                                  const SizedBox(height: 4),
                                  buildSetRow(section.setControllers, menuIndex, 2, 2, 3),
                                  const SizedBox(height: 4),
                                  buildSetRow(section.setControllers, menuIndex, 3, 4, 5),
                                  const Divider(), // 各種目間の区切り線
                                ],
                              );
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _addMenuItem(sectionIndex), // このセクションに種目を追加
                              icon: const Icon(Icons.add),
                              label: const Text('種目を追加'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // 最下部の「ターゲットを追加」ボタン
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addTargetSection, // 新しいターゲットセクションを追加
                  icon: const Icon(Icons.add),
                  label: const Text('ターゲットを追加'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
