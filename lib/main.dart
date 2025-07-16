import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

// MenuData クラスの定義
// @HiveType(typeId: 0) は、このクラスがHiveによって保存されることを示します。
// typeId は、アプリケーション内で一意である必要があります。
@HiveType(typeId: 0)
class MenuData extends HiveObject {
  // @HiveField(0) は、このフィールドがHiveによって保存されることを示し、
  // フィールドのインデックスを指定します。
  @HiveField(0)
  String name;

  @HiveField(1)
  List<int> weights;

  @HiveField(2)
  List<int> reps;

  // コンストラクタ
  MenuData({required this.name, required this.weights, required this.reps});
}

// MenuDataAdapter クラスの定義 (通常は build_runner によって自動生成されます)
// このアダプターは、MenuData オブジェクトをバイナリ形式に変換し、
// またバイナリ形式からMenuData オブジェクトに変換する方法をHiveに教えます。
class MenuDataAdapter extends TypeAdapter<MenuData> {
  @override
  final int typeId = 0; // MenuData クラスの typeId と一致させる必要があります。

  @override
  MenuData read(BinaryReader reader) {
    // 読み込むフィールドの数を読み取ります。
    final numOfFields = reader.readByte();
    // 各フィールドのインデックスと値をマップに読み取ります。
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // 読み取ったデータから MenuData オブジェクトを再構築します。
    return MenuData(
      name: fields[0] as String,
      weights: (fields[1] as List).cast<int>(), // List<dynamic> を List<int> にキャスト
      reps: (fields[2] as List).cast<int>(),     // List<dynamic> を List<int> にキャスト
    );
  }

  @override
  void write(BinaryWriter writer, MenuData obj) {
    // 書き込むフィールドの数を指定します。
    writer
      ..writeByte(3) // 3つのフィールドを書き込みます。
      ..writeByte(0) // フィールド0 (name) のインデックス
      ..write(obj.name) // name の値
      ..writeByte(1) // フィールド1 (weights) のインデックス
      ..write(obj.weights) // weights の値
      ..writeByte(2) // フィールド2 (reps) のインデックス
      ..write(obj.reps); // reps の値
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MenuDataAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}

// アプリケーションのエントリーポイント
void main() async {
  // Flutter ウィジェットバインディングが初期化されていることを確認します。
  WidgetsFlutterBinding.ensureInitialized();
  // Hive を初期化します。
  await Hive.initFlutter();
  // MenuData のアダプターを登録します。これにより、Hive が MenuData オブジェクトを保存・読み込みできるようになります。
  Hive.registerAdapter(MenuDataAdapter());
  // 'recordsBox' という名前のBoxを開きます。このBoxには List<MenuData> が保存されます。
  await Hive.openBox<List<MenuData>>('recordsBox');

  // アプリケーションを実行します。
  runApp(const TrainingRecordApp());
}

// メインアプリケーションウィジェット
class TrainingRecordApp extends StatelessWidget {
  const TrainingRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training Record', // アプリケーションのタイトル
      theme: ThemeData(primarySwatch: Colors.blue), // アプリケーションのテーマ
      home: const CalendarScreen(), // アプリケーションの開始画面
    );
  }
}

// カレンダー画面
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now(); // 現在フォーカスされている日付
  DateTime? _selectedDay; // ユーザーが選択した日付

  // 記録画面へ遷移する関数
  void navigateToRecord(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordScreen(selectedDate: date), // 選択された日付を渡します
      ),
    );
  }

  // 設定画面へ遷移する関数
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
        title: const Text('トレーニングカレンダー'), // アプリバーのタイトル
        actions: [
          IconButton(
            icon: const Icon(Icons.settings), // 設定アイコン
            onPressed: () => navigateToSettings(context), // 設定画面へ遷移
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1), // カレンダーの開始日
            lastDay: DateTime.utc(2030, 12, 31), // カレンダーの終了日
            focusedDay: _focusedDay, // 現在フォーカスされている日
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day), // 日が選択されているかを判断する述語
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay; // 選択された日を更新
                _focusedDay = focusedDay; // フォーカスされている日を更新
              });
              navigateToRecord(context, selectedDay); // 記録画面へ遷移
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.orange, // 今日の日付の装飾
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue, // 選択された日付の装飾
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 記録画面
class RecordScreen extends StatefulWidget {
  final DateTime selectedDate; // 選択された日付

  const RecordScreen({super.key, required this.selectedDate});

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  String? _selectedPart; // 選択されたターゲット部位
  final List<String> _bodyParts = [
    '腕', '胸', '肩', '背中', '足', '全体', 'その他',
  ]; // ターゲット部位のリスト

