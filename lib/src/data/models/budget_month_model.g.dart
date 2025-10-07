// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_month_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetMonthModelAdapter extends TypeAdapter<BudgetMonthModel> {
  @override
  final int typeId = 1;

  @override
  BudgetMonthModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetMonthModel(
      id: fields[0] as String,
      year: fields[1] as int,
      month: fields[2] as int,
      baseAllowance: fields[3] as double,
      rolloverAmount: fields[4] as double,
      rolloverEnabled: fields[5] as bool,
      savingsTarget: fields[6] as double,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      cycleLockDate: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetMonthModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.year)
      ..writeByte(2)
      ..write(obj.month)
      ..writeByte(3)
      ..write(obj.baseAllowance)
      ..writeByte(4)
      ..write(obj.rolloverAmount)
      ..writeByte(5)
      ..write(obj.rolloverEnabled)
      ..writeByte(6)
      ..write(obj.savingsTarget)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.cycleLockDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetMonthModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
