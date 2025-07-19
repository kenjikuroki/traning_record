import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Hiveをインポート

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 部位選択の状態を保持するマップ。初期値は全てfalse。
  // Hiveからロードされるか、デフォルト値が使用される。
  final Map<String, bool> _bodyParts = {
    '腕': false,
    '胸': false,
    '肩': false,
    '背中': false,
    '足': false,
    '全体': false,
    'その他': false,
  };

  late Box<Map<String, bool>> _settingsBox; // 設定を保存するBox

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box<Map<String, bool>>('settingsBox');
    _loadSettings(); // 保存された設定をロード
  }

  // Hiveから設定をロードする関数
  void _loadSettings() {
    // 'selectedBodyParts'というキーで設定を保存します。
    // もしデータがなければ空のマップをデフォルト値として使用します。
    Map<String, bool>? savedSettings = _settingsBox.get('selectedBodyParts');

    if (savedSettings != null) {
      setState(() {
        // 保存された設定で_bodyPartsマップを更新します。
        // 新しい部位が追加された場合でも対応できるように、既存の_bodyPartsをベースにします。
        _bodyParts.forEach((key, value) {
          _bodyParts[key] = savedSettings[key] ?? false;
        });
      });
    } else {
      // 初回起動時など、設定が保存されていない場合は、全ての部位をtrue（選択済み）として初期化
      // これにより、デフォルトで全ての部位が記録画面に表示されるようになります。
      setState(() {
        _bodyParts.keys.forEach((key) {
          _bodyParts[key] = true;
        });
      });
      // 初期状態をHiveに保存
      _saveSettings();
    }
  }

  // Hiveに設定を保存する関数
  void _saveSettings() {
    _settingsBox.put('selectedBodyParts', _bodyParts);
  }

  @override
  void dispose() {
    _saveSettings(); // 画面が破棄される前に設定を保存
    super.dispose();
  }

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
                    _saveSettings(); // 変更があったらすぐに保存
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
