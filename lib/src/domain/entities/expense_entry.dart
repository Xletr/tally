import 'package:equatable/equatable.dart';

import 'expense_category.dart';

class ExpenseEntry extends Equatable {
  const ExpenseEntry({
    required this.id,
    required this.monthId,
    required this.category,
    required this.amount,
    required this.date,
    this.isRecurring = false,
    this.recurringTemplateId,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String monthId;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final bool isRecurring;
  final String? recurringTemplateId;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseEntry copyWith({
    String? id,
    String? monthId,
    ExpenseCategory? category,
    double? amount,
    DateTime? date,
    bool? isRecurring,
    String? recurringTemplateId,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      monthId: monthId ?? this.monthId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringTemplateId: recurringTemplateId ?? this.recurringTemplateId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    monthId,
    category,
    amount,
    date,
    isRecurring,
    recurringTemplateId,
    note,
    createdAt,
    updatedAt,
  ];
}
