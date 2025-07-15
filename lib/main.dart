import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

part 'menu_data.g.dart';

@HiveType(typeId: 0)
class MenuData {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<int> weights;

  @HiveField(2)
  List<int> reps;

  MenuData({required this.name, required this.weights, required this.reps});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(MenuDataAdapter());
  await Hive.openBox<List>('recordsBox');

  runApp(const TrainingRecordApp());
}

class TrainingRecordApp extends StatelessWidget {
  const TrainingRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Record',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CalendarScreen(),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  void navigateToRecord(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordScreen(selectedDate: date),
      ),
    );
  }

  void navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングカレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => navigateToSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              navigateToRecord(context, selectedDay);
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordScreen extends StatefulWidget {
  final DateTime selectedDate;

  const RecordScreen({super.key, required this.selectedDate});

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  String? _selectedPart;
  final List<String> _bodyParts = [
    '腕',
    '胸',
    '肩',
    '背中',
    '足',
    '全体',
    'その他',
  ];

  late List<TextEditingController> _menuControllers;
  late List<List<TextEditingController>> _setControllers;
  late Box<List> _recordsBox;

  @override
  void initState() {
    super.initState();
    _recordsBox = Hive.box<List>('recordsBox');
    _initControllers();
  }

  void _initControllers() {
    _menuControllers = List.generate(4, (_) => TextEditingController());
    _setControllers = List.generate(
      4,
          (_) => List.generate(6, (_) => TextEditingController()),
    );
  }

  void _loadDataToControllers(String part) {
    List<MenuData>? list = _recordsBox.get(part)?.cast<MenuData>();

    for (int i = 0; i < 4; i++) {
      if (list != null && i < list.length) {
        var data = list[i];
        _menuControllers[i].text = data.name;
        for (int s = 0; s < 3; s++) {
          _setControllers[i][s * 2].text = data.weights[s].toString();
          _setControllers[i][s * 2 + 1].text = data.reps[s].toString();
        }
      } else {
        _menuControllers[i].clear();
        for (int j = 0; j < 6; j++) {
          _setControllers[i][j].clear();
        }
      }
    }
  }

  void _saveCurrentControllersToData(String part) {
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

    _recordsBox.put(part, list);
  }

  @override
  void dispose() {
    if (_selectedPart != null) {
      _saveCurrentControllersToData(_selectedPart!);
    }
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
            decoration: const InputDecoration(
              hintText: 'kg',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            ),
          ),
        ),
        const Text(' kg '),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _setControllers[menuIndex][repIndex],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '回',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            ),
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('ターゲット：'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  hint: const Text('選択'),
                  value: _selectedPart,
                  items: _bodyParts.map((part) => DropdownMenuItem(value: part, child: Text(part))).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (_selectedPart != null) {
                        _saveCurrentControllersToData(_selectedPart!);
                      }
                      _selectedPart = value;
                      if (_selectedPart != null) {
                        _loadDataToControllers(_selectedPart!);
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('メニューとセット'),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _menuControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _menuControllers[index],
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(50),
                          ],
                          decoration: const InputDecoration(
                            hintText: '種目名（最大50文字）',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        buildSetRow(index, 1, 0, 1),
                        const SizedBox(height: 4),
                        buildSetRow(index, 2, 2, 3),
                        const SizedBox(height: 4),
                        buildSetRow(index, 3, 4, 5),
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, bool> _bodyParts = {
    '腕': false,
    '胸': false,
    '肩': false,
    '背中': false,
    '足': false,
    '全体': false,
    'その他': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text('鍛える部位を選択'),
            children: _bodyParts.keys.map((part) {
              return CheckboxListTile(
                title: Text(part),
                value: _bodyParts[part],
                onChanged: (bool? value) {
                  setState(() {
                    _bodyParts[part] = value ?? false;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}