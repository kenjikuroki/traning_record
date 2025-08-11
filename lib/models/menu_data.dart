import 'package:hive/hive.dart';

part 'menu_data.g.dart';

@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final List<String> weights;
  @HiveField(2)
  final List<String> reps;

  // 💡 有酸素運動用のフィールドを追加
  @HiveField(3)
  final String? distance; // 距離 (km)
  @HiveField(4)
  final String? duration; // 時間 (分:秒)

  MenuData({
    required this.name,
    required this.weights,
    required this.reps,
    this.distance, // 💡 コンストラクタに追加
    this.duration, // 💡 コンストラクタに追加
  });

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      name: json['name'] as String,
      weights: (json['weights'] as List).map((e) => e == null || e == 0 ? '' : e.toString()).toList(),
      reps: (json['reps'] as List).map((e) => e == null || e == 0 ? '' : e.toString()).toList(),
      distance: json['distance'] as String?,
      duration: json['duration'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weights': weights,
      'reps': reps,
      'distance': distance,
      'duration': duration,
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


  DailyRecord({
    required this.date,
    required this.menus,
    this.lastModifiedPart,
    this.weight,
  });
}