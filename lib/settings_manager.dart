// lib/settings_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// アプリ全体の設定を管理するユーティリティ（静的クラス）
/// - 重さ（kg/lbs）: 体重・トレーニング重量に影響
/// - 長さ（km/mile）: 距離・身長・ウエストに影響（身長/ウエストは cm / ft/in に自動切替）
/// - 既存互換: distance 系 API は length にエイリアス
class SettingsManager {
  static const String _boxName = 'settings';

  static Box<dynamic>? _box;

  static bool demoMode = true; // 撮影中は true。本番は false に戻す
  // ===== Keys =====
  static const String _unitKey = 'unit_of_weight'; // 'kg' | 'lbs'
  static const String _lengthUnitKey = 'unit_of_length'; // 'km' | 'mile'
  static const String _distanceUnitKey = 'unit_of_distance'; // 旧距離キー（互換読み書き）
  static const String _themeModeKey =
      'theme_mode'; // 0: system, 1: light, 2: dark
  static const String _appColorThemeKey =
      'app_color_theme'; // 0:mono,1:purple,2:blue,3:green,4:yellow ← 追加
  static const String _backgroundAssetKey = 'background_asset';
  static const String _showStopwatchTimerKey =
      'show_stopwatch_timer'; // true/false
  static const String _showWeightInputKey =
      'show_weight_input'; // 体重入力の表示ON/OFF（互換）
  static const String _aerobicCalorieKey = 'enable_aerobic_calories';
  static const String _personalWeightKey = 'personal.weightKg';
  static const String _showTotalVolumeKey = 'show_total_volume';
  static const String _showSatisfactionKey = 'show_satisfaction';
  static const String _showIntervalTimerKey = 'show_interval_timer';
  static const String _manageBmrKey = 'manage.bmr';
  static const String _showRmKey = 'show_rm';
  static const String _showRirKey = 'show_rir';
  static const String _showFailKey = 'show_fail';

  // ===== Notifiers =====
  // 重さ
  static final ValueNotifier<String> _unitNotifier =
      ValueNotifier<String>('kg'); // 'kg' | 'lbs'

  // 長さ（距離・身長・ウエスト）
  static final ValueNotifier<String> _lengthUnitNotifier =
      ValueNotifier<String>('km'); // 'km' | 'mile'

  // テーマ
  static final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  // カラーテーマ（モノトーン／紫／青／緑／黄）← デフォルトは青
  static final ValueNotifier<int> _appColorThemeIndexNotifier =
      ValueNotifier<int>(2);

  // 背景（使っていない場合は空文字）
  static final ValueNotifier<String> _backgroundAssetNotifier =
      ValueNotifier<String>('');

  // ストップウォッチ/タイマー表示
  static final ValueNotifier<bool> _showStopwatchTimerNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _showTotalVolumeNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _showSatisfactionNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _showIntervalTimerNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _showRmNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _showRirNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _showFailNotifier =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> _manageBmrNotifier =
      ValueNotifier<bool>(false);

  // 体重入力の表示
  static final ValueNotifier<bool> _showWeightInputNotifier =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> _aerobicCalorieNotifier =
      ValueNotifier<bool>(false);

  // パーソナル体重（kg）
  static final ValueNotifier<double?> _personalWeightNotifier =
      ValueNotifier<double?>(null);

