
/// タイムライン上のエントリ種別
enum TimelineEntryType {
  strength, // 筋トレ
  meal,     // 食事
  memo,     // メモ
  weight,   // 体重
  cardio,   // 有酸素
  schedule, // 予定（スケジュール）
}

/// タイムライン上の1つのエントリ（カード）
class TimelineEntry {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final TimelineEntryType type;
  final String? refId;

  TimelineEntry({
    required this.id,
    required this.startTime,
    required this.type,
    this.endTime,
    this.refId,
  });
}

/// 1日分のタイムラインデータ
class TimelineDay {
  final DateTime date;
  final List<TimelineEntry> entries;

  TimelineDay({
    required this.date,
    required this.entries,
  });
}
