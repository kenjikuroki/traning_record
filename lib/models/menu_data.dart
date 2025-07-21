import 'package:hive/hive.dart';

part 'menu_data.g.dart'; // build_runnerによって生成されるアダプターファイル

// MenuData モデル
@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> weights; // List<int> から List<String> に変更

  @HiveField(2)
  List<String> reps; // List<int> から List<String> に変更

  MenuData({required this.name, required this.weights, required this.reps});
}

// DailyRecord モデル (typeId は MenuData と異なるものを使用)
@HiveType(typeId: 1)
class DailyRecord extends HiveObject {
  // 日付キー (YYYY-MM-DD) に紐づく、部位ごとのメニューリストを保存
  @HiveField(0)
  Map<String, List<MenuData>> menus;

  // その日に最後に変更されたターゲット部位を記録する新しいフィールド
  @HiveField(1) // 新しいフィールドなので、既存のフィールドと異なるIDを割り当てます
  String? lastModifiedPart; // null許容にして、既存のデータとの互換性を保ちます

  DailyRecord({required this.menus, this.lastModifiedPart}); // コンストラクタを更新
}