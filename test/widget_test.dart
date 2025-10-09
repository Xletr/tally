import 'package:flutter_test/flutter_test.dart';

import 'package:tally/src/domain/entities/budget_month.dart';
import 'package:tally/src/domain/entities/expense_category.dart';
import 'package:tally/src/domain/entities/expense_entry.dart';
import 'package:tally/src/domain/entities/income_entry.dart';
import 'package:tally/src/domain/entities/recurring_expense.dart';
import 'package:tally/src/domain/logic/budget_metrics.dart';

void main() {
  test('BudgetMetrics calculates inflow and average daily spend', () {
    final now = DateTime.now();
    final month = BudgetMonth(
      id: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      year: now.year,
      month: now.month,
      baseAllowance: 0,
      rolloverAmount: 200,
      rolloverEnabled: true,
      savingsTarget: 120,
      incomes: [
        IncomeEntry(
          id: 'inc-1',
          monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          source: 'Monthly inflow',
          amount: 1000,
          date: DateTime(now.year, now.month, 1),
          createdAt: DateTime(now.year, now.month, 1),
        ),
      ],
      expenses: [
        ExpenseEntry(
          id: 'exp-1',
          monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          category: ExpenseCategory.subscriptions,
          amount: 150,
          date: DateTime(now.year, now.month, 1),
          createdAt: DateTime(now.year, now.month, 1),
        ),
        ExpenseEntry(
          id: 'exp-2',
          monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          category: ExpenseCategory.food,
          amount: 200,
          date: DateTime(now.year, now.month, 5),
          createdAt: DateTime(now.year, now.month, 5),
        ),
        ExpenseEntry(
          id: 'exp-3',
          monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          category: ExpenseCategory.savings,
          amount: 120,
          date: DateTime(now.year, now.month, 3),
          createdAt: DateTime(now.year, now.month, 3),
        ),
      ],
      recurringExpenses: [
        RecurringExpense(
          id: 'rec-1',
          label: 'Music',
          category: ExpenseCategory.subscriptions,
          amount: 150,
          dayOfMonth: 1,
          autoAdd: true,
          active: true,
          note: null,
          createdAt: DateTime(now.year, now.month, 1),
          updatedAt: DateTime(now.year, now.month, 1),
        ),
      ],
      createdAt: DateTime(now.year, now.month, 1),
      updatedAt: DateTime(now.year, now.month, 5),
    );

    final metrics = BudgetMetrics.fromMonth(month);

    final daysElapsed = metrics.daysElapsed == 0 ? 1 : metrics.daysElapsed;
    final otherExpenseTotal = month.expenseTotal - metrics.subscriptionsTotal - metrics.savingsDeposited;
    final expectedAverage = (metrics.subscriptionsMonthly / 30.0) + (otherExpenseTotal / daysElapsed);

    expect(metrics.available, 1200);
    expect(metrics.subscriptionsTotal, 150);
    expect(metrics.subscriptionsMonthly, 150);
    expect(metrics.savingsDeposited, 120);
    expect(metrics.rolloverAmount, 200);
    expect(metrics.averageDailySpend, closeTo(expectedAverage, 0.01));
    expect(metrics.daysInMonth, DateTime(now.year, now.month + 1, 0).day);
    expect(metrics.isCurrentMonth, true);
  });
}
