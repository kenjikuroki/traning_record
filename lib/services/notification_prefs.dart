import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefs {
  static const _kOptIn = 'noti_opt_in';
  static const _kAskedOnce = 'noti_asked_once';
  static const _kLastAskedAt = 'noti_last_asked_at';
  static const _kCoolDownDays = 7;

  static const _kDailyHour = 'noti_daily_hour';
  static const _kDailyMinute = 'noti_daily_minute';
  static const _kDailyEnabledPrefix = 'noti_daily_enabled_';
  static const _kDailyHourPrefix = 'noti_daily_hour_';
  static const _kDailyMinutePrefix = 'noti_daily_min_';
  static const List<String> _wd = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<bool> isOptIn() async =>
      (await _prefs()).getBool(_kOptIn) ?? false;

  static Future<void> setOptIn(bool v) async {
    final p = await _prefs();
    await p.setBool(_kOptIn, v);
  }

  static Future<void> markAskedNow() async {
    final p = await _prefs();
    await p.setBool(_kAskedOnce, true);
    await p.setInt(_kLastAskedAt, DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  static Future<bool> canAskAgain() async {
    final p = await _prefs();
    final last = p.getInt(_kLastAskedAt);
    if (last == null) return true;
    final next = DateTime.fromMillisecondsSinceEpoch(last * 1000)
        .add(const Duration(days: _kCoolDownDays));
    return DateTime.now().isAfter(next);
  }

  static Future<void> migrateSingleDailyToWeekdaysIfNeeded() async {
    final p = await _prefs();
    var hasAny = false;
    for (final s in _wd) {
      if (p.containsKey('$_kDailyEnabledPrefix$s')) {
        hasAny = true;
        break;
      }
    }
    if (hasAny) return;

    final h = p.getInt(_kDailyHour) ?? 19;
    final m = p.getInt(_kDailyMinute) ?? 0;
    for (final s in _wd) {
      await p.setBool('$_kDailyEnabledPrefix$s', true);
      await p.setInt('$_kDailyHourPrefix$s', h);
      await p.setInt('$_kDailyMinutePrefix$s', m);
    }
  }

  static Future<bool> getWeekdayEnabled(int weekdayMon1) async {
    final p = await _prefs();
    final sfx = _wd[weekdayMon1 - 1];
    return p.getBool('$_kDailyEnabledPrefix$sfx') ?? true;
  }

  static Future<void> setWeekdayEnabled(int weekdayMon1, bool enabled) async {
    final p = await _prefs();
    final sfx = _wd[weekdayMon1 - 1];
    await p.setBool('$_kDailyEnabledPrefix$sfx', enabled);
  }

  static Future<TimeOfDay> getWeekdayTime(int weekdayMon1) async {
    final p = await _prefs();
    final sfx = _wd[weekdayMon1 - 1];
    final h = p.getInt('$_kDailyHourPrefix$sfx') ?? 19;
    final m = p.getInt('$_kDailyMinutePrefix$sfx') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  static Future<void> setWeekdayTime(int weekdayMon1, TimeOfDay t) async {
    final p = await _prefs();
    final sfx = _wd[weekdayMon1 - 1];
    await p.setInt('$_kDailyHourPrefix$sfx', t.hour);
    await p.setInt('$_kDailyMinutePrefix$sfx', t.minute);
  }

  static Future<void> setAllWeekdays(TimeOfDay t, {bool? enabled}) async {
    final p = await _prefs();
    for (var i = 0; i < 7; i++) {
      final sfx = _wd[i];
      await p.setInt('$_kDailyHourPrefix$sfx', t.hour);
      await p.setInt('$_kDailyMinutePrefix$sfx', t.minute);
      if (enabled != null) {
        await p.setBool('$_kDailyEnabledPrefix$sfx', enabled);
      }
    }
  }
}
