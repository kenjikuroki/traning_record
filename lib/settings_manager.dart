import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';

class SettingsManager {
  static const String _boxName = 'app_settings';
  static const String _unitKey = 'unit_of_weight';
  static const String _themeModeKey = 'theme_mode';
  // 💡 追加: 体重管理のON/OFFキー
  static const String _showWeightInputKey = 'show_weight_input';
  // 💡 追加: 体重管理のON/OFF ValueNotifier
  static final ValueNotifier<bool> _showWeightInputNotifier = ValueNotifier<bool>(true);

  static final ValueNotifier<String> _unitNotifier = ValueNotifier<String>('kg');
  static final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  static ValueNotifier<String> get unitNotifier => _unitNotifier;
  static ValueNotifier<ThemeMode> get themeModeNotifier => _themeModeNotifier;
  // 💡 追加: 体重管理のON/OFF ValueNotifierのゲッター
  static ValueNotifier<bool> get showWeightInputNotifier => _showWeightInputNotifier;

  static String get currentUnit => _unitNotifier.value;
  static ThemeMode get currentThemeMode => _themeModeNotifier.value;
  // 💡 追加: 体重管理のON/OFFのゲッター
  static bool get showWeightInput => _showWeightInputNotifier.value;

  static Box<dynamic>? _settingsBox;

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _settingsBox = await Hive.openBox(_boxName);
    } else {
      _settingsBox = Hive.box(_boxName);
    }
    _loadSettings();
  }

  static void _loadSettings() {
    final savedUnit = _settingsBox!.get(_unitKey, defaultValue: 'kg') as String;
    _unitNotifier.value = savedUnit;

    final savedThemeModeIndex = _settingsBox!.get(_themeModeKey, defaultValue: ThemeMode.system.index);
    _themeModeNotifier.value = ThemeMode.values[savedThemeModeIndex as int];

    // 💡 追加: 体重管理のON/OFF状態を読み込む
    final savedShowWeightInput = _settingsBox!.get(_showWeightInputKey, defaultValue: true) as bool;
    _showWeightInputNotifier.value = savedShowWeightInput;
  }

  static Future<void> setUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') {
      throw ArgumentError('単位は "kg" または "lbs" のみ設定可能です。');
    }
    await _settingsBox?.put(_unitKey, unit);
    _unitNotifier.value = unit;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    await _settingsBox?.put(_themeModeKey, mode.index);
    _themeModeNotifier.value = mode;
  }

  // 💡 追加: 体重管理のON/OFF状態を設定するメソッド
  static Future<void> setShowWeightInput(bool value) async {
    await _settingsBox?.put(_showWeightInputKey, value);
    _showWeightInputNotifier.value = value;
  }
}