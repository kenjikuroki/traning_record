import 'package:flutter/material.dart';

class CalendarWidgetChipData {
  const CalendarWidgetChipData({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}

class CalendarWidgetDayData {
  const CalendarWidgetDayData({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.hasContent,
    required this.chips,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool hasContent;
  final List<CalendarWidgetChipData> chips;
}

class CalendarWidgetView extends StatelessWidget {
  const CalendarWidgetView({
    super.key,
    required this.monthLabel,
    required this.yearLabel,
    required this.weekdayLabels,
    required this.days,
    required this.colorScheme,
    required this.width,
    required this.height,
  });

  final String monthLabel;
  final String yearLabel;
  final List<String> weekdayLabels;
  final List<CalendarWidgetDayData> days;
  final ColorScheme colorScheme;
  final double width;
  final double height;

  static const int _columns = 7;
  static const int _rows = 6;

  @override
  Widget build(BuildContext context) {
    final double headerHeight = (height * 0.16).clamp(28, 56);
    final double weekdayHeight = (height * 0.10).clamp(20, 42);
    final double verticalPadding = 12;
    final double horizontalPadding = 12;
    final double spacing = 6;
    final double gridHeight =
        height - headerHeight - weekdayHeight - verticalPadding - spacing;
    final double cellHeight = gridHeight / _rows;
    final double cellWidth = (width - horizontalPadding * 2) / _columns;
    final int maxChips = _maxChipsFor(cellHeight);
    final double dayFontSize = (cellHeight * 0.32).clamp(10, 18);
    final double chipFontSize = (cellHeight * 0.22).clamp(8, 12);
    final double chipVerticalPadding = (cellHeight * 0.08).clamp(1.0, 4.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: verticalPadding / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: headerHeight,
              child: _buildHeader(dayFontSize, context),
            ),
            SizedBox(height: spacing / 2),
            SizedBox(
              height: weekdayHeight,
              child: _buildWeekdayRow(),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _buildGrid(
                cellHeight: cellHeight,
                cellWidth: cellWidth,
                dayFontSize: dayFontSize,
                chipFontSize: chipFontSize,
                chipVerticalPadding: chipVerticalPadding,
                maxChips: maxChips,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double baseFontSize, BuildContext context) {
    final double monthFont = baseFontSize.clamp(12, 20);
    final double yearFont = (baseFontSize * 0.9).clamp(10, 18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          monthLabel,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: monthFont,
            height: 1.1,
          ),
        ),
        Text(
          yearLabel,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: yearFont,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    final List<Widget> labels = [];
    for (int i = 0; i < _columns; i++) {
      final String label = weekdayLabels[i];
      final bool isWeekend = i >= 5;
      labels.add(
        Expanded(
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isWeekend
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: labels);
  }

  Widget _buildGrid({
    required double cellHeight,
    required double cellWidth,
    required double dayFontSize,
    required double chipFontSize,
    required double chipVerticalPadding,
    required int maxChips,
  }) {
    final List<Row> rows = [];
    for (int row = 0; row < _rows; row++) {
      final List<Widget> children = [];
      for (int col = 0; col < _columns; col++) {
        final int index = row * _columns + col;
        final CalendarWidgetDayData data = days[index];
        children.add(
          SizedBox(
            width: cellWidth,
            height: cellHeight,
            child: _DayCell(
              data: data,
              colorScheme: colorScheme,
              dayFontSize: dayFontSize,
              chipFontSize: chipFontSize,
              chipVerticalPadding: chipVerticalPadding,
              maxChips: maxChips,
            ),
          ),
        );
      }
      rows.add(Row(children: children));
    }
    return Column(children: rows);
  }

  static int _maxChipsFor(double cellHeight) {
    if (cellHeight >= 74) return 4;
    if (cellHeight >= 56) return 3;
    if (cellHeight >= 40) return 2;
    if (cellHeight >= 30) return 1;
    return 0;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.data,
    required this.colorScheme,
    required this.dayFontSize,
    required this.chipFontSize,
    required this.chipVerticalPadding,
    required this.maxChips,
  });

  final CalendarWidgetDayData data;
  final ColorScheme colorScheme;
  final double dayFontSize;
  final double chipFontSize;
  final double chipVerticalPadding;
  final int maxChips;

  @override
  Widget build(BuildContext context) {
    final bool useAccent = data.isToday;
    final bool outOfMonth = !data.inMonth;
    final List<CalendarWidgetChipData> chips = data.chips;
    final List<CalendarWidgetChipData> displayChips =
        chips.take(maxChips).toList(growable: false);
    final double indicatorSize = 4.0;

    return Container(
      decoration: BoxDecoration(
        color: outOfMonth
            ? colorScheme.surface.withOpacity(0.36)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: useAccent ? colorScheme.primary : colorScheme.outlineVariant,
          width: useAccent ? 1.2 : 0.6,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.date.day.toString(),
            style: TextStyle(
              color: outOfMonth
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: dayFontSize,
              height: 1.1,
            ),
          ),
          if (displayChips.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (int i = 0; i < displayChips.length; i++)
              Padding(
                padding: EdgeInsets.only(
                    bottom: i == displayChips.length - 1 ? 0 : 3),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: chipVerticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: displayChips[i].backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    displayChips[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: displayChips[i].textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: chipFontSize,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
          ] else if (data.hasContent) ...[
            const Spacer(),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
        ],
      ),
    );
  }
}
