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
    );
  }

  @override
  void write(BinaryWriter writer, MenuData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weights)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.duration);
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
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.menus)
      ..writeByte(2)
      ..write(obj.lastModifiedPart)
      ..writeByte(3)
      ..write(obj.weight);
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
