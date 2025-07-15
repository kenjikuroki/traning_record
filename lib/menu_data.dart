import 'package:hive/hive.dart';

part 'menu_data.g.dart';

@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<int> weights;

  @HiveField(2)
  List<int> reps;

  MenuData({
    required this.name,
    required this.weights,
    required this.reps,
  });
}
