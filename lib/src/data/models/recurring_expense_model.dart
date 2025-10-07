import 'package:hive/hive.dart';

import '../../domain/entities/expense_category.dart';
import '../../domain/entities/recurring_expense.dart';

part 'recurring_expense_model.g.dart';

@HiveType(typeId: 4)
class RecurringExpenseModel extends HiveObject {
  RecurringExpenseModel({
    required this.id,
    required this.label,
    required this.category,
    required this.amount,
    required this.dayOfMonth,
    this.autoAdd = true,
    this.note,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  ExpenseCategory category;

  @HiveField(3)
  double amount;

  @HiveField(4)
  int dayOfMonth;

  @HiveField(5)
  bool autoAdd;

  @HiveField(6)
  String? note;

  @HiveField(7)
  bool active;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  RecurringExpense toDomain() {
    return RecurringExpense(
      id: id,
      label: label,
      category: category,
      amount: amount,
      dayOfMonth: dayOfMonth,
      autoAdd: autoAdd,
      note: note,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static RecurringExpenseModel fromDomain(RecurringExpense expense) {
    return RecurringExpenseModel(
      id: expense.id,
      label: expense.label,
      category: expense.category,
      amount: expense.amount,
      dayOfMonth: expense.dayOfMonth,
      autoAdd: expense.autoAdd,
      note: expense.note,
      active: expense.active,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'category': category.name,
      'amount': amount,
      'dayOfMonth': dayOfMonth,
      'autoAdd': autoAdd,
      'note': note,
      'active': active,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static RecurringExpenseModel fromMap(Map<String, dynamic> map) {
    return RecurringExpenseModel(
      id: map['id'] as String,
      label: map['label'] as String,
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ExpenseCategory.misc,
      ),
      amount: (map['amount'] as num).toDouble(),
      dayOfMonth: map['dayOfMonth'] as int,
      autoAdd: map['autoAdd'] as bool? ?? true,
      note: map['note'] as String?,
      active: map['active'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
