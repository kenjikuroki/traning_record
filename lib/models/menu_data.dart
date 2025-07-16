import 'package:hive/hive.dart';

part 'menu_data.g.dart'; // build_runnerによって生成されるアダプターファイル

// MenuData モデル
@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<int> weights;

  @HiveField(2)
  List<int> reps;

  MenuData({required this.name, required this.weights, required this.reps});
}

// DailyRecord モデル (typeId は MenuData と異なるものを使用)
@HiveType(typeId: 1)
class DailyRecord extends HiveObject {
  // 日付キー (YYYY-MM-DD) に紐づく、部位ごとのメニューリストを保存
  @HiveField(0)
  Map<String, List<MenuData>> menus;

  DailyRecord({required this.menus});
}
