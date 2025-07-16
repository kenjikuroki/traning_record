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
  void initState() { // initState 開始
    super.initState();
    recordsBox = Hive.box<DailyRecord>('recordsBox');
    lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');
    _initControllers();
    _loadFullDayData(); // 初回に全データをロード
  } // initState 終了

  void _initControllers() { // _initControllers 開始
    _menuControllers = List.generate(4, (_) => TextEditingController());
    _setControllers = List.generate(4, (_) => List.generate(6, (_) => TextEditingController()));
  } // _initControllers 終了

  // 日付キーを生成するヘルパー関数
  String _getDateKey(DateTime date) { // _getDateKey 開始
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  } // _getDateKey 終了

  // 画面表示時にその日の記録があれば、最初のターゲットを自動選択して表示
  void _loadFullDayData() { // _loadFullDayData 開始
    String key = _getDateKey(widget.selectedDate);
    var record = recordsBox.get(key);

    if (record != null && record.menus.isNotEmpty) { // if record != null 開始
      // 最後に操作していたターゲットを自動選択（最初の部位）
      setState(() { // setState 開始
        _selectedPart = record.menus.keys.first;
      }); // setState 終了
      _setControllersFromData(record.menus[_selectedPart!]!);
    } // if record != null 終了
  } // _loadFullDayData 終了

  // 特定の部位のデータをロード
  void _loadDataForPart(String part) { // _loadDataForPart 開始
    String key = _getDateKey(widget.selectedDate);
    var record = recordsBox.get(key);

    if (record != null && record.menus.containsKey(part)) { // if record != null 開始
      // その日のその部位の記録があればそれをロード
      _setControllersFromData(record.menus[part]!);
    } else { // else (record == null) 開始
      // その日のその部位の記録がなければ、前回使用したメニューをロード
      List<MenuData>? lastMenus = lastUsedMenusBox.get(part);
      if (lastMenus != null) { // if lastMenus != null 開始
        _setControllersFromData(lastMenus);
      } else { // else (lastMenus == null) 開始
        // 前回使用したメニューもなければクリア
        _clearControllers();
      } // else (lastMenus == null) 終了
    } // else (record == null) 終了
  } // _loadDataForPart 終了

  // コントローラーにデータをセット
  void _setControllersFromData(List<MenuData> list) { // _setControllersFromData 開始
    for (int i = 0; i < 4; i++) { // for i 開始
      if (i < list.length) { // if i < list.length 開始
        _menuControllers[i].text = list[i].name;
        for (int s = 0; s < 3; s++) { // for s 開始
          _setControllers[i][s * 2].text = list[i].weights[s].toString();
          _setControllers[i][s * 2 + 1].text = list[i].reps[s].toString();
        } // for s 終了
      } else { // else (i >= list.length) 開始
        _menuControllers[i].clear();
        for (int j = 0; j < 6; j++) { // for j 開始
          _setControllers[i][j].clear();
        } // for j 終了
      } // else (i >= list.length) 終了
    } // for i 終了
  } // _setControllersFromData 終了

  // コントローラーをクリア
  void _clearControllers() { // _clearControllers 開始
    for (var c in _menuControllers) { // for c (menuControllers) 開始
      c.clear();
    } // for c (menuControllers) 終了
    for (var list in _setControllers) { // for list (setControllers) 開始
      for (var c in list) { // for c (list) 開始
        c.clear();
      } // for c (list) 終了
    } // for list (setControllers) 終了
  } // _clearControllers 終了

  // 現在のデータを保存
  void _saveData() { // _saveData 開始
    if (_selectedPart == null) return;

    List<MenuData> list = [];
    for (int i = 0; i < 4; i++) { // for i 開始
      String name = _menuControllers[i].text.trim();
      // 種目名が空で、かつ重量と回数もすべて0の場合はスキップ（完全に空の行）
      if (name.isEmpty &&
          (int.tryParse(_setControllers[i][0].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][1].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][2].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][3].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][4].text) ?? 0) == 0 &&
          (int.tryParse(_setControllers[i][5].text) ?? 0) == 0) { // if (name.isEmpty...) 開始
        continue;
      } // if (name.isEmpty...) 終了

      List<int> weights = [];
      List<int> reps = [];
      for (int s = 0; s < 3; s++) { // for s 開始
        int w = int.tryParse(_setControllers[i][s * 2].text) ?? 0;
        int r = int.tryParse(_setControllers[i][s * 2 + 1].text) ?? 0;
        weights.add(w);
        reps.add(r);
      } // for s 終了
      list.add(MenuData(name: name, weights: weights, reps: reps));
    } // for i 終了

    String key = _getDateKey(widget.selectedDate);

    // その日のDailyRecordを取得または新規作成
    var record = recordsBox.get(key);
    if (record == null) { // if record == null 開始
      record = DailyRecord(menus: {});
    } // if record == null 終了

    // 選択された部位のメニューリストを更新
    record.menus[_selectedPart!] = list;

    // もしその日のすべての部位のメニューリストが空になったら、DailyRecord自体を削除
    bool allMenusEmpty = record.menus.values.every((menuList) => menuList.isEmpty);
    if (allMenusEmpty) { // if allMenusEmpty 開始
      recordsBox.delete(key);
    } else { // else (allMenusEmpty) 開始
      recordsBox.put(key, record); // DailyRecordを保存
    } // else (allMenusEmpty) 終了
    // if allMenusEmpty 終了 (else が if を閉じる)

    // 前回値も更新 (空でないリストの場合のみ)
    if (list.isNotEmpty) { // if list.isNotEmpty 開始
      lastUsedMenusBox.put(_selectedPart!, list);
    } // if list.isNotEmpty 終了
  } // _saveData 終了

  // 画面を離れる際にデータを保存
  void _saveOnDispose() { // _saveOnDispose 開始
    _saveData();
  } // _saveOnDispose 終了

  // 設定画面へ遷移する関数
  void _navigateToSettings(BuildContext context) { // _navigateToSettings 開始
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  } // _navigateToSettings 終了

  @override
  void dispose() { // dispose 開始
    _saveOnDispose(); // dispose時に保存
    for (var c in _menuControllers) { // for c (menuControllers) 開始
      c.dispose();
    } // for c (menuControllers) 終了
    for (var list in _setControllers) { // for list (setControllers) 開始
      for (var c in list) { // for c (list) 開始
        c.dispose();
      } // for c (list) 終了
    } // for list (setControllers) 終了
    super.dispose();
  } // dispose 終了

  Widget buildSetRow(int menuIndex, int setNumber, int weightIndex, int repIndex) { // buildSetRow 開始
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
  } // buildSetRow 終了

  @override
  Widget build(BuildContext context) { // build 開始
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
  } // build 終了
} // _RecordScreenState クラス終了
