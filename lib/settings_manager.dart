// lib/settings_manager.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// アプリ内の設定をまとめて管理するマネージャ。
/// Hive Box: 'app_settings'
/// 保存キー:
///   - unit_of_weight     : 'kg' | 'lbs'
///   - theme_mode         : ThemeMode.index
///   - show_weight_input  : bool
///   - show_stopwatch     : bool
///   - backgroundAsset    : String（'' = なし）
class SettingsManager {
  static const String _boxName = 'app_settings';

  // ====== Keys ======
  static const String _unitKey = 'unit_of_weight';
  static const String _themeModeKey = 'theme_mode';
  static const String _showWeightInputKey = 'show_weight_input';
  static const String _showStopwatchKey = 'show_stopwatch';
  static const String _backgroundAssetKey = 'backgroundAsset';

  static Box<dynamic>? _box;

  // ====== Notifiers ======
  /// 重量単位（'kg' / 'lbs'）
  static final ValueNotifier<String> _unitNotifier =
  ValueNotifier<String>('kg');

  /// テーマモード（system / light / dark）
  static final ValueNotifier<ThemeMode> _themeModeNotifier =
  ValueNotifier<ThemeMode>(ThemeMode.system);

  /// 体重入力カードの表示ON/OFF
  static final ValueNotifier<bool> _showWeightInputNotifier =
  ValueNotifier<bool>(true);

  /// ストップウォッチ表示ON/OFF
  static final ValueNotifier<bool> _showStopwatchNotifier =
  ValueNotifier<bool>(true);

  /// 背景アセット（'' = なし）
  static final ValueNotifier<String> _backgroundAssetNotifier =
  ValueNotifier<String>('');

  // ====== Public getters ======
  static ValueNotifier<String> get unitNotifier => _unitNotifier;
  static ValueNotifier<ThemeMode> get themeModeNotifier => _themeModeNotifier;
  static ValueNotifier<bool> get showWeightInputNotifier =>
      _showWeightInputNotifier;
  static ValueNotifier<bool> get showStopwatchNotifier =>
      _showStopwatchNotifier;
  static ValueNotifier<String> get backgroundAssetNotifier =>
      _backgroundAssetNotifier;

  static String get currentUnit => _unitNotifier.value;
  static ThemeMode get currentThemeMode => _themeModeNotifier.value;
  static bool get showWeightInput => _showWeightInputNotifier.value;
  static bool get showStopwatch => _showStopwatchNotifier.value;
  static String get currentBackgroundAsset => _backgroundAssetNotifier.value;

  /// 必ず `Hive.initFlutter()` 後に呼び出すこと（main.dart で実施）
  static Future<void> initialize() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<dynamic>(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
    _loadFromStorage();
  }

  // ====== Load from storage ======
  static void _loadFromStorage() {
    final box = _box;
    if (box == null) return;

    // 単位
    final savedUnit = box.get(_unitKey, defaultValue: 'kg') as String;
    _unitNotifier.value = (savedUnit == 'lbs') ? 'lbs' : 'kg';

    // テーマ
    final savedThemeIndex =
    box.get(_themeModeKey, defaultValue: ThemeMode.system.index) as int;
    final safeIndex = (savedThemeIndex >= 0 &&
        savedThemeIndex < ThemeMode.values.length)
        ? savedThemeIndex
        : ThemeMode.system.index;
    _themeModeNotifier.value = ThemeMode.values[safeIndex];

    // 体重入力の表示/非表示
    final savedShowWeight =
    box.get(_showWeightInputKey, defaultValue: true) as bool;
    _showWeightInputNotifier.value = savedShowWeight;

    // ストップウォッチ表示/非表示
    final savedShowStopwatch =
    box.get(_showStopwatchKey, defaultValue: true) as bool;
    _showStopwatchNotifier.value = savedShowStopwatch;

    // 背景アセット
    final savedBg =
    box.get(_backgroundAssetKey, defaultValue: '') as String;
    _backgroundAssetNotifier.value = savedBg;
  }

  // ====== Setters (save & notify) ======
  static Future<void> setUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') {
      throw ArgumentError('unit must be "kg" or "lbs".');
    }
    await _box?.put(_unitKey, unit);
    _unitNotifier.value = unit;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    await _box?.put(_themeModeKey, mode.index);
    _themeModeNotifier.value = mode;
  }

  static Future<void> setShowWeightInput(bool value) async {
    await _box?.put(_showWeightInputKey, value);
    _showWeightInputNotifier.value = value;
  }

  static Future<void> setShowStopwatch(bool value) async {
    await _box?.put(_showStopwatchKey, value);
    _showStopwatchNotifier.value = value;
  }

  static Future<void> setBackgroundAsset(String assetPath) async {
    await _box?.put(_backgroundAssetKey, assetPath);
    _backgroundAssetNotifier.value = assetPath;
  }
}
