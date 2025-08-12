import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:ttraining_record/screens/calendar_screen.dart';
import '../widgets/ad_banner.dart';
import '../settings_manager.dart';
import 'record_screen.dart';
import 'graph_screen.dart';
import '../models/menu_data.dart';

class SettingsScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List> lastUsedMenusBox; // 型を統一
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const SettingsScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _bodyPartsOriginal = const [
    '有酸素運動',
    '腕',
    '胸',
    '背中',
    '肩',
    '足',
    '全身',
    'その他１',
    'その他２',
    'その他３'
  ];

  Map<String, bool> _selectedBodyParts = {};
  int _setCount = 3;
  late String _selectedUnit;
  late bool _showWeightInput;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _setCount = widget.setCountBox.get('setCount', defaultValue: 3)!;

    // SettingsManager を信頼ソースに
    _showWeightInput = SettingsManager.showWeightInput;
    _selectedUnit = SettingsManager.currentUnit;
    _themeMode = SettingsManager.currentThemeMode;

    // 部位表示設定は既存の settingsBox を使用
    final Map<String, bool>? savedBodyParts = widget.settingsBox.get('selectedBodyParts');
    if (savedBodyParts != null) {
      _selectedBodyParts = Map<String, bool>.from(savedBodyParts);
    } else {
      for (var part in _bodyPartsOriginal) {
        _selectedBodyParts[part] = true;
      }
    }
  }

  void _saveSettings() {
    widget.settingsBox.put('selectedBodyParts', _selectedBodyParts);
    widget.setCountBox.put('setCount', _setCount);
    // 単位とテーマ、体重管理は SettingsManager で保存するためここでは保存しない
  }

  Future<void> _onUnitChanged(String? newUnit) async {
    if (newUnit == null) return;
    setState(() => _selectedUnit = newUnit);
    await SettingsManager.setUnit(newUnit);
  }

  String _translatePart(BuildContext context, String originalPart) {
    final l10n = AppLocalizations.of(context)!;
    switch (originalPart) {
      case '有酸素運動':
        return l10n.aerobicExercise;
      case '腕':
        return l10n.arm;
      case '胸':
        return l10n.chest;
      case '背中':
        return l10n.back;
      case '肩':
        return l10n.shoulder;
      case '足':
        return l10n.leg;
      case '全身':
        return l10n.fullBody;
      case 'その他１':
        return l10n.other1;
      case 'その他２':
        return l10n.other2;
      case 'その他３':
        return l10n.other3;
      default:
        return originalPart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _saveSettings();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          title: Text(
            l10n.settings,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const AdBanner(screenName: 'settings'),
              const SizedBox(height: 16.0),
              Expanded(
                child: ListView(
                  children: [
                    // 体重管理 ON/OFF
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          l10n.bodyWeightTracking,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                        value: _showWeightInput,
                        onChanged: (bool value) async {
                          setState(() => _showWeightInput = value);
                          await SettingsManager.setShowWeightInput(value);
                          // 互換のため従来ボックスにも保存（任意）
                          await widget.settingsBox.put('showWeightInput', value);
                        },
                        activeColor: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // 表示する部位の選択
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.selectBodyParts,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ),
                            ..._bodyPartsOriginal.map((part) {
                              final translatedPart = _translatePart(context, part);
                              return SwitchListTile(
                                title: Text(
                                  translatedPart,
                                  style: TextStyle(color: colorScheme.onSurface),
                                ),
                                value: _selectedBodyParts[part] ?? true,
                                onChanged: (bool value) {
                                  setState(() {
                                    _selectedBodyParts[part] = value;
                                    _saveSettings();
                                  });
                                },
                                activeColor: colorScheme.primary,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // デフォルトのセット数
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.defaultSets,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ),
                            Slider(
                              value: _setCount.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: _setCount.toString(),
                              onChanged: (double newValue) {
                                setState(() {
                                  _setCount = newValue.round();
                                  _saveSettings();
                                });
                              },
                              activeColor: colorScheme.primary,
                              inactiveColor:
                              colorScheme.onSurfaceVariant.withOpacity(0.3),
                            ),
                            Center(
                              child: Text(
                                '${_setCount}${l10n.sets}',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // テーマモード（システムデフォルト/ライト/ダーク）
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.themeMode,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RadioListTile<ThemeMode>(
                              title: Text(l10n.systemDefault),
                              value: ThemeMode.system,
                              groupValue: _themeMode,
                              onChanged: (mode) async {
                                if (mode == null) return;
                                setState(() => _themeMode = mode);
                                await SettingsManager.setThemeMode(mode);
                              },
                              activeColor: colorScheme.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<ThemeMode>(
                              title: Text(l10n.light),
                              value: ThemeMode.light,
                              groupValue: _themeMode,
                              onChanged: (mode) async {
                                if (mode == null) return;
                                setState(() => _themeMode = mode);
                                await SettingsManager.setThemeMode(mode);
                              },
                              activeColor: colorScheme.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<ThemeMode>(
                              title: Text(l10n.dark),
                              value: ThemeMode.dark,
                              groupValue: _themeMode,
                              onChanged: (mode) async {
                                if (mode == null) return;
                                setState(() => _themeMode = mode);
                                await SettingsManager.setThemeMode(mode);
                              },
                              activeColor: colorScheme.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // 重量単位（kg / lbs）
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.unit,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(l10n.kg),
                                    value: 'kg',
                                    groupValue: _selectedUnit,
                                    onChanged: _onUnitChanged,
                                    activeColor: colorScheme.primary,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(l10n.lbs),
                                    value: 'lbs',
                                    groupValue: _selectedUnit,
                                    onChanged: _onUnitChanged,
                                    activeColor: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: 'Record',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Graph',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: 3,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          onTap: (index) {
            if (index == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    selectedDate: DateTime.now(),
                  ),
                ),
              );
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    selectedDate: DateTime.now(),
                  ),
                ),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GraphScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
