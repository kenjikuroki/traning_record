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
      weights: (fields[1] as List).cast<int>(),
      reps: (fields[2] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, MenuData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weights)
      ..writeByte(2)
      ..write(obj.reps);
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
