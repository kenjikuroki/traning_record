import 'package:hive/hive.dart';

part 'menu_data.g.dart'; // build_runnerによって生成されるアダプターファイル

// MenuData モデル
@HiveType(typeId: 0)
class MenuData extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> weights;

  @HiveField(2)
  List<String> reps;

  MenuData({required this.name, required this.weights, required this.reps});

  // ★ 追加: MapからMenuDataを生成するファクトリコンストラクタ ★
  factory MenuData.fromJson(Map<dynamic, dynamic> json) {
    return MenuData(
      name: json['name'] as String,
      weights: (json['weights'] as List).map((e) => e.toString()).toList(),
      reps: (json['reps'] as List).map((e) => e.toString()).toList(),
    );
  }

  // ★ 追加: MenuDataをMapに変換するメソッド (Hiveの内部処理で必要になる場合がある) ★
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weights': weights,
      'reps': reps,
    };
  }
}

// DailyRecord モデル (typeId は MenuData と異なるものを使用)
@HiveType(typeId: 1)
class DailyRecord extends HiveObject {
  // 日付キー (YYYY-MM-DD) に紐づく、部位ごとのメニューリストを保存
  @HiveField(0)
  Map<String, List<MenuData>> menus;

  // その日に最後に変更されたターゲット部位を記録する新しいフィールド
  @HiveField(1)
  String? lastModifiedPart;

  DailyRecord({required this.menus, this.lastModifiedPart});

  // ★ 追加: MapからDailyRecordを生成するファクトリコンストラクタ ★
  factory DailyRecord.fromJson(Map<dynamic, dynamic> json) {
    return DailyRecord(
      menus: (json['menus'] as Map<dynamic, dynamic>).map(
            (key, value) => MapEntry(
          key as String,
          (value as List).map((e) => MenuData.fromJson(e as Map<dynamic, dynamic>)).toList(),
        ),
      ),
      lastModifiedPart: json['lastModifiedPart'] as String?,
    );
  }

  // ★ 追加: DailyRecordをMapに変換するメソッド ★
  Map<String, dynamic> toJson() {
    return {
      'menus': menus.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
      'lastModifiedPart': lastModifiedPart,
    };
  }
}
