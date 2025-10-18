// lib/screens/calendar_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:home_widget/home_widget.dart';
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../models/meal.dart';
import '../widgets/ad_banner.dart';
import '../settings_manager.dart';
import '../utils/training_display_utils.dart';
import 'record_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';
import '../routes/slide_up_route.dart';
import '../widgets/centered_constrained.dart';
import '../widgets/big_earning_ad.dart';
import '../widgets/calendar_widget_view.dart';

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

// === 空データ時の画像選択（曜日・特別日付） ===
// 画像は assets/calendar_empty/ 配下に配置してください（pubspec.yaml 登録が必要）。
const Map<int, String> _weekdayEmptyAssets = {
  DateTime.monday: 'assets/calendar/mon.png',
  DateTime.tuesday: 'assets/calendar/tue.png',
  DateTime.wednesday: 'assets/calendar/wed.png',
  DateTime.thursday: 'assets/calendar/thu.png',
  DateTime.friday: 'assets/calendar/fri.png',
  DateTime.saturday: 'assets/calendar/sat.png',
  DateTime.sunday: 'assets/calendar/sun.png',
};

// 年をまたいで使える特別日（MM-dd）
const Map<String, String> _specialEmptyAssetsByMonthDay = {
  // '01-01': 'assets/calendar_empty/newyear.png',
  // '12-25': 'assets/calendar_empty/xmas.png',
};

// 固定年月日（yyyy-MM-dd）
const Map<String, String> _specialEmptyAssetsByDate = {
  // '2025-09-22': 'assets/calendar_empty/event.png',
};

String two(int n) => n.toString().padLeft(2, '0');

String _emptyStateAssetFor(DateTime d) {
  final ymd = '${d.year}-${two(d.month)}-${two(d.day)}';
  final md = '${two(d.month)}-${two(d.day)}';
  if (_specialEmptyAssetsByDate.containsKey(ymd)) {
    return _specialEmptyAssetsByDate[ymd]!;
  }
  if (_specialEmptyAssetsByMonthDay.containsKey(md)) {
    return _specialEmptyAssetsByMonthDay[md]!;
  }
  return _weekdayEmptyAssets[d.weekday] ??
      'assets/illustrations/empty/calendar/default.png';
}

