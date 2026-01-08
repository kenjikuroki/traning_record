import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

/// 種類・ステータス別の自動表示トグル種別。
enum AwardAutoShowTarget { first, day, pr }

const String _awardKeyPrefix = 'awards-';
const String _prDaysKey = 'prDays';
const String _snapEnabledKey = 'awards.snap.enabled';

String _buildAwardKey(DateTime date) => '$_awardKeyPrefix${_formatDateKey(date)}';

String _formatDateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return DateFormat('yyyy-MM-dd').format(normalized);
}

List<Map<String, dynamic>> _readAwardEntries(
  Box<dynamic> settingsBox,
  String key,
) {
  final dynamic raw = settingsBox.get(key);
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
  if (raw is Map) {
    return [Map<String, dynamic>.from(raw)];
  }
  return <Map<String, dynamic>>[];
}

Set<String> _readPrDaySet(Box<dynamic> settingsBox) {
  final dynamic raw = settingsBox.get(_prDaysKey);
  if (raw is Set) {
    return raw.whereType<String>().toSet();
  }
  if (raw is List) {
    return raw.whereType<String>().toSet();
  }
  return <String>{};
}

String _autoShowKey(AwardAutoShowTarget target) {
  switch (target) {
    case AwardAutoShowTarget.first:
      return 'awards.autoShow.first';
    case AwardAutoShowTarget.day:
      return 'awards.autoShow.day';
    case AwardAutoShowTarget.pr:
      return 'awards.autoShow.pr';
  }
}

Future<void> saveAwardMeta({
  required Box<dynamic> settingsBox,
  required DateTime date,
  required Map<String, dynamic> metadata,
}) async {
  final key = _buildAwardKey(date);
  final entries = _readAwardEntries(settingsBox, key);
  final normalized = Map<String, dynamic>.from(metadata);
  normalized.putIfAbsent('date', () => _formatDateKey(date));
  final updated = [...entries, normalized];
  await settingsBox.put(key, updated);
}

List<Map<String, dynamic>> listAwards({
  required Box<dynamic> settingsBox,
  required DateTime date,
}) {
  final key = _buildAwardKey(date);
  return _readAwardEntries(settingsBox, key);
}

bool hasAward({
  required Box<dynamic> settingsBox,
  required String type,
  int? dayCount,
}) {
  for (final dynamic key in settingsBox.keys) {
    if (key is! String || !key.startsWith(_awardKeyPrefix)) {
      continue;
    }
    for (final entry in _readAwardEntries(settingsBox, key)) {
      if (entry['type'] != type) {
        continue;
      }
      if (dayCount == null || entry['dayCount'] == dayCount) {
        return true;
      }
    }
  }
  return false;
}

Future<void> markPrDay({
  required Box<dynamic> settingsBox,
  required DateTime date,
}) async {
  final prDays = _readPrDaySet(settingsBox);
  final key = _formatDateKey(date);
  if (prDays.add(key)) {
    final sorted = prDays.toList()..sort();
    await settingsBox.put(_prDaysKey, sorted);
  }
}

bool isPrDay({
  required Box<dynamic> settingsBox,
  required DateTime date,
}) {
  final prDays = _readPrDaySet(settingsBox);
  return prDays.contains(_formatDateKey(date));
}

bool isAwardAutoShowEnabled({
  required Box<dynamic> settingsBox,
  required AwardAutoShowTarget target,
}) {
  final dynamic raw = settingsBox.get(_autoShowKey(target));
  if (raw is bool) {
    return raw;
  }
  return true;
}

Future<void> setAwardAutoShowEnabled({
  required Box<dynamic> settingsBox,
  required AwardAutoShowTarget target,
  required bool enabled,
}) async {
  await settingsBox.put(_autoShowKey(target), enabled);
}

bool isAwardSnapEnabled({
  required Box<dynamic> settingsBox,
}) {
  final dynamic raw = settingsBox.get(_snapEnabledKey);
  if (raw is bool) {
    return raw;
  }
  return true;
}

Future<void> setAwardSnapEnabled({
  required Box<dynamic> settingsBox,
  required bool enabled,
}) async {
  await settingsBox.put(_snapEnabledKey, enabled);
}

