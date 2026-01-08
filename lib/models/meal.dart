// lib/models/meal.dart

enum MealCategory { morning, noon, evening, snack }

class MealItem {
  MealItem({this.name = '', this.kcal});

  String name;
  double? kcal;
}

class MealCardState {
  MealCardState({
    required this.category,
    required this.items,
    this.subtotalKcal = 0,
    this.hour,
    this.minute,
  });

  MealCategory category;
  List<MealItem> items;
  double subtotalKcal;
  int? hour;
  int? minute;
}
