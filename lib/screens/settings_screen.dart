import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:ttraining_record/settings_manager.dart';
import '../widgets/ad_banner.dart'; // バナー広告ウィジェットをインポート

// ignore_for_file: library_private_types_in_public_api

class SettingsScreen extends StatefulWidget {
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const SettingsScreen({
    super.key,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _allBodyParts = [];
  Map<String, bool> _selectedBodyParts = {};
  int _currentSetCount = 3;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAllBodyParts();
    _loadSettings();
  }

  String _getOriginalPartName(BuildContext context, String translatedPart) {
    final l10n = AppLocalizations.of(context)!;
    if (translatedPart == l10n.aerobicExercise) return '有酸素運動';
    if (translatedPart == l10n.arm) return '腕';
    if (translatedPart == l10n.chest) return '胸';
    if (translatedPart == l10n.back) return '背中';
    if (translatedPart == l10n.shoulder) return '肩';
    if (translatedPart == l10n.leg) return '足';
    if (translatedPart == l10n.fullBody) return '全身';
    if (translatedPart == l10n.other1) return 'その他１';
    if (translatedPart == l10n.other2) return 'その他２';
    if (translatedPart == l10n.other3) return 'その他３';
    return translatedPart;
  }

  String _translatePartToLocale(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
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
        return part;
    }
  }

  void _loadAllBodyParts() {
    final l10n = AppLocalizations.of(context)!;
    _allBodyParts = [
      l10n.aerobicExercise,
      l10n.arm,
      l10n.chest,
      l10n.back,
      l10n.shoulder,
      l10n.leg,
      l10n.fullBody,
      l10n.other1,
      l10n.other2,
      l10n.other3,
    ];
  }

  void _loadSettings() {
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

    final dynamic savedUnit = SettingsManager.currentUnit;
    if (savedUnit is String) {
      SettingsManager.setUnit(savedUnit);
    }

    setState(() {
      _selectedBodyParts.clear();
      if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
        for (var part in savedBodyPartsSettings.keys) {
          final translatedPart = _translatePartToLocale(context, part);
          _selectedBodyParts[translatedPart] = savedBodyPartsSettings[part]!;
        }
      } else {
        for (var translatedPart in _allBodyParts) {
          _selectedBodyParts[translatedPart] = true;
        }
      }

      _currentSetCount = savedSetCount ?? 3;
    });
  }

  void _saveSettings() {
    final Map<String, bool> settingsToSave = {};
    _selectedBodyParts.forEach((translatedPart, value) {
      final originalPart = _getOriginalPartName(context, translatedPart);
      settingsToSave[originalPart] = value;
    });

    widget.settingsBox.put('selectedBodyParts', settingsToSave);
    widget.setCountBox.put('setCount', _currentSetCount);

    SettingsManager.setUnit(SettingsManager.currentUnit);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_allBodyParts.isEmpty) {
      _loadAllBodyParts();
    }
    if (_selectedBodyParts.isEmpty && _allBodyParts.isNotEmpty) {
      for (var translatedPart in _allBodyParts) {
        _selectedBodyParts[translatedPart] = true;
      }
    }

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
          title: Text(l10n.settings,
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trainingParts,
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
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
                              color: (_selectedBodyParts[part] ?? false)
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: colorScheme.surfaceContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                              side: BorderSide(
                                color: (_selectedBodyParts[part] ?? false)
                                    ? colorScheme.primary
                                    : colorScheme.outline,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.setCount,
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
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
                              inactiveColor:
                              colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          Text(
                            _currentSetCount.toString(),
                            style: TextStyle(
                                fontSize: 16.0, color: colorScheme.onSurface),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.themeMode,
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: SettingsManager.themeModeNotifier,
                        builder: (context, currentThemeMode, child) {
                          return Column(
                            children: ThemeMode.values.map((mode) {
                              String modeText;
                              switch (mode) {
                                case ThemeMode.system:
                                  modeText = l10n.systemDefault;
                                  break;
                                case ThemeMode.light:
                                  modeText = l10n.light;
                                  break;
                                case ThemeMode.dark:
                                  modeText = l10n.dark;
                                  break;
                              }
                              return RadioListTile<ThemeMode>(
                                title: Text(modeText,
                                    style: TextStyle(color: colorScheme.onSurface)),
                                value: mode,
                                groupValue: currentThemeMode,
                                onChanged: (ThemeMode? value) {
                                  if (value != null) {
                                    SettingsManager.setThemeMode(value);
                                  }
                                },
                                activeColor: colorScheme.primary,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 重量単位設定
              Card(
                color: colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.weightUnit,
                        style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<String>(
                        valueListenable: SettingsManager.unitNotifier,
                        builder: (context, currentUnit, child) {
                          return ToggleButtons(
                            isSelected: [currentUnit == 'kg', currentUnit == 'lbs'],
                            onPressed: (int index) async {
                              final newUnit = index == 0 ? 'kg' : 'lbs';
                              await SettingsManager.setUnit(newUnit);
                            },
                            borderRadius: BorderRadius.circular(8.0),
                            borderColor: colorScheme.primary.withOpacity(0.5),
                            selectedBorderColor: colorScheme.primary,
                            fillColor: colorScheme.primary,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text('KG',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(l10n.lbs,
                                    style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AdBanner(), // ★ ここにバナー広告ウィジェットを配置
      ),
    );
  }
}