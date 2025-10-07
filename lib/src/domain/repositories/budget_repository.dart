import '../entities/budget_insights.dart';
import '../entities/budget_month.dart';
import '../entities/expense_entry.dart';
import '../entities/income_entry.dart';
import '../entities/recurring_expense.dart';
import '../entities/subscription_summary.dart';

abstract class BudgetRepository {
  Future<BudgetMonth> ensureCurrentMonth({bool allowRollover = true});

  Stream<BudgetMonth> watchMonth(String monthId);

  Future<BudgetMonth> getMonth(String monthId);

  Future<List<BudgetMonth>> getRecentMonths({int limit = 6});

  Future<void> saveBudgetMonth(BudgetMonth month);

  Future<void> addIncome(IncomeEntry entry);

  Future<void> updateIncome(IncomeEntry entry);

  Future<void> removeIncome(String id);

  Future<void> addExpense(ExpenseEntry entry);

  Future<void> updateExpense(ExpenseEntry entry);

  Future<void> removeExpense(String id);

  Future<List<RecurringExpense>> getRecurringExpenses();

  Stream<List<RecurringExpense>> watchRecurringExpenses();

  Future<void> upsertRecurringExpense(RecurringExpense expense);

  Future<void> deleteRecurringExpense(String id);

  Stream<List<IncomeEntry>> watchIncome(String monthId);

  Stream<List<ExpenseEntry>> watchExpenses(String monthId);

  Future<BudgetInsights> computeInsights(String monthId);

  Future<Map<String, dynamic>> exportData();

  Future<void> importData(Map<String, dynamic> data);

  Future<List<SubscriptionSummary>> getSubscriptionSummaries();
}
