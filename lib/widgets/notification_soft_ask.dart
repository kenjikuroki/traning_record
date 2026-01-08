import 'package:flutter/material.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import '../services/notification_prefs.dart';
import '../services/notification_service.dart';

class NotificationSoftAsk {
  static Future<bool> shouldShowPrompt() async {
    final TimeOfDay now = TimeOfDay.now();
    final bool quietHours = (now.hour >= 22 || now.hour < 8);
    if (quietHours) return false;
    if (await NotificationPrefs.isOptIn()) return false;
    if (!await NotificationPrefs.canAskAgain()) return false;
    return true;
  }

  static Future<bool> showIfNeeded(BuildContext context) async {
    if (!await shouldShowPrompt()) {
      return false;
    }

    await NotificationPrefs.markAskedNow();

    final AppLocalizations s = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final ColorScheme cs = theme.colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  s.notiSoftAskTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  s.notiSoftAskBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                        },
                        child: Text(s.notiSoftAskLater),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await NotificationPrefs.setOptIn(true);
                          await NotificationService.instance.requestPermissionsIfNeeded();
                          const TimeOfDay t = TimeOfDay(hour: 19, minute: 0);
                          await NotificationPrefs.setAllWeekdays(t, enabled: true);
                          await NotificationService.instance.resetDailyFromPrefs(
                            title: s.notiDailyTitle,
                            randomBody: () {
                              final List<String> list = [
                                s.notiDailyBodyA,
                                s.notiDailyBodyB,
                              ]
                                ..shuffle();
                              return list.first;
                            },
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: Text(s.notiSoftAskEnable),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return true;
  }
}
