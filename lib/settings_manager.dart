// lib/settings_manager.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsManager {
  static const String _boxName = 'app_settings';
  static const String _unitKey = 'unit_of_weight';

  static final ValueNotifier<String> unitNotifier = ValueNotifier<String>('kg');

  static Future<void> initialize() async {
    // main.dartでHiveが初期化されていることを前提とする
    await Hive.openBox(_boxName);
    _loadUnit();
  }

  static void _loadUnit() {
    final box = Hive.box(_boxName);
    final savedUnit = box.get(_unitKey, defaultValue: 'kg') as String;
    unitNotifier.value = savedUnit;
  }

  static Future<void> setUnit(String unit) async {
    // ★修正: 単位を 'kg' または 'lbs' に変更
    if (unit != 'kg' && unit != 'lbs') {
      throw ArgumentError('単位は "kg" または "lbs" のみ設定可能です。');
    }
    final box = Hive.box(_boxName);
    await box.put(_unitKey, unit);
    unitNotifier.value = unit;
  }

  static String get currentUnit => unitNotifier.value;
}