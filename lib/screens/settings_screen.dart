import 'package:flutter/material.dart';

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
