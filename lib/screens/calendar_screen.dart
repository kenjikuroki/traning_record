// lib/screens/calendar_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../widgets/ad_banner.dart';
import '../settings_manager.dart';
import 'record_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';
import '../widgets/coach_bubble.dart';
import '../routes/slide_up_route.dart';
import '../widgets/centered_constrained.dart';
import '../widgets/gradient_fab.dart';
import '../widgets/big_earning_ad.dart';
import '../theme/app_theme.dart' as T; // ← 追加：エイリアス T で

String _fmtWaist(double cm, AppLocalizations l10n) {
  final v = SettingsManager.waistCmToDisplay(cm).toStringAsFixed(1);
  final u = SettingsManager.isWaistInch ? l10n.unitIn : l10n.unitCm;
  return '$v $u';
}

String _fmtWaistRange(double minCm, double maxCm, AppLocalizations l10n) {
  final a = SettingsManager.waistCmToDisplay(minCm).toStringAsFixed(1);
  final b = SettingsManager.waistCmToDisplay(maxCm).toStringAsFixed(1);
  final u = SettingsManager.isWaistInch ? l10n.unitIn : l10n.unitCm;
  return '$a〜$b $u';
}

// ignore_for_file: library_private_types_in_public_api

class CalendarScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;
  final DateTime selectedDate;

  const CalendarScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
    required this.selectedDate,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

// 日付のラベルを l10n で作る（context 必須）
String _dayRecordLabel(BuildContext context, DateTime d) {
  final l10n = AppLocalizations.of(context)!;
  return l10n.results(_formatResultsDate(context, d));
}

// ロケールに合わせた簡易的な日付文字列（intl 不要）
// ja: "M月d日"、その他: "yyyy/MM/dd"
String _formatResultsDate(BuildContext context, DateTime d) {
  final lang = Localizations.localeOf(context).languageCode.toLowerCase();
  if (lang == 'ja') {
    return '${d.month}月${d.day}日';
  }
  // es / id / en などは共通表記でOK
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}

class _CalendarScreenState extends State<CalendarScreen> {

  final GlobalKey _kCalendarCard = GlobalKey();
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // 写真有無キャッシュ（key = yyyy-MM-dd）
  final Map<String, bool> _photoCache = {};

  // --- 部位→色マップ ---
  static const Map<String, Color> _partColors = {
    '有酸素運動': Colors.purple,
    '腕': Colors.blue,
    '胸': Colors.red,
    '背中': Colors.teal,
    '肩': Colors.amber,
    '足': Colors.green,
    '全身': Colors.orange,
    'その他１': Colors.grey,
    'その他２': Colors.grey,
    'その他３': Colors.grey,
  };

  Color _colorForPart(String part, ColorScheme cs) {
    final c = _partColors[part];
    return (c ?? cs.primary).withOpacity(0.9);
  }

  @override
  void initState() {
    super.initState();

    _focusedDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );

    // CoachBubble（「日付をタップ」のみ）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = widget.settingsBox.get('hint_seen_calendar') as bool? ?? false;
      if (seen) return;

      final l10n = AppLocalizations.of(context)!;
      await CoachBubbleController.showSequence(
        context: context,
        anchors: [_kCalendarCard],
        messages: [l10n.hintCalendarTapDate],
        semanticsPrefix: l10n.coachBubbleSemantic,
      );

