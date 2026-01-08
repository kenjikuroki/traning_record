import 'package:flutter/material.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/notification_prefs.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool enabled = false;
  final List<bool> weekdayEnabled = List<bool>.filled(7, true);
  final List<TimeOfDay> weekdayTime =
      List<TimeOfDay>.filled(7, const TimeOfDay(hour: 19, minute: 0));

  @override
  void initState() {
    super.initState();
    () async {
      await NotificationPrefs.migrateSingleDailyToWeekdaysIfNeeded();
      final opt = await NotificationPrefs.isOptIn();
      final enabledList = <bool>[];
      final timeList = <TimeOfDay>[];
      for (int w = 1; w <= 7; w++) {
        enabledList.add(await NotificationPrefs.getWeekdayEnabled(w));
        timeList.add(await NotificationPrefs.getWeekdayTime(w));
      }
      if (!mounted) return;
      setState(() {
        enabled = opt;
        for (int i = 0; i < 7; i++) {
          weekdayEnabled[i] = enabledList[i];
          weekdayTime[i] = timeList[i];
        }
      });
    }();
  }

  String _randomDailyBody(AppLocalizations s) {
    final list = [s.notiDailyBodyA, s.notiDailyBodyB]..shuffle();
    return list.first;
  }

  Future<void> _reschedule(AppLocalizations s) {
    return NotificationService.instance.resetDailyFromPrefs(
      title: s.notiDailyTitle,
      randomBody: () => _randomDailyBody(s),
    );
  }

  String _weekdayLabel(BuildContext context, AppLocalizations s, int weekdayMon1) {
    final locale = Localizations.localeOf(context);
    final localeName = locale.countryCode == null
        ? locale.languageCode
        : '${locale.languageCode}-${locale.countryCode}';
    final base = DateTime.utc(2023, 1, 2 + (weekdayMon1 - 1));
    final formatted = DateFormat.E(localeName).format(base);
    return s.notiSettingsWeeklyLabel(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double _contentOpacity = enabled ? 1.0 : 0.45;

    return Scaffold(
      appBar: AppBar(title: Text(s.notiSettingsTitle)),
      backgroundColor: colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(s.notiSettingsSubtitle),
            value: enabled,
            onChanged: (v) async {
              setState(() => enabled = v);
              await NotificationPrefs.setOptIn(v);
              await NotificationPrefs.markAskedNow();
              if (v) {
                await NotificationService.instance.requestPermissionsIfNeeded();
              }
              await _reschedule(s);
            },
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _contentOpacity,
            duration: kThemeAnimationDuration,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: !enabled
                              ? null
                              : () async {
                                  final ok = await _confirmCopy(
                                    context,
                                    title: s.notiCopyAllTitle,
                                    message: s.notiCopyAllMessage,
                                  );
                                  if (!ok) return;
                                  final t = weekdayTime[0];
                                  await NotificationPrefs.setAllWeekdays(t);
                                  if (!mounted) return;
                                  setState(() {
                                    for (int i = 0; i < 7; i++) {
                                      weekdayTime[i] = t;
                                    }
                                  });
                                  await _reschedule(s);
                                },
                          child: Text(
                            s.notiSettingsAllSame,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: !enabled
                              ? null
                              : () async {
                                  final ok = await _confirmCopy(
                                    context,
                                    title: s.notiCopyWeekdaysTitle,
                                    message: s.notiCopyWeekdaysMessage,
                                  );
                                  if (!ok) return;
                                  final t = weekdayTime[0];
                                  for (int w = 2; w <= 5; w++) {
                                    await NotificationPrefs.setWeekdayTime(w, t);
                                  }
                                  if (!mounted) return;
                                  setState(() {
                                    for (int i = 1; i < 5; i++) {
                                      weekdayTime[i] = t;
                                    }
                                  });
                                  await _reschedule(s);
                                },
                          child: Text(
                            s.notiSettingsCopyWeekdays,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: !enabled
                              ? null
                              : () async {
                                  final ok = await _confirmCopy(
                                    context,
                                    title: s.notiCopyWeekendTitle,
                                    message: s.notiCopyWeekendMessage,
                                  );
                                  if (!ok) return;
                                  final t = weekdayTime[5];
                                  await NotificationPrefs.setWeekdayTime(7, t);
                                  if (!mounted) return;
                                  setState(() {
                                    weekdayTime[6] = t;
                                  });
                                  await _reschedule(s);
                                },
                          child: Text(
                            s.notiSettingsCopyWeekend,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...List.generate(7, (index) {
                    final weekday = index + 1;
                    final on = weekdayEnabled[index];
                    final t = weekdayTime[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _weekdayLabel(context, s, weekday),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(t.format(context)),
                      trailing: Switch(
                        value: on,
                        onChanged: enabled
                            ? (v) async {
                                setState(() => weekdayEnabled[index] = v);
                                await NotificationPrefs.setWeekdayEnabled(weekday, v);
                                await _reschedule(s);
                              }
                            : null,
                      ),
                      onTap: !enabled
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                  context: context, initialTime: t);
                              if (picked != null) {
                                if (!mounted) return;
                                setState(() => weekdayTime[index] = picked);
                                await NotificationPrefs.setWeekdayTime(
                                    weekday, picked);
                                await _reschedule(s);
                              }
                            },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmCopy(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final s = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.notiConfirmNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.notiConfirmYes),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
