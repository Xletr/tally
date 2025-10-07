// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseEntryModelAdapter extends TypeAdapter<ExpenseEntryModel> {
  @override
  final int typeId = 3;

  @override
  ExpenseEntryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseEntryModel(
      id: fields[0] as String,
      monthId: fields[1] as String,
      category: fields[2] as ExpenseCategory,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      isRecurring: fields[5] as bool,
      recurringTemplateId: fields[6] as String?,
      note: fields[7] as String?,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseEntryModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.monthId)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.isRecurring)
      ..writeByte(6)
      ..write(obj.recurringTemplateId)
      ..writeByte(7)
      ..write(obj.note)
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
      other is ExpenseEntryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
