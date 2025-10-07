import 'package:equatable/equatable.dart';

import 'expense_category.dart';

class RecurringExpense extends Equatable {
  const RecurringExpense({
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

  final String id;
  final String label;
  final ExpenseCategory category;
  final double amount;
  final int dayOfMonth;
  final bool autoAdd;
  final String? note;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringExpense copyWith({
    String? id,
    String? label,
    ExpenseCategory? category,
    double? amount,
    int? dayOfMonth,
    bool? autoAdd,
    String? note,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      autoAdd: autoAdd ?? this.autoAdd,
      note: note ?? this.note,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    label,
    category,
    amount,
    dayOfMonth,
    autoAdd,
    note,
    active,
    createdAt,
    updatedAt,
  ];
}
