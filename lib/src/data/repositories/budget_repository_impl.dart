import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../core/bootstrap/bootstrap.dart';
import '../../domain/entities/budget_insights.dart';
import '../../domain/entities/budget_month.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/entities/subscription_summary.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/budget_month_model.dart';
import '../models/budget_settings_model.dart';
import '../models/expense_entry_model.dart';
import '../models/income_entry_model.dart';
import '../models/recurring_expense_model.dart';
import '../services/insights_payload.dart';
import '../services/insights_worker.dart';
import '../services/month_id.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(
    this._bootstrap,
    this._settingsRepository, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppBootstrap _bootstrap;
  final SettingsRepository _settingsRepository;
  final DateTime Function() _now;

  @override
  Future<BudgetMonth> ensureCurrentMonth({bool allowRollover = true}) async {
    final today = _now();
    final monthId = buildMonthId(DateTime(today.year, today.month));
    final existing = _bootstrap.monthsBox.get(monthId);
    final settings = await _settingsRepository.load();
    if (existing != null) {
      await _migrateExistingMonth(existing, settings);
      return _buildMonth(existing);
    }

    final previousMonthId = buildMonthId(DateTime(today.year, today.month - 1));
    double rolloverAmount = 0;
    double inferredAllowance = settings.defaultMonthlyAllowance;
    if (_bootstrap.monthsBox.containsKey(previousMonthId)) {
      final previous = await getMonth(previousMonthId);
      inferredAllowance = previous.baseAllowance;
      if (allowRollover && settings.autoRollover && previous.rolloverEnabled) {
        rolloverAmount = previous.remaining;
      }
    }

    if (inferredAllowance <= 0) {
      inferredAllowance = settings.defaultMonthlyAllowance;
    }

    final savingsTarget = settings.monthlySavingsGoal > 0
        ? settings.monthlySavingsGoal
        : max(
            0.0,
            (inferredAllowance + rolloverAmount) * settings.defaultSavingsRate,
          );

    final model = BudgetMonthModel(
      id: monthId,
      year: today.year,
      month: today.month,
      baseAllowance: 0,
      rolloverAmount: rolloverAmount,
      rolloverEnabled: settings.autoRollover,
      savingsTarget: savingsTarget,
      createdAt: today,
      updatedAt: today,
      cycleLockDate: null,
    );
    await _bootstrap.monthsBox.put(monthId, model);

    await _seedRecurringExpenses(model);
    await _seedAllowanceIncome(model, settings);

    return _buildMonth(model);
  }

  @override
  Future<BudgetMonth> getMonth(String monthId) async {
    final model = _bootstrap.monthsBox.get(monthId);
    if (model == null) {
      throw StateError('Month $monthId not found');
    }
    return _buildMonth(model);
  }

  @override
  Stream<BudgetMonth> watchMonth(String monthId) {
    final controller = StreamController<BudgetMonth>.broadcast();
    StreamSubscription? monthSub;
    StreamSubscription? incomesSub;
    StreamSubscription? expensesSub;
    StreamSubscription? recurringSub;

    Future<void> emit() async {
      if (controller.isClosed) {
        return;
      }
      try {
        final month = await getMonth(monthId);
        controller.add(month);
      } catch (_) {
        // ignore errors after deletion
      }
    }

    controller.onListen = () {
      emit();
      monthSub = _bootstrap.monthsBox.watch(key: monthId).listen((_) => emit());
      incomesSub = _bootstrap.incomesBox.watch().listen((event) {
        if (controller.isClosed) return;
        final value = event.value;
        if (value is IncomeEntryModel && value.monthId == monthId) {
          emit();
        } else if (event.deleted) {
          emit();
        }
      });
      expensesSub = _bootstrap.expensesBox.watch().listen((event) {
        if (controller.isClosed) return;
        final value = event.value;
        if (value is ExpenseEntryModel && value.monthId == monthId) {
          emit();
        } else if (event.deleted) {
          emit();
        }
      });
      recurringSub = _bootstrap.recurringBox.watch().listen((event) {
        if (controller.isClosed) return;
        emit();
      });
    };

    controller.onCancel = () async {
      await monthSub?.cancel();
      await incomesSub?.cancel();
      await expensesSub?.cancel();
      await recurringSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<List<BudgetMonth>> getRecentMonths({int limit = 6}) async {
    final models = _bootstrap.monthsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sliced = models.take(limit).toList();
    final results = <BudgetMonth>[];
    for (final model in sliced) {
      results.add(await _buildMonth(model));
    }
    return results;
  }

  @override
  Future<void> saveBudgetMonth(BudgetMonth month) async {
    final model = BudgetMonthModel.fromDomain(month)..updatedAt = _now();
    await _bootstrap.monthsBox.put(model.id, model);
  }

  @override
  Future<void> addIncome(IncomeEntry entry) async {
    final model = IncomeEntryModel.fromDomain(entry);
    await _bootstrap.incomesBox.put(model.id, model);
    await _touchMonth(entry.monthId);
  }

  @override
  Future<void> updateIncome(IncomeEntry entry) async {
    await addIncome(entry);
  }

  @override
  Future<void> removeIncome(String id) async {
    final existing = _bootstrap.incomesBox.get(id);
    await _bootstrap.incomesBox.delete(id);
    if (existing != null) {
      await _touchMonth(existing.monthId);
    }
  }

  @override
  Future<void> addExpense(ExpenseEntry entry) async {
    final model = ExpenseEntryModel.fromDomain(entry);
    await _bootstrap.expensesBox.put(model.id, model);
    await _touchMonth(entry.monthId);
  }

  @override
  Future<void> updateExpense(ExpenseEntry entry) async {
    await addExpense(entry);
    if (entry.isRecurring && entry.recurringTemplateId != null) {
      final template = _bootstrap.recurringBox.get(entry.recurringTemplateId!);
      if (template != null) {
        template
          ..amount = entry.amount
          ..note = entry.note
          ..updatedAt = _now();
        await template.save();
      }
    }
  }

  @override
  Future<void> removeExpense(String id) async {
    final existing = _bootstrap.expensesBox.get(id);
    await _bootstrap.expensesBox.delete(id);
    if (existing != null) {
      await _touchMonth(existing.monthId);
    }
  }

  @override
  Future<List<RecurringExpense>> getRecurringExpenses() async {
    return _bootstrap.recurringBox.values.map((e) => e.toDomain()).toList();
  }

  @override
  Stream<List<RecurringExpense>> watchRecurringExpenses() {
    return _bootstrap.recurringBox
        .watch()
        .asyncMap((_) async {
          return getRecurringExpenses();
        })
        .startWithFuture(() => getRecurringExpenses());
  }

  @override
  Future<void> upsertRecurringExpense(RecurringExpense expense) async {
    final model = RecurringExpenseModel.fromDomain(expense);
    await _bootstrap.recurringBox.put(model.id, model);
    final now = _now();
    final currentMonthId = buildMonthId(DateTime(now.year, now.month));
    final currentMonth = _bootstrap.monthsBox.get(currentMonthId);
    if (currentMonth != null) {
      await _rebuildRecurringAggregatesForMonth(currentMonth);
    }
  }

  @override
  Future<void> deleteRecurringExpense(String id) async {
    await _bootstrap.recurringBox.delete(id);
    final now = _now();
    final currentMonthId = buildMonthId(DateTime(now.year, now.month));
    final currentMonth = _bootstrap.monthsBox.get(currentMonthId);
    if (currentMonth != null) {
      await _rebuildRecurringAggregatesForMonth(currentMonth);
    }
  }

  @override
  Stream<List<IncomeEntry>> watchIncome(String monthId) {
    return _bootstrap.incomesBox
        .watch()
        .asyncMap((_) async {
          return _incomesFor(monthId);
        })
        .startWithFuture(() => _incomesFor(monthId));
  }

  @override
  Stream<List<ExpenseEntry>> watchExpenses(String monthId) {
    return _bootstrap.expensesBox
        .watch()
        .asyncMap((_) async {
          return _expensesFor(monthId);
        })
        .startWithFuture(() => _expensesFor(monthId));
  }

  @override
  Future<BudgetInsights> computeInsights(String monthId) async {
    final months = await getRecentMonths(limit: 6);
    final target =
        months.firstWhereOrNull((m) => m.id == monthId) ??
        await getMonth(monthId);
    final payload = InsightsPayload(
      target: serializeBudgetMonth(target),
      history: serializeBudgetMonths(months),
      nowIso: _now().toIso8601String(),
    );
    final result = await compute(runInsightsWorker, payload);
    return _mapToInsights(result);
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final months = _bootstrap.monthsBox.values.map((m) => m.toMap()).toList();
    final incomes = _bootstrap.incomesBox.values.map((m) => m.toMap()).toList();
    final expenses = _bootstrap.expensesBox.values
        .map((m) => m.toMap())
        .toList();
    final recurring = _bootstrap.recurringBox.values
        .map((m) => m.toMap())
        .toList();
    final settings = _bootstrap.activeSettingsModel.toMap();

    return {
      'version': 1,
      'exportedAt': _now().toIso8601String(),
      'months': months,
      'incomes': incomes,
      'expenses': expenses,
      'recurring': recurring,
      'settings': settings,
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    final months = (data['months'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              BudgetMonthModel.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final incomes = (data['incomes'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              IncomeEntryModel.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final expenses = (data['expenses'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              ExpenseEntryModel.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final recurring = (data['recurring'] as List<dynamic>? ?? const [])
        .map(
          (item) => RecurringExpenseModel.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    final settingsMap = Map<String, dynamic>.from(
      data['settings'] as Map? ?? {},
    );
    final settings = BudgetSettingsModel.fromMap(settingsMap);

    await Future.wait([
      _bootstrap.monthsBox.clear(),
      _bootstrap.incomesBox.clear(),
      _bootstrap.expensesBox.clear(),
      _bootstrap.recurringBox.clear(),
    ]);

    for (final model in months) {
      await _bootstrap.monthsBox.put(model.id, model);
    }
    for (final model in incomes) {
      await _bootstrap.incomesBox.put(model.id, model);
    }
    for (final model in expenses) {
      await _bootstrap.expensesBox.put(model.id, model);
    }
    for (final model in recurring) {
      await _bootstrap.recurringBox.put(model.id, model);
    }
    await _bootstrap.saveSettingsModel(settings);
  }

  Future<List<IncomeEntry>> _incomesFor(String monthId) async {
    return _bootstrap.incomesBox.values
        .where((element) => element.monthId == monthId)
        .map((e) => e.toDomain())
        .sorted((a, b) => b.date.compareTo(a.date));
  }

  Future<List<ExpenseEntry>> _expensesFor(String monthId) async {
    return _bootstrap.expensesBox.values
        .where((element) => element.monthId == monthId)
        .map((e) => e.toDomain())
        .sorted((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<SubscriptionSummary>> getSubscriptionSummaries() async {
    final templates = _bootstrap.recurringBox.values.toList();
    final expensesByTemplate = <String, List<ExpenseEntryModel>>{};
    for (final expense in _bootstrap.expensesBox.values) {
      final templateId = expense.recurringTemplateId;
      if (templateId == null) continue;
      expensesByTemplate
          .putIfAbsent(templateId, () => <ExpenseEntryModel>[])
          .add(expense);
    }

    final summaries = <SubscriptionSummary>[];
    for (final template in templates) {
      final related = expensesByTemplate[template.id];
      if (related == null || related.isEmpty) {
        summaries.add(
          SubscriptionSummary(
            template: template.toDomain(),
            lifetimeSpent: 0,
            chargeCount: 0,
            lastChargedAt: null,
          ),
        );
        continue;
      }

      final total = related.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );
      final last = related.reduce(
        (a, b) => a.date.isAfter(b.date) ? a : b,
      ).date;

      summaries.add(
        SubscriptionSummary(
          template: template.toDomain(),
          lifetimeSpent: total,
          chargeCount: related.length,
          lastChargedAt: last,
        ),
      );
    }
    summaries.sort((a, b) => a.template.label.compareTo(b.template.label));
    return summaries;
  }

  Future<void> _touchMonth(String monthId) async {
    final model = _bootstrap.monthsBox.get(monthId);
    if (model == null) {
      return;
    }
    model.updatedAt = _now();
    await model.save();
  }

  Future<BudgetMonth> _buildMonth(BudgetMonthModel model) async {
    final incomes = await _incomesFor(model.id);
    final expenses = await _expensesFor(model.id);
    final recurring = _bootstrap.recurringBox.values
        .map((e) => e.toDomain())
        .toList();
    return model.toDomain(
      incomes: incomes,
      expenses: expenses,
      recurring: recurring,
    );
  }

  Future<void> _seedRecurringExpenses(BudgetMonthModel month) async {
    await _rebuildRecurringAggregatesForMonth(month);
  }

  Future<void> _migrateExistingMonth(
    BudgetMonthModel monthModel,
    BudgetSettings settings,
  ) async {
    var changed = false;
    if (monthModel.baseAllowance != 0) {
      monthModel.baseAllowance = 0;
      changed = true;
    }
    if (changed) {
      await monthModel.save();
    }
    await _seedAllowanceIncome(monthModel, settings);
    await _rebuildRecurringAggregatesForMonth(monthModel);
  }

  Future<void> _rebuildRecurringAggregatesForMonth(
    BudgetMonthModel month,
  ) async {
    final monthDate = DateTime(month.year, month.month);
    final templates = _bootstrap.recurringBox.values
        .where((template) => template.autoAdd && template.active)
        .where((template) {
          final creationMonth = DateTime(
            template.createdAt.year,
            template.createdAt.month,
          );
          return !creationMonth.isAfter(monthDate);
        })
        .toList();

    // Remove legacy per-template entries.
    final legacyEntries = _bootstrap.expensesBox.values.where(
      (expense) =>
          expense.monthId == month.id &&
          expense.isRecurring &&
          expense.recurringTemplateId != null,
    );
    for (final legacy in legacyEntries) {
      await _bootstrap.expensesBox.delete(legacy.id);
    }

    final grouped = <int, List<RecurringExpenseModel>>{};
    for (final template in templates) {
      final chargeDate = _subscriptionChargeDateForMonth(template, month);
      if (chargeDate == null) continue;
      final day = chargeDate.day;
      grouped.putIfAbsent(day, () => []).add(template);
    }

    final expectedIds = <String>{};

    for (final entry in grouped.entries) {
      final day = entry.key;
      final items = entry.value;
      final id = _aggregateExpenseId(month.id, day);
      expectedIds.add(id);

      final amount = items.fold<double>(0, (sum, item) => sum + item.amount);
      final note = _buildSubscriptionNote(items);
      final chargeDate = DateTime(month.year, month.month, day);

      final existing = _bootstrap.expensesBox.get(id);
      if (existing != null) {
        final updated = existing
          ..amount = amount
          ..note = note
          ..date = chargeDate
          ..category = ExpenseCategory.subscriptions
          ..isRecurring = true
          ..recurringTemplateId = null
          ..updatedAt = _now();
        await updated.save();
      } else {
        final model = ExpenseEntryModel(
          id: id,
          monthId: month.id,
          category: ExpenseCategory.subscriptions,
          amount: amount,
          date: chargeDate,
          isRecurring: true,
          recurringTemplateId: null,
          note: note,
          createdAt: _now(),
          updatedAt: null,
        );
        await _bootstrap.expensesBox.put(id, model);
      }
    }

    // Remove aggregates that are no longer needed.
    final existingAggregates = _bootstrap.expensesBox.values.where(
      (expense) =>
          expense.monthId == month.id &&
          expense.isRecurring &&
          expense.recurringTemplateId == null &&
          expense.id.startsWith('recurring-${month.id}-'),
    );
    for (final aggregate in existingAggregates) {
      if (!expectedIds.contains(aggregate.id)) {
        await _bootstrap.expensesBox.delete(aggregate.id);
      }
    }
  }

  DateTime? _subscriptionChargeDateForMonth(
    RecurringExpenseModel template,
    BudgetMonthModel month,
  ) {
    final monthDate = DateTime(month.year, month.month);
    final creationMonth = DateTime(
      template.createdAt.year,
      template.createdAt.month,
    );
    if (creationMonth.isAfter(monthDate)) {
      return null;
    }
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    var day = template.dayOfMonth.clamp(1, lastDay);
    if (creationMonth == monthDate && template.createdAt.day > day) {
      day = template.createdAt.day.clamp(1, lastDay);
    }
    return DateTime(month.year, month.month, day);
  }

  String _aggregateExpenseId(String monthId, int day) =>
      'recurring-$monthId-$day';

  String _buildSubscriptionNote(List<RecurringExpenseModel> templates) {
    final parts = templates
        .map(
          (template) =>
              '${template.label} (\$${template.amount.toStringAsFixed(2)})',
        )
        .toList();
    return 'Includes: ${parts.join(', ')}';
  }

  Future<void> _seedAllowanceIncome(
    BudgetMonthModel month,
    BudgetSettings settings,
  ) async {
    if (settings.defaultMonthlyAllowance <= 0) {
      return;
    }
    final allowanceId = 'allowance-${month.id}';
    final existing = _bootstrap.incomesBox.get(allowanceId);
    if (existing != null) {
      existing
        ..amount = settings.defaultMonthlyAllowance
        ..source = 'Monthly inflow'
        ..date = DateTime(month.year, month.month, 1)
        ..updatedAt = _now();
      await existing.save();
      return;
    }
    final income = IncomeEntryModel(
      id: allowanceId,
      monthId: month.id,
      source: 'Monthly inflow',
      amount: settings.defaultMonthlyAllowance,
      date: DateTime(month.year, month.month, 1),
      note: null,
      createdAt: _now(),
      updatedAt: null,
    );
    await _bootstrap.incomesBox.put(allowanceId, income);
  }

  BudgetInsights _mapToInsights(Map<String, dynamic> map) {
    final topCategories = (map['topCategories'] as List<dynamic>)
        .map(
          (item) => CategoryBreakdown(
            category: ExpenseCategory.values.firstWhere(
              (cat) => cat.name == (item['category'] as String? ?? 'misc'),
              orElse: () => ExpenseCategory.misc,
            ),
            total: (item['total'] as num?)?.toDouble() ?? 0,
            percentage: (item['percentage'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();

    final comparison = map['comparison'] as Map<String, dynamic>? ?? const {};
    final trend = (map['trendline'] as List<dynamic>? ?? const [])
        .map(
          (item) => TrendPoint(
            monthLabel: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();

    return BudgetInsights(
      monthId: map['monthId'] as String? ?? '',
      totalIncome: (map['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0,
      remaining: (map['remaining'] as num?)?.toDouble() ?? 0,
      averageDailySpend: (map['averageDailySpend'] as num?)?.toDouble() ?? 0,
      topCategories: topCategories,
      previousComparison: ComparisonDelta(
        vsPreviousMonth:
            (comparison['vsPreviousMonth'] as num?)?.toDouble() ?? 0,
        vsThreeMonthAverage:
            (comparison['vsThreeMonthAverage'] as num?)?.toDouble() ?? 0,
      ),
      trendline: Trendline(
        points: trend,
        isImproving: map['isImproving'] as bool? ?? false,
      ),
      projectedOverspendPercent:
          (map['projectedOverspendPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

extension _FutureStream<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> Function() supplier) async* {
    yield await supplier();
    yield* this;
  }
}
