// lib/screens/calendar_screen.dart
import 'dart:ui';
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
import '../widgets/ad_square.dart';
import '../widgets/coach_bubble.dart';
import '../routes/slide_up_route.dart';
import '../widgets/centered_constrained.dart';


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

  Widget _satisfactionLine(AppLocalizations l10n, int value, ColorScheme cs) {
    IconData icon;
    switch (value) {
      case 0:
      // 記録画面と同じ「バッド」
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
        Text('${l10n.satisfaction}：',
            style: TextStyle(color: cs.onSurface, fontSize: 13)),
        const SizedBox(width: 6),
        Icon(icon, size: 20, color: cs.onSurfaceVariant), // 大きさも記録画面に合わせて20
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
    // ▼ 追加：当日の個人値だけの日も「実績あり」にする
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
  String _formatDistance(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final value = double.tryParse(raw);
    if (value == null) return '-';
    final km = value.floor();
    final m = ((value - km) * 1000).round();
    return '$km${l10n.km}$m${l10n.m}';
  }

// 「1:30」→「1時間30分」(ja) / 「1h30min」(それ以外)
  String _formatDurationHM(BuildContext context, String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parts = raw.split(':');
    final hour = (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : '0';
    final min  = (parts.length > 1 && parts[1].isNotEmpty) ? parts[1] : '0';

    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    return isJa ? '${hour}時間${min}${l10n.min}' : '${hour}h${min}${l10n.min}';
  }

  // ウエスト表示単位の取得（cm / in）
  String _waistUnitPref() {
    // 明示キー優先（文字列想定）
    for (final k in ['waistUnit', 'lengthUnit', 'unitLength', 'personal.lengthUnit']) {
      final v = widget.settingsBox.get(k);
      if (v is String) {
        final s = v.toLowerCase();
        if (s.contains('inch') || s == 'in') return 'in';
        if (s.contains('cm')) return 'cm';
      }
    }
    // true/false 系の補助キー
    final useInch = widget.settingsBox.get('useInch');
    if (useInch is bool && useInch) return 'in';
    return 'cm';
  }

  // ウエスト数値の表示加工（cm→in 変換・小数桁）
  ({double value, String unit}) _formatWaistForDisplay(double waistCm) {
    final pref = _waistUnitPref();
    if (pref == 'in') {
      final inch = waistCm / 2.54;
      return (value: double.parse(inch.toStringAsFixed(1)), unit: 'in');
    }
    return (value: double.parse(waistCm.toStringAsFixed(1)), unit: 'cm');
  }


  // 「30:45」→「30分45秒」
  String _formatDuration(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parts = raw.split(':');
    final min = (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : '0';
    final sec = (parts.length > 1 && parts[1].isNotEmpty) ? parts[1] : '0';
    return '$min${l10n.min}$sec${l10n.sec}';
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
    // 新：設定画面の保存先
    final pg = widget.settingsBox.get('personal.gender');
    if (pg is String) {
      final s = pg.toLowerCase();
      if (s.startsWith('male') || s == 'm' || s.contains('男')) return 'male';
      if (s.startsWith('female') || s == 'f' || s.contains('女')) return 'female';
      // 'unspecified' などは null 扱い
    }

    // 互換：旧キー群
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

  // record に存在するかもしれない動的プロパティから double を読む
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
      } catch (_) {/* 未定義なら無視 */}
    }
    return null;
  }

  // 基準テキスト（性別文言は出さない）
  String _bmiRangeText() => '18.5〜24.9';
  String _bodyFatRangeText(String gender) => gender == 'male' ? '10〜20' : '20〜30';
  String _waistStdText(String gender) => gender == 'male' ? '85' : '90';

    // ====== ここから追加：パーソナル指標の取得/計算ヘルパー ======

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
    // 新：設定画面の正規化保存値（cm）
    final phc = widget.settingsBox.get('personal.heightCm');
    if (phc is num && phc > 0) return phc.toDouble() / 100.0;
    if (phc is String) {
      final d = double.tryParse(phc);
      if (d != null && d > 0) return d / 100.0;
    }

    // 互換：従来キー（cm か m 推定）
    for (final key in ['height_cm', 'user_height_cm', '身長cm', '身長', 'height']) {
      final v = widget.settingsBox.get(key);
      if (v == null) continue;
      if (v is num && v > 0) return v.toDouble() / 100.0;
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null && d > 0) return (d > 100) ? (d / 100.0) : d; // 100超はcm扱い
      }
    }

    // m保存
    final hM = widget.settingsBox.get('height_m');
    if (hM is num && hM > 0) return hM.toDouble();
    if (hM is String) {
      final d = double.tryParse(hM);
      if (d != null && d > 0) return d;
    }

    // 互換：ft/in 保存
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

  // レコードから身長(m)（フォールバック用）
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
      final v = (r as dynamic).height; // cm または m 想定（>10 を cm と見なす）
      if (v is num) return v > 10 ? v.toDouble() / 100.0 : v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d > 10 ? d / 100.0 : d;
      }
    } catch (_) {}
    return null;
  }

  // 設定の性別（表示には使わず、基準の選択だけに使う）
  String? _genderFromSettings() {
    final g = widget.settingsBox.get('gender');
    if (g == null) return null;
    final s = g.toString().toLowerCase();
    if (s.contains('male')) return 'male';
    if (s.contains('female')) return 'female';
    return null;
  }

  // 単位：lb→kg 変換（BMI計算用）
  double _toKg(double w) => (SettingsManager.currentUnit == 'kg') ? w : (w * 0.45359237);

  // 基準値（性別ありのときのみ返す）
  Map<String, double>? _standardsForGender(String gender) {
    // BMI（共通）
    final bmiMin = (widget.settingsBox.get('bmiRangeMin') as num?)?.toDouble() ?? 18.5;
    final bmiMax = (widget.settingsBox.get('bmiRangeMax') as num?)?.toDouble() ?? 25.0;

    // 体脂肪率（性別で既定）
    double bfMin = (widget.settingsBox.get('bodyFatRangeMin') as num?)?.toDouble() ??
        (gender == 'male' ? 10.0 : 20.0);
    double bfMax = (widget.settingsBox.get('bodyFatRangeMax') as num?)?.toDouble() ??
        (gender == 'male' ? 20.0 : 30.0);

    // ウエスト（性別で既定、上書きがあれば使う）
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

  // settingsBox に保存されている数値（num / 文字列 / Map内の数値）を柔軟に取り出す
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

  // settingsBox を「-yyyy-MM-dd」サフィックスで横断探索（キー名の表記揺れを吸収）
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

  // DailyRecord 内の Map（extras/metrics/personal/stats/attributes 等）を横断探索
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

  // ====== ここまで追加 ======

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
        if (has) break; // returnしない
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
    // 仮値 false を入れておいて非同期で更新
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

    // ▼ 安全マージン(+4px)を加算してオーバーフロー回避
    const double safety = 4.0;
    return (topPad + dayLine + chipH * 3 + gaps + safety).ceilToDouble();
  }

  // セル描画
  Widget _buildDayCell(BuildContext context, DateTime day,
      {required Color textColor, bool selected = false, bool showEventsForOutOfMonth = false}) {
    final cs = Theme.of(context).colorScheme;

    // 非同期で写真有無を更新（キャッシュ未登録時のみ）
    _ensurePhotoFlag(day);
    final bool hasPhoto = _photoCache[_dateKey(day)] ?? false;

    // その日の記録
    final record = widget.recordsBox.get(_dateKey(day));
    final partsAll = (record == null) ? <String>[] : _partsWithDataForDay(record);

    // 分類：無酸素（有酸素以外） / 有酸素
    final strengthParts = partsAll.where((p) => p != '有酸素運動').toList();
    final hasAerobic = partsAll.contains('有酸素運動');
    final hasMemo = _hasMemoForDate(day);
    final hasWeight = record?.weight != null;

    final bool canShowChips = (showEventsForOutOfMonth || day.month == _focusedDay.month);

    // チップ生成
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
          l10n.bodyWeight, // 数値は出さない
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.1, color: cs.onSecondaryContainer, fontWeight: FontWeight.w700),
        ),
      );
    }

    Widget _photoChip() {
      final isJa = Localizations.localeOf(context).languageCode == 'ja';
      final label = isJa ? '写真' : 'Photos';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.1, color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
        ),
      );
    }

    // 優先度に沿って最大3つ選択：部位（無酸素*複数）→有酸素→メモ→体重→写真
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

    // ▼ 土日カラーを「月外の行でも」適用
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
        transitionDuration: Duration(milliseconds: 0),
        reverseTransitionDuration: Duration(milliseconds: 0),
        transitionsBuilder: (_, __, ___, child) => child, // ← 完全に無アニメ
      ),
    );
    if (mounted) setState(() {});
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
    final fmt = DateFormat.yMMMM(locale.toString()); // 例: ja_JP → "2025年9月"
    final s = fmt.format(d);

    if (isJa) {
      // 先頭の西暦4桁だけ全角化 → 「２０２５年9月」
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'TrainingrRecord', // ← ここを固定文字列に
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.58),
                    Colors.black.withOpacity(0.38),
                    Colors.black.withOpacity(0.16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      body: CenteredConstrained(
        maxWidth: 760,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), // 既存の余白は維持
        child: ValueListenableBuilder<Box<DailyRecord>>(
        valueListenable: widget.recordsBox.listenable(),
          builder: (context, box, _) {
            final selectedRecord = box.get(_dateKey(_selectedDay ?? DateTime.now()));
            return Column(
              children: [
                const AdBanner(screenName: 'calendar'),
                const SizedBox(height: 2),
                _buildCalendar(context),
                const SizedBox(height: 2),
                _buildResultsArea(context, selectedRecord),
              ],
            );
          },
        ),
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
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar<Object>(
          firstDay: DateTime.utc(2015, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          locale: Localizations.localeOf(context).toString(), // ← ロケール反映

          // 行の高さ＝「日付＋最大3ボックス」ぴったり
          rowHeight: _rowHeightFor3(context),

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
            leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
            rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
          ),

          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: colorScheme.onSurface),
            weekendTextStyle: TextStyle(color: colorScheme.onSurface),
            outsideTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            todayDecoration: const BoxDecoration(), // 今日リングなし
            selectedDecoration: const BoxDecoration(), // 選択の円もなし
            selectedTextStyle: TextStyle(color: colorScheme.onSurface),
            markersMaxCount: 0, // 標準の●マーカーを無効化
          ),

          // ▼ セル一体描画（markerBuilderは使わない）
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
                textColor: cs.onSurfaceVariant, // 平日は薄色、でも土日色は _buildDayCell で適用
                selected: false,
                showEventsForOutOfMonth: false,
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

          // 1回目のタップ：選択だけ、同じ日をもう一度タップ：記録画面
          onDaySelected: (selectedDay, focusedDay) async {
            if (_selectedDay != null && _sameDate(selectedDay, _selectedDay!)) {
              await _openRecordSheet(selectedDay);
              return;
            }
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

  Future<void> _showResultsDialog(BuildContext context, List<Widget> summaryChildren) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.results, // 「実績」
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: summaryChildren,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildResultsArea(BuildContext context, DailyRecord? record) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // 追加：選択日のメモ
    final DateTime sel = _selectedDay ?? DateTime.now();
    final String? memoText = _getMemoTextForDate(sel);
    final bool hasMemo = memoText != null && memoText.trim().isNotEmpty;

    // 実績ゼロ日：広告のみ（※ メモがあれば実績あり扱い）
    final bool noData = (record == null || !_hasAnyData(record)) && !hasMemo;
    if (noData) {
      return Expanded(
        child: ListView(
          padding: const EdgeInsets.only(top: 8.0),
          children: const [
            Center(
              child: AdSquare(
                adSize: AdBoxSize.largeBanner,
                showPlaceholder: false,
                screenName: 'calendar',
              ),
            ),
          ],
        ),
      );
    }

    // ▼ 実績あり：カードは「実績」1枚のみ。タップで簡易一覧を展開
    final unit = SettingsManager.currentUnit;
    final String selKey = _dateKey(_selectedDay ?? DateTime.now());

    final List<Widget> summaryChildren = [];

    // ===== パーソナル用の素材値 =====
    final double? bodyFatVal = record?.bodyFatPercent; // %
    final double? waistValCm = record?.waistCm;        // cm
    double? bmiVal;
    if (record?.weight != null) {
      final w = record!.weight!;
      final h = _heightMetersFromSettings() ?? _heightMetersFromRecord(record);
      if (h != null && h > 0) {
        bmiVal = _toKg(w) / (h * h);
      }
    }

    bool _menuHasAnyData(m) {
      final len = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
      for (int i = 0; i < len; i++) {
        final w = m.weights[i].toString().trim();
        final r = m.reps[i].toString().trim();
        if (w.isNotEmpty || r.isNotEmpty) return true;
      }
      if ((m.distance?.trim().isNotEmpty ?? false) || (m.duration?.trim().isNotEmpty ?? false)) {
        return true;
      }
      return false;
    }

    // ===== 1) 有酸素 =====
    // null を空リストに正規化して以降を非nullで扱う
    final List<MenuData> aerobicMenus =
        (record?.menus['有酸素運動'] as List<MenuData>?) ?? const <MenuData>[];

    if (aerobicMenus.any(_menuHasAnyData)) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, '有酸素運動')}',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      final dynamic satAllRaw = widget.settingsBox.get('satisfaction-$selKey');
      final Map<String, dynamic> satAll = (satAllRaw is Map<String, dynamic>) ? satAllRaw : {};

      for (final m in aerobicMenus) {
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                m.name,
                textAlign: TextAlign.left,
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        );

        if ((m.distance?.trim().isNotEmpty ?? false)) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.distance}: ${_formatDistance(m.distance, l10n)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                ),
              ),
            ),
          );
        }
        if ((m.duration?.trim().isNotEmpty ?? false)) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.time}: ${_formatDurationHM(context, m.duration, l10n)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                ),
              ),
            ),
          );
        }

        final Map partSat = (satAll['有酸素運動'] is Map) ? satAll['有酸素運動'] as Map : const {};
        final int? satVal = partSat[m.name] is int ? partSat[m.name] as int : null;
        if (satVal != null) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _satisfactionLine(l10n, satVal, colorScheme),
              ),
            ),
          );
        }
      }
      summaryChildren.add(const SizedBox(height: 8));
    }

    // ===== 2) トレーニング（有酸素以外） =====
    record?.menus.forEach((originalPart, menuList) {
      if (originalPart == '有酸素運動') return;

      bool partHasData = false;
      for (final m in menuList) {
        if (_menuHasAnyData(m)) { partHasData = true; break; }
      }
      if (!partHasData) return;

      final partTitle = _translatePartToLocale(context, originalPart);
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■$partTitle',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );

      final dynamic satAllRaw = widget.settingsBox.get('satisfaction-$selKey');
      final Map<String, dynamic> satAll = (satAllRaw is Map<String, dynamic>) ? satAllRaw : {};

      for (final m in menuList) {
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                m.name,
                textAlign: TextAlign.left,
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        );

        final setCount = (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
        for (int i = 0; i < setCount; i++) {
          final wStr = m.weights[i].toString().trim();
          final rStr = m.reps[i].toString().trim();
          if (wStr.isEmpty && rStr.isEmpty) continue;
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${i + 1}${l10n.sets}：'
                      '${wStr.isNotEmpty ? '$wStr${unit == 'kg' ? l10n.kg : l10n.lbs}' : '-'}'
                      ' × '
                      '${rStr.isNotEmpty ? rStr : '-'}${l10n.reps}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                ),
              ),
            ),
          );
        }

        final Map partSat = (satAll[originalPart] is Map) ? satAll[originalPart] as Map : const {};
        final int? satVal = partSat[m.name] is int ? partSat[m.name] as int : null;
        if (satVal != null) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _satisfactionLine(l10n, satVal, colorScheme),
              ),
            ),
          );
        }
      }
      summaryChildren.add(const SizedBox(height: 8));
    });

    // ===== メモ（任意） =====
    if (hasMemo) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            l10n.memo,
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
          child: Text(
            memoText!,
            textAlign: TextAlign.left,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14, height: 1.3),
          ),
        ),
      );
    }

    // ===== 3) パーソナル =====
    final bool hasPersonal = (record?.weight != null) || (bodyFatVal != null) || (waistValCm != null) || (bmiVal != null);
    if (hasPersonal) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            '■${l10n.personal}',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
      if (record?.weight != null) {
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${l10n.bodyWeight}: ${record!.weight!.toStringAsFixed(1)} $unit',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      }
      if (bodyFatVal != null) {
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${l10n.bodyFatPercentage}: ${bodyFatVal.toStringAsFixed(1)} ${l10n.percentSymbol}',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      }
      if (waistValCm != null) {
        final formatted = _formatWaistForDisplay(waistValCm);
        final String unitLabel = (formatted.unit == 'in') ? l10n.unitIn : l10n.unitCm;
        final String waistText =
            '${l10n.waist}: ${formatted.value.toStringAsFixed(1)} $unitLabel';

        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                waistText,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      }
      if (bmiVal != null) {
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${l10n.bmi}: ${bmiVal.toStringAsFixed(1)}',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      }
      summaryChildren.add(const SizedBox(height: 8));
    }

// ===== 4) 基準（従来の表記） =====
    final String? gender = _getUserGender();
    final List<Widget> stdWidgets = [];
    final TextStyle stdStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 11,
      height: 1.15,
    );

    if (bodyFatVal != null) {
      if (gender != null) {
        final std = _standardsForGender(gender)!;
        stdWidgets.add(Text(
          '${l10n.bodyFatPercentage}: ${std['bfMin']!.toStringAsFixed(1)}〜${std['bfMax']!.toStringAsFixed(1)}（${l10n.percentSymbol}）',
          style: stdStyle,
          textAlign: TextAlign.left,
        ));
      } else {
        final m = _standardsForGender('male')!;
        final f = _standardsForGender('female')!;
        stdWidgets.add(Text(
          '${l10n.bodyFatPercentage}: ${l10n.maleShort} ${m['bfMin']!.toStringAsFixed(1)}〜${m['bfMax']!.toStringAsFixed(1)} / '
              '${l10n.femaleShort} ${f['bfMin']!.toStringAsFixed(1)}〜${f['bfMax']!.toStringAsFixed(1)}（${l10n.percentSymbol}）',
          style: stdStyle,
          textAlign: TextAlign.left,
        ));
      }
    }

    if (waistValCm != null) {
      if (gender != null) {
        final std = _standardsForGender(gender)!;
        stdWidgets.add(Text(
          '${l10n.waist}: ${std['waistStd']!.toStringAsFixed(0)}（${l10n.unitCm}）',
          style: stdStyle,
          textAlign: TextAlign.left,
        ));
      } else {
        final m = _standardsForGender('male')!;
        final f = _standardsForGender('female')!;
        stdWidgets.add(Text(
          '${l10n.waist}: ${l10n.maleShort} ${m['waistStd']!.toStringAsFixed(0)} / '
              '${l10n.femaleShort} ${f['waistStd']!.toStringAsFixed(0)}（${l10n.unitCm}）',
          style: stdStyle,
          textAlign: TextAlign.left,
        ));
      }
    }

    if (bmiVal != null) {
      final bmiMin = (widget.settingsBox.get('bmiRangeMin') as num?)?.toDouble() ?? 18.5;
      final bmiMax = (widget.settingsBox.get('bmiRangeMax') as num?)?.toDouble() ?? 25.0;
      stdWidgets.add(Text(
        '${l10n.bmi}: ${bmiMin.toStringAsFixed(1)}〜${bmiMax.toStringAsFixed(1)}',
        style: stdStyle,
        textAlign: TextAlign.left,
      ));
    }

    if (stdWidgets.isNotEmpty) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.standards,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                ...stdWidgets.map((w) => Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: w,
                )),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.only(top: 0.0),
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              dividerColor: Colors.transparent,
            ),
            child: Card(
              color: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 4,
              clipBehavior: Clip.none,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                title: Text(
                  l10n.results,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                onTap: () => _showResultsDialog(context, summaryChildren),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
