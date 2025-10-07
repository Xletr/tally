import 'dart:math';

import 'package:equatable/equatable.dart';

import 'expense_entry.dart';
import 'income_entry.dart';
import 'recurring_expense.dart';

class BudgetMonth extends Equatable {
  const BudgetMonth({
    required this.id,
    required this.year,
    required this.month,
    required this.baseAllowance,
    required this.rolloverAmount,
    required this.rolloverEnabled,
    required this.savingsTarget,
    required this.incomes,
    required this.expenses,
    required this.recurringExpenses,
    required this.createdAt,
    required this.updatedAt,
    this.cycleLockDate,
  });

  final String id;
  final int year;
  final int month;
  final double baseAllowance;
  final double rolloverAmount;
  final bool rolloverEnabled;
  final double savingsTarget;
  final List<IncomeEntry> incomes;
  final List<ExpenseEntry> expenses;
  final List<RecurringExpense> recurringExpenses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cycleLockDate;

  DateTime get cycleStart => DateTime(year, month, 1);
  DateTime get cycleEnd => DateTime(year, month + 1, 0);

  double get incomeTotal => incomes.fold(0, (sum, item) => sum + item.amount);
  double get expenseTotal => expenses.fold(0, (sum, item) => sum + item.amount);

  double get availableFunds =>
      baseAllowance + (rolloverEnabled ? rolloverAmount : 0) + incomeTotal;

  double get remaining => availableFunds - expenseTotal;

  double get projectedSavings => max(0, remaining);

  double get savingsDelta => projectedSavings - savingsTarget;

  double spendingByDay(DateTime day) {
    return expenses
        .where(
          (e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day,
        )
        .fold(0, (sum, e) => sum + e.amount);
  }

  double categoryTotal(String categoryKey) {
    return expenses
        .where((expense) => expense.category.name == categoryKey)
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  BudgetMonth copyWith({
    String? id,
    int? year,
    int? month,
    double? baseAllowance,
    double? rolloverAmount,
    bool? rolloverEnabled,
    double? savingsTarget,
    List<IncomeEntry>? incomes,
    List<ExpenseEntry>? expenses,
    List<RecurringExpense>? recurringExpenses,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cycleLockDate,
  }) {
    return BudgetMonth(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      baseAllowance: baseAllowance ?? this.baseAllowance,
      rolloverAmount: rolloverAmount ?? this.rolloverAmount,
      rolloverEnabled: rolloverEnabled ?? this.rolloverEnabled,
      savingsTarget: savingsTarget ?? this.savingsTarget,
      incomes: incomes ?? this.incomes,
      expenses: expenses ?? this.expenses,
      recurringExpenses: recurringExpenses ?? this.recurringExpenses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cycleLockDate: cycleLockDate ?? this.cycleLockDate,
    );
  }

  @override
  List<Object?> get props => [
    id,
    year,
    month,
    baseAllowance,
    rolloverAmount,
    rolloverEnabled,
    savingsTarget,
    incomes,
    expenses,
    recurringExpenses,
    createdAt,
    updatedAt,
    cycleLockDate,
  ];
}
