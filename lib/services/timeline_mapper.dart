
import 'dart:math';
import 'package:hive/hive.dart';
import '../models/timeline_day.dart';
import '../models/menu_data.dart';

class TimelineMapper {
  final Box<DailyRecord> recordsBox;
  final Box<dynamic> settingsBox;

  TimelineMapper(this.recordsBox, this.settingsBox);

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(100000);
    return '$now-$random';
  }

  /// 指定された日付の DailyRecord (および関連データ) を読み込み、
  /// TimelineDay に変換して返す。
  Future<TimelineDay> buildTimelineFromDailyRecord(DateTime date) async {
    final dateKey = _getDateKey(date);
    final record = recordsBox.get(dateKey);
    final List<TimelineEntry> entries = [];

    // 1. 体重 (Weight)
    if (record?.weight != null) {
      entries.add(TimelineEntry(
        id: _generateId(),
        startTime: date, // 時間情報がないので日付の0:00とする
        type: TimelineEntryType.weight,
        refId: 'weight_$dateKey', // 仮のrefId
      ));
    }

    // 2. 食事 (Meal)
    if (record?.meals != null) {
      for (final mealMap in record!.meals!) {
        if (mealMap is! Map) continue;
        final map = mealMap.cast<String, dynamic>();
        final category = map['category'] as String? ?? 'unknown';
        final rawHour = map['hour'];
        final rawMinute = map['minute'];
        final startTime = DateTime(
          date.year,
          date.month,
          date.day,
          (rawHour is num) ? rawHour.toInt().clamp(0, 23) : 0,
          (rawMinute is num) ? rawMinute.toInt().clamp(0, 59) : 0,
        );
        entries.add(TimelineEntry(
          id: _generateId(),
          startTime: startTime,
          type: TimelineEntryType.meal,
          refId: 'meal_${category}_$startTime',
        ));
      }
    }

    // 3. トレーニング (Strength / Cardio)
    if (record?.menus != null) {
      record!.menus.forEach((originalPart, menuList) {
        if (menuList.isEmpty) return;

        // "有酸素運動" というキーであれば cardio、それ以外は strength
        final isCardio = (originalPart == '有酸素運動');
        final type = isCardio ? TimelineEntryType.cardio : TimelineEntryType.strength;

        for (final menu in menuList) {
           entries.add(TimelineEntry(
             id: _generateId(),
             startTime: date,
             type: type,
             refId: menu.name, // メニュー名をrefIdに入れておく
           ));
        }
      });
    }

    return TimelineDay(
      date: date,
      entries: entries,
    );
  }

  /// TimelineDay の内容を DailyRecord (および関連データ) に反映する。
  /// (Pass 2 では未実装・スタブ)
  Future<void> applyTimelineToDailyRecord(TimelineDay timelineDay) async {
    // TODO: Pass 3以降で実装
    // timelineDay.entries を解析し、
    // - type == weight -> recordsBox の weight を更新
    // - type == meal -> recordsBox の meals を更新
    // - type == strength/cardio -> recordsBox の menus を更新
    // - type == memo -> settingsBox の memo-... を更新
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
