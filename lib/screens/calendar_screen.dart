// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart'; // ★ 追加
import '../l10n/app_localizations.dart';
import '../models/menu_data.dart';
import '../widgets/ad_banner.dart';
import '../settings_manager.dart';
import 'record_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';
import '../widgets/ad_square.dart';

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
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay =
        DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _selectedDay = DateTime(widget.selectedDate.year, widget.selectedDate.month,
        widget.selectedDate.day);
  }

  // ---------- Helpers ----------
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  // 「30:45」→「30分45秒」
  String _formatDuration(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final parts = raw.split(':');
    final min = (parts.isNotEmpty && parts[0].isNotEmpty) ? parts[0] : '0';
    final sec = (parts.length > 1 && parts[1].isNotEmpty) ? parts[1] : '0';
    return '$min${l10n.min}$sec${l10n.sec}';
  }

  // TableCalendar：その日に何か（体重 or トレ）あれば 1 件返す → ● マーカー
  List<Object> _eventLoader(DateTime day) {
    final r = widget.recordsBox.get(_dateKey(day));
    if (_hasAnyData(r)) {
      return const [1]; // ダミー
    }
    return const [];
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    //  final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          DateFormat('yyyy/MM').format(_focusedDay),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // ★ recordsBox の変更を監視して即時再描画
        child: ValueListenableBuilder<Box<DailyRecord>>(
          valueListenable: widget.recordsBox.listenable(),
          builder: (context, box, _) {
            final selectedRecord =
                box.get(_dateKey(_selectedDay ?? DateTime.now()));
            return Column(
              children: [
                const AdBanner(screenName: 'calendar'),
                const SizedBox(height: 12),
                _buildCalendar(context),
                const SizedBox(height: 12),
                _buildResultsArea(context, selectedRecord),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Graph'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: 0,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surface,
        onTap: (index) async {
          if (index == 0) return;
          if (index == 1) {
            // ★ 記録画面から戻ったら即 setState で再描画
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordScreen(
                  selectedDate: _selectedDay ?? DateTime.now(),
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                ),
              ),
            );
            setState(() {});
          } else if (index == 2) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GraphScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                ),
              ),
            );
            setState(() {});
          } else if (index == 3) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  recordsBox: widget.recordsBox,
                  lastUsedMenusBox: widget.lastUsedMenusBox,
                  settingsBox: widget.settingsBox,
                  setCountBox: widget.setCountBox,
                ),
              ),
            );
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar<Object>(
          firstDay: DateTime.utc(2015, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) =>
              _selectedDay != null &&
              day.year == _selectedDay!.year &&
              day.month == _selectedDay!.month &&
              day.day == _selectedDay!.day,
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
            todayDecoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
            markersMaxCount: 1,
            markerDecoration: BoxDecoration(
              color: colorScheme.primary, // ●
              shape: BoxShape.circle,
            ),
          ),
          eventLoader: _eventLoader,
          onDaySelected: (selectedDay, focusedDay) async {
            // 同じ日をもう一度タップ → 記録画面へ
            if (_selectedDay != null &&
                selectedDay.year == _selectedDay!.year &&
                selectedDay.month == _selectedDay!.month &&
                selectedDay.day == _selectedDay!.day) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordScreen(
                    selectedDate: selectedDay,
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
              );
              // ★ 戻り直後に再描画（●と実績を即反映）
              setState(() {});
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

  Widget _buildResultsArea(BuildContext context, DailyRecord? record) {
    final colorScheme = Theme.of(context).colorScheme;
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
                adSize: AdBoxSize.largeBanner, // 320x100
                showPlaceholder: false, // ★本番広告にするのでfalse
                screenName: 'calendar', // ★カレンダー画面用IDを使う
              ),
            ),
          ],
        ),
      );
    }

    // 実績あり：体重カード／部位カード
    final unit = SettingsManager.currentUnit;
    final List<Widget> cards = [];

    // 体重カード（体重実績がある場合のみ表示）
    if (record.weight != null) {
      cards.add(
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
                borderRadius: BorderRadius.circular(16.0)),
            elevation: 4,
            clipBehavior: Clip.none,
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedAlignment: Alignment.centerLeft,
              maintainState: true,
              title: Text(
                l10n.bodyWeight,
                style: TextStyle(
                    color: colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${record.weight?.toStringAsFixed(1) ?? '-'} $unit',
                    textAlign: TextAlign.left,
                    style:
                        TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 部位カード（タイトル＝部位名）。トレ実績がある部位だけ表示
    record.menus.forEach((originalPart, menuList) {
      bool partHasData = false;
      for (final m in menuList) {
        final len = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        for (int i = 0; i < len; i++) {
          if (m.weights[i].toString().trim().isNotEmpty ||
              m.reps[i].toString().trim().isNotEmpty) {
            partHasData = true;
            break;
          }
        }
        if ((m.distance?.trim().isNotEmpty ?? false) ||
            (m.duration?.trim().isNotEmpty ?? false)) {
          partHasData = true;
        }
        if (partHasData) break;
      }
      if (!partHasData) return;

      final partTitle = _translatePartToLocale(context, originalPart);

      final List<Widget> lines = [];
      for (final m in menuList) {
        // 種目名（左寄せ）
        lines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
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

        // セット（左寄せ）
        final setCount = (m.weights.length < m.reps.length)
            ? m.weights.length
            : m.reps.length;
        for (int i = 0; i < setCount; i++) {
          final w = m.weights[i].toString().trim();
          final r = m.reps[i].toString().trim();
          if (w.isEmpty && r.isEmpty) continue;
          lines.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${i + 1}${l10n.sets}：${w.isNotEmpty ? '$w${unit == 'kg' ? l10n.kg : l10n.lbs}' : '-'} × ${r.isNotEmpty ? r : '-'}${l10n.reps}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ),
          );
        }

        // 有酸素の距離・時間（ある場合のみ、km/m・分/秒で表示）
        if ((m.distance?.trim().isNotEmpty ?? false)) {
          lines.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.distance}: ${_formatDistance(m.distance, l10n)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ),
          );
        }
        if ((m.duration?.trim().isNotEmpty ?? false)) {
          lines.add(
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.time}: ${_formatDuration(m.duration, l10n)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ),
          );
        }
      }

      if (lines.isEmpty) return;

      cards.add(
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
                borderRadius: BorderRadius.circular(16.0)),
            elevation: 4,
            clipBehavior: Clip.none,
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedAlignment: Alignment.centerLeft,
              maintainState: true,
              title: Text(
                partTitle,
                style: TextStyle(
                    color: colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines,
                ),
              ],
            ),
          ),
        ),
      );
    });

    // 実績カードをスクロール（縞々対策）
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8.0),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}
