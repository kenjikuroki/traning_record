import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../model/menu_data.dart';

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

  final recordsBox = Hive.box<DailyRecord>('recordsBox');
  final lastUsedMenusBox = Hive.box<List<MenuData>>('lastUsedMenusBox');

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadFullDayData(); // 初回に全データをロード
  }

  void _initControllers() {
    _menuControllers = List.generate(4, (_) => TextEditingController());
    _setControllers = List.generate(4, (_) => List.generate(6, (_) => TextEditingController()));
  }

  void _loadFullDayData() {
    String key = _getDateKey(widget.selectedDate);
    var record = recordsBox.get(key);

    if (record != null && record.menus.isNotEmpty) {
      // 最後に操作していたターゲットを自動選択（最初の部位）
      setState(() {
        _selectedPart = record.menus.keys.first;
      });
      _setControllersFromData(record.menus[_selectedPart!]!);
    }
  }

  void _loadDataForPart(String part) {
    String key = _getDateKey(widget.selectedDate);
    var record = recordsBox.get(key);

    if (record != null && record.menus.containsKey(part)) {
      _setControllersFromData(record.menus[part]!);
    } else {
      List<MenuData>? lastMenus = lastUsedMenusBox.get(part);
      if (lastMenus != null) {
        _setControllersFromData(lastMenus);
      } else {
        _clearControllers();
      }
    }
  }

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

  void _saveData() {
    if (_selectedPart == null) return;

    List<MenuData> list = [];
    for (int i = 0; i < 4; i++) {
      String name = _menuControllers[i].text.trim();
      if (name.isEmpty) continue;
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

    var record = recordsBox.get(key);
    if (record == null) {
      record = DailyRecord(menus: {});
    }

    record.menus[_selectedPart!] = list;
    recordsBox.put(key, record);

    // 前回値も更新
    lastUsedMenusBox.put(_selectedPart!, list);
  }

  void _saveAllPartsData() {
    if (_selectedPart != null) {
      _saveData();
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  @override
  void dispose() {
    _saveAllPartsData();
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
            decoration: const InputDecoration(isDense: true, hintText: 'kg'),
          ),
        ),
        const Text(' kg '),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _setControllers[menuIndex][repIndex],
            keyboardType: TextInputType.number,
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
      appBar: AppBar(title: Text('${widget.selectedDate.year}/${widget.selectedDate.month}/${widget.selectedDate.day} 記録')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text('ターゲットを選択'),
              value: _selectedPart,
              items: _bodyParts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) {
                if (_selectedPart != null) {
                  _saveData();
                }
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
