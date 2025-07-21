import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:hive/hive.dart'; // Unnecessary import, removed
import '../widgets/custom_widgets.dart'; // StylishInput を使用するためにインポートを追加

// ThemeMode変更を通知するための型定義
typedef ThemeModeChangedCallback = void Function(ThemeMode newMode);

class SettingsScreen extends StatefulWidget {
  final Box<Map<String, bool>> settingsBox; // 部位選択の設定用Box
  final Box<int> setCountBox; // セット数設定用Box
  final Box<int> themeModeBox; // ★テーマモード保存用Box
  final ThemeModeChangedCallback onThemeModeChanged; // main.dartに通知するためのコールバック

  const SettingsScreen({
    super.key,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox, // ★コンストラクタに追加
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, bool> _bodyParts = {
    '腕': false, '胸': false, '肩': false, '背中': false,
    '足': false, '全体': false, 'その他': false,
  };

  int _selectedSetCount = 3;
  ThemeMode _selectedThemeMode = ThemeMode.system; // デフォルトはシステム設定

  @override
  void initState() {
    super.initState();
    _loadSettings(); // 保存された設定をロード
  }

  void _loadSettings() {
    // 部位選択設定をロード
    Map<dynamic, dynamic>? savedDynamicBodyPartsSettings = widget.settingsBox.get('selectedBodyParts');
    Map<String, bool>? savedBodyPartsSettings;

    if (savedDynamicBodyPartsSettings != null) {
      savedBodyPartsSettings = savedDynamicBodyPartsSettings.map(
            (key, value) => MapEntry(key.toString(), value as bool),
      );
    }

    if (savedBodyPartsSettings != null) {
      setState(() {
        _bodyParts.forEach((key, value) {
          _bodyParts[key] = savedBodyPartsSettings![key] ?? false;
        });
      });
    } else {
      setState(() {
        _bodyParts.keys.forEach((key) {
          _bodyParts[key] = true; // デフォルトで全て選択
        });
      });
      _saveSettings(); // 初期状態をHiveに保存
    }

    // セット数をロード
    int? savedSetCount = widget.setCountBox.get('setCount');
    if (savedSetCount != null) {
      setState(() {
        _selectedSetCount = savedSetCount;
      });
    }

    // テーマモードをロード
    // savedThemeModeIndex が null の可能性があるので、null-aware演算子を使用
    final int? savedThemeModeIndex = widget.themeModeBox.get('themeMode', defaultValue: ThemeMode.system.index);
    setState(() {
      _selectedThemeMode = ThemeMode.values[savedThemeModeIndex ?? ThemeMode.system.index]; // ★null安全なアクセス
    });
  }

  void _saveSettings() {
    widget.settingsBox.put('selectedBodyParts', _bodyParts);
    widget.setCountBox.put('setCount', _selectedSetCount);

    // テーマモードを保存 (int型で保存)
    widget.themeModeBox.put('themeMode', _selectedThemeMode.index);

    // 保存完了のSnackBarは、自動保存では頻繁に表示されるため削除
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('設定を保存しました！')),
    // );
  }

  @override
  void dispose() {
    _saveSettings(); // 画面が破棄される前に設定を保存
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          '設定',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 1.0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        // ★保存ボタンを削除
        actions: [],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 鍛える部位
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
            elevation: 4.0, // ★影を戻す
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            color: colorScheme.surfaceVariant,
            child: Theme( // ★ExpansionTileのテーマをオーバーライド
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  '鍛える部位を選択',
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18.0),
                ),
                initiallyExpanded: false,
                iconColor: colorScheme.primary,
                collapsedIconColor: colorScheme.primary,
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                // tilePaddingはデフォルトに戻すか、必要に応じて調整
                tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: _bodyParts.keys.map((part) {
                  return CheckboxListTile(
                    title: Text(
                      part,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
                    ),
                    value: _bodyParts[part],
                    onChanged: (bool? value) {
                      setState(() {
                        _bodyParts[part] = value ?? false;
                        _saveSettings(); // ★変更時に自動保存
                      });
                    },
                    activeColor: colorScheme.primary,
                    checkColor: colorScheme.onPrimary,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // デフォルトのセット数
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
            elevation: 4.0, // ★影を戻す
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            color: colorScheme.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'デフォルトのセット数',
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18.0),
                  ),
                  const SizedBox(height: 12.0),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      hintText: 'セット数を選択',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16.0),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    value: _selectedSetCount,
                    items: List.generate(10, (index) => index + 1)
                        .map((count) => DropdownMenuItem(value: count, child: Text('$count セット', style: TextStyle(color: colorScheme.onSurface))))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSetCount = value ?? 3;
                        _saveSettings(); // ★変更時に自動保存
                      });
                    },
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16.0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // ダークモード切り替えスイッチ
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
            elevation: 4.0, // ★影を戻す
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            color: colorScheme.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ダークモード',
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18.0),
                  ),
                  Switch(
                    value: _selectedThemeMode == ThemeMode.dark,
                    onChanged: (bool value) {
                      setState(() {
                        _selectedThemeMode = value ? ThemeMode.dark : ThemeMode.light;
                      });
                      widget.onThemeModeChanged(_selectedThemeMode); // main.dartに通知
                      _saveSettings(); // ★変更時に自動保存
                    },
                    activeColor: colorScheme.primary,
                    inactiveThumbColor: colorScheme.onSurfaceVariant,
                    inactiveTrackColor: colorScheme.surface,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
