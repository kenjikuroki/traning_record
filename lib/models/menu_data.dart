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

  MenuData({required this.name, required this.weights, required this.reps});

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      name: json['name'] as String,
      // 修正: nullまたは0の場合は空文字列に変換
      weights: (json['weights'] as List).map((e) => e == null || e == 0 ? '' : e.toString()).toList(),
      // 修正: nullまたは0の場合は空文字列に変換
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
  final Map<String, List<MenuData>> menus;
  @HiveField(1)
  final String? lastModifiedPart; // 追加

  DailyRecord({required this.menus, this.lastModifiedPart});
}
