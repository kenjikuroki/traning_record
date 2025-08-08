import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsManager {
  static const String _boxName = 'app_settings';
  static const String _unitKey = 'unit_of_weight';
  static const String _themeModeKey = 'theme_mode';

  static final ValueNotifier<String> unitNotifier = ValueNotifier<String>('kg');
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _loadUnit();
    _loadThemeMode();
  }

  static void _loadUnit() {
    final box = Hive.box(_boxName);
    final savedUnit = box.get(_unitKey, defaultValue: 'kg') as String;
    unitNotifier.value = savedUnit;
  }

  static Future<void> setUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') {
      throw ArgumentError('単位は "kg" または "lbs" のみ設定可能です。');
    }
    final box = Hive.box(_boxName);
    await box.put(_unitKey, unit);
    unitNotifier.value = unit;
  }

  static String get currentUnit => unitNotifier.value;

  static void _loadThemeMode() {
    final box = Hive.box(_boxName);
    final savedThemeModeIndex = box.get(_themeModeKey, defaultValue: ThemeMode.system.index);
    themeModeNotifier.value = ThemeMode.values[savedThemeModeIndex as int];
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final box = Hive.box(_boxName);
    await box.put(_themeModeKey, mode.index);
    themeModeNotifier.value = mode;
  }
}