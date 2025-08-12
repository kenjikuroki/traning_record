import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// アプリ内の設定をまとめて管理するシンプルなマネージャ。
/// - Hive Box: 'app_settings'
/// - 保存キー:
///   - unit_of_weight: 'kg' | 'lbs'
///   - theme_mode: ThemeMode.index
///   - show_weight_input: bool
class SettingsManager {
  static const String _boxName = 'app_settings';

  static const String _unitKey = 'unit_of_weight';
  static const String _themeModeKey = 'theme_mode';
  static const String _showWeightInputKey = 'show_weight_input';

  static Box<dynamic>? _box;

  /// 重量単位（'kg' / 'lbs'）
  static final ValueNotifier<String> _unitNotifier =
      ValueNotifier<String>('kg');

  /// テーマモード（system / light / dark）
  static final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// 体重入力カードの表示ON/OFF
  static final ValueNotifier<bool> _showWeightInputNotifier =
      ValueNotifier<bool>(true);

  // ======= public getters =======
  static ValueNotifier<String> get unitNotifier => _unitNotifier;
  static ValueNotifier<ThemeMode> get themeModeNotifier => _themeModeNotifier;
  static ValueNotifier<bool> get showWeightInputNotifier =>
      _showWeightInputNotifier;

  static String get currentUnit => _unitNotifier.value;
  static ThemeMode get currentThemeMode => _themeModeNotifier.value;
  static bool get showWeightInput => _showWeightInputNotifier.value;

  /// 必ず `Hive.initFlutter()` 後に呼び出すこと（main.dart で実施済み）
  static Future<void> initialize() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
    _loadFromStorage();
  }

  static void _loadFromStorage() {
    // 単位
    final savedUnit = _box!.get(_unitKey, defaultValue: 'kg') as String;
    _unitNotifier.value = (savedUnit == 'lbs') ? 'lbs' : 'kg';

    // テーマ
    final savedThemeIndex =
        _box!.get(_themeModeKey, defaultValue: ThemeMode.system.index) as int;
    _themeModeNotifier.value = ThemeMode.values[savedThemeIndex];

    // 体重入力の表示/非表示
    final savedShowWeight =
        _box!.get(_showWeightInputKey, defaultValue: true) as bool;
    _showWeightInputNotifier.value = savedShowWeight;
  }

  /// 単位を保存して通知
  static Future<void> setUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') {
      throw ArgumentError('unit must be "kg" or "lbs".');
    }
    await _box?.put(_unitKey, unit);
    _unitNotifier.value = unit;
  }

  /// テーマモードを保存して通知
  static Future<void> setThemeMode(ThemeMode mode) async {
    await _box?.put(_themeModeKey, mode.index);
    _themeModeNotifier.value = mode;
  }

  /// 体重入力の表示/非表示を保存して通知
  static Future<void> setShowWeightInput(bool value) async {
    await _box?.put(_showWeightInputKey, value);
    _showWeightInputNotifier.value = value;
  }
}
