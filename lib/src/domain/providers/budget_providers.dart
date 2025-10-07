import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/bootstrap.dart';
import '../../data/repositories/budget_repository_impl.dart';
import '../../domain/entities/budget_insights.dart';
import '../../domain/entities/budget_month.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/entities/subscription_summary.dart';
import '../../domain/repositories/budget_repository.dart';
import 'settings_providers.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapProvider);
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  return BudgetRepositoryImpl(bootstrap, settingsRepository);
});

final currentDateStreamProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

final currentDateProvider = Provider<DateTime>((ref) {
  return ref
      .watch(currentDateStreamProvider)
      .maybeWhen(data: (value) => value, orElse: () => DateTime.now());
});

final currentMonthIdProvider = Provider<String>((ref) {
  final now = ref.watch(currentDateProvider);
  final normalized = DateTime(now.year, now.month);
  return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}';
});

final currentBudgetMonthProvider = StreamProvider<BudgetMonth>((ref) async* {
  final repository = ref.watch(budgetRepositoryProvider);
  final monthId = ref.watch(currentMonthIdProvider);
  await repository.ensureCurrentMonth();
  yield* repository.watchMonth(monthId);
});

final incomeListProvider = StreamProvider<List<IncomeEntry>>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  final monthId = ref.watch(currentMonthIdProvider);
  return repository.watchIncome(monthId);
});

final expenseListProvider = StreamProvider<List<ExpenseEntry>>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  final monthId = ref.watch(currentMonthIdProvider);
  return repository.watchExpenses(monthId);
});

final recurringExpenseListProvider = StreamProvider<List<RecurringExpense>>((
  ref,
) {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.watchRecurringExpenses();
});

final budgetInsightsProvider = FutureProvider<BudgetInsights>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);
  final month = await ref.watch(currentBudgetMonthProvider.future);
  return repository.computeInsights(month.id);
});

final recentMonthsProvider = FutureProvider<List<BudgetMonth>>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getRecentMonths(limit: 6);
});

final expenseSuggestionsProvider = Provider<Map<ExpenseCategory, List<double>>>(
  (ref) {
    final monthAsync = ref.watch(currentBudgetMonthProvider);
    return monthAsync.maybeWhen(
      data: (month) {
        final grouped = <ExpenseCategory, List<double>>{};
        for (final expense in month.expenses) {
          grouped
              .putIfAbsent(expense.category, () => <double>[])
              .add(expense.amount);
        }
        final result = <ExpenseCategory, List<double>>{};
        grouped.forEach((category, amounts) {
          final top = amounts.map((value) => value.abs()).toList()..sort();
          result[category] = top.reversed.take(5).toList().reversed.toList();
        });
        return result;
      },
      orElse: () => const {},
    );
  },
);

final incomeSuggestionsProvider = Provider<List<double>>((ref) {
  final monthAsync = ref.watch(currentBudgetMonthProvider);
  return monthAsync.maybeWhen(
    data: (month) {
      final amounts =
          month.incomes.map((income) => income.amount.abs()).toList()..sort();
      return amounts.reversed.take(5).toList().reversed.toList();
    },
    orElse: () => const <double>[20, 50, 100],
  );
});

final subscriptionSummariesProvider = FutureProvider<List<SubscriptionSummary>>(
  (ref) {
    ref.watch(recurringExpenseListProvider);
    final repository = ref.watch(budgetRepositoryProvider);
    return repository.getSubscriptionSummaries();
  },
);
