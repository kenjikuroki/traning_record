import 'package:hive/hive.dart';

part 'menu_data.g.dart'; // この行があることを確認

@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final List<String> weights;
  @HiveField(2)
  final List<String> reps;

  MenuData({required this.name, required this.weights, required this.reps});

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      name: json['name'] as String,
      weights: (json['weights'] as List).map((e) => e == null || e == 0 ? '' : e.toString()).toList(),
      reps: (json['reps'] as List).map((e) => e == null || e == 0 ? '' : e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weights': weights,
      'reps': reps,
    };
  }
}

@HiveType(typeId: 1)
class DailyRecord extends HiveObject {
  @HiveField(0)
  late DateTime date; // 💡 この行を追加

  @HiveField(1)
  final Map<String, List<MenuData>> menus;

  @HiveField(2)
  final String? lastModifiedPart; // HiveFieldの番号を振り直す

  DailyRecord({
    required this.date,
    required this.menus,
    this.lastModifiedPart
  });
}
