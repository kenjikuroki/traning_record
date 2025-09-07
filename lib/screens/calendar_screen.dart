// lib/screens/calendar_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

    _focusedDay =
        DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );

    // CoachBubble（「日付をタップ」のみ）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = widget.settingsBox.get('hint_seen_calendar') as bool? ??
          false;
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

  // ---------- Helpers ----------
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day
          .toString()
          .padLeft(2, '0')}';

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasAnyTrainingData(DailyRecord r) {
    for (final entry in r.menus.entries) {
      for (final m in entry.value) {
        final len = (m.weights.length < m.reps.length) ? m.weights.length : m
            .reps.length;
        for (var i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final p = m.reps[i].toString().trim();
          if (w.isNotEmpty || p.isNotEmpty) return true;
        }
        if ((m.distance
            ?.trim()
            .isNotEmpty ?? false) || (m.duration
            ?.trim()
            .isNotEmpty ?? false)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAnyData(DailyRecord? r) {
    if (r == null) return false;
    if (r.weight != null) return true;
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
    if (raw == null || raw
        .trim()
        .isEmpty) return '-';
    final value = double.tryParse(raw);
    if (value == null) return '-';
    final km = value.floor();
    final m = ((value - km) * 1000).round();
    return '$km${l10n.km}$m${l10n.m}';
  }

  // 「30:45」→「30分45秒」
  String _formatDuration(String? raw, AppLocalizations l10n) {
    if (raw == null || raw
        .trim()
        .isEmpty) return '-';
    final parts = raw.split(':');
    final min = (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : '0';
    final sec = (parts.length > 1 && parts[1].isNotEmpty) ? parts[1] : '0';
    return '$min${l10n.min}$sec${l10n.sec}';
  }

  // その日に実績のある「部位」一覧を返す（表示用）
  List<String> _partsWithDataForDay(DailyRecord r) {
    final List<String> parts = [];
    r.menus.forEach((part, menuList) {
      bool has = false;
      for (final m in menuList) {
        final len = (m.weights.length < m.reps.length) ? m.weights.length : m
            .reps.length;
        for (int i = 0; i < len; i++) {
          final w = m.weights[i].toString().trim();
          final p = m.reps[i].toString().trim();
          if (w.isNotEmpty || p.isNotEmpty) {
            has = true;
            break;
          }
        }
        if ((m.distance
            ?.trim()
            .isNotEmpty ?? false) || (m.duration
            ?.trim()
            .isNotEmpty ?? false)) {
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
    final double dayFont = Theme
        .of(context)
        .textTheme
        .bodyMedium
        ?.fontSize ?? 14.0;
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

  // セル描画（数字は上固定 / 直下に体重+部位ボックスを“上→下”に積む・合計最大3つ）
  Widget _buildDayCell(BuildContext context,
      DateTime day, {
        required Color textColor,
        bool selected = false,
        bool showEventsForOutOfMonth = false,
      }) {
    final cs = Theme
        .of(context)
        .colorScheme;

    // その日の部位イベント（'_w'＝体重のみは除外）
    final parts = _eventLoader(day)
        .map((e) => e.toString())
        .where((p) => p != '_w')
        .toList();

    // 体重の有無
    final record = widget.recordsBox.get(_dateKey(day));
    final hasWeight = record?.weight != null;

    // 合計最大3つ（体重があれば1スロット使用）
    final bool canShowParts = (showEventsForOutOfMonth ||
        day.month == _focusedDay.month);
    final int maxSlots = 3;
    final int partSlots = canShowParts ? (maxSlots - (hasWeight ? 1 : 0)) : 0;
    final List<String> showParts =
    (partSlots > 0 ? parts.take(partSlots).toList() : const []);

    // 体重ボックス
    Widget? weightBox;
    if (hasWeight) {
      final l10n = AppLocalizations.of(context)!;
      weightBox = Container(
        margin: EdgeInsets.only(bottom: showParts.isNotEmpty ? 2 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.bodyWeight, // 数値は表示しない
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.1,
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.10) : null,
          borderRadius: selected ? BorderRadius.circular(8) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // 横幅いっぱい
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上に日付（当月のみ：土=青 / 日=赤）
            Builder(
              builder: (_) {
                final outOfMonth = day.month != _focusedDay.month;
                final Color dayNumberColor = outOfMonth
                    ? textColor
                    : (day.weekday == DateTime.sunday
                    ? Colors.red
                    : (day.weekday == DateTime.saturday ? Colors.blue : textColor));
                return _dayLabelTop(
                  context,
                  day,
                  textColor: dayNumberColor,
                  selected: selected,
                );
              },
            ),
            // 日付と最初のボックスの間は常に 2px（体重 or 部位があれば）
            if (hasWeight || showParts.isNotEmpty) const SizedBox(height: 2),

            // 体重ボックス（あれば）
            if (hasWeight) weightBox!,

            // 部位ボックス（上→下）
            for (int i = 0; i < showParts.length; i++)
              Builder(
                builder: (_) {
                  final p = showParts[i];
                  final label = _translatePartToLocale(context, p);
                  final boxColor = _colorForPart(p, cs);
                  final textOnBox =
                  ThemeData.estimateBrightnessForColor(boxColor) ==
                      Brightness.dark
                      ? Colors.white
                      : Colors.black87;
                  return Container(
                    // 最後のボックスだけ下マージン0
                    margin: EdgeInsets.only(
                        bottom: i == showParts.length - 1 ? 0 : 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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
                        fontSize: 10,
                        height: 1.1,
                        color: textOnBox,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 記録画面（不透明ボトムシート）
  Future<void> _openRecordSheet(DateTime day) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      // ▼ 下スワイプ/ドラッグで閉じない
      enableDrag: false,
      // ▼ 外側タップやAndroid戻るキーで閉じない
      isDismissible: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final cs = Theme
            .of(ctx)
            .colorScheme;
        return WillPopScope( // ← 戻る（ボタン/スワイプ）は許可
          onWillPop: () async => true,
          child: SizedBox.expand(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: SafeArea(
                  top: false,
                  child: RecordScreen(
                    selectedDate: day,
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _formatMonthTitle(context, _focusedDay),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.00),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      body: Padding(
        // 上だけ 8px にして AppBar と広告の間を詰める
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: ValueListenableBuilder<Box<DailyRecord>>(
          valueListenable: widget.recordsBox.listenable(),
          builder: (context, box, _) {
            final selectedRecord = box.get(
                _dateKey(_selectedDay ?? DateTime.now()));
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
    final colorScheme = Theme
        .of(context)
        .colorScheme;

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
            leftChevronIcon: Icon(
                Icons.chevron_left, color: colorScheme.onSurface),
            rightChevronIcon: Icon(
                Icons.chevron_right, color: colorScheme.onSurface),
          ),

          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: colorScheme.onSurface),
            weekendTextStyle: TextStyle(color: colorScheme.onSurface),
            outsideTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            todayDecoration: const BoxDecoration(),
            // 今日リングなし
            selectedDecoration: const BoxDecoration(),
            // 選択の円もなし
            selectedTextStyle: TextStyle(color: colorScheme.onSurface),
            markersMaxCount: 0, // 標準の●マーカーを無効化
          ),

          // ▼ セル一体描画（markerBuilderは使わない）
          calendarBuilders: CalendarBuilders<Object>(
            defaultBuilder: (context, day, focusedDay) {
              final cs = Theme
                  .of(context)
                  .colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurface,
                selected: false,
              );
            },
            outsideBuilder: (context, day, focusedDay) {
              final cs = Theme
                  .of(context)
                  .colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurfaceVariant,
                selected: false,
                showEventsForOutOfMonth: false,
              );
            },
            todayBuilder: (context, day, focusedDay) {
              final cs = Theme
                  .of(context)
                  .colorScheme;
              return _buildDayCell(
                context,
                day,
                textColor: cs.onSurface,
                selected: false,
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              final cs = Theme
                  .of(context)
                  .colorScheme;
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
              _selectedDay = DateTime(
                  selectedDay.year, selectedDay.month, selectedDay.day);
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

  Future<void> _showResultsDialog(BuildContext context,
      List<Widget> summaryChildren) async {
    final cs = Theme
        .of(context)
        .colorScheme;
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 24),
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
                      maxHeight: MediaQuery
                          .of(ctx)
                          .size
                          .height * 0.65,
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
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // 実績ゼロ日：広告のみ（スクロール可能）
    final bool noData = record == null || !_hasAnyData(record);
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

    // 1) 体重があれば最上部に簡易表示
    final List<Widget> summaryChildren = [];
    if (record!.weight != null) {
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${l10n.bodyWeight}: ${record.weight!.toStringAsFixed(1)} $unit',
              style: TextStyle(color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      );
    }

    // 2) 各部位の簡易表示（これまでのカード中身を“1枚の中”にまとめる）
    record.menus.forEach((originalPart, menuList) {
      // その部位に表示すべきデータがあるか
      bool partHasData = false;
      for (final m in menuList) {
        final len = (m.weights.length < m.reps.length) ? m.weights.length : m
            .reps.length;
        for (int i = 0; i < len; i++) {
          if (m.weights[i]
              .toString()
              .trim()
              .isNotEmpty || m.reps[i]
              .toString()
              .trim()
              .isNotEmpty) {
            partHasData = true;
            break;
          }
        }
        if ((m.distance
            ?.trim()
            .isNotEmpty ?? false) || (m.duration
            ?.trim()
            .isNotEmpty ?? false)) {
          partHasData = true;
        }
        if (partHasData) break;
      }
      if (!partHasData) return;

      final partTitle = _translatePartToLocale(context, originalPart);

      // 見出し（部位名）
      summaryChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Text(
            partTitle,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );

      // 中身（種目名・セット、距離・時間）
      for (final m in menuList) {
        // 種目名
        summaryChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                m.name,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );

        // セット
        final setCount = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        for (int i = 0; i < setCount; i++) {
          final w = m.weights[i].toString().trim();
          final r = m.reps[i].toString().trim();
          if (w.isEmpty && r.isEmpty) continue;
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${i + 1}${l10n.sets}：${w.isNotEmpty ? '$w${unit == 'kg'
                      ? l10n.kg
                      : l10n.lbs}' : '-'} × ${r.isNotEmpty ? r : '-'}${l10n
                      .reps}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                ),
              ),
            ),
          );
        }

        // 有酸素の距離・時間
        if ((m.distance
            ?.trim()
            .isNotEmpty ?? false)) {
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
        if ((m.duration
            ?.trim()
            .isNotEmpty ?? false)) {
          summaryChildren.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 1.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.time}: ${_formatDuration(m.duration, l10n)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                ),
              ),
            ),
          );
        }
      }
    });

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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                title: Text(
                  l10n.results, // 「実績」
                  style: TextStyle(color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold),
                ),
                trailing: Icon(Icons.open_in_new, color: colorScheme.onSurface),
                onTap: () => _showResultsDialog(context, summaryChildren),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