      await widget.settingsBox.put('hint_seen_calendar', true);
    });

  }

  bool _isPastDate(DateTime d) {
    final DateTime t = DateTime.now();
    final DateTime a = DateTime(d.year, d.month, d.day);
    final DateTime b = DateTime(t.year, t.month, t.day);
    return a.isBefore(b);
  }

  Widget _satisfactionLine(AppLocalizations l10n, int value, ColorScheme cs) {
    IconData icon;
    switch (value) {
      case 0:
        icon = Icons.sentiment_very_dissatisfied;
        break;
      case 1:
        icon = Icons.sentiment_neutral;
        break;
      default:
        icon = Icons.sentiment_very_satisfied;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${l10n.satisfaction}：',
          style: TextStyle(color: cs.onSurface, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainer, // record_screen と同じ基調
            border: Border.all(
              color: cs.onSurfaceVariant.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ---------- Helpers ----------
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasAnyTrainingData(DailyRecord r) {
    for (final entry in r.menus.entries) {
      for (final m in entry.value) {
        final len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
        for (var i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final p = m.reps[i].toString().trim();
          if (w.isNotEmpty || p.isNotEmpty) return true;
        }
        if ((m.distance?.trim().isNotEmpty ?? false) || (m.duration?.trim().isNotEmpty ?? false)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAnyData(DailyRecord? r) {
    if (r == null) return false;
    if (r.weight != null) return true;
    if (r.bodyFatPercent != null) return true;
    if (r.waistCm != null) return true;
    if (r.menus.isEmpty) return false;
    return _hasAnyTrainingData(r);
  }

  String _translatePartToLocale(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
      case '有酸素運動':
        return l10n.aerobicExercise;
      case '腕':
        return l10n.arm;
      case '胸':
        return l10n.chest;
      case '背中':
        return l10n.back;
      case '肩':
        return l10n.shoulder;
      case '足':
        return l10n.leg;
      case '全身':
        return l10n.fullBody;
      case 'その他１':
        return l10n.other1;
      case 'その他２':
        return l10n.other2;
      case 'その他３':
        return l10n.other3;
      default:
        return part;
    }
  }

  // 「5.3」→「5km300m」
  // 「5.3」→ 「5km300m」 または 「3mi  720yd」
  String _formatDistance(String? raw, AppLocalizations l10n) {
    if (raw == null) return '-';
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return '-';
    final dKm = double.tryParse(normalized);
    if (dKm == null || dKm <= 0) return '-';

    final useImperial =
        (SettingsManager.currentLengthUnit == 'mi' || SettingsManager.currentLengthUnit == 'mile') ||
        SettingsManager.isWaistInch;

    if (useImperial) {
      final miles = dKm / 1.609344;
      final totalYd = miles * 1760.0;
      final mi = totalYd ~/ 1760;
      final yd = (totalYd - mi * 1760).round();
      if (mi == 0 && yd == 0) return '-';
      if (mi == 0) return '${yd} yd';
      if (yd == 0) return '${mi} mi';
      return '${mi} mi ${yd} yd';
    } else {
      final km = dKm.floor();
      final m = ((dKm - km) * 1000).round();
      if (km == 0 && m == 0) return '-';
      if (km == 0) return '${m}${l10n.m}';
      if (m == 0) return '${km}${l10n.km}';
      return '${km}${l10n.km}${m}${l10n.m}';
    }
  }

  String _formatDurationHM(BuildContext context, String? raw, AppLocalizations l10n) {
    if (raw == null) return '-';
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return '-';
    final parts = normalized.split(':');
    int hour = 0;
    int min = 0;
    int sec = 0;
    if (parts.length >= 3) {
      hour = int.tryParse(parts[0]) ?? 0;
      min = int.tryParse(parts[1]) ?? 0;
      sec = int.tryParse(parts[2]) ?? 0;
    } else if (parts.length == 2) {
      hour = int.tryParse(parts[0]) ?? 0;
      min = int.tryParse(parts[1]) ?? 0;
    } else if (parts.length == 1) {
      if (normalized.contains(':')) {
        min = int.tryParse(parts[0]) ?? 0;
      } else {
        final totalMinutes = double.tryParse(normalized) ?? 0;
        hour = (totalMinutes ~/ 60).toInt();
        min = (totalMinutes % 60).round();
      }
    }

    if (hour == 0 && min == 0 && sec == 0) return '-';

    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    final buffer = StringBuffer();
    if (hour > 0) {
      buffer.write(isJa ? '${hour}時間' : '${hour}h');
    }
    if (min > 0) {
      buffer.write('${min}${l10n.min}');
    }
    if (hour == 0 && min == 0 && sec > 0) {
      buffer.write('${sec}${l10n.sec}');
    }
    final result = buffer.toString();
    return result.isEmpty ? '-' : result;
  }

  bool _hasPositiveDistanceValue(String? raw) {
    if (raw == null) return false;
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return false;
    final value = double.tryParse(normalized);
    return value != null && value > 0;
  }

  bool _hasPositiveDurationValue(String? raw) {
    if (raw == null) return false;
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return false;
    if (normalized.contains(':')) {
      final parts = normalized.split(':');
      int hours = int.tryParse(parts[0]) ?? 0;
      int minutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      int seconds = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
      return hours > 0 || minutes > 0 || seconds > 0;
    }
    final value = double.tryParse(normalized);
    return value != null && value > 0;
  }

  Widget _selectableLine({
    required String text,
    EdgeInsets padding = const EdgeInsets.only(left: 8.0, bottom: 6.0),
    TextStyle? style,
  }) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          text,
          textAlign: TextAlign.left,
          style: style,
        ),
      ),
    );
  }

  // 「30:45」→「30分45秒」
  String _formatDuration(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parts = raw.split(':');
    final min = (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : '0';
    final sec = (parts.length > 1 && parts[1].isNotEmpty) ? parts[1] : '0';
    return '$min${l10n.min}$sec${l10n.sec}';
  }

  // ウエスト表示（SettingsBoxの実設定を優先：in/cm）※未使用でも残してOK
  String _fmtWaistLocal(double cm, AppLocalizations l10n) {
    final pref = _waistUnitPref(); // 'in' or 'cm'
    final val = (pref == 'in') ? (cm / 2.54) : cm;
    final unit = (pref == 'in') ? l10n.unitIn : l10n.unitCm;
    return '${val.toStringAsFixed(1)} $unit';
  }

  // settingsBox からウエスト単位を推測（カスタム保存との互換用）
  String _waistUnitPref() {
    for (final k in ['waistUnit', 'lengthUnit', 'unitLength', 'personal.lengthUnit']) {
      final v = widget.settingsBox.get(k);
      if (v is String) {
        final s = v.toLowerCase();
        if (s.contains('inch') || s == 'in') return 'in';
        if (s.contains('cm')) return 'cm';
      }
    }
    final useInch = widget.settingsBox.get('useInch');
    if (useInch is bool && useInch) return 'in';
    return 'cm';
  }

  // ▼ 個人値表示用のユーティリティ -------------------------------

  // settingsBox から身長(cm)を推測して取得
  double? _getUserHeightCm() {
    final keys = ['user_height_cm', 'height_cm', 'height', '身長cm', '身長'];
    for (final k in keys) {
      final v = widget.settingsBox.get(k);
      if (v == null) continue;
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    return null;
  }

  // settingsBox から性別を推測して取得（'male' | 'female' を返す）
  String? _getUserGender() {
    final pg = widget.settingsBox.get('personal.gender');
    if (pg is String) {
      final s = pg.toLowerCase();
      if (s.startsWith('male') || s == 'm' || s.contains('男')) return 'male';
      if (s.startsWith('female') || s == 'f' || s.contains('女')) return 'female';
    }
    for (final k in ['user_gender', 'gender', 'sex', '性別']) {
      final v = widget.settingsBox.get(k);
      if (v is String) {
        final s = v.toLowerCase();
        if (s.contains('male') || s.contains('man') || s == 'm' || s.contains('男')) return 'male';
        if (s.contains('female') || s.contains('woman') || s == 'f' || s.contains('女')) return 'female';
      } else if (v is int) {
        if (v == 0) return 'male';
        if (v == 1) return 'female';
      } else if (v is bool) {
        return v ? 'male' : 'female';
      }
    }
    return null;
  }

  double? _getOptionalDouble(dynamic dyn, List<String> candidates) {
    for (final name in candidates) {
      try {
        final dynamic v = switch (name) {
          'bodyFatPercent' => dyn.bodyFatPercent,
          'bodyFat'        => dyn.bodyFat,
          'fatPercent'     => dyn.fatPercent,
          'waistCm'        => dyn.waistCm,
          'waist'          => dyn.waist,
          'waist_cm'       => dyn.waist_cm,
          _                => null,
        };
        if (v == null) continue;
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v);
          if (d != null) return d;
        }
      } catch (_) {}
    }
    return null;
  }

  String _bmiRangeText() => '18.5〜24.9';
  String _bodyFatRangeText(String gender) => gender == 'male' ? '10〜20' : '20〜30';
  String _waistStdText(String gender) => gender == 'male' ? '85' : '90';

  // 体脂肪率（よくあるキー名の取りこぼし防止）
  double? _safeBodyFat(dynamic r) {
    try {
      final v = (r as dynamic).bodyFatPercent;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).bodyFat;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).bodyFatPercentage;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).bodyFatRate;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).fatPercentage;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    return null;
  }

  // ウエスト(cm)
  double? _safeWaist(dynamic r) {
    try {
      final v = (r as dynamic).waist;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).waistCm;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).waist_cm;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    return null;
  }

  // 設定から身長(m)
  double? _heightMetersFromSettings() {
    final phc = widget.settingsBox.get('personal.heightCm');
    if (phc is num && phc > 0) return phc.toDouble() / 100.0;
    if (phc is String) {
      final d = double.tryParse(phc);
      if (d != null && d > 0) return d / 100.0;
    }
    for (final key in ['height_cm', 'user_height_cm', '身長cm', '身長', 'height']) {
      final v = widget.settingsBox.get(key);
      if (v == null) continue;
      if (v is num && v > 0) return v.toDouble() / 100.0;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null && d > 0) return (d > 100) ? (d / 100.0) : d;
      }
    }
    final hM = widget.settingsBox.get('height_m');
    if (hM is num && hM > 0) return hM.toDouble();
    if (hM is String) {
      final d = double.tryParse(hM);
      if (d != null && d > 0) return d;
    }
    final hFt = widget.settingsBox.get('height_ft');
    final hIn = widget.settingsBox.get('height_in');
    double? ft, inch;
    if (hFt is num) ft = hFt.toDouble();
    if (hIn is num) inch = hIn.toDouble();
    if (hFt is String) ft = double.tryParse(hFt) ?? ft;
    if (hIn is String) inch = double.tryParse(hIn) ?? inch;
    if (ft != null || inch != null) {
      final totalIn = (ft ?? 0) * 12.0 + (inch ?? 0);
      if (totalIn > 0) return (totalIn * 2.54) / 100.0;
    }
    return null;
  }

  // レコードから身長(m)
  double? _heightMetersFromRecord(dynamic r) {
    try {
      final v = (r as dynamic).height_m;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    } catch (_) {}
    try {
      final v = (r as dynamic).heightCm;
      if (v is num) return v.toDouble() / 100.0;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d / 100.0;
      }
    } catch (_) {}
    try {
      final v = (r as dynamic).height_cm;
      if (v is num) return v.toDouble() / 100.0;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d / 100.0;
      }
    } catch (_) {}
    try {
      final v = (r as dynamic).height;
      if (v is num) return v > 10 ? v.toDouble() / 100.0 : v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d > 10 ? d / 100.0 : d;
      }
    } catch (_) {}
    return null;
  }

  String? _genderFromSettings() {
    final g = widget.settingsBox.get('gender');
    if (g == null) return null;
    final s = g.toString().toLowerCase();
    if (s.contains('male')) return 'male';
    if (s.contains('female')) return 'female';
    return null;
  }

  double _toKg(double w) => (SettingsManager.currentUnit == 'kg') ? w : (w * 0.45359237);

