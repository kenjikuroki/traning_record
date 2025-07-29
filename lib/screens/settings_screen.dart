import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

import '../main.dart'; // currentThemeMode を使用するためにインポート

// ignore_for_file: library_private_types_in_public_api

class SettingsScreen extends StatefulWidget {
  final Box<dynamic> settingsBox; // 修正: Boxの型をdynamicに合わせる
  final Box<int> setCountBox;
  final Box<int> themeModeBox;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.settingsBox,
    required this.setCountBox,
    required this.themeModeBox,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // トレーニング部位の順番と名称を修正
  final List<String> _allBodyParts = [
    '有酸素運動', '腕', '胸', '背中', '肩', '足', '全身', 'その他１', 'その他２', 'その他３',
  ];
  Map<String, bool> _selectedBodyParts = {};
  int _currentSetCount = 3;
  ThemeMode _selectedThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // 修正: 型安全にMap<String, bool>を構築
    Map<String, bool>? savedBodyPartsSettings;
    final dynamic rawSettings = widget.settingsBox.get('selectedBodyParts');

    if (rawSettings != null && rawSettings is Map) {
      savedBodyPartsSettings = {};
      rawSettings.forEach((key, value) {
        if (key is String && value is bool) {
          savedBodyPartsSettings![key] = value;
        }
      });
    }

    int? savedSetCount = widget.setCountBox.get('setCount');
    int? savedThemeModeIndex = widget.themeModeBox.get('themeMode');

    setState(() {
      if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
        _selectedBodyParts = Map.from(savedBodyPartsSettings);
      } else {
        // デフォルトで全ての部位を選択状態にする
        for (var part in _allBodyParts) {
          _selectedBodyParts[part] = true;
        }
      }
      _currentSetCount = savedSetCount ?? 3;
      _selectedThemeMode = savedThemeModeIndex != null
          ? ThemeMode.values[savedThemeModeIndex]
          : ThemeMode.system;
    });
  }

  void _saveSettings() {
    widget.settingsBox.put('selectedBodyParts', _selectedBodyParts);
    widget.setCountBox.put('setCount', _currentSetCount);
    widget.themeModeBox.put('themeMode', _selectedThemeMode.index);
    widget.onThemeModeChanged(_selectedThemeMode); // main.dart に変更を通知
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        _saveSettings();
        return true;
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          title: Text('設定', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20.0)),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // トレーニング部位選択
              Card(
                color: colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '表示するトレーニング部位',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _allBodyParts.map((part) {
                          return ChoiceChip(
                            label: Text(part),
                            selected: _selectedBodyParts[part] ?? false,
                            onSelected: (selected) {
                              setState(() {
                                _selectedBodyParts[part] = selected;
                              });
                            },
                            selectedColor: colorScheme.primary,
                            labelStyle: TextStyle(
                              color: (_selectedBodyParts[part] ?? false) ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: colorScheme.surfaceContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                              side: BorderSide(
                                color: (_selectedBodyParts[part] ?? false) ? colorScheme.primary : colorScheme.outline,
                              ),
                            ),
                            elevation: 2,
                            pressElevation: 5,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // デフォルトセット数設定
              Card(
                color: colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'デフォルトのセット数',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _currentSetCount.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: _currentSetCount.toString(),
                              onChanged: (double value) {
                                setState(() {
                                  _currentSetCount = value.round();
                                });
                              },
                              activeColor: colorScheme.primary,
                              inactiveColor: colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          Text(
                            _currentSetCount.toString(),
                            style: TextStyle(fontSize: 16.0, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // テーマモード設定
              Card(
                color: colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'テーマモード',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: ThemeMode.values.map((mode) {
                          String modeText;
                          switch (mode) {
                            case ThemeMode.system:
                              modeText = 'システム設定に従う';
                              break;
                            case ThemeMode.light:
                              modeText = 'ライトモード';
                              break;
                            case ThemeMode.dark:
                              modeText = 'ダークモード';
                              break;
                          }
                          return RadioListTile<ThemeMode>(
                            title: Text(modeText, style: TextStyle(color: colorScheme.onSurface)),
                            value: mode,
                            groupValue: _selectedThemeMode,
                            onChanged: (ThemeMode? value) {
                              if (value != null) {
                                setState(() {
                                  _selectedThemeMode = value;
                                });
                              }
                            },
                            activeColor: colorScheme.primary,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
