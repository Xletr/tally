import '../entities/budget_month.dart';
import '../entities/expense_category.dart';

class BudgetMetrics {
  BudgetMetrics({
    required this.available,
    required this.spent,
    required this.remaining,
    required this.utilization,
    required this.categoryTotals,
    required this.subscriptionsTotal,
    required this.subscriptionsMonthly,
    required this.savingsDeposited,
    required this.rolloverAmount,
    required this.averageDailySpend,
    required this.savingsTarget,
    required this.daysInMonth,
    required this.daysElapsed,
    required this.isCurrentMonth,
  });

  final double available;
  final double spent;
  final double remaining;
  final double utilization;
  final Map<ExpenseCategory, double> categoryTotals;
  final double subscriptionsTotal;
  final double subscriptionsMonthly;
  final double savingsDeposited;
  final double rolloverAmount;
  final double averageDailySpend;
  final double savingsTarget;
  final int daysInMonth;
  final int daysElapsed;
  final bool isCurrentMonth;

  static BudgetMetrics fromMonth(BudgetMonth month) {
    final now = DateTime.now();
    final monthDate = DateTime(month.year, month.month);
    final currentMonthDate = DateTime(now.year, now.month);
    final isCurrentMonth = monthDate.year == now.year && monthDate.month == now.month;
    final isFutureMonth = monthDate.isAfter(currentMonthDate);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysElapsed = isFutureMonth
        ? 0
        : isCurrentMonth
            ? now.day.clamp(1, daysInMonth)
            : daysInMonth;
    final available = month.availableFunds;
    final spent = month.expenseTotal;
    final remaining = month.remaining;
    double utilization = 0;
    if (available > 0) {
      final ratio = spent / available;
      utilization = ratio > 1 ? 1 : ratio;
    }
    final categoryTotals = <ExpenseCategory, double>{};
    double subscriptionsTotal = 0;
    double savingsDeposited = 0;
    for (final expense in month.expenses) {
      categoryTotals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
      if (expense.category == ExpenseCategory.subscriptions ||
          expense.isRecurring) {
        subscriptionsTotal += expense.amount;
      }
      if (expense.category == ExpenseCategory.savings) {
        savingsDeposited += expense.amount;
      }
    }
    final subscriptionsMonthly = month.recurringExpenses
        .where((template) => template.autoAdd && template.active)
        .where((template) {
          final creationMonth = DateTime(
            template.createdAt.year,
            template.createdAt.month,
          );
          return !creationMonth.isAfter(monthDate);
        })
        .fold<double>(0, (sum, template) => sum + template.amount);
    final averageDailySpend = _calculateAverageDailySpend(
      subscriptionsMonthly: subscriptionsMonthly,
      otherExpenseTotal: spent - subscriptionsTotal - savingsDeposited,
      daysElapsed: daysElapsed,
    );
    return BudgetMetrics(
      available: available,
      spent: spent,
      remaining: remaining,
      utilization: utilization,
      categoryTotals: categoryTotals,
      subscriptionsTotal: subscriptionsTotal,
      subscriptionsMonthly: subscriptionsMonthly,
      savingsDeposited: savingsDeposited,
      rolloverAmount: month.rolloverEnabled ? month.rolloverAmount : 0,
      averageDailySpend: averageDailySpend,
      savingsTarget: month.savingsTarget,
      daysInMonth: daysInMonth,
      daysElapsed: daysElapsed,
      isCurrentMonth: isCurrentMonth,
    );
  }

  static double _calculateAverageDailySpend({
    required double subscriptionsMonthly,
    required double otherExpenseTotal,
    required int daysElapsed,
  }) {
    final subscriptionDaily = subscriptionsMonthly / 30.0;
    final otherDaily = daysElapsed <= 0 ? 0 : otherExpenseTotal / daysElapsed;
    return subscriptionDaily + otherDaily;
  }
}
