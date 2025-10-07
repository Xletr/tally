import '../../domain/entities/budget_month.dart';

class InsightsPayload {
  InsightsPayload({
    required this.target,
    required this.history,
    required this.nowIso,
  });

  final Map<String, dynamic> target;
  final List<Map<String, dynamic>> history;
  final String nowIso;
}

Map<String, dynamic> serializeBudgetMonth(BudgetMonth month) {
  return {
    'id': month.id,
    'year': month.year,
    'month': month.month,
    'baseAllowance': month.baseAllowance,
    'rolloverAmount': month.rolloverAmount,
    'rolloverEnabled': month.rolloverEnabled,
    'savingsTarget': month.savingsTarget,
    'incomes': month.incomes
        .map(
          (income) => {
            'amount': income.amount,
            'date': income.date.toIso8601String(),
          },
        )
        .toList(),
    'expenses': month.expenses
        .map(
          (expense) => {
            'amount': expense.amount,
            'category': expense.category.name,
            'date': expense.date.toIso8601String(),
          },
        )
        .toList(),
  };
}

List<Map<String, dynamic>> serializeBudgetMonths(Iterable<BudgetMonth> months) {
  return months.map(serializeBudgetMonth).toList();
}
