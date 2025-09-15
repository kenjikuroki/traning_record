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

  static bool demoMode = true; // 撮影用に広告非表示

  // ===== Keys =====
  static const String _unitKey = 'unit_of_weight';            // 'kg' | 'lbs'
  static const String _lengthUnitKey = 'unit_of_length';      // 'km' | 'mile'
  static const String _distanceUnitKey = 'unit_of_distance';  // 旧距離キー（互換読み書き）
  static const String _themeModeKey = 'theme_mode';           // 0: system, 1: light, 2: dark
  static const String _backgroundAssetKey = 'background_asset';
  static const String _showStopwatchTimerKey = 'show_stopwatch_timer'; // true/false
  static const String _showWeightInputKey = 'show_weight_input';       // 体重入力の表示ON/OFF（互換）

  // ★ 追加：機能トグル（有酸素カロリー算出）
  static const String _featureAeroKcalEnabledKey = 'feature.aeroKcalEnabled';

  // ★ 追加：身長の保存キー（既存の SettingsScreen と同一キー）
  static const String _personalHeightCmKey = 'personal.heightCm';

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

  // 背景（使っていない場合は空文字）
  static final ValueNotifier<String> _backgroundAssetNotifier =
  ValueNotifier<String>('');

  // ストップウォッチ/タイマー表示
  static final ValueNotifier<bool> _showStopwatchTimerNotifier =
  ValueNotifier<bool>(true);

  // 体重入力の表示
  static final ValueNotifier<bool> _showWeightInputNotifier =
  ValueNotifier<bool>(true);

// ★ 追加：有酸素運動のカロリー算出トグル
  static final ValueNotifier<bool> _aeroKcalEnabledNotifier =
  ValueNotifier<bool>(false); // 既定OFF
// （ここでは代入しない。読み込みは _loadFromStorage() に移動）


  // ★ 追加：有酸素運動のカロリー算出（設定トグル）
  static bool get aerobicCalorieEstimationEnabled =>
  _aeroKcalEnabledNotifier.value;
  static ValueNotifier<bool> get aerobicCalorieEstimationEnabledNotifier =>
  _aeroKcalEnabledNotifier;

  // ★ 追加：身長(cm)の現在値（設定からそのまま読む／存在しなければ null）
  static double? get heightCmSetting {
  final v = _box?.get(_personalHeightCmKey);
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
  }

  // ★ 追加：身長(cm)から標準体重(kg)を算出（BMI=22）
  static double? standardWeightKgFromHeightCm(double? heightCm) {
  if (heightCm == null || heightCm <= 0) return null;
  final m = heightCm / 100.0;
  return 22.0 * m * m;
  }

  // ★ 追加：現在の重量単位に応じて kg に正規化
  static double toKg(double value) {
  return (currentUnit == 'lbs') ? (value * 0.45359237) : value;
  }

  // ★ 追加：有酸素運動のカロリー算出トグル設定
  static Future<void> setAerobicCalorieEstimationEnabled(bool enabled) async {
  await _ensureBox();
  await _box?.put(_featureAeroKcalEnabledKey, enabled);
  _aeroKcalEnabledNotifier.value = enabled;
  }

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
    final String savedLen =
    ((box.get(_lengthUnitKey)) ?? (box.get(_distanceUnitKey)) ?? 'km')
    as String;
    _lengthUnitNotifier.value = (savedLen == 'mile') ? 'mile' : 'km';

    // テーマ
    final int themeIndex = (box.get(_themeModeKey, defaultValue: 0) as int);
    _themeModeNotifier.value = switch (themeIndex) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // 背景
    _backgroundAssetNotifier.value =
        (box.get(_backgroundAssetKey, defaultValue: '') as String?) ?? '';

    // ストップウォッチ/タイマー
    _showStopwatchTimerNotifier.value =
        (box.get(_showStopwatchTimerKey) as bool?) ?? true;

    // 体重入力の表示
    _showWeightInputNotifier.value =
        (box.get(_showWeightInputKey) as bool?) ?? true;

    // ★ 追加：有酸素カロリー算出トグルを読み込み
    _aeroKcalEnabledNotifier.value =
        (box.get(_featureAeroKcalEnabledKey) as bool?) ?? false;
  }

  // ===== Getters / Notifiers =====

  /// 有酸素カロリー算出トグル（読み取り）
  static bool get aerobicCalorieEstimationEnabled =>
      _aeroKcalEnabledNotifier.value;
  static ValueNotifier<bool> get aerobicCalorieEstimationEnabledNotifier =>
      _aeroKcalEnabledNotifier;

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

  /// 背景
  static String get currentBackgroundAsset => _backgroundAssetNotifier.value;
  static ValueNotifier<String> get backgroundAssetNotifier =>
      _backgroundAssetNotifier;

  /// ストップウォッチ/タイマー表示
  static bool get showStopwatchTimer => _showStopwatchTimerNotifier.value;
  static ValueNotifier<bool> get showStopwatchTimerNotifier =>
      _showStopwatchTimerNotifier;

  /// 体重入力の表示
  static bool get showWeightInput => _showWeightInputNotifier.value;
  static ValueNotifier<bool> get showWeightInputNotifier =>
      _showWeightInputNotifier;

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

  /// 体重入力の表示設定
  static Future<void> setShowWeightInput(bool show) async {
    await _ensureBox();
    await _box?.put(_showWeightInputKey, show);
    _showWeightInputNotifier.value = show;
  }

  // 互換（旧API名）
  static Future<void> setShowStopwatch(bool show) =>
      setShowStopwatchTimer(show);

  /// 有酸素カロリー算出トグルの保存
  static Future<void> setAerobicCalorieEstimationEnabled(bool enabled) async {
    await _ensureBox();
    await _box?.put(_featureAeroKcalEnabledKey, enabled);
    _aeroKcalEnabledNotifier.value = enabled;
  }

}


