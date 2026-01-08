import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import 'package:ttraining_record/settings_manager.dart';

enum CalendarExportStatus {
  success,
  permissionDenied,
  noWritableCalendar,
  cancelled,
  error,
}

class CalendarExportResult {
  final CalendarExportStatus status;
  final String? errorMessage;
  final String? eventId;

  const CalendarExportResult(this.status, {this.errorMessage, this.eventId});
}

class CalendarSelectionResult {
  final CalendarExportStatus status;
  final String? errorMessage;
  final Calendar? calendar;

  const CalendarSelectionResult(this.status, {this.errorMessage, this.calendar});
}

class CalendarExportService {
  CalendarExportService._();

  static final DeviceCalendar _plugin = DeviceCalendar.instance;

  static Future<CalendarExportResult> createEventInCalendar({
    required BuildContext context,
    required String calendarId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String eventTitle,
    required String description,
  }) async {
    try {
      final permissionStatus = await _ensurePermissions();
      if (permissionStatus != CalendarPermissionStatus.granted &&
          permissionStatus != CalendarPermissionStatus.writeOnly) {
        return const CalendarExportResult(CalendarExportStatus.permissionDenied);
      }

      final startDate = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );
      final endDate = DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );

      final location = SettingsManager.trainingLocation?.trim();
      final effectiveLocation =
          (location != null && location.isNotEmpty) ? location : null;

      final eventId = await _plugin.createEvent(
        calendarId: calendarId,
        title: eventTitle,
        startDate: startDate,
        endDate: endDate,
        description: description.isEmpty ? null : description,
        location: effectiveLocation,
      );

      return CalendarExportResult(
        CalendarExportStatus.success,
        eventId: eventId,
      );
    } on DeviceCalendarException catch (e) {
      return CalendarExportResult(
        CalendarExportStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return CalendarExportResult(
        CalendarExportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  static Future<CalendarPermissionStatus> _ensurePermissions() async {
    final currentStatus = await _plugin.hasPermissions();
    if (currentStatus == CalendarPermissionStatus.granted ||
        currentStatus == CalendarPermissionStatus.writeOnly) {
      return currentStatus;
    }
    final newStatus = await _plugin.requestPermissions();
    return newStatus;
  }

  static Future<CalendarSelectionResult> selectCalendarAndStore({
    required BuildContext context,
  }) async {
    final result = await _selectCalendar(context: context);
    if (result.status == CalendarExportStatus.success &&
        result.calendar != null) {
      await SettingsManager.setSelectedCalendar(
        id: result.calendar!.id,
        name: result.calendar!.name,
      );
    }
    return result;
  }

  static Future<CalendarSelectionResult> _selectCalendar({
    required BuildContext context,
  }) async {
    try {
      final permissionStatus = await _ensurePermissions();
      if (permissionStatus != CalendarPermissionStatus.granted &&
          permissionStatus != CalendarPermissionStatus.writeOnly) {
        return const CalendarSelectionResult(
          CalendarExportStatus.permissionDenied,
        );
      }

      final calendars = await _plugin.listCalendars();
      final writableCalendars =
          calendars.where((c) => !c.readOnly).toList(growable: false);

      if (writableCalendars.isEmpty) {
        return const CalendarSelectionResult(
          CalendarExportStatus.noWritableCalendar,
        );
      }

      final selected = await _pickCalendar(
        context: context,
        calendars: writableCalendars,
      );

      if (selected == null) {
        return const CalendarSelectionResult(CalendarExportStatus.cancelled);
      }

      return CalendarSelectionResult(
        CalendarExportStatus.success,
        calendar: selected,
      );
    } on DeviceCalendarException catch (e) {
      return CalendarSelectionResult(
        CalendarExportStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return CalendarSelectionResult(
        CalendarExportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  static Future<CalendarExportResult> deleteEvent({
    required String eventId,
  }) async {
    try {
      final permissionStatus = await _ensurePermissions();
      if (permissionStatus != CalendarPermissionStatus.granted &&
          permissionStatus != CalendarPermissionStatus.writeOnly) {
        return const CalendarExportResult(CalendarExportStatus.permissionDenied);
      }
      await _plugin.deleteEvent(eventId: eventId);
      return const CalendarExportResult(CalendarExportStatus.success);
    } on DeviceCalendarException catch (e) {
      return CalendarExportResult(
        CalendarExportStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return CalendarExportResult(
        CalendarExportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  static Future<Calendar?> _pickCalendar({
    required BuildContext context,
    required List<Calendar> calendars,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    return showModalBottomSheet<Calendar>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Container(
            color: colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    l10n.calendarSelectTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: calendars.length,
                    itemBuilder: (context, index) {
                      final cal = calendars[index];
                      return ListTile(
                        title: Text(cal.name),
                        subtitle: cal.isPrimary
                            ? Text(
                                l10n.calendarPrimaryLabel,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(cal),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
