import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/menu_data.dart';     // MenuDataとDailyRecordをインポート
import 'settings_screen.dart'; // SettingsScreenをインポート

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;

  const RecordScreen({super.key, required this.selectedDate});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _bodyParts = ['腕', '胸', '肩', '背中', '足', '全体', 'その他'];
  String? _selectedPart;

  late List<TextEditingController> _menuControllers;
  late List<List<TextEditingController>> _setControllers;

  // Boxの型をDailyRecordに変更
  late final Box<DailyRecord> recordsBox;
  late final Box<List<MenuData>> lastUsedMenusBox;

  @override
  void initState() {
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox');
    lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');
    _initControllers();
    _loadFullDayData(); // 初回に全データをロード
  }

  void _initControllers() {
    _menuControllers = List.generate(4, (_) => TextEditingController());
    _setControllers = List.generate(4, (_) => List.generate(6, (_) => TextEditingController()));
  }

  // 日付キーを生成するヘルパー関数
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 画面表示時にその日の記録があれば、最初のターゲットを自動選択して表示
  void _loadFullDayData() {
    String key = _getDateKey(widget.selectedDate);
    var record = recordsBox.get(key);

    if (record != null && record.menus.isNotEmpty) {
      // lastModifiedPart が設定されていればそれを使用、なければ最初の部位を選択
      setState(() {
        _selectedPart = record.lastModifiedPart ?? record.menus.keys.first;
      });
      _setControllersFromData(record.menus[_selectedPart!]!);
    }
  }

  // 特定の部位のデータをロード
  void _loadDataForPart(String part) {
    String key = _getDateKey(widget.selectedDate);
    var record = recordsBox.get(key);

    if (record != null && record.menus.containsKey(part)) {
      // その日のその部位の記録があればそれをロード
      _setControllersFromData(record.menus[part]!);
    } else {
      // その日のその部位の記録がなければ、前回使用したメニューをロード
      List<MenuData>? lastMenus = lastUsedMenusBox.get(part);
      if (lastMenus != null) {
        _setControllersFromData(lastMenus);
      } else {
        // 前回使用したメニューもなければクリア
        _clearControllers();
      }
    }
  }

  // コントローラーにデータをセット
  void _setControllersFromData(List<MenuData> list) {
    for (int i = 0; i < 4; i++) {
      if (i < list.length) {
        _menuControllers[i].text = list[i].name;
        for (int s = 0; s < 3; s++) {
          _setControllers[i][s * 2].text = list[i].weights[s].toString();
          _setControllers[i][s * 2 + 1].text = list[i].reps[s].toString();
        }
      } else {
        _menuControllers[i].clear();
        for (int j = 0; j < 6; j++) {
          _setControllers[i][j].clear();
        }
      }
    }
  }

  // コントローラーをクリア
  void _clearControllers() {
    for (var c in _menuControllers) {
      c.clear();
    }
    for (var list in _setControllers) {
      for (var c in list) {
        c.clear();
      }
    }
  }

  // 現在のデータを保存
  void _saveData() {
    if (_selectedPart == null) return;

    List<MenuData> list = [];
    for (int i = 0; i < 4; i++) {
      String name = _menuControllers[i].text.trim();
      // 種目名が空で、かつ重量と回数もすべて0の場合はスキップ（完全に空の行）
      if (name.isEmpty &&
          (int.tryParse(_setControllers[i][0].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][1].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][2].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][3].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][4].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][5].text) ?? 0) == 0) {
        continue;
      }

      List<int> weights = [];
      List<int> reps = [];
      for (int s = 0; s < 3; s++) {
        int w = int.tryParse(_setControllers[i][s * 2].text) ?? 0;
        int r = int.tryParse(_setControllers[i][s * 2 + 1].text) ?? 0;
        weights.add(w);
        reps.add(r);
      }
      list.add(MenuData(name: name, weights: weights, reps: reps));
    }

    String key = _getDateKey(widget.selectedDate);

    // その日のDailyRecordを取得または新規作成
    var record = recordsBox.get(key);
    if (record == null) {
      record = DailyRecord(menus: {});
    }

    // 選択された部位のメニューリストを更新
    record.menus[_selectedPart!] = list;
    // 最後に変更された部位を記録
    record.lastModifiedPart = _selectedPart!;

    // DailyRecord を保存します。
    // 特定の部位のメニューリストが空になっても、DailyRecord自体は削除しません。
    // これにより、ユーザーが空にした場合でも、その日のその部位の記録は「空のリスト」として残ります。
    recordsBox.put(key, record);

    // 前回値も更新 (空でないリストの場合のみ)
    if (list.isNotEmpty) {
      lastUsedMenusBox.put(_selectedPart!, list);
    }
  }

  // 画面を離れる際にデータを保存
  void _saveOnDispose() {
    _saveData();
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

  @override
  void dispose() {
    _saveOnDispose(); // dispose時に保存
    for (var c in _menuControllers) {
      c.dispose();
    }
    for (var list in _setControllers) {
      for (var c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Widget buildSetRow(int menuIndex, int setNumber, int weightIndex, int repIndex) {
    return Row(
      children: [
        Text('${setNumber}セット：'),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _setControllers[menuIndex][weightIndex],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 数字のみを許可
            decoration: const InputDecoration(isDense: true, hintText: 'kg'),
          ),
        ),
        const Text(' kg '),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _setControllers[menuIndex][repIndex],
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
            DropdownButton<String>(
              hint: const Text('ターゲットを選択'),
              value: _selectedPart,
              items: _bodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) {
                // 部位変更前に現在のデータを保存
                _saveData();
                setState(() {
                  _selectedPart = value;
                  if (_selectedPart != null) {
                    _loadDataForPart(_selectedPart!);
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _menuControllers[index],
                        inputFormatters: [LengthLimitingTextInputFormatter(50)], // 最大50文字
                        decoration: const InputDecoration(isDense: true, hintText: '種目名'),
                      ),
                      buildSetRow(index, 1, 0, 1),
                      buildSetRow(index, 2, 2, 3),
                      buildSetRow(index, 3, 4, 5),
                      const Divider(),
                    ],
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
