import 'dart:math' as math;

import '../entities/budget_insights.dart';
import '../entities/budget_month.dart';
import '../entities/expense_category.dart';

class SpendingGuidance {
  const SpendingGuidance({
    required this.now,
    required this.remaining,
    required this.averageDailySpend,
    required this.daysInMonth,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.breakEvenDaily,
    required this.savingsAwareDaily,
    required this.savingsGoal,
    required this.savingsSoFar,
    required this.savingsGap,
    required this.projectedClose,
    required this.projectedTotalSpend,
    required this.runwayDays,
    required this.budgetedDaily,
    required this.burnVariancePercent,
  });

  final DateTime now;
  final double remaining;
  final double averageDailySpend;
  final int daysInMonth;
  final int daysElapsed;
  final int daysRemaining;
  final double breakEvenDaily;
  final double savingsAwareDaily;
  final double savingsGoal;
  final double savingsSoFar;
  final double savingsGap;
  final double projectedClose;
  final double projectedTotalSpend;
  final double? runwayDays;
  final double budgetedDaily;
  final double burnVariancePercent;
}

SpendingGuidance computeSpendingGuidance({
  required BudgetMonth month,
  required BudgetInsights insights,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final isCurrentMonth = clock.year == month.year && clock.month == month.month;
  final daysElapsed = isCurrentMonth
      ? math.max(1, math.min(clock.day, daysInMonth))
      : daysInMonth;
  final daysRemaining = math.max(0, daysInMonth - daysElapsed);

  final remaining = insights.remaining;
  final averageDailySpend = insights.averageDailySpend;

  final budgetedDaily = daysInMonth == 0
      ? 0.0
      : month.availableFunds / daysInMonth;
  final burnVariancePercent = budgetedDaily <= 0
      ? 0.0
      : ((averageDailySpend - budgetedDaily) / budgetedDaily) * 100;

  final breakEvenDaily = daysRemaining == 0 ? 0.0 : remaining / daysRemaining;

  final savingsGoal = month.savingsTarget > 0 ? month.savingsTarget : 0.0;
  final savingsSoFar = month.expenses
      .where((expense) => expense.category == ExpenseCategory.savings)
      .fold<double>(0, (sum, expense) => sum + expense.amount);
  final savingsGap = (savingsGoal - savingsSoFar) <= 0
      ? 0.0
      : savingsGoal - savingsSoFar;
  final spendableAfterSavings = (remaining - savingsGap) <= 0
      ? 0.0
      : remaining - savingsGap;
  final savingsAwareDaily = daysRemaining == 0
      ? 0.0
      : spendableAfterSavings / daysRemaining;

  final totalAvailable = month.availableFunds;
  final projectedDiscretionary = averageDailySpend * daysInMonth;
  final projectedTotalSpend = projectedDiscretionary + savingsSoFar;
  final projectedClose = totalAvailable - projectedTotalSpend;

  double? runwayDays;
  if (averageDailySpend <= 0) {
    runwayDays = null;
  } else if (remaining <= 0) {
    runwayDays = 0;
  } else {
    runwayDays = remaining / averageDailySpend;
  }

  return SpendingGuidance(
    now: clock,
    remaining: remaining,
    averageDailySpend: averageDailySpend,
    daysInMonth: daysInMonth,
    daysElapsed: daysElapsed,
    daysRemaining: daysRemaining,
    breakEvenDaily: breakEvenDaily,
    savingsAwareDaily: savingsAwareDaily,
    savingsGoal: savingsGoal,
    savingsSoFar: savingsSoFar,
    savingsGap: savingsGap,
    projectedClose: projectedClose,
    projectedTotalSpend: projectedTotalSpend,
    runwayDays: runwayDays,
    budgetedDaily: budgetedDaily,
    burnVariancePercent: burnVariancePercent,
  );
}