  // ===== Initialize =====
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<dynamic>(_boxName);
    } else {
      _box = Hive.box<dynamic>(_boxName);
    }
    await _loadFromStorage();
  }

  // 互換（main.dart が initialize() を呼んでいるため）
  static Future<void> initialize() => init();

  static Future<void> _ensureBox() async {
    if (_box == null) {
      await init();
    }
  }

  static Future<void> _loadFromStorage() async {
    final box = _box;
    if (box == null) return;

    // 重さ
    final String savedWeight =
        (box.get(_unitKey, defaultValue: 'kg') as String?) ?? 'kg';
    _unitNotifier.value = (savedWeight == 'lbs') ? 'lbs' : 'kg';

    // 長さ（まず新キー、なければ旧distanceキーから互換読み）
    final String savedLen = ((box.get(_lengthUnitKey)) ??
        (box.get(_distanceUnitKey)) ??
        'km') as String;
    _lengthUnitNotifier.value = (savedLen == 'mile') ? 'mile' : 'km';

    // テーマ
    final int themeIndex = (box.get(_themeModeKey, defaultValue: 0) as int);
    _themeModeNotifier.value = switch (themeIndex) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // カラーテーマ ← 追加
    final int colorIdx = (box.get(_appColorThemeKey, defaultValue: 2) as int);
    _appColorThemeIndexNotifier.value =
        (colorIdx < 0 || colorIdx > 4) ? 2 : colorIdx;

    // 背景
    _backgroundAssetNotifier.value =
        (box.get(_backgroundAssetKey, defaultValue: '') as String?) ?? '';

    // ストップウォッチ/タイマー
    _showStopwatchTimerNotifier.value =
        (box.get(_showStopwatchTimerKey) as bool?) ?? true;
    _showTotalVolumeNotifier.value =
        (box.get(_showTotalVolumeKey) as bool?) ?? true;
    _showSatisfactionNotifier.value =
        (box.get(_showSatisfactionKey) as bool?) ?? true;
    _showIntervalTimerNotifier.value =
        (box.get(_showIntervalTimerKey) as bool?) ?? true;
    _showRmNotifier.value = (box.get(_showRmKey) as bool?) ?? true;
    _showRirNotifier.value = (box.get(_showRirKey) as bool?) ?? false;
    _showFailNotifier.value = (box.get(_showFailKey) as bool?) ?? false;

    // 体重入力の表示
    _showWeightInputNotifier.value =
        (box.get(_showWeightInputKey) as bool?) ?? true;

    // 有酸素カロリー算出
    _aerobicCalorieNotifier.value =
        (box.get(_aerobicCalorieKey) as bool?) ?? false;

    _manageBmrNotifier.value = (box.get(_manageBmrKey) as bool?) ?? false;

    final storedWeight = box.get(_personalWeightKey);
    double? weightKg;
    if (storedWeight is num) {
      weightKg = storedWeight.toDouble();
    } else if (storedWeight is String) {
      weightKg = double.tryParse(storedWeight);
    }
    _personalWeightNotifier.value = weightKg;
  }

  // ===== Getters / Notifiers =====

  /// 重さ（'kg' / 'lbs'）
  static String get currentUnit => _unitNotifier.value;
  static ValueNotifier<String> get unitNotifier => _unitNotifier;

  /// 長さ（'km' / 'mile'）※距離・身長・ウエストはこの選択に従う
  static String get currentLengthUnit => _lengthUnitNotifier.value;
  static ValueNotifier<String> get lengthUnitNotifier => _lengthUnitNotifier;

  /// 身長・ウエストの単位（長さに追従：'cm' / 'ft/in'）
  static String get currentHeightUnit =>
      (currentLengthUnit == 'km') ? 'cm' : 'ft/in';

  /// 既存互換：距離ユニット参照（中身は currentLengthUnit）
  static String get currentDistanceUnit => currentLengthUnit;

  /// 既存互換：距離ユニット Notifier（中身は _lengthUnitNotifier）
  static ValueNotifier<String> get distanceUnitNotifier => _lengthUnitNotifier;

  /// 既存互換：ウエスト単位（身長と同じ）
  static String get waistUnit => currentHeightUnit;

  /// 既存互換：ウエスト単位の変更通知（UI再描画用）→ 長さユニットの Notifier を流用
  static ValueListenable<String> get waistUnitNotifier => _lengthUnitNotifier;

  /// 既存互換：ウエストが inch 表示か？
  static bool get isWaistInch => currentHeightUnit != 'cm';

  /// 既存互換：ウエスト(cm) → 表示単位へ変換（cm or inch）
  static double waistCmToDisplay(double cm) {
    return isWaistInch ? (cm / 2.54) : cm;
  }

  /// メートル法かどうか（長さに基づく）
  static bool get isMetric => (currentLengthUnit == 'km');

  /// テーマ
  static ThemeMode get currentThemeMode => _themeModeNotifier.value;
  static ValueNotifier<ThemeMode> get themeModeNotifier => _themeModeNotifier;

  /// カラーテーマ（0:mono,1:purple,2:blue,3:green,4:yellow）← 追加
  static int get currentAppColorThemeIndex => _appColorThemeIndexNotifier.value;
  static ValueNotifier<int> get appColorThemeIndexNotifier =>
      _appColorThemeIndexNotifier;

  /// 背景
  static String get currentBackgroundAsset => _backgroundAssetNotifier.value;
  static ValueNotifier<String> get backgroundAssetNotifier =>
      _backgroundAssetNotifier;

  /// ストップウォッチ/タイマー表示
  static bool get showStopwatchTimer => _showStopwatchTimerNotifier.value;
  static ValueNotifier<bool> get showStopwatchTimerNotifier =>
      _showStopwatchTimerNotifier;

  static bool get showTotalVolume => _showTotalVolumeNotifier.value;
  static ValueNotifier<bool> get showTotalVolumeNotifier =>
      _showTotalVolumeNotifier;

  static bool get showSatisfaction => _showSatisfactionNotifier.value;
  static ValueNotifier<bool> get showSatisfactionNotifier =>
      _showSatisfactionNotifier;

  static bool get showIntervalTimer => _showIntervalTimerNotifier.value;
  static ValueNotifier<bool> get showIntervalTimerNotifier =>
      _showIntervalTimerNotifier;

  static bool get showRM => _showRmNotifier.value;
  static ValueNotifier<bool> get showRmNotifier => _showRmNotifier;

  static bool get showRIR => _showRirNotifier.value;
  static ValueNotifier<bool> get showRirNotifier => _showRirNotifier;

  static bool get showFail => _showFailNotifier.value;
  static ValueNotifier<bool> get showFailNotifier => _showFailNotifier;

  /// 体重入力の表示
  static bool get showWeightInput => _showWeightInputNotifier.value;
  static ValueNotifier<bool> get showWeightInputNotifier =>
      _showWeightInputNotifier;

  /// 有酸素運動のカロリー算出
  static bool get enableAerobicCalories => _aerobicCalorieNotifier.value;
  static ValueNotifier<bool> get aerobicCalorieNotifier =>
      _aerobicCalorieNotifier;

  static bool get manageBmr => _manageBmrNotifier.value;
  static ValueNotifier<bool> get manageBmrNotifier => _manageBmrNotifier;

  /// パーソナル体重（kg）
  static double? get personalWeightKg => _personalWeightNotifier.value;
  static ValueNotifier<double?> get personalWeightNotifier =>
      _personalWeightNotifier;

  // 互換（旧API名）
  static bool get showStopwatch => showStopwatchTimer;
  static ValueNotifier<bool> get showStopwatchNotifier =>
      _showStopwatchTimerNotifier;

  // ===== Setters =====

  /// 重さの単位を保存（'kg' / 'lbs'）
  static Future<void> setUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') {
      throw ArgumentError('unit must be "kg" or "lbs".');
    }
    await _ensureBox();
    await _box?.put(_unitKey, unit);
    _unitNotifier.value = unit;
  }

  /// 長さの単位を保存（'km' / 'mile'）
  /// 距離・身長・ウエストがこの設定に追従する
  static Future<void> setLengthUnit(String unit) async {
    if (unit != 'km' && unit != 'mile') {
      throw ArgumentError('unit must be "km" or "mile".');
    }
    await _ensureBox();
    await _box?.put(_lengthUnitKey, unit);
    // 互換: 旧distanceキーにも書いておく
    await _box?.put(_distanceUnitKey, unit);
    _lengthUnitNotifier.value = unit;
  }

  /// 既存互換：距離の単位を保存（実体は setLengthUnit）
  static Future<void> setDistanceUnit(String unit) => setLengthUnit(unit);

  /// テーマの保存
  static Future<void> setThemeMode(ThemeMode mode) async {
    await _ensureBox();
    final int idx = switch (mode) {
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
      _ => 0,
    };
    await _box?.put(_themeModeKey, idx);
    _themeModeNotifier.value = mode;
  }

  // カラーテーマの保存 ← 追加
  static Future<void> setAppColorThemeIndex(int idx) async {
    final int clamped = idx.clamp(0, 4);
    await _ensureBox();
    await _box?.put(_appColorThemeKey, clamped);
    _appColorThemeIndexNotifier.value = clamped;
  }

  /// 背景アセットの保存
  static Future<void> setBackgroundAsset(String asset) async {
    await _ensureBox();
    await _box?.put(_backgroundAssetKey, asset);
    _backgroundAssetNotifier.value = asset;
  }

  /// ストップウォッチ/タイマー表示設定
  static Future<void> setShowStopwatchTimer(bool show) async {
    await _ensureBox();
    await _box?.put(_showStopwatchTimerKey, show);
    _showStopwatchTimerNotifier.value = show;
  }

  static Future<void> setShowTotalVolume(bool show) async {
    await _ensureBox();
    await _box?.put(_showTotalVolumeKey, show);
    _showTotalVolumeNotifier.value = show;
  }

  static Future<void> setShowSatisfaction(bool show) async {
    await _ensureBox();
    await _box?.put(_showSatisfactionKey, show);
    _showSatisfactionNotifier.value = show;
  }

  static Future<void> setShowIntervalTimer(bool show) async {
    await _ensureBox();
    await _box?.put(_showIntervalTimerKey, show);
    _showIntervalTimerNotifier.value = show;
  }

  static Future<void> setShowRM(bool show) async {
    await _ensureBox();
    await _box?.put(_showRmKey, show);
    _showRmNotifier.value = show;
  }

  static Future<void> setShowRIR(bool show) async {
    await _ensureBox();
    await _box?.put(_showRirKey, show);
    _showRirNotifier.value = show;
  }

  static Future<void> setShowFail(bool show) async {
    await _ensureBox();
    await _box?.put(_showFailKey, show);
    _showFailNotifier.value = show;
  }

  /// 体重入力の表示設定
  static Future<void> setShowWeightInput(bool show) async {
    await _ensureBox();
    await _box?.put(_showWeightInputKey, show);
    _showWeightInputNotifier.value = show;
  }

  static Future<void> setEnableAerobicCalories(bool enable) async {
    await _ensureBox();
    await _box?.put(_aerobicCalorieKey, enable);
    _aerobicCalorieNotifier.value = enable;
  }

  static Future<void> setManageBmr(bool value) async {
    await _ensureBox();
    await _box?.put(_manageBmrKey, value);
    _manageBmrNotifier.value = value;
  }

  static Future<void> setPersonalWeightKg(double? kg) async {
    await _ensureBox();
    if (kg == null) {
      await _box?.delete(_personalWeightKey);
    } else {
      await _box?.put(_personalWeightKey, kg);
    }
    _personalWeightNotifier.value = kg;
  }

  // 互換（旧API名）
  static Future<void> setShowStopwatch(bool show) =>
      setShowStopwatchTimer(show);
}
