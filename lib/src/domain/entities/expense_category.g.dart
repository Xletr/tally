// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 0;

  @override
  ExpenseCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpenseCategory.food;
      case 1:
        return ExpenseCategory.transport;
      case 2:
        return ExpenseCategory.subscriptions;
      case 3:
        return ExpenseCategory.purchases;
      case 4:
        return ExpenseCategory.misc;
      case 5:
        return ExpenseCategory.savings;
      default:
        return ExpenseCategory.food;
    }
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    switch (obj) {
      case ExpenseCategory.food:
        writer.writeByte(0);
        break;
      case ExpenseCategory.transport:
        writer.writeByte(1);
        break;
      case ExpenseCategory.subscriptions:
        writer.writeByte(2);
        break;
      case ExpenseCategory.purchases:
        writer.writeByte(3);
        break;
      case ExpenseCategory.misc:
        writer.writeByte(4);
        break;
      case ExpenseCategory.savings:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
