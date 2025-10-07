import 'package:flutter_test/flutter_test.dart';

import 'package:tally/src/domain/entities/budget_month.dart';
import 'package:tally/src/domain/entities/expense_category.dart';
import 'package:tally/src/domain/entities/expense_entry.dart';
import 'package:tally/src/domain/entities/income_entry.dart';
import 'package:tally/src/domain/logic/budget_metrics.dart';

void main() {
  test('BudgetMetrics calculates inflow and average daily spend', () {
    final month = BudgetMonth(
      id: '2025-09',
      year: 2025,
      month: 9,
      baseAllowance: 0,
      rolloverAmount: 200,
      rolloverEnabled: true,
      savingsTarget: 120,
      incomes: [
        IncomeEntry(
          id: 'inc-1',
          monthId: '2025-09',
          source: 'Monthly inflow',
          amount: 1000,
          date: DateTime(2025, 9, 1),
          createdAt: DateTime(2025, 9, 1),
        ),
      ],
      expenses: [
        ExpenseEntry(
          id: 'exp-1',
          monthId: '2025-09',
          category: ExpenseCategory.subscriptions,
          amount: 150,
          date: DateTime(2025, 9, 1),
          createdAt: DateTime(2025, 9, 1),
        ),
        ExpenseEntry(
          id: 'exp-2',
          monthId: '2025-09',
          category: ExpenseCategory.food,
          amount: 200,
          date: DateTime(2025, 9, 5),
          createdAt: DateTime(2025, 9, 5),
        ),
        ExpenseEntry(
          id: 'exp-3',
          monthId: '2025-09',
          category: ExpenseCategory.savings,
          amount: 120,
          date: DateTime(2025, 9, 3),
          createdAt: DateTime(2025, 9, 3),
        ),
      ],
      recurringExpenses: const [],
      createdAt: DateTime(2025, 9, 1),
      updatedAt: DateTime(2025, 9, 5),
    );

    final metrics = BudgetMetrics.fromMonth(month);

    final daysElapsed = DateTime.now().day.clamp(1, DateTime(2025, 9, 30).day);
    final expectedAverage = (150 / 30.0) + (200 / daysElapsed);

    expect(metrics.available, 1200);
    expect(metrics.subscriptionsTotal, 150);
    expect(metrics.savingsDeposited, 120);
    expect(metrics.rolloverAmount, 200);
    expect(metrics.averageDailySpend, closeTo(expectedAverage, 0.01));
  });
}