// --- 距離表示用 ---
  double _kmToDisplay(double km) =>
      (SettingsManager.currentLengthUnit == 'mile') ? km * 0.6213711922 : km;
  String _distanceUnitLabel(AppLocalizations l10n) =>
      (SettingsManager.currentLengthUnit == 'mile') ? l10n.mile : l10n.km;

  Map<String, double>? _standardsForGender(String gender) {
    final bmiMin = (widget.settingsBox.get('bmiRangeMin') as num?)?.toDouble() ?? 18.5;
    final bmiMax = (widget.settingsBox.get('bmiRangeMax') as num?)?.toDouble() ?? 25.0;
    double bfMin = (widget.settingsBox.get('bodyFatRangeMin') as num?)?.toDouble() ??
        (gender == 'male' ? 10.0 : 20.0);
    double bfMax = (widget.settingsBox.get('bodyFatRangeMax') as num?)?.toDouble() ??
        (gender == 'male' ? 20.0 : 30.0);
    double waistStd;
    final keyGender = gender == 'male' ? 'waistStdMaleCm' : 'waistStdFemaleCm';
    final gVal = widget.settingsBox.get(keyGender);
    if (gVal is num) {
      waistStd = gVal.toDouble();
    } else {
      final anyVal = widget.settingsBox.get('waistStdCm');
      waistStd = (anyVal is num) ? anyVal.toDouble() : (gender == 'male' ? 85.0 : 90.0);
    }
    return {
      'bmiMin': bmiMin,
      'bmiMax': bmiMax,
      'bfMin': bfMin,
      'bfMax': bfMax,
      'waistStd': waistStd,
    };
  }

  double? _getDoubleFromSettings(List<String> candidateKeys) {
    for (final k in candidateKeys) {
      final v = widget.settingsBox.get(k);
      if (v == null) continue;
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
      if (v is Map) {
        for (final e in v.values) {
          if (e is num) return e.toDouble();
          if (e is String) {
            final d = double.tryParse(e);
            if (d != null) return d;
          }
        }
      }
    }
    return null;
  }

  double? _scanSettingsBySuffix(String dateKey, List<String> tokenVariants) {
    try {
      for (final k in widget.settingsBox.keys) {
        final ks = k.toString().toLowerCase();
        if (!ks.endsWith('-$dateKey')) continue;
        for (final t in tokenVariants) {
          if (!ks.contains(t)) continue;
          final v = widget.settingsBox.get(k);
          if (v is num) return v.toDouble();
          if (v is String) {
            final d = double.tryParse(v);
            if (d != null) return d;
          }
          if (v is Map) {
            for (final e in (v as Map).values) {
              if (e is num) return e.toDouble();
              if (e is String) {
                final d = double.tryParse(e);
                if (d != null) return d;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  double? _scanRecordMaps(dynamic r, List<String> mapProps, List<String> tokenVariants) {
    for (final prop in mapProps) {
      try {
        final dynamic m = switch (prop) {
          'extras'      => (r as dynamic).extras,
          'extra'       => (r as dynamic).extra,
          'metrics'     => (r as dynamic).metrics,
          'personal'    => (r as dynamic).personal,
          'stats'       => (r as dynamic).stats,
          'attributes'  => (r as dynamic).attributes,
          _             => null,
        };
        if (m is Map) {
          for (final entry in m.entries) {
            final key = entry.key.toString().toLowerCase();
            for (final t in tokenVariants) {
              if (!key.contains(t)) continue;
              final v = entry.value;
              if (v is num) return v.toDouble();
              if (v is String) {
                final d = double.tryParse(v);
                if (d != null) return d;
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // その日に実績のある「部位」一覧を返す（表示用）
  List<String> _partsWithDataForDay(DailyRecord r) {
    final List<String> parts = [];
    r.menus.forEach((part, menuList) {
      bool has = false;
      for (final m in menuList) {
        final len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
        for (int i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final p = m.reps[i].toString().trim();
          if (w.isNotEmpty || p.isNotEmpty) {
            has = true;
            break;
          }
        }
        if ((m.distance?.trim().isNotEmpty ?? false) || (m.duration?.trim().isNotEmpty ?? false)) {
          has = true;
        }
        if (m.calories?.trim().isNotEmpty ?? false) {
          has = true;
        }
        if (has) break;
      }
      if (has) parts.add(part);
    });
    return parts;
  }

  // TableCalendar：その日の「部位一覧」を返す
  // ※体重のみ記録日＝部位なしの場合は '_w' を1件返す（UIでは非表示）
  List<Object> _eventLoader(DateTime day) {
    final r = widget.recordsBox.get(_dateKey(day));
    if (r == null) return const [];
    final parts = _partsWithDataForDay(r);
    if (parts.isEmpty && r.weight != null) return const ['_w'];
    return parts;
  }

  // ====== メモ取得（DailyRecord.note → settingsBox の順で復元） ======
  String? _getMemoTextForDate(DateTime day) {
    final key = _dateKey(day);
    final rec = widget.recordsBox.get(key);

    try {
      final dyn = rec as dynamic;
      final note = dyn?.note as String?;
      if (note != null && note.trim().isNotEmpty) return note;
    } catch (_) {}

    final m = widget.settingsBox.get('memo-$key');
    if (m is Map) {
      final body = (m['body'] as String?) ?? (m['title'] as String?);
      if (body != null && body.trim().isNotEmpty) return body;
    } else if (m is String && m.trim().isNotEmpty) {
      return m;
    }
    return null;
  }

  bool _hasMemoForDate(DateTime day) =>
      (_getMemoTextForDate(day)?.trim().isNotEmpty ?? false);

  // ====== 写真有無の判定（キャッシュ＆遅延ロード） ======
  Future<bool> _checkPhotosForDate(DateTime date) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/media/${_dateKey(date)}');
    if (!await dir.exists()) return false;
    try {
      final List<FileSystemEntity> list = await dir.list().toList();
      for (final e in list) {
        if (e is! File) continue;
        final p = e.path.toLowerCase();
        if (p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.heic')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  void _ensurePhotoFlag(DateTime day) {
    final key = _dateKey(day);
    if (_photoCache.containsKey(key)) return;
    _photoCache[key] = false;
    Future.microtask(() async {
      final has = await _checkPhotosForDate(day);
      if (mounted) setState(() => _photoCache[key] = has);
    });
  }

  // 日付数字を「上寄せ固定」で描く（※ 今日リングは出さない）
  Widget _dayLabelTop(BuildContext context, DateTime day,
      {required Color textColor, bool selected = false}) {
    final label = Text(
      '${day.day}',
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: label,
      ),
    );
  }

  // 最大3ボックス（日付下：体重+部位の合計）の行高を算出
  double _rowHeightFor3(BuildContext context) {
    const double topPad = 6.0;
    final double dayFont = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14.0;
    final double dayLine = dayFont * 1.2;

    const double chipFont = 10.0;
    const double chipLine = chipFont * 1.1;
    const double chipVPad = 2.0;
    const double chipH = chipLine + chipVPad * 2;

    const double gaps = 2.0 + 2.0 + 2.0;

    const double safety = 4.0;
    return (topPad + dayLine + chipH * 3 + gaps + safety).ceilToDouble();
  }

  // セル描画
  Widget _buildDayCell(BuildContext context, DateTime day,
      {required Color textColor, bool selected = false, bool showEventsForOutOfMonth = false}) {
    final cs = Theme.of(context).colorScheme;

    _ensurePhotoFlag(day);
    final bool hasPhoto = _photoCache[_dateKey(day)] ?? false;

    final record = widget.recordsBox.get(_dateKey(day));
    final partsAll = (record == null) ? <String>[] : _partsWithDataForDay(record);

    final strengthParts = partsAll.where((p) => p != '有酸素運動').toList();
    final hasAerobic = partsAll.contains('有酸素運動');
    final hasMemo = _hasMemoForDate(day);
    final hasWeight = record?.weight != null;

    final bool canShowChips = showEventsForOutOfMonth || day.month == _focusedDay.month || record != null || hasMemo || hasPhoto;

    Widget _partChip(String part) {
      final label = _translatePartToLocale(context, part);
      final boxColor = _colorForPart(part, cs);
      final textOnBox = ThemeData.estimateBrightnessForColor(boxColor) == Brightness.dark
          ? Colors.white
          : Colors.black87;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.1, color: textOnBox, fontWeight: FontWeight.w600),
        ),
      );
    }

    Widget _memoChip() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AppLocalizations.of(context)!.memo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, height: 1.1, color: cs.onTertiaryContainer, fontWeight: FontWeight.w700),
      ),
    );

    Widget _weightChip() {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.bodyWeight,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.1, color: cs.onSecondaryContainer, fontWeight: FontWeight.w700),
        ),
      );
    }

    Widget _photoChip() {
      final cs = Theme.of(context).colorScheme;
      final l10n = AppLocalizations.of(context)!; // l10n

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.photos, // ← '写真' / 'Photos' を l10n に統一
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.1,
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final chips = <Widget>[];
    if (canShowChips) {
      for (final p in strengthParts) {
        if (chips.length >= 3) break;
        chips.add(_partChip(p));
      }
      if (chips.length < 3 && hasAerobic) chips.add(_partChip('有酸素運動'));
      if (chips.length < 3 && hasMemo) chips.add(_memoChip());
      if (chips.length < 3 && hasWeight) chips.add(_weightChip());
      if (chips.length < 3 && hasPhoto) chips.add(_photoChip());
    }

    final Color dayNumberColor = (day.weekday == DateTime.sunday)
        ? Colors.red
        : (day.weekday == DateTime.saturday ? Colors.blue : textColor);

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.10) : null,
          borderRadius: selected ? BorderRadius.circular(8) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _dayLabelTop(context, day, textColor: dayNumberColor, selected: selected),
            if (chips.isNotEmpty) const SizedBox(height: 2),
            for (int i = 0; i < chips.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == chips.length - 1 ? 0 : 2),
                child: chips[i],
              ),
          ],
        ),
      ),
    );
  }

  // 記録画面（フルスクリーン遷移・アニメーションなし）
  Future<void> _openRecordSheet(DateTime day) async {
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => RecordScreen(
          selectedDate: day,
          recordsBox: widget.recordsBox,
          lastUsedMenusBox: widget.lastUsedMenusBox,
          settingsBox: widget.settingsBox,
          setCountBox: widget.setCountBox,
        ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
    if (!mounted) {
      return;
    }

    _photoCache.remove(_dateKey(day));

    setState(() {});
  }

  Future<void> _handleAddPressed() async {
    final base = _selectedDay ?? DateTime.now();
    final DateTime sel = DateTime(base.year, base.month, base.day);
    final bool isPast = _isPastDate(sel);

    if (isPast) {
      // 過去日：実績ダイアログ
      final DailyRecord? rec = widget.recordsBox.get(_dateKey(sel));
      final List<Widget> summaryChildren = _buildSummaryChildrenForDate(context, sel, rec);
      await _showResultsDialog(context, summaryChildren, sel);
    } else {
      // 今日以降：記録画面
      await _openRecordSheet(sel);
    }
  }

  // 半角→全角数字（0-9）変換
  String _toZenkakuDigits(String s) {
    const half = '0123456789';
    const full = '０１２３４５６７８９';
    return s.split('').map((ch) {
      final i = half.indexOf(ch);
      return i >= 0 ? full[i] : ch;
    }).join();
  }

  // AppBar/ヘッダ用のローカライズ済みタイトル
  String _formatMonthTitle(BuildContext context, DateTime d) {
    final locale = Localizations.localeOf(context);
    final isJa = locale.languageCode == 'ja';
    final fmt = DateFormat.yMMMM(locale.toString());
    final s = fmt.format(d);

    if (isJa) {
      final m = RegExp(r'^(\d{4})年').firstMatch(s);
      if (m != null) {
        final fullYear = _toZenkakuDigits(m.group(1)!);
        return s.replaceFirst(m.group(1)!, fullYear);
      }
    }
    return s;
  }


  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SettingsManager.backgroundAssetNotifier.value.isEmpty
          ? null
          : Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 56,
        title: const Text('TrainingRecord'),
      ),


      // ▼ ここで SettingsManager.waistUnitNotifier を監視して即反映
      // ▼ ここで SettingsManager.waistUnitNotifier を監視して即反映
      body: ValueListenableBuilder<String>(
        valueListenable: SettingsManager.waistUnitNotifier,
        builder: (context, __, ___) {
          // ▼ 距離（mi/km）の切替にも反応
          return ValueListenableBuilder(
            valueListenable: SettingsManager.lengthUnitNotifier,
            builder: (context, ___, ____) {
              return CenteredConstrained(
                maxWidth: 760,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: ValueListenableBuilder<Box<dynamic>>(
                  valueListenable: widget.settingsBox.listenable(),
                  builder: (context, _settings, __) {
                    return ValueListenableBuilder<Box<DailyRecord>>(
                      valueListenable: widget.recordsBox.listenable(),
                      builder: (context, box, _) {
                        final selectedRecord = box.get(_dateKey(_selectedDay ?? DateTime.now()));
                        return Column(
                          children: [
                            const AdBanner(screenName: 'calendar'),
                            const SizedBox(height: 2),
                            _buildCalendar(context),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),

      // ▼ 右下のプラス（FAB）を復活：RecordScreen を開く既存メソッドを呼ぶ
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendarFab',
        onPressed: () {
          final day = _selectedDay ?? widget.selectedDate; // 選択日がなければ初期日
          _openRecordSheet(day); // ※ RecordScreen の必須引数を内部で全て渡す既存メソッド
        },
        child: const Icon(Icons.add),
      ),
    );

  }

  Widget _buildCalendar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: _kCalendarCard,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 4,
      child: Padding(
        // 下の余白を少し詰めて、実画面上の高さを稼ぐ
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: TableCalendar<Object>(
          firstDay: DateTime.utc(2015, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          locale: Localizations.localeOf(context).toString(),

          // ここで高さを少しアップ（12%拡大）
          rowHeight: _rowHeightFor3(context) * 1.12,

          selectedDayPredicate: (day) =>
          _selectedDay != null && _sameDate(day, _selectedDay!),
          startingDayOfWeek: StartingDayOfWeek.monday,

          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            leftChevronIcon:
            Icon(Icons.chevron_left, color: colorScheme.onSurface),
            rightChevronIcon:
            Icon(Icons.chevron_right, color: colorScheme.onSurface),
          ),

          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: colorScheme.onSurface),
            weekendTextStyle: TextStyle(color: colorScheme.onSurface),
            outsideTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            todayDecoration: const BoxDecoration(),
            selectedDecoration: const BoxDecoration(),
            selectedTextStyle: TextStyle(color: colorScheme.onSurface),
            markersMaxCount: 0,
          ),

          calendarBuilders: CalendarBuilders<Object>(
            defaultBuilder: (context, day, focusedDay) {
              final cs = Theme.of(context).colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurface,
                selected: false,
              );
            },
            outsideBuilder: (context, day, focusedDay) {
              final cs = Theme.of(context).colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurfaceVariant,
                selected: false,
                showEventsForOutOfMonth: true,
              );
            },
            todayBuilder: (context, day, focusedDay) {
              final cs = Theme.of(context).colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurface,
                selected: false,
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              final cs = Theme.of(context).colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurface,
                selected: true,
              );
            },
          ),

          eventLoader: _eventLoader,

          onDaySelected: (selectedDay, focusedDay) async {
            // 2回目タップ判定：すでに選択中の日付をもう一度タップした
            if (_selectedDay != null && _sameDate(selectedDay, _selectedDay!)) {
              final DateTime sel = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              final bool isPast = _isPastDate(sel);

              if (isPast) {
                // 過去日：実績ダイアログを開く
                final DailyRecord? rec = widget.recordsBox.get(_dateKey(sel));
                final List<Widget> summaryChildren = _buildSummaryChildrenForDate(context, sel, rec);
                await _showResultsDialog(context, summaryChildren, sel);
              } else {
                // 今日以降：記録画面へ
                await _openRecordSheet(sel);
              }
              return;
            }

            // 1回目タップ：その日に移動（選択＆フォーカス更新）のみ
            setState(() {
              _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
              _focusedDay = focusedDay;
            });
          },

          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
        ),
      ),
    );

  }

  String _formatResultsDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'ja') {
      return DateFormat('M月d日', locale.toString()).format(date);
    }
    return DateFormat.yMMMd(locale.toString()).format(date);
  }

  List<Widget> _buildSummaryChildrenForDate(
      BuildContext context,
      DateTime sel,
      DailyRecord? record,
      ) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> summaryChildren = [];

    if (record == null || !_hasAnyData(record)) {
      final memo = _getMemoTextForDate(sel);
      if (memo != null && memo.trim().isNotEmpty) {
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _selectableLine(
              text: memo.trim(),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              padding: const EdgeInsets.only(left: 4.0, bottom: 0),
            ),
          ),
        );
      }
      return summaryChildren;
    }

    // ===== ここから“従来のサマリ生成” =====

    // 個人値（体重/体脂肪/ウエスト/BMI）
    final double? bodyFatVal = _safeBodyFat(record);
    final double? waistValCm = _safeWaist(record);
    double? bmiVal;
    if (record.weight != null) {
      final w = record.weight!;
      final h = _heightMetersFromSettings() ?? _heightMetersFromRecord(record);
      if (h != null && h > 0) {
        bmiVal = _toKg(w) / (h * h);
      }
    }

    bool _menuHasAnyData(MenuData m) {
      final len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
      for (int i = 0; i < len; i++) {
        final w = m.weights[i].toString().trim();
        final r = m.reps[i].toString().trim();
        if (w.isNotEmpty || r.isNotEmpty) return true;
      }
      if (_hasPositiveDistanceValue(m.distance)) return true;
      if (_hasPositiveDurationValue(m.duration)) return true;
      if ((m.calories?.trim().isNotEmpty ?? false)) return true;
      return false;
    }

    // 有酸素
    final List<MenuData> aerobicMenus =
        (record.menus['有酸素運動'] as List<MenuData>?) ?? const <MenuData>[];
    if (aerobicMenus.any(_menuHasAnyData)) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, '有酸素運動')}',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      for (final m in aerobicMenus) {
        summaryChildren.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );
        final bool hasDistance = _hasPositiveDistanceValue(m.distance);
        final bool hasDuration = _hasPositiveDurationValue(m.duration);
        if (hasDistance) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.distance}: ${_formatDistance(m.distance, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if (hasDuration) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.time}: ${_formatDurationHM(context, m.duration, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if ((m.calories?.trim().isNotEmpty ?? false)) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.calorie}: ${m.calories} ${l10n.kcalUnit}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if (m.satisfaction != null) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _satisfactionLine(l10n, m.satisfaction!, cs),
              ),
            ),
          );
        }
      }
      summaryChildren.add(const SizedBox(height: 8));
    }

    // 有酸素以外（部位/メニュー名 + 簡易セット表示）
    record.menus.forEach((originalPart, menuList) {
      if (originalPart == '有酸素運動') return;

      bool partHas = false;
      for (final m in menuList) {
        if (_menuHasAnyData(m)) {
          partHas = true;
          break;
        }
      }
      if (!partHas) return;

      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, originalPart)}',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );

      for (final m in menuList) {
        if (!_menuHasAnyData(m)) continue;

        summaryChildren.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );

        final int len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
        for (int i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final r = m.reps[i].toString().trim();
          if (w.isEmpty && r.isEmpty) continue;
          summaryChildren.add(
            _selectableLine(
              text: '${i + 1}set: ${w.isEmpty ? '-' : w} × ${r.isEmpty ? '-' : r}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if (m.satisfaction != null) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _satisfactionLine(l10n, m.satisfaction!, cs),
              ),
            ),
          );
        }
      }
      summaryChildren.add(const SizedBox(height: 8));
    });

    // 個人値まとめ（あるものだけ）
    final hasPersonal = (record.weight != null) || (bodyFatVal != null) || (waistValCm != null) || (bmiVal != null);
    if (hasPersonal) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${l10n.personal}',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      if (record.weight != null) {
        final unit = SettingsManager.currentUnit;
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.bodyWeight}: ${record.weight!.toStringAsFixed(1)} $unit',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bodyFatVal != null) {
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.bodyFat}: ${bodyFatVal!.toStringAsFixed(1)}%',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (waistValCm != null) {
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.waist}: ${_fmtWaist(waistValCm!, l10n)}',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bmiVal != null) {
        summaryChildren.add(
          _selectableLine(
            text: 'BMI: ${bmiVal!.toStringAsFixed(1)}',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
    }

    // メモ
    final memo = _getMemoTextForDate(sel);
    if (memo != null && memo.trim().isNotEmpty) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _selectableLine(
            text: memo.trim(),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            padding: const EdgeInsets.only(left: 4.0, bottom: 0),
          ),
        ),
      );
    }

    return summaryChildren;
  }

  Future<void> _showResultsDialog(
      BuildContext context,
      List<Widget> body,
      DateTime sel,
      ) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // 記録の有無（ラベル切替に使用）
    final DailyRecord? rec = widget.recordsBox.get(_dateKey(sel));
    final bool hasRecord = (rec != null) && _hasAnyData(rec);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final double maxHeight = MediaQuery.of(ctx).size.height * 0.90;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.results(_formatResultsDate(ctx, sel)),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 実績本文（スクロール領域）
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: body.isEmpty
                          ? [
                        Text(
                          '記録はありません',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                        ),
                      ]
                          : body,
                    ),
                  ),
                ),

                // ↓↓↓ ここが “デカ広告” 領域（動画ネイティブ優先 → バナーMRECに自動フォールバック） ↓↓↓
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: BigEarningAd(
                    // ★本番の広告ユニットIDに差し替えてください
                    androidNativeUnitId: 'ca-app-pub-3331079517737737/8075628963',
                    iosNativeUnitId:     'ca-app-pub-3331079517737737/2163497749',
                    androidBannerUnitId: 'ca-app-pub-3331079517737737/6135915237',
                    iosBannerUnitId:     'ca-app-pub-3331079517737737/9252979261',
                    height: 260,
                    // NativeAd Factory ID（後述のプラットフォーム登録で使うID）
                    factoryId: 'large_media',
                  ),
                ),
                // ↑↑↑ 広告ここまで ↑↑↑

                const Divider(height: 1),

                // フッター（編集/追加）
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: Text(hasRecord ? l10n.editThisDay : l10n.addOnThisDay),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _openRecordSheet(sel);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// カレンダー直下に出す「◯月◯日の記録」のカード（左寄せ・スクロールしない）
  // カレンダー直下に出す「◯月◯日の記録」のカード（左寄せ・スクロールしない）
  Widget _buildResultsArea(BuildContext context, DailyRecord? record) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final DateTime sel = _selectedDay ?? _focusedDay ?? DateTime.now();

    // 何もなければ表示しない
    if (record == null || !_hasAnyData(record)) {
      return const SizedBox.shrink();
    }

    // ====== ここから “従来のサマリ生成” をメソッド内に集約 ======
    final List<Widget> summaryChildren = [];

    // --- 個人値（体重/体脂肪/ウエスト/BMI） ---
    final double? bodyFatVal = _safeBodyFat(record);      // %
    final double? waistValCm = _safeWaist(record);         // cm
    double? bmiVal;
    if (record.weight != null) {
      final w = record.weight!;
      final h = _heightMetersFromSettings() ?? _heightMetersFromRecord(record);
      if (h != null && h > 0) {
        bmiVal = _toKg(w) / (h * h);
      }
    }

    bool _menuHasAnyData(MenuData m) {
      final len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
      for (int i = 0; i < len; i++) {
        final w = m.weights[i].toString().trim();
        final r = m.reps[i].toString().trim();
        if (w.isNotEmpty || r.isNotEmpty) return true;
      }
      if (_hasPositiveDistanceValue(m.distance)) return true;
      if (_hasPositiveDurationValue(m.duration)) return true;
      if ((m.calories?.trim().isNotEmpty ?? false)) return true;
      return false;
    }

    // --- 有酸素 ---
    final List<MenuData> aerobicMenus =
        (record.menus['有酸素運動'] as List<MenuData>?) ?? const <MenuData>[];
    if (aerobicMenus.any(_menuHasAnyData)) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, '有酸素運動')}',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      for (final m in aerobicMenus) {
        summaryChildren.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );
        final bool hasDistance = _hasPositiveDistanceValue(m.distance);
        final bool hasDuration = _hasPositiveDurationValue(m.duration);
        if (hasDistance) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.distance}: ${_formatDistance(m.distance, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if (hasDuration) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.time}: ${_formatDurationHM(context, m.duration, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if ((m.calories?.trim().isNotEmpty ?? false)) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.calorie}: ${m.calories} ${l10n.kcalUnit}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if (m.satisfaction != null) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _satisfactionLine(l10n, m.satisfaction!, cs),
              ),
            ),
          );
        }
      }
      summaryChildren.add(const SizedBox(height: 8));
    }

    // --- 有酸素以外（部位/メニュー名 + 簡易セット表示） ---
    record.menus.forEach((originalPart, menuList) {
      if (originalPart == '有酸素運動') return;

      bool partHas = false;
      for (final m in menuList) {
        if (_menuHasAnyData(m)) {
          partHas = true;
          break;
        }
      }
      if (!partHas) return;

      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, originalPart)}',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );

      for (final m in menuList) {
        if (!_menuHasAnyData(m)) continue;

        summaryChildren.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );

        final int len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
        for (int i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final r = m.reps[i].toString().trim();
          if (w.isEmpty && r.isEmpty) continue;
          summaryChildren.add(
            _selectableLine(
              text: '${i + 1}set: ${w.isEmpty ? '-' : w} × ${r.isEmpty ? '-' : r}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          );
        }
        if (m.satisfaction != null) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _satisfactionLine(l10n, m.satisfaction!, cs),
              ),
            ),
          );
        }
      }
      summaryChildren.add(const SizedBox(height: 8));
    });

    // --- 個人値まとめ（あるものだけ）
    final hasPersonal = (record.weight != null) || (bodyFatVal != null) || (waistValCm != null) || (bmiVal != null);
    if (hasPersonal) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${l10n.personal}',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      if (record.weight != null) {
        final unit = SettingsManager.currentUnit;
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.bodyWeight}: ${record.weight!.toStringAsFixed(1)} $unit',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bodyFatVal != null) {
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.bodyFat}: ${bodyFatVal!.toStringAsFixed(1)}%',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (waistValCm != null) {
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.waist}: ${_fmtWaist(waistValCm!, l10n)}',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bmiVal != null) {
        summaryChildren.add(
          _selectableLine(
            text: 'BMI: ${bmiVal!.toStringAsFixed(1)}',
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
    }

    // メモ
    final memo = _getMemoTextForDate(sel);
    if (memo != null && memo.trim().isNotEmpty) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _selectableLine(
            text: memo.trim(),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            padding: const EdgeInsets.only(left: 4.0, bottom: 0),
          ),
        ),
      );
    }
    // ====== サマリ生成ここまで ======

    // FAB と重ならない横幅（右余白+安全マージンで約 96px 確保）
    final double screenW = MediaQuery.of(context).size.width;
    final double maxWidth = (screenW - 96).clamp(220.0, screenW);

    const double fabHeight = 56;
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,          // （既存）FABと重ならない幅上限
            minHeight: fabHeight,
            maxHeight: fabHeight,        // ← 高さ固定
          ),
          child: Card(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            color: cs.surfaceContainerHighest,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showResultsDialog(context, summaryChildren, sel),
              child: Container(
                height: fabHeight,                        // ← ここでも明示
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,          // 垂直中央寄せ
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.results(_formatResultsDate(context, sel)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }




}
