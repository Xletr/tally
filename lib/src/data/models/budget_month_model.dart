import 'package:hive/hive.dart';

import '../../domain/entities/budget_month.dart';
import '../../domain/entities/expense_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/entities/recurring_expense.dart';

part 'budget_month_model.g.dart';

@HiveType(typeId: 1)
class BudgetMonthModel extends HiveObject {
  BudgetMonthModel({
    required this.id,
    required this.year,
    required this.month,
    required this.baseAllowance,
    required this.rolloverAmount,
    required this.rolloverEnabled,
    required this.savingsTarget,
    required this.createdAt,
    required this.updatedAt,
    this.cycleLockDate,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  int year;

  @HiveField(2)
  int month;

  @HiveField(3)
  double baseAllowance;

  @HiveField(4)
  double rolloverAmount;

  @HiveField(5)
  bool rolloverEnabled;

  @HiveField(6)
  double savingsTarget;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  DateTime? cycleLockDate;

  BudgetMonth toDomain({
    required List<IncomeEntry> incomes,
    required List<ExpenseEntry> expenses,
    required List<RecurringExpense> recurring,
  }) {
    return BudgetMonth(
      id: id,
      year: year,
      month: month,
      baseAllowance: baseAllowance,
      rolloverAmount: rolloverAmount,
      rolloverEnabled: rolloverEnabled,
      savingsTarget: savingsTarget,
      incomes: incomes,
      expenses: expenses,
      recurringExpenses: recurring,
      createdAt: createdAt,
      updatedAt: updatedAt,
      cycleLockDate: cycleLockDate,
    );
  }

  static BudgetMonthModel fromDomain(BudgetMonth month) {
    return BudgetMonthModel(
      id: month.id,
      year: month.year,
      month: month.month,
      baseAllowance: month.baseAllowance,
      rolloverAmount: month.rolloverAmount,
      rolloverEnabled: month.rolloverEnabled,
      savingsTarget: month.savingsTarget,
      createdAt: month.createdAt,
      updatedAt: month.updatedAt,
      cycleLockDate: month.cycleLockDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'baseAllowance': baseAllowance,
      'rolloverAmount': rolloverAmount,
      'rolloverEnabled': rolloverEnabled,
      'savingsTarget': savingsTarget,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'cycleLockDate': cycleLockDate?.toIso8601String(),
    };
  }

  static BudgetMonthModel fromMap(Map<String, dynamic> map) {
    return BudgetMonthModel(
      id: map['id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      baseAllowance: (map['baseAllowance'] as num?)?.toDouble() ?? 0,
      rolloverAmount: (map['rolloverAmount'] as num?)?.toDouble() ?? 0,
      rolloverEnabled: map['rolloverEnabled'] as bool? ?? true,
      savingsTarget: (map['savingsTarget'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      cycleLockDate: map['cycleLockDate'] != null
          ? DateTime.parse(map['cycleLockDate'] as String)
          : null,
    );
  }
}