  late List<TextEditingController> _menuControllers; // 種目名入力用のコントローラーリスト
  late List<List<TextEditingController>> _setControllers; // セットの重量と回数入力用のコントローラーリスト
  late Box<List<MenuData>> _recordsBox; // Hive の Box

  @override
  void initState() {
    super.initState();
    _recordsBox = Hive.box<List<MenuData>>('recordsBox'); // Hive Box を取得
    _initControllers(); // コントローラーを初期化
  }

  // テキストフィールドコントローラーの初期化
  void _initControllers() {
    _menuControllers = List.generate(4, (_) => TextEditingController()); // 4つの種目名コントローラー
    _setControllers = List.generate(
      4,
          (_) => List.generate(6, (_) => TextEditingController()), // 各種目につき6つのセットコントローラー (重量3つ、回数3つ)
    );
  }

  // 選択された部位に基づいてデータをコントローラーに読み込む
  void _loadDataToControllers(String part) {
    List<MenuData>? list = _recordsBox.get(part); // Hive からデータを取得
    for (int i = 0; i < 4; i++) {
      if (list != null && i < list.length) {
        var data = list[i];
        _menuControllers[i].text = data.name; // 種目名をセット
        for (int s = 0; s < 3; s++) {
          // 重量と回数をセット (s*2 は重量、s*2+1 は回数)
          _setControllers[i][s * 2].text = data.weights[s].toString();
          _setControllers[i][s * 2 + 1].text = data.reps[s].toString();
        }
      } else {
        // データがない場合はクリア
        _menuControllers[i].clear();
        for (int j = 0; j < 6; j++) {
          _setControllers[i][j].clear();
        }
      }
    }
  }

  // 現在のコントローラーのデータをHiveに保存する
  void _saveCurrentControllersToData(String part) {
    List<MenuData> list = [];
    for (int i = 0; i < 4; i++) {
      String name = _menuControllers[i].text.trim();
      if (name.isEmpty) continue; // 種目名が空の場合はスキップ
      List<int> weights = [];
      List<int> reps = [];
      for (int s = 0; s < 3; s++) {
        // 重量と回数をパースし、リストに追加
        int w = int.tryParse(_setControllers[i][s * 2].text) ?? 0;
        int r = int.tryParse(_setControllers[i][s * 2 + 1].text) ?? 0;
        weights.add(w);
        reps.add(r);
      }
      list.add(MenuData(name: name, weights: weights, reps: reps)); // MenuData オブジェクトを作成しリストに追加
    }
    _recordsBox.put(part, list); // Hive に保存
  }

  @override
  void dispose() {
    // 画面が破棄される前に現在のデータを保存
    if (_selectedPart != null) {
      _saveCurrentControllersToData(_selectedPart!);
    }
    // すべてのコントローラーを破棄してメモリリークを防ぐ
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

  // 各セットの入力行を構築するウィジェット
  Widget buildSetRow(int menuIndex, int setNumber, int weightIndex, int repIndex) {
    return Row(
      children: [
        Text('${setNumber}セット：'),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _setControllers[menuIndex][weightIndex],
            keyboardType: TextInputType.number, // 数値入力のみ
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
            keyboardType: TextInputType.number, // 数値入力のみ
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
        title: Text('${widget.selectedDate.year}/${widget.selectedDate.month}/${widget.selectedDate.day} 記録'), // アプリバーのタイトル
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
                      // 選択部位が変わる前に現在のデータを保存
                      if (_selectedPart != null) {
                        _saveCurrentControllersToData(_selectedPart!);
                      }
                      _selectedPart = value; // 新しい選択部位をセット
                      // 新しい選択部位のデータを読み込む
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
                          inputFormatters: [LengthLimitingTextInputFormatter(50)], // 最大50文字
                          decoration: const InputDecoration(
                            hintText: '種目名（最大50文字）',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        buildSetRow(index, 1, 0, 1), // 1セット目
                        const SizedBox(height: 4),
                        buildSetRow(index, 2, 2, 3), // 2セット目
                        const SizedBox(height: 4),
                        buildSetRow(index, 3, 4, 5), // 3セット目
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

// 設定画面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 部位選択の状態を保持するマップ
  // 現状、この画面での選択は保存されず、RecordScreen のドロップダウンには影響しません。
  // 必要であれば、Hive などでこの状態を永続化し、RecordScreen に渡すロジックを追加できます。
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
        title: const Text('設定'), // アプリバーのタイトル
      ),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text('鍛える部位を選択'), // 展開可能なタイル
            children: _bodyParts.keys.map((part) {
              return CheckboxListTile(
                title: Text(part),
                value: _bodyParts[part], // チェックボックスの状態
                onChanged: (bool? value) {
                  setState(() {
                    _bodyParts[part] = value ?? false; // チェックボックスの状態を更新
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
