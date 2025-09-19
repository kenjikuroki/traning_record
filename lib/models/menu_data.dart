import 'package:hive/hive.dart';

part 'menu_data.g.dart';

@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0) final String name;
  @HiveField(1) final List<String> weights;
  @HiveField(2) final List<String> reps;

  @HiveField(3) final String? distance;
  @HiveField(4) final String? duration;
  @HiveField(5) final String? calories;
  @HiveField(6) final int? satisfaction; // 追加

  MenuData({
    required this.name,
    required this.weights,
    required this.reps,
    this.distance,
    this.duration,
    this.calories,
    this.satisfaction, // 追加
  });

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      name: json['name'] as String,
      weights: (json['weights'] as List).map((e) => e?.toString() ?? '').toList(),
      reps: (json['reps'] as List).map((e) => e?.toString() ?? '').toList(),
      distance: json['distance'] as String?,
      duration: json['duration'] as String?,
      satisfaction: json['satisfaction'] as int?, // ★追加
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weights': weights,
      'reps': reps,
      'distance': distance,
      'duration': duration,
      'satisfaction': satisfaction, // ★追加
    };
  }
}

@HiveType(typeId: 1)
class DailyRecord extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  final Map<String, List<MenuData>> menus;

  @HiveField(2)
  final String? lastModifiedPart;

  @HiveField(3)
  final double? weight;

  // ▼ 追加：固定フィールド
  @HiveField(4)
  final double? bodyFatPercent; // %

  @HiveField(5)
  final double? waistCm; // cm

  DailyRecord({
    required this.date,
    required this.menus,
    this.lastModifiedPart,
    this.weight,
    this.bodyFatPercent,
    this.waistCm,
  });
}