// 空画像の実体解決（存在チェック → default → 無ければ空文字でアイコンフォールバック）
Future<String> _calendarResolveEmptyAsset(DateTime d) async {
  final primary = _emptyStateAssetFor(d);
  try {
    await rootBundle.load(primary);
    return primary;
  } catch (_) {
    const fallback = 'assets/illustrations/empty/calendar/default.png';
    try {
      await rootBundle.load(fallback);
      return fallback;
    } catch (_) {
      return ''; // アイコン表示にフォールバック
    }
  }
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 空データ用画像の実体解決（存在チェックしてフォールバック）

  final GlobalKey _kCalendarCard = GlobalKey();
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // 写真有無キャッシュ（key = yyyy-MM-dd）
  final Map<String, bool> _photoCache = {};

  bool _widgetRefreshScheduled = false;

  bool get _shouldUpdateHomeWidget => false;

  double _clampDouble(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  EdgeInsets _scaledHeaderPadding(
      double chipScale, double scaleFactor, bool compact) {
    final double horizontal = _clampDouble(
      16.0 * chipScale * (0.7 + scaleFactor * 0.3) * (compact ? 0.92 : 1.0),
      8.0,
      20.0,
    );
    final double vertical = _clampDouble(
      (compact ? 10.0 : 12.0) * chipScale * (0.75 + scaleFactor * 0.25),
      6.0,
      14.0,
    );
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  int _maxChipRowsFor(double chipScale, bool forWidgetCapture) {
    if (!forWidgetCapture) {
      return chipScale >= 0.9 ? 4 : (chipScale >= 0.7 ? 3 : 2);
    }
    if (chipScale >= 0.95) {
      return 4;
    }
    if (chipScale >= 0.8) {
      return 3;
    }
    if (chipScale >= 0.65) {
      return 2;
    }
    return 1;
  }

  DateTime _firstCalendarDay(DateTime month) {
    final DateTime first = DateTime(month.year, month.month, 1);
    final int daysToSubtract = (first.weekday + 6) % 7; // Monday start
    return first.subtract(Duration(days: daysToSubtract));
  }

  CalendarWidgetDayData _buildHomeWidgetDayData(
    DateTime day,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    DateTime today,
    BuildContext context,
  ) {
    _ensurePhotoFlag(day);
    final bool hasPhoto = _photoCache[_dateKey(day)] ?? false;
    final DailyRecord? record = widget.recordsBox.get(_dateKey(day));
    final bool hasMemo = _hasMemoForDate(day);
    final bool hasMeal = _hasMealForRecord(record);
    final bool hasWeight = record?.weight != null;
    final List<String> partsAll =
        (record == null) ? <String>[] : _partsWithDataForDay(record);
    final Iterable<String> strengthParts = partsAll.where((p) => p != '有酸素運動');
    final bool hasAerobic = partsAll.contains('有酸素運動');

    final List<CalendarWidgetChipData> chips = [];

    Color chipTextColor(Color background) {
      return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : Colors.black87;
    }

    for (final part in strengthParts) {
      final String label = _translatePartToLocale(context, part);
      final Color bg = _colorForPart(part, colorScheme);
      chips.add(
        CalendarWidgetChipData(
          label: label,
          backgroundColor: bg,
          textColor: chipTextColor(bg),
        ),
      );
    }

    if (hasAerobic) {
      final String label = _translatePartToLocale(context, '有酸素運動');
      final Color bg = _colorForPart('有酸素運動', colorScheme);
      chips.add(
        CalendarWidgetChipData(
          label: label,
          backgroundColor: bg,
          textColor: chipTextColor(bg),
        ),
      );
    }

    if (hasMemo) {
      chips.add(
        CalendarWidgetChipData(
          label: l10n.memo,
          backgroundColor: colorScheme.tertiaryContainer,
          textColor: colorScheme.onTertiaryContainer,
        ),
      );
    }

    if (hasMeal) {
      chips.add(
        CalendarWidgetChipData(
          label: l10n.meal,
          backgroundColor: colorScheme.surfaceVariant,
          textColor: colorScheme.onSurface,
        ),
      );
    }

    if (hasWeight) {
      chips.add(
        CalendarWidgetChipData(
          label: l10n.bodyWeight,
          backgroundColor: colorScheme.secondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
        ),
      );
    }

    if (hasPhoto) {
      chips.add(
        CalendarWidgetChipData(
          label: l10n.photos,
          backgroundColor: colorScheme.primaryContainer,
          textColor: colorScheme.onPrimaryContainer,
        ),
      );
    }

    final bool hasContent = hasMemo ||
        hasMeal ||
        hasWeight ||
        hasPhoto ||
        partsAll.isNotEmpty ||
        (record != null && _hasAnyData(record));

    return CalendarWidgetDayData(
      date: day,
      inMonth: day.month == _focusedDay.month,
      isToday: _sameDate(day, today),
      hasContent: hasContent,
      chips: chips,
    );
  }

  String _widgetMonthLabel(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.MMM(localeTag);
    return formatter.format(_focusedDay);
  }

  void _requestWidgetRefresh() {
    if (!_shouldUpdateHomeWidget) {
      return;
    }
    if (_widgetRefreshScheduled) {
      return;
    }
    _widgetRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _widgetRefreshScheduled = false;
        return;
      }
      _widgetRefreshScheduled = false;
      _updateHomeWidget();
    });
  }

  Future<void> _updateHomeWidget() async {
    if (!_shouldUpdateHomeWidget) {
      return;
    }
    final BuildContext? cardContext = _kCalendarCard.currentContext;
    if (cardContext == null) {
      return;
    }

    final RenderBox? box = cardContext.findRenderObject() as RenderBox?;
    final Size? cardSize = box?.size;
    if (cardSize == null || cardSize.width <= 0 || cardSize.height <= 0) {
      return;
    }

    final MediaQueryData mediaQuery = MediaQuery.of(cardContext);
    final Locale locale = Localizations.localeOf(cardContext);
    final ThemeData theme = Theme.of(cardContext);
    final TextDirection direction = Directionality.of(cardContext);

    final int? widgetMinWidthDp =
        await HomeWidget.getWidgetData<int>('calendar_widget_min_width');
    final int? widgetMaxWidthDp =
        await HomeWidget.getWidgetData<int>('calendar_widget_max_width');
    final int? widgetMinHeightDp =
        await HomeWidget.getWidgetData<int>('calendar_widget_min_height');
    final int? widgetMaxHeightDp =
        await HomeWidget.getWidgetData<int>('calendar_widget_max_height');

    const double minWidgetWidth = 120.0;
    const double minWidgetHeight = 120.0;

    final int? storedFixedWidthDp =
        await HomeWidget.getWidgetData<int>('calendar_widget_fixed_width');
    double captureWidth = storedFixedWidthDp?.toDouble() ??
        (widgetMaxWidthDp ?? widgetMinWidthDp)?.toDouble() ??
        cardSize.width;
    if (captureWidth < minWidgetWidth) {
      captureWidth = minWidgetWidth;
    }

    double captureHeight =
        (widgetMinHeightDp ?? widgetMaxHeightDp)?.toDouble() ?? cardSize.height;
    if (captureHeight <= 0) {
      captureHeight = cardSize.height;
    }
    final double minHeightByWidth = captureWidth * 0.72;
    final double minHeightTarget =
        minHeightByWidth > minWidgetHeight ? minHeightByWidth : minWidgetHeight;
    final double maxHeightTarget = cardSize.height * 1.2;
    final double heightUpper =
        maxHeightTarget < minHeightTarget ? minHeightTarget : maxHeightTarget;
    captureHeight = _clampDouble(
      captureHeight,
      minHeightTarget,
      heightUpper,
    );

    final Size captureSize = Size(captureWidth, captureHeight);

    final Widget capture = MediaQuery(
      data: mediaQuery,
      child: Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: Theme(
          data: theme,
          child: Directionality(
            textDirection: direction,
            child: Builder(
              builder: (ctx) {
                final ColorScheme cs = Theme.of(ctx).colorScheme;
                final AppLocalizations l10n = AppLocalizations.of(ctx)!;
                final DateTime today = DateTime.now();
                final DateTime start = _firstCalendarDay(_focusedDay);
                final String localeTag = locale.toLanguageTag();
                final DateFormat weekdayFormat = DateFormat.E(localeTag);

                final List<String> weekdayLabels = List.generate(7, (index) {
                  final DateTime weekday = start.add(Duration(days: index));
                  final String label = weekdayFormat.format(weekday);
                  return label.length <= 3 ? label : label.substring(0, 3);
                });

                final List<CalendarWidgetDayData> dayEntries =
                    List<CalendarWidgetDayData>.generate(42, (index) {
                  final DateTime day = start.add(Duration(days: index));
                  return _buildHomeWidgetDayData(
                    day,
                    cs,
                    l10n,
                    today,
                    ctx,
                  );
                });

                final String monthLabel = _widgetMonthLabel(ctx);
                final String yearLabel =
                    DateFormat.y(localeTag).format(_focusedDay);

                return SizedBox(
                  width: captureSize.width,
                  height: captureSize.height,
                  child: CalendarWidgetView(
                    monthLabel: monthLabel,
                    yearLabel: yearLabel,
                    weekdayLabels: weekdayLabels,
                    days: dayEntries,
                    colorScheme: cs,
                    width: captureSize.width,
                    height: captureSize.height,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final double pixelRatio = mediaQuery.devicePixelRatio.clamp(1.0, 3.5);

    try {
      await HomeWidget.renderFlutterWidget(
        capture,
        key: 'calendar_widget',
        logicalSize: captureSize,
        pixelRatio: pixelRatio,
      );

      await HomeWidget.updateWidget(
        name: 'CalendarWidgetProvider',
        qualifiedAndroidName:
            'com.yourname.ttrainingrecord.CalendarWidgetProvider',
      );
    } catch (err, stack) {
      if (kDebugMode) {
        // 開発時のトレース確認用
        debugPrint('Calendar widget update failed: $err');
        debugPrint('$stack');
      }
    }
  }

  // --- 部位→色マップ ---
  static const Map<String, Color> _partColors = {
    '有酸素運動': Colors.purple,
    '腕': Colors.blue,
    '胸': Colors.red,
    '背中': Colors.teal,
    '肩': Colors.amber,
    '足': Colors.green,
    '腹筋': Colors.pink,
    '全身': Colors.orange,
    '自重': Colors.indigo,
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

    _focusedDay =
        DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );

    // 初回のみ：中央ウェルカムカード（2ステップ）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen =
          widget.settingsBox.get('hint_seen_calendar') as bool? ?? false;
      if (seen) return;

      await _showWelcomeCardSequence(context);
      await widget.settingsBox.put('hint_seen_calendar', true);
    });

    SettingsManager.showRmNotifier.addListener(_onDisplayToggleChanged);
    SettingsManager.showRirNotifier.addListener(_onDisplayToggleChanged);
    SettingsManager.showFailNotifier.addListener(_onDisplayToggleChanged);
  }

  @override
  void dispose() {
    SettingsManager.showRmNotifier.removeListener(_onDisplayToggleChanged);
    SettingsManager.showRirNotifier.removeListener(_onDisplayToggleChanged);
    SettingsManager.showFailNotifier.removeListener(_onDisplayToggleChanged);
    super.dispose();
  }

  bool _isPastDate(DateTime d) {
    final DateTime t = DateTime.now();
    final DateTime a = DateTime(d.year, d.month, d.day);
    final DateTime b = DateTime(t.year, t.month, t.day);
    return a.isBefore(b);
  }

  void _onDisplayToggleChanged() {
    if (!mounted) return;
    setState(() {});
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
          style: TextStyle(color: cs.onSurface, fontSize: 16),
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

  String _satisfactionLabel(int value, AppLocalizations l10n) {
    switch (value) {
      case 0:
        return l10n.satisfactionBad;
      case 1:
        return l10n.satisfactionOkay;
      default:
        return l10n.satisfactionGood;
    }
  }

  // ---------- Helpers ----------
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasAnyTrainingData(DailyRecord r) {
    for (final entry in r.menus.entries) {
      for (final m in entry.value) {
        final len = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        for (var i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final p = m.reps[i].toString().trim();
          if (w.isNotEmpty || p.isNotEmpty) return true;
        }
        if ((m.distance?.trim().isNotEmpty ?? false) ||
            (m.duration?.trim().isNotEmpty ?? false)) {
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
    if (_hasMealForRecord(r)) return true;
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
      case '腹筋':
        return l10n.abs;
      case '全身':
        return l10n.fullBody;
      case '自重':
        return l10n.bodyWeightTraining;
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

  String _failureTag(AppLocalizations l10n) {
    final locale = l10n.localeName;
    if (locale.startsWith('ja')) {
      return '(失敗)';
    }
    if (locale.startsWith('es')) {
      return '(Fallo)';
    }
    if (locale.startsWith('id')) {
      return '(Gagal)';
    }
    return '(Fail)';
  }

  Future<void> _showWelcomeCardSequence(BuildContext context) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 記録画面のヒントに合わせた色合い（青背景＋白文字）
    const Color _hintBlue = Color(0xFF2563EB); // brand-like blue
    const Color _hintFg = Colors.white;

    int step = 0;
    bool closed = false;

    await showGeneralDialog(
      context: context,
      barrierLabel: 'welcome',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 360),
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // 自動遷移は無し。タップでのみ進む/閉じる。
            final String message =
                (step == 0) ? l10n.welcomeThankYou : l10n.hintTapPlus;

            void nextOrClose() {
              if (step == 0) {
                setState(() => step = 1);
              } else {
                closed = true;
                Navigator.of(ctx).pop();
              }
            }

            return GestureDetector(
              onTap: nextOrClose, // 画面外側タップでも進む/閉じる（不要ならこの行を削除）
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: GestureDetector(
                    onTap: nextOrClose, // カード本体タップで次へ/閉じる
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                      decoration: BoxDecoration(
                        color: _hintBlue, // ★ 青背景
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: _hintFg, // ★ 白文字
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 「5.3」→「5km300m」
  // 「5.3」→ 「5km300m」 または 「3mi  720yd」
  String _formatDistance(String? raw, AppLocalizations l10n) {
    if (raw == null) return '-';
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return '-';
    final dKm = double.tryParse(normalized);
    if (dKm == null || dKm <= 0) return '-';

    final useImperial = (SettingsManager.currentLengthUnit == 'mi' ||
            SettingsManager.currentLengthUnit == 'mile') ||
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

  String _formatDurationHM(
      BuildContext context, String? raw, AppLocalizations l10n) {
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
    if (sec > 0) {
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
    for (final k in [
      'waistUnit',
      'lengthUnit',
      'unitLength',
      'personal.lengthUnit'
    ]) {
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
      if (s.startsWith('female') || s == 'f' || s.contains('女'))
        return 'female';
    }
    for (final k in ['user_gender', 'gender', 'sex', '性別']) {
      final v = widget.settingsBox.get(k);
      if (v is String) {
        final s = v.toLowerCase();
        if (s.contains('male') ||
            s.contains('man') ||
            s == 'm' ||
            s.contains('男')) return 'male';
        if (s.contains('female') ||
            s.contains('woman') ||
            s == 'f' ||
            s.contains('女')) return 'female';
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
          'bodyFat' => dyn.bodyFat,
          'fatPercent' => dyn.fatPercent,
          'waistCm' => dyn.waistCm,
          'waist' => dyn.waist,
          'waist_cm' => dyn.waist_cm,
          _ => null,
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

  String _bodyFatRangeText(String gender) =>
      gender == 'male' ? '10〜20' : '20〜30';

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

  double _toKg(double w) =>
      (SettingsManager.currentUnit == 'kg') ? w : (w * 0.45359237);

// --- 距離表示用 ---
  double _kmToDisplay(double km) =>
      (SettingsManager.currentLengthUnit == 'mile') ? km * 0.6213711922 : km;

  String _distanceUnitLabel(AppLocalizations l10n) =>
      (SettingsManager.currentLengthUnit == 'mile') ? l10n.mile : l10n.km;

  Map<String, double>? _standardsForGender(String gender) {
    final bmiMin =
        (widget.settingsBox.get('bmiRangeMin') as num?)?.toDouble() ?? 18.5;
    final bmiMax =
        (widget.settingsBox.get('bmiRangeMax') as num?)?.toDouble() ?? 25.0;
    double bfMin =
        (widget.settingsBox.get('bodyFatRangeMin') as num?)?.toDouble() ??
            (gender == 'male' ? 10.0 : 20.0);
    double bfMax =
        (widget.settingsBox.get('bodyFatRangeMax') as num?)?.toDouble() ??
            (gender == 'male' ? 20.0 : 30.0);
    double waistStd;
    final keyGender = gender == 'male' ? 'waistStdMaleCm' : 'waistStdFemaleCm';
    final gVal = widget.settingsBox.get(keyGender);
    if (gVal is num) {
      waistStd = gVal.toDouble();
    } else {
      final anyVal = widget.settingsBox.get('waistStdCm');
      waistStd = (anyVal is num)
          ? anyVal.toDouble()
          : (gender == 'male' ? 85.0 : 90.0);
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

  double? _scanRecordMaps(
      dynamic r, List<String> mapProps, List<String> tokenVariants) {
    for (final prop in mapProps) {
      try {
        final dynamic m = switch (prop) {
          'extras' => (r as dynamic).extras,
          'extra' => (r as dynamic).extra,
          'metrics' => (r as dynamic).metrics,
          'personal' => (r as dynamic).personal,
          'stats' => (r as dynamic).stats,
          'attributes' => (r as dynamic).attributes,
          _ => null,
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
        final len = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        for (int i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final p = m.reps[i].toString().trim();
          if (w.isNotEmpty || p.isNotEmpty) {
            has = true;
            break;
          }
        }
        if ((m.distance?.trim().isNotEmpty ?? false) ||
            (m.duration?.trim().isNotEmpty ?? false)) {
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

  bool _hasMealForRecord(DailyRecord? record) {
    final meals = record?.meals;
    if (meals == null || meals.isEmpty) {
      return false;
    }
    for (final entry in meals) {
      if (entry is! Map) continue;
      final subtotal = entry['subtotal'];
      if (subtotal is num && subtotal > 0) return true;
      if (subtotal is String && double.tryParse(subtotal) != null) {
        final parsed = double.tryParse(subtotal);
        if ((parsed ?? 0) > 0) return true;
      }
      final items = entry['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            final name = item['name']?.toString() ?? '';
            final kcal = item['kcal'];
            if (name.trim().isNotEmpty) return true;
            if (kcal is num && kcal > 0) return true;
            if (kcal is String) {
              final parsed = double.tryParse(kcal);
              if ((parsed ?? 0) > 0) return true;
            }
          }
        }
      }
    }
    return true;
  }

  double _totalMealKcalForRecord(DailyRecord? record) {
    final meals = record?.meals;
    if (meals == null) return 0;
    double total = 0;
    for (final entry in meals) {
      if (entry is! Map) continue;
      final subtotal = entry['subtotal'];
      if (subtotal is num) {
        total += subtotal.toDouble();
      } else if (subtotal is String) {
        final parsed = double.tryParse(subtotal);
        if (parsed != null) {
          total += parsed;
        }
      }
    }
    return total;
  }

  Map<MealCategory, double> _mealCalorieBreakdown(DailyRecord? record) {
    final Map<MealCategory, double> totals = {
      for (final category in MealCategory.values) category: 0,
    };
    final meals = record?.meals;
    if (meals == null) return totals;
    for (final entry in meals) {
      if (entry is! Map) continue;
      final category =
          _mealCategoryFromSerialized(entry['category'] as String?);
      double subtotal = 0;
      final rawSubtotal = entry['subtotal'];
      if (rawSubtotal is num) {
        subtotal = rawSubtotal.toDouble();
      } else if (rawSubtotal is String) {
        subtotal = double.tryParse(rawSubtotal) ?? 0;
      }
      if (subtotal <= 0) {
        final items = entry['items'];
        if (items is List) {
          for (final item in items) {
            if (item is! Map) continue;
            final kcal = item['kcal'];
            double? parsed;
            if (kcal is num) {
              parsed = kcal.toDouble();
            } else if (kcal is String) {
              parsed = double.tryParse(kcal);
            }
            if (parsed != null) {
              subtotal += parsed;
            }
          }
        }
      }
      if (subtotal <= 0) continue;
      totals[category] = (totals[category] ?? 0) + subtotal;
    }
    return totals;
  }

  MealCategory _mealCategoryFromSerialized(String? value) {
    switch (value) {
      case 'noon':
        return MealCategory.noon;
      case 'evening':
        return MealCategory.evening;
      case 'snack':
        return MealCategory.snack;
      case 'morning':
      default:
        return MealCategory.morning;
    }
  }

  String _mealCategoryLabel(AppLocalizations l10n, MealCategory category) {
    switch (category) {
      case MealCategory.morning:
        return l10n.mealMorning;
      case MealCategory.noon:
        return l10n.mealNoon;
      case MealCategory.evening:
        return l10n.mealEvening;
      case MealCategory.snack:
        return l10n.mealSnack;
    }
  }

  double _totalAerobicCalories(DailyRecord? record) {
    if (record == null) return 0;
    final aerobicMenus = record.menus['有酸素運動'];
    if (aerobicMenus == null) return 0;
    double total = 0;
    for (final m in aerobicMenus) {
      final text = m.calories?.trim();
      if (text == null || text.isEmpty) continue;
      final parsed = double.tryParse(text.replaceAll(',', ''));
      if (parsed != null) {
        total += parsed;
      }
    }
    return total;
  }

  double? _heightCmFromSettings() {
    final candidates = [
      widget.settingsBox.get('personal.heightCm'),
      widget.settingsBox.get('height_cm'),
      widget.settingsBox.get('heightCm'),
      widget.settingsBox.get('user_height_cm'),
      widget.settingsBox.get('height'),
    ];
    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    final personalMeters = widget.settingsBox.get('personal.heightM');
    if (personalMeters is num) return personalMeters.toDouble() * 100;
    if (personalMeters is String) {
      final parsed = double.tryParse(personalMeters);
      if (parsed != null) return parsed * 100;
    }

    final meters = widget.settingsBox.get('height_m');
    if (meters is num) return meters.toDouble() * 100;
    if (meters is String) {
      final parsed = double.tryParse(meters);
      if (parsed != null) return parsed * 100;
    }

    return null;
  }

  DateTime? _birthDateFromSettings() {
    final stored = widget.settingsBox.get('personal.birthDate');
    if (stored is DateTime) return stored;
    if (stored is String) {
      return DateTime.tryParse(stored);
    }
    return null;
  }

  String? _genderForBmr() {
    final candidates = [
      widget.settingsBox.get('personal.gender'),
      widget.settingsBox.get('gender'),
    ];
    for (final value in candidates) {
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower.contains('male') || lower.contains('男')) return 'male';
        if (lower.contains('female') || lower.contains('女')) return 'female';
      }
    }
    return null;
  }

  int? _ageFromBirth(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final hadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) {
      age -= 1;
    }
    if (age < 0) return null;
    return age;
  }

  double? _calculateBmrForRecord(DailyRecord? record) {
    if (record == null) return null;
    if (record.bmr != null) return record.bmr;

    double? weightKg;
    if (record.weight != null) {
      weightKg = SettingsManager.currentUnit == 'kg'
          ? record.weight
          : record.weight! * 0.45359237;
    } else {
      weightKg = SettingsManager.personalWeightKg;
    }

    final heightCm = _heightCmFromSettings();
    final birthDate = _birthDateFromSettings();
    final gender = _genderForBmr();
    if (weightKg == null ||
        heightCm == null ||
        birthDate == null ||
        gender == null) {
      return null;
    }
    final age = _ageFromBirth(birthDate);
    if (age == null) return null;

    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final offset = gender == 'male' ? 5 : -161;
    final result = base + offset;
    if (!result.isFinite) return null;
    return result;
  }

  String _formatKcalNumber(double value) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(value.round());
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
        if (p.endsWith('.jpg') ||
            p.endsWith('.jpeg') ||
            p.endsWith('.png') ||
            p.endsWith('.heic')) {
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

  // 4情報を想定した基本行高を算出
  double _baseRowHeight(BuildContext context) {
    const double topPad = 6.0;
    final double dayFont =
        Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14.0;
    final double dayLine = dayFont * 1.2;

    const double chipFont = 10.0;
    const double chipLine = chipFont * 1.1;
    const double chipVPad = 2.0;
    const double chipH = chipLine + chipVPad * 2;
    const int chipRows = 4;
    const double gapPerRow = 2.0;
    final double gaps = gapPerRow * (chipRows + 1);

    const double safety = 6.0;
    return (topPad + dayLine + chipH * chipRows + gaps + safety).ceilToDouble();
  }

  // セル描画
  Widget _buildDayCell(BuildContext context, DateTime day,
      {required Color textColor,
      bool selected = false,
      bool showEventsForOutOfMonth = false,
      double chipScale = 1.0,
      double? cellHeight,
      required int maxChipRows,
      bool compactMode = false}) {
    final cs = Theme.of(context).colorScheme;

    _ensurePhotoFlag(day);
    final bool hasPhoto = _photoCache[_dateKey(day)] ?? false;

    final record = widget.recordsBox.get(_dateKey(day));
    final partsAll =
        (record == null) ? <String>[] : _partsWithDataForDay(record);

    final strengthParts = partsAll.where((p) => p != '有酸素運動').toList();
    final hasAerobic = partsAll.contains('有酸素運動');
    final hasMemo = _hasMemoForDate(day);
    final hasWeight = record?.weight != null;
    final hasMeal = _hasMealForRecord(record);

    final bool canShowChips = showEventsForOutOfMonth ||
        day.month == _focusedDay.month ||
        record != null ||
        hasMemo ||
        hasPhoto;

    final double chipFontSize = _clampDouble(
      10.0 * chipScale,
      compactMode ? 5.0 : 6.5,
      12.0,
    );
    final double chipVPad = _clampDouble(
      2.0 * chipScale * (compactMode ? 0.85 : 1.0),
      0.6,
      3.0,
    );
    final double chipHPad = _clampDouble(
      6.0 * chipScale * (compactMode ? 0.85 : 1.0),
      3.0,
      8.0,
    );
    final double chipGap = _clampDouble(
      2.0 * chipScale * (compactMode ? 0.7 : 1.0),
      0.6,
      4.0,
    );
    final double chipBoxHeight = chipFontSize * 1.1 + chipVPad * 2;

    Widget _partChip(String part) {
      final label = _translatePartToLocale(context, part);
      final boxColor = _colorForPart(part, cs);
      final textOnBox =
          ThemeData.estimateBrightnessForColor(boxColor) == Brightness.dark
              ? Colors.white
              : Colors.black87;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: chipFontSize,
            height: 1.05,
            color: textOnBox,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Widget _memoChip() => Container(
          padding:
              EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            AppLocalizations.of(context)!.memo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: chipFontSize,
              height: 1.05,
              color: cs.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

    Widget _weightChip() {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.bodyWeight,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: chipFontSize,
            height: 1.05,
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget _mealChip() {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.meal,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: chipFontSize,
            height: 1.05,
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget _photoChip() {
      final cs = Theme.of(context).colorScheme;
      final l10n = AppLocalizations.of(context)!; // l10n

      return Container(
        padding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: chipVPad),
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
            fontSize: chipFontSize,
            height: 1.05,
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final chips = <Widget>[];
    if (canShowChips) {
      chips.addAll(strengthParts.map(_partChip));
      if (hasAerobic) chips.add(_partChip('有酸素運動'));
      if (hasMemo) chips.add(_memoChip());
      if (hasMeal) chips.add(_mealChip());
      if (hasWeight) chips.add(_weightChip());
      if (hasPhoto) chips.add(_photoChip());
    }

    final double baseDayFont =
        Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14.0;
    final double dayFontSize = baseDayFont *
        _clampDouble(
            compactMode ? (0.65 + chipScale * 0.25) : (0.85 + chipScale * 0.15),
            compactMode ? 0.6 : 0.7,
            1.05);
    final double dayLabelHeightEstimate = dayFontSize * 1.25 + 8.0;

    final Color dayNumberColor = (day.weekday == DateTime.sunday)
        ? Colors.red
        : (day.weekday == DateTime.saturday ? Colors.blue : textColor);

    final borderColor =
        selected ? cs.primary.withOpacity(0.40) : cs.primary.withOpacity(0.18);

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.10) : null,
          borderRadius: selected ? BorderRadius.circular(8) : BorderRadius.zero,
          border: Border.all(color: borderColor, width: 0.6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double effectiveCellHeight =
                  cellHeight ?? constraints.maxHeight;
              int capacity = chips.length;
              if (effectiveCellHeight.isFinite && effectiveCellHeight > 0) {
                final double usableForChips =
                    effectiveCellHeight - dayLabelHeightEstimate;
                if (usableForChips <= 0 || (chipBoxHeight + chipGap) <= 0) {
                  capacity = 0;
                } else {
                  capacity =
                      (usableForChips / (chipBoxHeight + chipGap)).floor();
                }
              }

              if (capacity > chips.length) capacity = chips.length;
              if (capacity > maxChipRows) capacity = maxChipRows;
              if (capacity < 0) capacity = 0;
              if (capacity == 0 && chips.isNotEmpty) {
                capacity = 1;
              }

              final List<Widget> displayChips =
                  chips.take(capacity).toList(growable: false);
              final int chipCount = displayChips.length;

              double remainingHeight = 0;
              if (effectiveCellHeight.isFinite && effectiveCellHeight > 0) {
                double usedHeight = dayLabelHeightEstimate;
                if (chipCount > 0) {
                  usedHeight += chipGap;
                  usedHeight += chipCount * chipBoxHeight;
                  if (chipCount > 1) {
                    usedHeight += (chipCount - 1) * chipGap;
                  }
                }
                remainingHeight = effectiveCellHeight - usedHeight;
                if (remainingHeight < 0) remainingHeight = 0;
              }

              final double bottomPad = remainingHeight;

              final List<Widget> children = [];

              children.add(
                _dayLabelTop(context, day,
                    textColor: dayNumberColor, selected: selected),
              );

              if (chipCount > 0) {
                children.add(SizedBox(height: chipGap));
                for (int i = 0; i < chipCount; i++) {
                  children.add(
                    SizedBox(
                      height: chipBoxHeight,
                      width: constraints.maxWidth,
                      child: displayChips[i],
                    ),
                  );
                  if (i != chipCount - 1) {
                    children.add(SizedBox(height: chipGap));
                  }
                }
              }

              if (bottomPad > 0) {
                children.add(SizedBox(height: bottomPad));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                children: children,
              );
            },
          ),
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

    // FAB は常に記録画面を開く（過去日でも編集可能に）
    if (_selectedDay == null || !_sameDate(_selectedDay!, sel)) {
      setState(() {
        _selectedDay = sel;
        _focusedDay = sel;
      });
    }

    await _openRecordSheet(sel);
  }

  Future<void> handleAddAction() => _handleAddPressed();

  // 半角→全角数字（0-9）変換
  String _toZenkakuDigits(String s) {
    const half = '0123456789';
    const full = '０１２３４５６７８９';
    return s.split('').map((ch) {
      final i = half.indexOf(ch);
      return i >= 0 ? full[i] : ch;
    }).join();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SettingsManager.backgroundAssetNotifier.value.isEmpty
          ? null
          : Colors.transparent,

      // ▼ ここで SettingsManager.waistUnitNotifier を監視して即反映
      // ▼ ここで SettingsManager.waistUnitNotifier を監視して即反映
      body: SafeArea(
        top: true,
        bottom: false,
        child: ValueListenableBuilder<String>(
          valueListenable: SettingsManager.waistUnitNotifier,
          builder: (context, __, ___) {
            return ValueListenableBuilder(
              valueListenable: SettingsManager.lengthUnitNotifier,
              builder: (context, ___, ____) {
                return CenteredConstrained(
                  maxWidth: 760,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: ValueListenableBuilder<Box<dynamic>>(
                    valueListenable: widget.settingsBox.listenable(),
                    builder: (context, _settings, __) {
                      return ValueListenableBuilder<Box<DailyRecord>>(
                        valueListenable: widget.recordsBox.listenable(),
                        builder: (context, ____, ___) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AdBanner(screenName: 'calendar'),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _buildCalendar(
                                  context,
                                  cardKey: _kCalendarCard,
                                ),
                              ),
                              const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context, {
    GlobalKey? cardKey,
    bool forWidgetCapture = false,
    double widgetScale = 1.0,
  }) {
    if (_shouldUpdateHomeWidget && !forWidgetCapture) {
      _requestWidgetRefresh();
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: forWidgetCapture ? cardKey : (cardKey ?? _kCalendarCard),
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 4,
      child: Padding(
        // 下の余白を少し詰めて、実画面上の高さを稼ぐ
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double baseRowOriginal = _baseRowHeight(context);
            final double effectiveScale = _clampDouble(widgetScale, 0.55, 1.05);
            final double sizeScale = forWidgetCapture ? effectiveScale : 1.0;
            final double baseRow = baseRowOriginal * sizeScale;
            double rowHeight = baseRow;
            final double available = constraints.maxHeight;

            if (available.isFinite && available > 0) {
              double estimate = rowHeight;
              for (int i = 0; i < 5; i++) {
                final double scale =
                    _clampDouble((estimate / baseRow), 0.3, 1.8);
                final double headerStatic = _clampDouble(
                  (forWidgetCapture ? 32.0 : 44.0) *
                      (0.85 + sizeScale * 0.3) *
                      (scale < 1.0
                          ? (0.8 + scale * 0.2)
                          : (0.95 + (scale - 1.0) * 0.12)),
                  24.0,
                  forWidgetCapture ? 40.0 : 50.0,
                );
                final double dowHeightGuess = _clampDouble(
                  28.0 * scale * (0.85 + sizeScale * 0.25),
                  forWidgetCapture ? 14.0 : 20.0,
                  forWidgetCapture ? 32.0 : 48.0,
                );
                final double headerReserve = headerStatic + dowHeightGuess;
                final double usable = available - headerReserve;
                if (usable <= 0) {
                  estimate = available / 6.0;
                  break;
                }
                final double next = usable / 6.0;
                if ((next - estimate).abs() < 0.5) {
                  estimate = next;
                  break;
                }
                estimate = next;
              }
              rowHeight = estimate;
            }

            if (rowHeight <= 0) {
              rowHeight = baseRow;
            }
            rowHeight = _clampDouble(
              rowHeight,
              26.0,
              baseRowOriginal * 1.45,
            );

            final double chipScale =
                _clampDouble(rowHeight / baseRowOriginal, 0.18, 1.4);
            final double dowHeight = _clampDouble(
              28.0 * chipScale * (0.85 + sizeScale * 0.2),
              forWidgetCapture ? 10.0 : 16.0,
              forWidgetCapture ? 32.0 : 44.0,
            );
            final int maxChipRows =
                _maxChipRowsFor(chipScale, forWidgetCapture);
            final double headerFontBase = forWidgetCapture ? 22.0 : 26.0;
            final double headerFontSize = _clampDouble(
              headerFontBase * (0.75 + sizeScale * 0.45),
              forWidgetCapture ? 14.0 : 18.0,
              headerFontBase,
            );
            final double chevronSize =
                _clampDouble(26.0 * (0.8 + sizeScale * 0.4), 18.0, 28.0);
            final EdgeInsets headerPadding =
                _scaledHeaderPadding(chipScale, sizeScale, forWidgetCapture);
            final bool compactMode = forWidgetCapture && effectiveScale < 0.95;

            final table = TableCalendar<Object>(
              firstDay: DateTime.utc(2015, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focusedDay,
              locale: Localizations.localeOf(context).toString(),
              rowHeight: rowHeight,
              daysOfWeekHeight: dowHeight,
              selectedDayPredicate: (day) =>
                  _selectedDay != null && _sameDate(day, _selectedDay!),
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                    bottom: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.onPrimary.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                ),
                titleTextStyle: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: headerFontSize,
                  height: 1.25,
                  letterSpacing: 0.2,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: colorScheme.onPrimary,
                  size: chevronSize,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onPrimary,
                  size: chevronSize,
                ),
                headerMargin: EdgeInsets.only(
                  bottom: forWidgetCapture ? 10 : 12,
                ),
                headerPadding: headerPadding,
              ),
              headerVisible: !forWidgetCapture,
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: colorScheme.onSurface),
                weekendTextStyle: TextStyle(color: colorScheme.onSurface),
                outsideTextStyle:
                    TextStyle(color: colorScheme.onSurfaceVariant),
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
                    chipScale: chipScale,
                    cellHeight: rowHeight,
                    maxChipRows: maxChipRows,
                    compactMode: compactMode,
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
                    chipScale: chipScale,
                    cellHeight: rowHeight,
                    maxChipRows: maxChipRows,
                    compactMode: compactMode,
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  final cs = Theme.of(context).colorScheme;
                  return _buildDayCell(
                    context,
                    day,
                    textColor: cs.onSurface,
                    selected: false,
                    chipScale: chipScale,
                    cellHeight: rowHeight,
                    maxChipRows: maxChipRows,
                    compactMode: compactMode,
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  final cs = Theme.of(context).colorScheme;
                  return _buildDayCell(
                    context,
                    day,
                    textColor: cs.onSurface,
                    selected: true,
                    chipScale: chipScale,
                    cellHeight: rowHeight,
                    maxChipRows: maxChipRows,
                    compactMode: compactMode,
                  );
                },
              ),
              eventLoader: _eventLoader,
              onDaySelected: (selectedDay, focusedDay) async {
                if (_selectedDay != null &&
                    _sameDate(selectedDay, _selectedDay!)) {
                  final DateTime sel = DateTime(
                      selectedDay.year, selectedDay.month, selectedDay.day);
                  final DailyRecord? rec = widget.recordsBox.get(_dateKey(sel));
                  final List<Widget> summaryChildren =
                      _buildSummaryChildrenForDate(context, sel, rec);
                  final List<String> summaryLines =
                      _buildSummaryLinesForDate(context, sel, rec);
                  await _showResultsDialog(
                      context, summaryChildren, summaryLines, sel);
                  return;
                }

                setState(() {
                  _selectedDay = DateTime(
                      selectedDay.year, selectedDay.month, selectedDay.day);
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
            );

            if (forWidgetCapture) {
              final String monthText = _widgetMonthLabel(context);
              final String yearText =
                  DateFormat.y(Localizations.localeOf(context).toLanguageTag())
                      .format(_focusedDay);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          monthText,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: _clampDouble(
                              16.0 * effectiveScale,
                              11.0,
                              16.0,
                            ),
                            height: 1.2,
                          ),
                        ),
                        Text(
                          yearText,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: _clampDouble(
                              12.0 * effectiveScale,
                              9.0,
                              13.0,
                            ),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: table),
                ],
              );
            }

            return table;
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
    final bool showBmr = SettingsManager.manageBmr;
    final List<Widget> summaryChildren = [];
    final List<Widget> strengthWidgets = [];
    final List<Widget> aerobicWidgets = [];
    final List<Widget> memoWidgets = [];
    final List<Widget> mealWidgets = [];
    final List<Widget> personalWidgets = [];
    final memoText = _getMemoTextForDate(sel);
    final bool hasMemoText = memoText != null && memoText.trim().isNotEmpty;
    final Widget? memoWidget = hasMemoText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _selectableLine(
                text: '■${l10n.memo}',
                padding: const EdgeInsets.only(bottom: 2.0),
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              _selectableLine(
                text: memoText!.trim(),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                padding: const EdgeInsets.only(left: 8.0, bottom: 0),
              ),
              const SizedBox(height: 8),
            ],
          )
        : null;

    if (record == null || !_hasAnyData(record)) {
      if (memoWidget != null) {
        return [memoWidget];
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

    final double mealTotal = _totalMealKcalForRecord(record);
    final bool hasMealSection = _hasMealForRecord(record);
    final double? bmrValue = _calculateBmrForRecord(record);
    final double? intakeMinusBmr =
        bmrValue != null ? (mealTotal - bmrValue) : null;

    bool _menuHasAnyData(MenuData m) {
      final len =
          (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
      for (int i = 0; i < len; i++) {
        final w = m.weights[i].toString().trim();
        final r = m.reps[i].toString().trim();
        if (w.isNotEmpty || r.isNotEmpty) return true;
      }
      if (_hasPositiveDistanceValue(m.distance)) return true;
      if (_hasPositiveDurationValue(m.duration)) return true;
      if ((m.calories?.trim().isNotEmpty ?? false)) return true;
      if (m.totalVolume != null) return true;
      return false;
    }

    // 有酸素
    final List<MenuData> aerobicMenus =
        (record.menus['有酸素運動'] as List<MenuData>?) ?? const <MenuData>[];
    final double aerobicTotal = _totalAerobicCalories(record);
    final double? energyBalance =
        bmrValue != null ? (mealTotal - (bmrValue + aerobicTotal)) : null;
    if (aerobicMenus.any(_menuHasAnyData)) {
      aerobicWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, '有酸素運動')}',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );
      for (final m in aerobicMenus) {
        aerobicWidgets.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        );
        final bool hasDistance = _hasPositiveDistanceValue(m.distance);
        final bool hasDuration = _hasPositiveDurationValue(m.duration);
        if (hasDistance) {
          aerobicWidgets.add(
            _selectableLine(
              text: '${l10n.distance}: ${_formatDistance(m.distance, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
            ),
          );
        }
        if (hasDuration) {
          aerobicWidgets.add(
            _selectableLine(
              text:
                  '${l10n.time}: ${_formatDurationHM(context, m.duration, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
            ),
          );
        }
        if ((m.calories?.trim().isNotEmpty ?? false)) {
          aerobicWidgets.add(
            _selectableLine(
              text: '${l10n.calorie}: ${m.calories} ${l10n.kcalUnit}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
            ),
          );
        }
        if (m.satisfaction != null) {
          aerobicWidgets.add(
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
      aerobicWidgets.add(const SizedBox(height: 8));
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

      strengthWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${_translatePartToLocale(context, originalPart)}',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );

      for (final m in menuList) {
        if (!_menuHasAnyData(m)) continue;

        strengthWidgets.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        );

        final int len = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        final unit = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
        final bool showRmColumn = SettingsManager.showRM;
        final bool showRirColumn = SettingsManager.showRIR;
        final bool showFailColumn = SettingsManager.showFail;
        final bool needsSpaceBeforeReps = l10n.reps.length > 1;
        final String repsSuffix =
            needsSpaceBeforeReps ? ' ${l10n.reps}' : l10n.reps;
        List<String>? rirValues;
        List<bool>? failureStates;
        try {
          final dynamic menuDynamic = m;
          final dynamic rawRir = menuDynamic.rirValues;
          if (rawRir is List) {
            rirValues = rawRir.map((e) => e?.toString() ?? '').toList();
          }
          final dynamic rawFailure = menuDynamic.failureStates;
          if (rawFailure is List) {
            failureStates = rawFailure.map((e) => e == true).toList();
          }
        } catch (_) {
          rirValues = null;
          failureStates = null;
        }

        List<double?>? rmValues;
        double? maxRm;
        if (showRmColumn && len > 0) {
          rmValues = List<double?>.filled(len, null);
          for (int i = 0; i < len; i++) {
            final weightValue = double.tryParse(m.weights[i].toString().trim());
            final repsValue = double.tryParse(m.reps[i].toString().trim());
            if (weightValue != null && repsValue != null) {
              final rm = weightValue * (1 + repsValue / 30);
              rmValues[i] = rm;
              if (maxRm == null || rm > maxRm!) {
                maxRm = rm;
              }
            }
          }
        }

        if (len > 0) {
          strengthWidgets.add(const SizedBox(height: 4));
        }

        for (int i = 0; i < len; i++) {
          final wRaw = m.weights[i].toString().trim();
          final rRaw = m.reps[i].toString().trim();
          final String weightDisplay =
              wRaw.isNotEmpty ? '$wRaw$unit' : '—$unit';
          final String repsDisplay = rRaw.isNotEmpty ? rRaw : '—';
          final double? rm =
              showRmColumn && rmValues != null ? rmValues[i] : null;
          final bool isMaxRm = showRmColumn && rm != null && maxRm != null
              ? (rm - maxRm!).abs() < 1e-6
              : false;

          final buffer = StringBuffer(
              '${i + 1}：$weightDisplay X $repsDisplay$repsSuffix');

          final List<String> extraParts = [];
          if (showRmColumn && rm != null) {
            final String rmText = rm.toStringAsFixed(1);
            extraParts.add('1RM:${rmText}${isMaxRm ? '(MAX)' : ''}');
          }
          if (showRirColumn) {
            final String rirValue = (rirValues != null && i < rirValues.length)
                ? rirValues[i].trim()
                : '';
            if (rirValue.isNotEmpty) {
              extraParts.add('RIR:$rirValue');
            }
          }
          if (showFailColumn) {
            final bool failed =
                (failureStates != null && i < failureStates.length)
                    ? (failureStates[i] == true)
                    : false;
            if (failed) {
              extraParts.add(_failureTag(l10n));
            }
          }
          if (extraParts.isNotEmpty) {
            buffer.write('｜${extraParts.join(' | ')}');
          }

          strengthWidgets.add(
            _selectableLine(
              text: buffer.toString(),
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }
        if (m.totalVolume != null) {
          strengthWidgets.add(
            _selectableLine(
              text:
                  '${l10n.totalVolumeLabel}：${formatTotalVolumeValue(l10n, m.totalVolume)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
            ),
          );
        }
        if (m.satisfaction != null) {
          strengthWidgets.add(
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
      strengthWidgets.add(const SizedBox(height: 8));
    });

    if (hasMealSection) {
      final mealBreakdown = _mealCalorieBreakdown(record);
      mealWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${l10n.meal}',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );
      for (final category in MealCategory.values) {
        final label = _mealCategoryLabel(l10n, category);
        final kcal = mealBreakdown[category] ?? 0;
        mealWidgets.add(
          _selectableLine(
            text: '$label: ${_formatKcalNumber(kcal)} ${l10n.kcalUnit}',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      mealWidgets.add(
        _selectableLine(
          text:
              '${l10n.mealTotalToday}: ${_formatKcalNumber(mealTotal)} ${l10n.kcalUnit}',
          style: TextStyle(color: cs.onSurface, fontSize: 15),
          padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
        ),
      );
      mealWidgets.add(const SizedBox(height: 8));
    }

    // 個人値まとめ（あるものだけ）
    final hasPersonal = (record.weight != null) ||
        (bodyFatVal != null) ||
        (waistValCm != null) ||
        (bmiVal != null) ||
        showBmr;
    if (hasPersonal) {
      personalWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${l10n.personal}',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );
      if (record.weight != null) {
        final unit = SettingsManager.currentUnit;
        personalWidgets.add(
          _selectableLine(
            text:
                '${l10n.bodyWeight}: ${record.weight!.toStringAsFixed(1)} $unit',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bodyFatVal != null) {
        personalWidgets.add(
          _selectableLine(
            text: '${l10n.bodyFat}: ${bodyFatVal!.toStringAsFixed(1)}%',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (waistValCm != null) {
        personalWidgets.add(
          _selectableLine(
            text: '${l10n.waist}: ${_fmtWaist(waistValCm!, l10n)}',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bmiVal != null) {
        personalWidgets.add(
          _selectableLine(
            text: 'BMI: ${bmiVal!.toStringAsFixed(1)}',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (showBmr) {
        final bmrDisplay = bmrValue != null
            ? '${_formatKcalNumber(bmrValue!)} ${l10n.kcalUnit}'
            : '—';
        personalWidgets.add(
          _selectableLine(
            text: '${l10n.bmrTitleShort}: $bmrDisplay',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
        final diffDisplay = intakeMinusBmr != null
            ? '${_formatKcalNumber(intakeMinusBmr)} ${l10n.kcalUnit}'
            : '—';
        personalWidgets.add(
          _selectableLine(
            text: '${l10n.bmrDiffShort}: $diffDisplay',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            padding: const EdgeInsets.only(left: 12.0, bottom: 1.0),
          ),
        );
      }
    }

    if (memoWidget != null) {
      memoWidgets.add(memoWidget);
    }

    summaryChildren
      ..addAll(strengthWidgets)
      ..addAll(aerobicWidgets)
      ..addAll(memoWidgets)
      ..addAll(mealWidgets)
      ..addAll(personalWidgets);

    final shouldShowSummary = showBmr;
    if (shouldShowSummary) {
      summaryChildren.add(const SizedBox(height: 12));
      final balanceText = energyBalance != null
          ? '${_formatKcalNumber(energyBalance)} ${l10n.kcalUnit}'
          : '—';
      final summaryLabel = l10n.dailyBalanceSummary;
      final labelWithColon =
          (summaryLabel.endsWith('：') || summaryLabel.endsWith(':'))
              ? summaryLabel
              : '$summaryLabel:';
      summaryChildren.add(
        _selectableLine(
          text: '$labelWithColon $balanceText',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.only(left: 4.0, bottom: 0),
        ),
      );
    }

    return summaryChildren;
  }

  List<String> _buildSummaryLinesForDate(
    BuildContext context,
    DateTime sel,
    DailyRecord? record,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final bool showBmr = SettingsManager.manageBmr;
    final lines = <String>[];
    final strengthLines = <String>[];
    final aerobicLines = <String>[];
    final memoLines = <String>[];
    final mealLines = <String>[];
    final personalLines = <String>[];

    final memoText = _getMemoTextForDate(sel);

    if (record == null || !_hasAnyData(record)) {
      if (memoText != null && memoText.trim().isNotEmpty) {
        lines.add(memoText.trim());
      }
      return lines;
    }

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

    final double mealTotal = _totalMealKcalForRecord(record);
    final bool hasMealSection = _hasMealForRecord(record);
    final double? bmrValue = _calculateBmrForRecord(record);
    final double? intakeMinusBmr =
        bmrValue != null ? (mealTotal - bmrValue) : null;

    bool _menuHasAnyData(MenuData m) {
      final len =
          (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
      for (int i = 0; i < len; i++) {
        final w = m.weights[i].toString().trim();
        final r = m.reps[i].toString().trim();
        if (w.isNotEmpty || r.isNotEmpty) return true;
      }
      if (_hasPositiveDistanceValue(m.distance)) return true;
      if (_hasPositiveDurationValue(m.duration)) return true;
      if ((m.calories?.trim().isNotEmpty ?? false)) return true;
      if (m.totalVolume != null) return true;
      return false;
    }

    final List<MenuData> aerobicMenus =
        (record.menus['有酸素運動'] as List<MenuData>?) ?? const <MenuData>[];
    final double aerobicTotal = _totalAerobicCalories(record);
    final double? energyBalance =
        bmrValue != null ? (mealTotal - (bmrValue + aerobicTotal)) : null;
    if (aerobicMenus.any(_menuHasAnyData)) {
      final sectionLines = <String>[
        '■${_translatePartToLocale(context, '有酸素運動')}'
      ];
      for (final m in aerobicMenus) {
        if (!_menuHasAnyData(m)) continue;
        sectionLines.add(m.name);
        final bool hasDistance = _hasPositiveDistanceValue(m.distance);
        final bool hasDuration = _hasPositiveDurationValue(m.duration);
        if (hasDistance) {
          sectionLines
              .add('  ${l10n.distance}: ${_formatDistance(m.distance, l10n)}');
        }
        if (hasDuration) {
          sectionLines.add(
              '  ${l10n.time}: ${_formatDurationHM(context, m.duration, l10n)}');
        }
        if ((m.calories?.trim().isNotEmpty ?? false)) {
          sectionLines.add('  ${l10n.calorie}: ${m.calories} ${l10n.kcalUnit}');
        }
        if (m.satisfaction != null) {
          sectionLines.add(
              '  ${l10n.satisfaction}：${_satisfactionLabel(m.satisfaction!, l10n)}');
        }
      }
      sectionLines.add('');
      aerobicLines.addAll(sectionLines);
    }

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

      final sectionLines = <String>[
        '■${_translatePartToLocale(context, originalPart)}'
      ];

      for (final m in menuList) {
        if (!_menuHasAnyData(m)) continue;
        sectionLines.add(m.name);

        final int len = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        final unit = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
        final bool showRmColumn = SettingsManager.showRM;
        final bool showRirColumn = SettingsManager.showRIR;
        final bool showFailColumn = SettingsManager.showFail;
        final bool needsSpaceBeforeReps = l10n.reps.length > 1;
        final String repsSuffix =
            needsSpaceBeforeReps ? ' ${l10n.reps}' : l10n.reps;
        List<String>? rirValues;
        List<bool>? failureStates;
        try {
          final dynamic menuDynamic = m;
          final dynamic rawRir = menuDynamic.rirValues;
          if (rawRir is List) {
            rirValues = rawRir.map((e) => e?.toString() ?? '').toList();
          }
          final dynamic rawFailure = menuDynamic.failureStates;
          if (rawFailure is List) {
            failureStates = rawFailure.map((e) => e == true).toList();
          }
        } catch (_) {
          rirValues = null;
          failureStates = null;
        }

        List<double?>? rmValues;
        double? maxRm;
        if (showRmColumn && len > 0) {
          rmValues = List<double?>.filled(len, null);
          for (int i = 0; i < len; i++) {
            final weightValue = double.tryParse(m.weights[i].toString().trim());
            final repsValue = double.tryParse(m.reps[i].toString().trim());
            if (weightValue != null && repsValue != null) {
              final rm = weightValue * (1 + repsValue / 30);
              rmValues[i] = rm;
              if (maxRm == null || rm > maxRm!) {
                maxRm = rm;
              }
            }
          }
        }

        if (len > 0) {
          sectionLines.add('');
        }

        for (int i = 0; i < len; i++) {
          final wRaw = m.weights[i].toString().trim();
          final rRaw = m.reps[i].toString().trim();
          final String weightDisplay =
              wRaw.isNotEmpty ? '$wRaw$unit' : '—$unit';
          final String repsDisplay = rRaw.isNotEmpty ? rRaw : '—';
          final double? rm =
              showRmColumn && rmValues != null ? rmValues[i] : null;
          final bool isMaxRm = showRmColumn && rm != null && maxRm != null
              ? (rm - maxRm!).abs() < 1e-6
              : false;

          final buffer = StringBuffer(
              '  ${i + 1}：$weightDisplay X $repsDisplay$repsSuffix');

          final List<String> extraParts = [];
          if (showRmColumn && rm != null) {
            final String rmText = rm.toStringAsFixed(1);
            extraParts.add('1RM:${rmText}${isMaxRm ? '(MAX)' : ''}');
          }
          if (showRirColumn) {
            final String rirValue = (rirValues != null && i < rirValues.length)
                ? rirValues[i].trim()
                : '';
            if (rirValue.isNotEmpty) {
              extraParts.add('RIR:$rirValue');
            }
          }
          if (showFailColumn) {
            final bool failed =
                (failureStates != null && i < failureStates.length)
                    ? (failureStates[i] == true)
                    : false;
            if (failed) {
              extraParts.add(_failureTag(l10n));
            }
          }
          if (extraParts.isNotEmpty) {
            buffer.write('｜${extraParts.join(' | ')}');
          }

          sectionLines.add(buffer.toString());
        }
        if (m.totalVolume != null) {
          sectionLines.add(
              '  ${l10n.totalVolumeLabel}：${formatTotalVolumeValue(l10n, m.totalVolume)}');
        }
        if (m.satisfaction != null) {
          sectionLines.add(
              '  ${l10n.satisfaction}：${_satisfactionLabel(m.satisfaction!, l10n)}');
        }
      }
      sectionLines.add('');
      strengthLines.addAll(sectionLines);
    });

    if (memoText != null && memoText.trim().isNotEmpty) {
      memoLines
        ..add('■${l10n.memo}')
        ..add(memoText.trim())
        ..add('');
    }

    if (hasMealSection) {
      final mealBreakdown = _mealCalorieBreakdown(record);
      final sectionLines = <String>['■${l10n.meal}'];
      for (final category in MealCategory.values) {
        final label = _mealCategoryLabel(l10n, category);
        final kcal = mealBreakdown[category] ?? 0;
        sectionLines.add('$label: ${_formatKcalNumber(kcal)} ${l10n.kcalUnit}');
      }
      sectionLines.add(
          '${l10n.mealTotalToday}: ${_formatKcalNumber(mealTotal)} ${l10n.kcalUnit}');
      sectionLines.add('');
      mealLines.addAll(sectionLines);
    }

    final bool hasPersonal = (record.weight != null) ||
        (bodyFatVal != null) ||
        (waistValCm != null) ||
        (bmiVal != null) ||
        showBmr;
    if (hasPersonal) {
      personalLines.add('■${l10n.personal}');
      if (record.weight != null) {
        final unit = SettingsManager.currentUnit;
        personalLines.add(
            '${l10n.bodyWeight}: ${record.weight!.toStringAsFixed(1)} $unit');
      }
      if (bodyFatVal != null) {
        personalLines
            .add('${l10n.bodyFat}: ${bodyFatVal!.toStringAsFixed(1)}%');
      }
      if (waistValCm != null) {
        personalLines.add('${l10n.waist}: ${_fmtWaist(waistValCm!, l10n)}');
      }
      if (bmiVal != null) {
        personalLines.add('BMI: ${bmiVal!.toStringAsFixed(1)}');
      }
      if (showBmr) {
        final bmrDisplay = bmrValue != null
            ? '${_formatKcalNumber(bmrValue!)} ${l10n.kcalUnit}'
            : '—';
        personalLines.add('${l10n.bmrTitleShort}: $bmrDisplay');
        final diffDisplay = intakeMinusBmr != null
            ? '${_formatKcalNumber(intakeMinusBmr)} ${l10n.kcalUnit}'
            : '—';
        personalLines.add('${l10n.bmrDiffShort}: $diffDisplay');
      }
    }

    final combinedLines = <String>[]
      ..addAll(strengthLines)
      ..addAll(aerobicLines)
      ..addAll(memoLines)
      ..addAll(mealLines)
      ..addAll(personalLines);

    if (showBmr) {
      if (combinedLines.isNotEmpty && combinedLines.last.trim().isNotEmpty) {
        combinedLines.add('');
      }
      final summaryLabel = l10n.dailyBalanceSummary;
      final labelWithColon =
          (summaryLabel.endsWith('：') || summaryLabel.endsWith(':'))
              ? summaryLabel
              : '$summaryLabel:';
      final balanceText = energyBalance != null
          ? '${_formatKcalNumber(energyBalance)} ${l10n.kcalUnit}'
          : '—';
      combinedLines.add('$labelWithColon $balanceText');
    }

    while (combinedLines.isNotEmpty && combinedLines.last.trim().isEmpty) {
      combinedLines.removeLast();
    }

    return combinedLines;
  }

  Future<void> _showResultsDialog(
    BuildContext context,
    List<Widget> body,
    List<String> summaryLines,
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
                            fontSize: 20,
                          ),
                        ),
                      ),
                      if (hasRecord && summaryLines.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          tooltip: l10n.resultsCopy,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: summaryLines.join('\n')),
                            );
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(l10n.resultsCopied),
                                  duration: const Duration(milliseconds: 1600),
                                ),
                              );
                          },
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
                // 実績本文（スクロール領域）
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: body.isEmpty
                          ? [
                              Center(
                                child: Column(
                                  children: [
                                    SizedBox.square(
                                      dimension:
                                          MediaQuery.of(context).size.height /
                                              3, // 正方形：画面高の約1/3
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(24), // 角丸
                                        child: Image.asset(
                                          _emptyStateAssetFor(sel),
                                          fit: BoxFit.contain, // 画像は切り抜かず収める
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                            'assets/illustrations/empty/calendar/mon.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.event_busy,
                                              size: 72,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.noRecords,
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
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
                    androidNativeUnitId:
                        'ca-app-pub-3331079517737737/8075628963',
                    iosNativeUnitId: 'ca-app-pub-3331079517737737/2163497749',
                    androidBannerUnitId:
                        'ca-app-pub-3331079517737737/6135915237',
                    iosBannerUnitId: 'ca-app-pub-3331079517737737/9252979261',
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
                          label: Text(
                              hasRecord ? l10n.editThisDay : l10n.addOnThisDay),
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
    final double? bodyFatVal = _safeBodyFat(record); // %
    final double? waistValCm = _safeWaist(record); // cm
    double? bmiVal;
    if (record.weight != null) {
      final w = record.weight!;
      final h = _heightMetersFromSettings() ?? _heightMetersFromRecord(record);
      if (h != null && h > 0) {
        bmiVal = _toKg(w) / (h * h);
      }
    }

    bool _menuHasAnyData(MenuData m) {
      final len =
          (m.weights.length < m.reps.length) ? m.weights.length : m.reps.length;
      for (int i = 0; i < len; i++) {
        final w = m.weights[i].toString().trim();
        final r = m.reps[i].toString().trim();
        if (w.isNotEmpty || r.isNotEmpty) return true;
      }
      if (_hasPositiveDistanceValue(m.distance)) return true;
      if (_hasPositiveDurationValue(m.duration)) return true;
      if ((m.calories?.trim().isNotEmpty ?? false)) return true;
      if (m.totalVolume != null) return true;
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
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );
      for (final m in aerobicMenus) {
        summaryChildren.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        );
        final bool hasDistance = _hasPositiveDistanceValue(m.distance);
        final bool hasDuration = _hasPositiveDurationValue(m.duration);
        if (hasDistance) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.distance}: ${_formatDistance(m.distance, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
            ),
          );
        }
        if (hasDuration) {
          summaryChildren.add(
            _selectableLine(
              text:
                  '${l10n.time}: ${_formatDurationHM(context, m.duration, l10n)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
            ),
          );
        }
        if ((m.calories?.trim().isNotEmpty ?? false)) {
          summaryChildren.add(
            _selectableLine(
              text: '${l10n.calorie}: ${m.calories} ${l10n.kcalUnit}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
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
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );

      for (final m in menuList) {
        if (!_menuHasAnyData(m)) continue;

        summaryChildren.add(
          _selectableLine(
            text: m.name,
            padding: const EdgeInsets.only(bottom: 2.0),
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        );

        final int len = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        final unit = SettingsManager.currentUnit == 'kg' ? l10n.kg : l10n.lbs;
        final bool showRmColumn = SettingsManager.showRM;
        final bool showRirColumn = SettingsManager.showRIR;
        final bool showFailColumn = SettingsManager.showFail;
        final bool needsSpaceBeforeReps = l10n.reps.length > 1;
        final String repsSuffix =
            needsSpaceBeforeReps ? ' ${l10n.reps}' : l10n.reps;
        List<String>? rirValues;
        List<bool>? failureStates;
        try {
          final dynamic menuDynamic = m;
          final dynamic rawRir = menuDynamic.rirValues;
          if (rawRir is List) {
            rirValues = rawRir.map((e) => e?.toString() ?? '').toList();
          }
          final dynamic rawFailure = menuDynamic.failureStates;
          if (rawFailure is List) {
            failureStates = rawFailure.map((e) => e == true).toList();
          }
        } catch (_) {
          rirValues = null;
          failureStates = null;
        }

        List<double?>? rmValues;
        double? maxRm;
        if (showRmColumn && len > 0) {
          rmValues = List<double?>.filled(len, null);
          for (int i = 0; i < len; i++) {
            final weightValue = double.tryParse(m.weights[i].toString().trim());
            final repsValue = double.tryParse(m.reps[i].toString().trim());
            if (weightValue != null && repsValue != null) {
              final rm = weightValue * (1 + repsValue / 30);
              rmValues[i] = rm;
              if (maxRm == null || rm > maxRm!) {
                maxRm = rm;
              }
            }
          }
        }

        if (len > 0) {
          summaryChildren.add(const SizedBox(height: 4));
        }

        for (int i = 0; i < len; i++) {
          final wRaw = m.weights[i].toString().trim();
          final rRaw = m.reps[i].toString().trim();
          final String weightDisplay =
              wRaw.isNotEmpty ? '$wRaw$unit' : '—$unit';
          final String repsDisplay = rRaw.isNotEmpty ? rRaw : '—';
          final double? rm =
              showRmColumn && rmValues != null ? rmValues[i] : null;
          final bool isMaxRm = showRmColumn && rm != null && maxRm != null
              ? (rm - maxRm!).abs() < 1e-6
              : false;

          final buffer = StringBuffer(
              '${i + 1}：$weightDisplay X $repsDisplay$repsSuffix');

          final List<String> extraParts = [];
          if (showRmColumn && rm != null) {
            final String rmText = rm.toStringAsFixed(1);
            extraParts.add('1RM:${rmText}${isMaxRm ? '(MAX)' : ''}');
          }
          if (showRirColumn) {
            final String rirValue = (rirValues != null && i < rirValues.length)
                ? rirValues[i].trim()
                : '';
            if (rirValue.isNotEmpty) {
              extraParts.add('RIR:$rirValue');
            }
          }
          if (showFailColumn) {
            final bool failed =
                (failureStates != null && i < failureStates.length)
                    ? (failureStates[i] == true)
                    : false;
            if (failed) {
              extraParts.add(_failureTag(l10n));
            }
          }
          if (extraParts.isNotEmpty) {
            buffer.write('｜${extraParts.join(' | ')}');
          }

          summaryChildren.add(
            _selectableLine(
              text: buffer.toString(),
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }
        if (m.totalVolume != null) {
          summaryChildren.add(
            _selectableLine(
              text:
                  '${l10n.totalVolumeLabel}：${formatTotalVolumeValue(l10n, m.totalVolume)}',
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
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
    final hasPersonal = (record.weight != null) ||
        (bodyFatVal != null) ||
        (waistValCm != null) ||
        (bmiVal != null);
    if (hasPersonal) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            '■${l10n.personal}',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      );
      if (record.weight != null) {
        final unit = SettingsManager.currentUnit;
        summaryChildren.add(
          _selectableLine(
            text:
                '${l10n.bodyWeight}: ${record.weight!.toStringAsFixed(1)} $unit',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bodyFatVal != null) {
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.bodyFat}: ${bodyFatVal!.toStringAsFixed(1)}%',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (waistValCm != null) {
        summaryChildren.add(
          _selectableLine(
            text: '${l10n.waist}: ${_fmtWaist(waistValCm!, l10n)}',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
      if (bmiVal != null) {
        summaryChildren.add(
          _selectableLine(
            text: 'BMI: ${bmiVal!.toStringAsFixed(1)}',
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
          ),
        );
      }
    }

    // メモ
    final memo = _getMemoTextForDate(sel);
    if (memo != null && memo.trim().isNotEmpty) {
      final memoText = memo.trim();
      summaryChildren.add(const SizedBox(height: 8));
      summaryChildren.add(
        _selectableLine(
          text: '■${l10n.memo}',
          padding: const EdgeInsets.only(bottom: 2.0),
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
      summaryChildren.add(const SizedBox(height: 4));
      summaryChildren.add(
        _selectableLine(
          text: memoText,
          padding: const EdgeInsets.only(left: 8.0, bottom: 0),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
        ),
      );
      summaryChildren.add(const SizedBox(height: 8));
    }
    // ====== サマリ生成ここまで ======

    // FAB と重ならない横幅（右余白+安全マージンで約 96px 確保）
    final double screenW = MediaQuery.of(context).size.width;
    final double maxWidth = (screenW - 96).clamp(220.0, screenW);

    const double fabHeight = 56;
    final summaryLines = _buildSummaryLinesForDate(context, sel, record);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth, // （既存）FABと重ならない幅上限
          minHeight: fabHeight,
          maxHeight: fabHeight, // ← 高さ固定
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
            onTap: () => _showResultsDialog(
              context,
              summaryChildren,
              summaryLines,
              sel,
            ),
            child: Container(
              height: fabHeight, // ← ここでも明示
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft, // 垂直中央寄せ
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

typedef CalendarScreenState = _CalendarScreenState;
