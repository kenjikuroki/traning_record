// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_data.dart';

List<bool>? _readBoolList(dynamic value) {
  if (value is Iterable && value is! String) {
    return value.map((e) => e == true).toList();
  }
  return null;
}

double? _readTotalVolume(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MenuDataAdapter extends TypeAdapter<MenuData> {
  @override
  final int typeId = 0;

  @override
  @override
  MenuData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    String? calories;
    int? sat;
    List<bool>? checked;
    double? totalVolume;

    if (fields.containsKey(5)) {
      final dynamic v5 = fields[5];
      if (v5 is String) {
        calories = v5;
        final dynamic v6 = fields[6];
        sat = (v6 is int) ? v6 : null;
        checked = _readBoolList(fields[7]);
        totalVolume = _readTotalVolume(fields[8]);
      } else if (v5 is int) {
        sat = v5;
        final dynamic v6 = fields[6];
        if (v6 is String) {
          calories = v6;
          checked = _readBoolList(fields[7]);
          totalVolume = _readTotalVolume(fields[8]);
        } else {
          calories = v6 as String?; // 中間期のデータでは null
          checked = _readBoolList(v6);
          totalVolume = _readTotalVolume(fields[7]);
        }
      } else {
        calories = v5 as String?;
        sat = (fields[6] is int) ? fields[6] as int : null;
        checked = _readBoolList(fields[7]);
        totalVolume = _readTotalVolume(fields[8]);
      }
    } else {
      calories = fields[6] as String?;
      sat = (fields[7] is int) ? fields[7] as int : null;
      checked = _readBoolList(fields[8]);
      totalVolume = _readTotalVolume(fields[9]);
    }

    return MenuData(
      name: fields[0] as String,
      weights: (fields[1] as List).cast<String>(),
      reps: (fields[2] as List).cast<String>(),
      distance: fields[3] as String?,
      duration: fields[4] as String?,
      calories: calories,
      satisfaction: sat,
      checkedStates: checked,
      totalVolume: totalVolume,
    );
  }

  @override
  void write(BinaryWriter writer, MenuData obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weights)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.duration)
      ..writeByte(5)
      ..write(obj.calories)
      ..writeByte(6)
      ..write(obj.satisfaction)
      ..writeByte(7)
      ..write(obj.checkedStates)
      ..writeByte(8)
      ..write(obj.totalVolume);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyRecordAdapter extends TypeAdapter<DailyRecord> {
  @override
  final int typeId = 1;

  @override
  DailyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyRecord(
      date: fields[0] as DateTime,
      menus: (fields[1] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<MenuData>())),
      lastModifiedPart: fields[2] as String?,
      weight: fields[3] as double?,
      bodyFatPercent: fields[4] as double?, // 追加
      waistCm: fields[5] as double?,        // 追加
      meals: (fields[6] as List?)
          ?.map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      bmr: fields[7] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.menus)
      ..writeByte(2)
      ..write(obj.lastModifiedPart)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4) // 追加
      ..write(obj.bodyFatPercent)
      ..writeByte(5) // 追加
      ..write(obj.waistCm)
      ..writeByte(6)
      ..write(obj.meals)
      ..writeByte(7)
      ..write(obj.bmr);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
