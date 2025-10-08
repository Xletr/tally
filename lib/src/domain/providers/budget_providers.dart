import 'package:collection/collection.dart';
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

final allMonthsProvider = FutureProvider<List<BudgetMonth>>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);
  ref.watch(currentBudgetMonthProvider);
  return repository.getAllMonths();
});

final earliestMonthStartProvider = FutureProvider<DateTime>((ref) async {
  final repository = ref.watch(budgetRepositoryProvider);
  ref.watch(currentBudgetMonthProvider);
  return repository.getEarliestMonthStart();
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
        final presets = ref.read(categoryQuickPresetsProvider);
        final grouped = month.expenses.groupListsBy(
          (expense) => expense.category,
        );
        final result = <ExpenseCategory, List<double>>{};
        grouped.forEach((category, entries) {
          final presetValues = presets[category] ?? const <double>[];
          final sorted = entries.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final recent = sorted.firstWhereOrNull(
            (entry) => !presetValues.contains(entry.amount),
          );
          if (recent != null) {
            result[category] = [recent.amount.abs()];
          }
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
      final sorted = month.incomes.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (sorted.isEmpty) {
        return const <double>[20, 50, 100];
      }
      return [sorted.first.amount.abs()];
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
