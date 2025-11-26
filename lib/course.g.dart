// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'course.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 0;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      title: fields[0] as String,
      sem: fields[6] as String,
      id: fields[1] as String,
      grade1: fields[3] as int,
      grade2: fields[4] as int,
      discipline: fields[5] as String,
      credits: (fields[2] as num).toDouble(),
      elective: fields[7] == null ? 'CDC' : fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.credits)
      ..writeByte(3)
      ..write(obj.grade1)
      ..writeByte(4)
      ..write(obj.grade2)
      ..writeByte(5)
      ..write(obj.discipline)
      ..writeByte(6)
      ..write(obj.sem)
      ..writeByte(7)
      ..write(obj.elective);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
