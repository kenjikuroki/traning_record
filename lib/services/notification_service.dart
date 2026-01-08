import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_prefs.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int idDailyBase = 1000;
  static const int idDailySingle = idDailyBase;
  static const int idInactive3 = 2003;
  static const int idInactive7 = 2007;
  static const AndroidNotificationChannel _dailyChannel =
      AndroidNotificationChannel(
    'trainingrecord_daily',
    'Daily Reminders',
    description: 'TrainingRecord daily reminders',
    importance: Importance.high,
  );

  Future<void> init() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_dailyChannel);

    tz.initializeTimeZones();
    final String localName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));
  }

  Future<void> requestPermissionsIfNeeded() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannel.id,
          _dailyChannel.name,
          channelDescription: _dailyChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _atLocal(TimeOfDay time, {int addDays = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    final base = now.add(Duration(days: addDays));
    return tz.TZDateTime(
      tz.local, base.year, base.month, base.day, time.hour, time.minute,
    );
  }

  Future<void> showTest({required String title, required String body}) async {
    await _plugin.show(0, title, body, _details);
  }

  Future<void> scheduleDaily({
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      idDailySingle, title, body, _nextInstance(time), _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily',
    );
  }

  Future<void> scheduleDailyWeekday({
    required int weekdayMon1,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    int deltaDays = weekdayMon1 - (now.weekday == 7 ? 0 : now.weekday);
    deltaDays %= 7;
    if (deltaDays < 0) deltaDays += 7;

    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    ).add(Duration(days: deltaDays));

    if (first.isBefore(now)) {
      first = first.add(const Duration(days: 7));
    }

    await _plugin.zonedSchedule(
      idDailyBase + weekdayMon1,
      title,
      body,
      first,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'daily_w$weekdayMon1',
    );
  }

  Future<void> cancelDailyWeekday(int weekdayMon1) =>
      _plugin.cancel(idDailyBase + weekdayMon1);

  Future<void> resetDailyFromPrefs({
    required String title,
    required String Function() randomBody,
  }) async {
    for (int w = 1; w <= 7; w++) {
      await cancelDailyWeekday(w);
    }

    await NotificationPrefs.migrateSingleDailyToWeekdaysIfNeeded();

    if (!await NotificationPrefs.isOptIn()) {
      return;
    }

    for (int w = 1; w <= 7; w++) {
      final enabled = await NotificationPrefs.getWeekdayEnabled(w);
      if (!enabled) continue;
      final t = await NotificationPrefs.getWeekdayTime(w);
      await scheduleDailyWeekday(
        weekdayMon1: w,
        time: t,
        title: title,
        body: randomBody(),
      );
    }
  }

  Future<void> scheduleInactiveOnce({
    required int id,
    required int days,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id, title, body, _atLocal(time, addDays: days), _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: 'inactive_$days',
    );
  }

  Future<void> resetInactiveTimersLocalized({
    required TimeOfDay time,
    required String title3,
    required String body3,
    required String title7,
    required String body7,
  }) async {
    await _plugin.cancel(idInactive3);
    await _plugin.cancel(idInactive7);

    await scheduleInactiveOnce(
      id: idInactive3, days: 3, time: time, title: title3, body: body3,
    );
    await scheduleInactiveOnce(
      id: idInactive7, days: 7, time: time, title: title7, body: body7,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
