import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Hive_flutterをインポート
import 'package:hive/hive.dart'; // Hiveをインポート

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 部位選択の状態を保持するマップ。初期値は全てfalse。
  final Map<String, bool> _bodyParts = {
    '腕': false,
    '胸': false,
    '肩': false,
    '背中': false,
    '足': false,
    '全体': false,
    'その他': false,
  };

  // ★セット数の選択状態を保持する変数。デフォルトは3セット。
  int _selectedSetCount = 3;

  late Box<Map<String, bool>> _bodyPartsSettingsBox; // 部位選択の設定用Box
  late Box<int> _setCountBox; // ★セット数設定用Box

  @override
  void initState() {
    super.initState();
    _bodyPartsSettingsBox = Hive.box<Map<String, bool>>('settingsBox'); // 部位選択用Boxを初期化
    _setCountBox = Hive.box<int>('setCountBox'); // ★セット数用Boxを初期化
    _loadSettings(); // 保存された設定をロード
  }

  // Hiveから設定をロードする関数
  void _loadSettings() {
    // 'selectedBodyParts'というキーで設定を保存します。
    // もしデータがなければ空のマップをデフォルト値として使用します。
    // ★明示的な型キャストを追加
    Map<String, bool>? savedBodyPartsSettings = _bodyPartsSettingsBox.get('selectedBodyParts') as Map<String, bool>?;
    int? savedSetCount = _setCountBox.get('setCount'); // ★セット数用Boxからロード

    if (savedBodyPartsSettings != null) {
      setState(() {
        _bodyParts.forEach((key, value) {
          _bodyParts[key] = savedBodyPartsSettings[key] ?? false;
        });
      });
    } else {
      setState(() {
        _bodyParts.keys.forEach((key) {
          _bodyParts[key] = true;
        });
      });
      _saveSettings(); // 初回起動時にデフォルト設定を保存
    }

    // ★保存されたセット数があれば更新、なければデフォルト値を使用
    if (savedSetCount != null) {
      setState(() {
        _selectedSetCount = savedSetCount;
      });
    }
  }

  // Hiveに設定を保存する関数
  void _saveSettings() {
    _bodyPartsSettingsBox.put('selectedBodyParts', _bodyParts); // ★部位選択用Boxに保存
    _setCountBox.put('setCount', _selectedSetCount); // ★セット数用Boxに保存
  }

  @override
  void dispose() {
    _saveSettings(); // 画面が破棄される前に設定を保存
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // 全体の背景色をRecordScreenと合わせる
      appBar: AppBar(
        title: Text(
          '設定',
          style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 20.0), // タイトルスタイルをRecordScreenと合わせる
        ),
        backgroundColor: Colors.white, // AppBarの背景色を白に
        elevation: 1.0, // AppBarの影を少しつける
        iconTheme: IconThemeData(color: Colors.grey[700]), // アイコンの色をRecordScreenと合わせる
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0), // 全体のパディングをRecordScreenと合わせる
        children: [
          Card( // ExpansionTileをCardで囲む
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0), // 垂直方向の余白
            elevation: 4.0, // 影
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // 角丸
            color: Colors.white, // カードの背景色
            child: ExpansionTile(
              title: Text(
                '鍛える部位を選択',
                style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 18.0), // タイトルスタイル
              ),
              initiallyExpanded: false, // ★デフォルトで閉じるように変更
              iconColor: Colors.blue[600], // 展開アイコンの色
              collapsedIconColor: Colors.blue[600], // 折りたたみアイコンの色
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // 子要素のパディング
              children: _bodyParts.keys.map((part) {
                return CheckboxListTile(
                  title: Text(
                    part,
                    style: TextStyle(color: Colors.grey[700], fontSize: 16.0),
                  ),
                  value: _bodyParts[part],
                  onChanged: (bool? value) {
                    setState(() {
                      _bodyParts[part] = value ?? false;
                      _saveSettings(); // 変更があったらすぐに保存
                    });
                  },
                  activeColor: Colors.blue[600], // チェックボックスがオンの時の色
                  checkColor: Colors.white, // チェックマークの色
                  contentPadding: EdgeInsets.zero, // パディングをリセットしてCardのPaddingに任せる
                );
              }).toList(),
            ),
          ),
          // ★セット数の変更欄を追加
          Card( // ExpansionTileをCardで囲む
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0), // 垂直方向の余白
            elevation: 4.0, // 影
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // 角丸
            color: Colors.white, // カードの背景色
            child: ExpansionTile(
              title: Text(
                'セット数の変更',
                style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 18.0), // タイトルスタイル
              ),
              initiallyExpanded: false, // ★デフォルトで閉じるように変更
              iconColor: Colors.blue[600], // 展開アイコンの色
              collapsedIconColor: Colors.blue[600], // 折りたたみアイコンの色
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // 子要素のパディング
              children: List.generate(5, (index) { // 1から5まで
                final setCount = index + 1;
                return RadioListTile<int>(
                  title: Text(
                    '${setCount}セット',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16.0),
                  ),
                  value: setCount,
                  groupValue: _selectedSetCount,
                  onChanged: (int? value) {
                    setState(() {
                      _selectedSetCount = value ?? 3; // デフォルトは3セット
                      _saveSettings(); // 変更があったらすぐに保存
                    });
                  },
                  activeColor: Colors.blue[600], // ラジオボタンがオンの時の色
                  controlAffinity: ListTileControlAffinity.trailing, // ★ラジオボタンを右側に配置
                  contentPadding: EdgeInsets.zero, // パディングをリセットしてCardのPaddingに任せる
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
