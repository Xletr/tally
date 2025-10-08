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
    final targetMonth = DateTime(today.year, today.month);
    final settings = await _settingsRepository.load();

    await _backfillMissingMonths(targetMonth, settings);

    return _ensureMonthWithSettings(
      targetMonth,
      settings,
      allowRollover: allowRollover,
    );
  }

  @override
  Future<BudgetMonth> ensureMonth(
    DateTime date, {
    bool allowRollover = true,
  }) async {
    final normalized = DateTime(date.year, date.month);
    final settings = await _settingsRepository.load();
    final monthId = buildMonthId(normalized);
    final existing = _bootstrap.monthsBox.get(monthId);
    if (existing != null) {
      await _migrateExistingMonth(existing, settings);
      return _buildMonth(existing);
    }
    await _backfillMissingMonths(normalized, settings);
    return _ensureMonthWithSettings(
      normalized,
      settings,
      allowRollover: allowRollover,
    );
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
    final models = _sortedMonthModelsDesc().take(limit).toList();
    return _buildMonths(models);
  }

  @override
  Future<List<BudgetMonth>> getAllMonths() async {
    final models = _sortedMonthModelsDesc();
    return _buildMonths(models);
  }

  @override
  Future<DateTime> getEarliestMonthStart() async {
    if (_bootstrap.monthsBox.isEmpty) {
      final now = _now();
      return DateTime(now.year, now.month, 1);
    }
    final models = _sortedMonthModelsAsc();
    final first = models.first;
    return DateTime(first.year, first.month, 1);
  }

  @override
  Future<void> saveBudgetMonth(BudgetMonth month) async {
    final model = BudgetMonthModel.fromDomain(month)..updatedAt = _now();
    await _bootstrap.monthsBox.put(model.id, model);
  }

  @override
  Future<void> addIncome(IncomeEntry entry) async {
    await ensureMonth(entry.date);
    final model = IncomeEntryModel.fromDomain(entry);
    await _bootstrap.incomesBox.put(model.id, model);
    await _touchMonth(entry.monthId);
    await _propagateRollover(_normalizeMonth(entry.date));
  }

  @override
  Future<void> updateIncome(IncomeEntry entry) async {
    final existing = _bootstrap.incomesBox.get(entry.id);
    final originalDate = existing?.date;
    await addIncome(entry);
    if (existing != null && existing.monthId != entry.monthId) {
      await _touchMonth(existing.monthId);
    }
    final start = _minMonth(originalDate, entry.date);
    await _propagateRollover(start);
  }

  @override
  Future<void> removeIncome(String id) async {
    final existing = _bootstrap.incomesBox.get(id);
    await _bootstrap.incomesBox.delete(id);
    if (existing != null) {
      await _touchMonth(existing.monthId);
      await _propagateRollover(_normalizeMonth(existing.date));
    }
  }

  @override
  Future<void> addExpense(ExpenseEntry entry) async {
    await ensureMonth(entry.date);
    final model = ExpenseEntryModel.fromDomain(entry);
    await _bootstrap.expensesBox.put(model.id, model);
    await _touchMonth(entry.monthId);
    await _propagateRollover(_normalizeMonth(entry.date));
  }

  @override
  Future<void> updateExpense(ExpenseEntry entry) async {
    final existing = _bootstrap.expensesBox.get(entry.id);
    final originalDate = existing?.date;
    await addExpense(entry);
    if (existing != null && existing.monthId != entry.monthId) {
      await _touchMonth(existing.monthId);
    }
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
    final start = _minMonth(originalDate, entry.date);
    await _propagateRollover(start);
  }

  @override
  Future<void> removeExpense(String id) async {
    final existing = _bootstrap.expensesBox.get(id);
    await _bootstrap.expensesBox.delete(id);
    if (existing != null) {
      await _touchMonth(existing.monthId);
      await _propagateRollover(_normalizeMonth(existing.date));
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
      final last = related
          .reduce((a, b) => a.date.isAfter(b.date) ? a : b)
          .date;

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

  List<BudgetMonthModel> _sortedMonthModelsDesc() {
    final models = _bootstrap.monthsBox.values.toList()
      ..sort(
        (a, b) =>
            DateTime(b.year, b.month).compareTo(DateTime(a.year, a.month)),
      );
    return models;
  }

  List<BudgetMonthModel> _sortedMonthModelsAsc() {
    final models = _bootstrap.monthsBox.values.toList()
      ..sort(
        (a, b) =>
            DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month)),
      );
    return models;
  }

  Future<List<BudgetMonth>> _buildMonths(List<BudgetMonthModel> models) async {
    final results = <BudgetMonth>[];
    for (final model in models) {
      results.add(await _buildMonth(model));
    }
    return results;
  }

  Future<void> _seedRecurringExpenses(BudgetMonthModel month) async {
    await _rebuildRecurringAggregatesForMonth(month);
  }

  Future<void> _propagateRollover(DateTime startMonth) async {
    final normalizedStart = _normalizeMonth(startMonth);
    final settings = await _settingsRepository.load();
    var months = _sortedMonthModelsAsc();
    var index = months.indexWhere(
      (model) => model.id == buildMonthId(normalizedStart),
    );
    if (index == -1) {
      return;
    }

    while (index < months.length - 1) {
      final currentModel = months[index];
      final currentDomain = await _buildMonth(currentModel);
      final nextModelId = months[index + 1].id;
      final nextModel = _bootstrap.monthsBox.get(nextModelId);
      if (nextModel == null) {
        break;
      }

      final shouldCarry =
          settings.autoRollover && currentDomain.rolloverEnabled;
      final newRollover = shouldCarry ? currentDomain.remaining : 0.0;
      if ((nextModel.rolloverAmount - newRollover).abs() > 0.01) {
        nextModel.rolloverAmount = newRollover;
        nextModel.updatedAt = _now();
        await nextModel.save();
      }

      await _seedAllowanceIncome(nextModel, settings);
      await _rebuildRecurringAggregatesForMonth(nextModel);
      await _touchMonth(nextModel.id);

      months = _sortedMonthModelsAsc();
      index = months.indexWhere((model) => model.id == nextModelId);
      if (index == -1) {
        break;
      }
    }
  }

  Future<BudgetMonth> _ensureMonthWithSettings(
    DateTime monthDate,
    BudgetSettings settings, {
    bool allowRollover = true,
  }) async {
    final normalized = DateTime(monthDate.year, monthDate.month);
    final monthId = buildMonthId(normalized);
    final existing = _bootstrap.monthsBox.get(monthId);
    if (existing != null) {
      await _migrateExistingMonth(existing, settings);
      return _buildMonth(existing);
    }

    final previousMonthId = buildMonthId(
      DateTime(normalized.year, normalized.month - 1),
    );
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

    final now = _now();
    final model = BudgetMonthModel(
      id: monthId,
      year: normalized.year,
      month: normalized.month,
      baseAllowance: 0,
      rolloverAmount: rolloverAmount,
      rolloverEnabled: settings.autoRollover,
      savingsTarget: savingsTarget,
      createdAt: now,
      updatedAt: now,
      cycleLockDate: null,
    );
    await _bootstrap.monthsBox.put(monthId, model);

    await _seedAllowanceIncome(model, settings);
    await _seedRecurringExpenses(model);

    return _buildMonth(model);
  }

  Future<void> _backfillMissingMonths(
    DateTime targetMonth,
    BudgetSettings settings,
  ) async {
    if (_bootstrap.monthsBox.isEmpty) {
      return;
    }

    final normalizedTarget = DateTime(targetMonth.year, targetMonth.month);
    final months = _sortedMonthModelsAsc();
    final priorMonths = months.where((model) {
      final date = DateTime(model.year, model.month);
      return date.isBefore(normalizedTarget);
    }).toList();

    if (priorMonths.isEmpty) {
      return;
    }

    var cursor = DateTime(priorMonths.last.year, priorMonths.last.month);
    while (cursor.isBefore(normalizedTarget)) {
      cursor = DateTime(cursor.year, cursor.month + 1);
      if (!cursor.isBefore(normalizedTarget)) {
        break;
      }
      await _ensureMonthWithSettings(cursor, settings);
    }
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

  DateTime _normalizeMonth(DateTime date) => DateTime(date.year, date.month);

  DateTime _minMonth(DateTime? a, DateTime b) {
    final normalizedB = _normalizeMonth(b);
    if (a == null) return normalizedB;
    final normalizedA = _normalizeMonth(a);
    return normalizedA.isBefore(normalizedB) ? normalizedA : normalizedB;
  }
}

extension _FutureStream<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> Function() supplier) async* {
    yield await supplier();
    yield* this;
  }
}
