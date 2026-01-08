// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MenuDataAdapter extends TypeAdapter<MenuData> {
  @override
  final int typeId = 0;

  @override
  MenuData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MenuData(
      name: fields[0] as String,
      weights: (fields[1] as List).cast<String>(),
      reps: (fields[2] as List).cast<String>(),
      distance: fields[3] as String?,
      duration: fields[4] as String?,
      calories: fields[5] as String?,
      satisfaction: fields[6] as int?,
      checkedStates: (fields[7] as List?)?.cast<bool>(),
      totalVolume: fields[8] as double?,
      rirValues: (fields[9] as List?)?.cast<String>(),
      failureFlags: (fields[10] as List?)?.cast<bool>(),
    );
  }

  @override
  void write(BinaryWriter writer, MenuData obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.totalVolume)
      ..writeByte(9)
      ..write(obj.rirValues)
      ..writeByte(10)
      ..write(obj.failureFlags);
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
      bodyFatPercent: fields[4] as double?,
      waistCm: fields[5] as double?,
      meals: (fields[6] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      bmr: fields[7] as double?,
      trainingStart: fields[8] as DateTime?,
      trainingEnd: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.menus)
      ..writeByte(2)
      ..write(obj.lastModifiedPart)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.bodyFatPercent)
      ..writeByte(5)
      ..write(obj.waistCm)
      ..writeByte(6)
      ..write(obj.meals)
      ..writeByte(7)
      ..write(obj.bmr)
      ..writeByte(8)
      ..write(obj.trainingStart)
      ..writeByte(9)
      ..write(obj.trainingEnd);
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
