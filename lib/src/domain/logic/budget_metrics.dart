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
    required this.savingsDeposited,
    required this.rolloverAmount,
    required this.averageDailySpend,
    required this.savingsTarget,
  });

  final double available;
  final double spent;
  final double remaining;
  final double utilization;
  final Map<ExpenseCategory, double> categoryTotals;
  final double subscriptionsTotal;
  final double savingsDeposited;
  final double rolloverAmount;
  final double averageDailySpend;
  final double savingsTarget;

  static BudgetMetrics fromMonth(BudgetMonth month) {
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
    final daysElapsed = DateTime.now().day.clamp(
      1,
      DateTime(month.year, month.month + 1, 0).day,
    );
    final averageDailySpend = _calculateAverageDailySpend(
      subscriptionsTotal: subscriptionsTotal,
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
      savingsDeposited: savingsDeposited,
      rolloverAmount: month.rolloverEnabled ? month.rolloverAmount : 0,
      averageDailySpend: averageDailySpend,
      savingsTarget: month.savingsTarget,
    );
  }

  static double _calculateAverageDailySpend({
    required double subscriptionsTotal,
    required double otherExpenseTotal,
    required int daysElapsed,
  }) {
    final subscriptionDaily = subscriptionsTotal / 30.0;
    final otherDaily = daysElapsed == 0 ? 0 : otherExpenseTotal / daysElapsed;
    return subscriptionDaily + otherDaily;
  }
}
