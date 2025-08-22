// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../l10n/app_localizations.dart';
import '../screens/calendar_screen.dart';
import '../widgets/ad_banner.dart';
import '../widgets/ad_square.dart';
import '../settings_manager.dart';
import 'record_screen.dart';
import 'graph_screen.dart';
import '../models/menu_data.dart';
import 'package:flutter/widgets.dart' show RadioGroup;


class SettingsScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
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

  bool _isBodyPartsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _setCount = widget.setCountBox.get('setCount', defaultValue: 3) ?? 3;
    _showWeightInput = SettingsManager.showWeightInput;
    _selectedUnit = SettingsManager.currentUnit;
    _themeMode = SettingsManager.currentThemeMode;

    final Map<String, bool>? savedBodyParts =
        widget.settingsBox.get('selectedBodyParts')?.cast<String, bool>();
    if (savedBodyParts != null) {
      _selectedBodyParts = Map<String, bool>.from(savedBodyParts);
    } else {
      for (var part in _bodyPartsOriginal) {
        _selectedBodyParts[part] = true;
      }
    }
  }

  Future<void> _saveSettings() async {
    await widget.settingsBox.put('selectedBodyParts', _selectedBodyParts);
    await widget.setCountBox.put('setCount', _setCount);
    await SettingsManager.setUnit(_selectedUnit);
    await SettingsManager.setShowWeightInput(_showWeightInput);
    await SettingsManager.setThemeMode(_themeMode);
  }

  void _onUnitChanged(String? newUnit) {
    if (newUnit != null) {
      setState(() => _selectedUnit = newUnit);
      SettingsManager.setUnit(newUnit);
    }
  }

  void _onThemeChanged(ThemeMode? mode) {
    if (mode != null) {
      setState(() => _themeMode = mode);
      SettingsManager.setThemeMode(mode);
    }
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

    // カード間の余白（外側）
    const double gap = 8.0;
    // カード内の標準パディング（内側）
    const EdgeInsets cardPad = EdgeInsets.all(12.0);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveSettings();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(
            l10n.settingsScreenTitle,
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
              const SizedBox(height: 2),
              const SizedBox(
                  height: 50, child: AdBanner(screenName: 'settings')),
              const SizedBox(height: 12.0),
              Expanded(
                child: ListView(
                  children: [
                    // テーマ
                    // テーマ
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: cardPad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.themeMode,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ここから：RadioGroup で3つの RadioListTile を包む
                            RadioGroup<ThemeMode>(
                              groupValue: _themeMode,
                              onChanged: _onThemeChanged,
                              child: Column(
                                children: [
                                  RadioListTile<ThemeMode>(
                                    dense: true,
                                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(l10n.systemDefault),
                                    value: ThemeMode.system,
                                    activeColor: colorScheme.primary,
                                  ),
                                  RadioListTile<ThemeMode>(
                                    dense: true,
                                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(l10n.light),
                                    value: ThemeMode.light,
                                    activeColor: colorScheme.primary,
                                  ),
                                  RadioListTile<ThemeMode>(
                                    dense: true,
                                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(l10n.dark),
                                    value: ThemeMode.dark,
                                    activeColor: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                            // ここまで
                          ],
                        ),
                      ),
                    ),
                    // ★ カード間の余白（テーマ ↔ 体重管理 を狭める）
                    const SizedBox(height: gap),

                    // 体重管理（“太め”に）
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: SwitchListTile(
                        // 太めにするために上下パディングを増やす
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        // dense は使わない（薄くならないように）
                        title: Text(
                          l10n.bodyWeightTracking,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                        value: _showWeightInput,
                        onChanged: (bool value) {
                          setState(() => _showWeightInput = value);
                          SettingsManager.setShowWeightInput(value);
                          widget.settingsBox.put('showWeightInput', value);
                        },
                        activeThumbColor: colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: gap),

                    // 表示する部位を選択（アコーディオン、光らない）
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _isBodyPartsExpanded,
                            onExpansionChanged: (v) =>
                                setState(() => _isBodyPartsExpanded = v),
                            expandedAlignment: Alignment.centerLeft,
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            title: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.selectBodyParts,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.0,
                                ),
                              ),
                            ),
                            children: [
                              ..._bodyPartsOriginal.map((p) {
                                final translated = _translatePart(context, p);
                                final current = _selectedBodyParts[p] ?? true;
                                return SwitchListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                      horizontal: -2, vertical: -3),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    translated,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  value: current,
                                  onChanged: (bool value) async {
                                    setState(
                                        () => _selectedBodyParts[p] = value);
                                    await widget.settingsBox.put(
                                        'selectedBodyParts',
                                        _selectedBodyParts);
                                  },
                                  activeThumbColor: colorScheme.primary,
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ★ Large Banner 広告（320x100）— 選択部位 ↔ デフォルトセット の間
                    const SizedBox(height: gap),
                    Center(
                      child: AdSquare(
                        adSize: AdBoxSize.largeBanner, // 320x100
                        showPlaceholder: false, // ★本番広告にする
                        screenName: 'settings', // ★設定画面用IDを指定
                      ),
                    ),
                    const SizedBox(height: gap),

                    // デフォルトセット数
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0)),
                      child: Padding(
                        padding: cardPad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.defaultSets,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                              ),
                              child: Slider(
                                value: _setCount.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: _setCount.toString(),
                                onChanged: (double newValue) {
                                  setState(() => _setCount = newValue.round());
                                },
                                onChangeEnd: (v) {
                                  widget.setCountBox.put('setCount', v.round());
                                },
                                activeColor: colorScheme.primary,
                                inactiveColor: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$_setCount${l10n.sets}',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: gap),

                    // 重量単位
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0)),
                      child: Padding(
                        padding: cardPad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.unit,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                        horizontal: -2, vertical: -2),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      l10n.kg,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    value: 'kg',
                                    groupValue: _selectedUnit,
                                    onChanged: _onUnitChanged,
                                    activeColor: colorScheme.primary,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                        horizontal: -2, vertical: -2),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      l10n.lbs,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
            if (index == 3) return; // 自分
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
