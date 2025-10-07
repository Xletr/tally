// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_expense_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringExpenseModelAdapter extends TypeAdapter<RecurringExpenseModel> {
  @override
  final int typeId = 4;

  @override
  RecurringExpenseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringExpenseModel(
      id: fields[0] as String,
      label: fields[1] as String,
      category: fields[2] as ExpenseCategory,
      amount: fields[3] as double,
      dayOfMonth: fields[4] as int,
      autoAdd: fields[5] as bool,
      note: fields[6] as String?,
      active: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringExpenseModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.dayOfMonth)
      ..writeByte(5)
      ..write(obj.autoAdd)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.active)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpenseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
