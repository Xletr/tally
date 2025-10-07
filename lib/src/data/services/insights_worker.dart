import 'dart:math';

import 'package:intl/intl.dart';

import '../../domain/entities/expense_category.dart';
import 'insights_payload.dart';

Map<String, dynamic> runInsightsWorker(InsightsPayload payload) {
  final now = DateTime.parse(payload.nowIso);
  final target = _Snapshot.fromMap(payload.target);
  final history = payload.history.map(_Snapshot.fromMap).toList()
    ..sort((a, b) => a.compareKey.compareTo(b.compareKey));

  final categoryTotals = target.categoryTotals;
  final totalExpenses = target.expenseTotal;
  final totalIncome = target.incomeTotal;
  final remaining = target.remaining;
  final averageDailySpend = target.averageDailySpend(now);

  final previous = history
      .where((snap) => snap.compareKey < target.compareKey)
      .lastWhere((snap) => true, orElse: () => target);

  final threeMonthWindow =
      history.where((snap) => snap.compareKey < target.compareKey).toList()
        ..sort((a, b) => b.compareKey.compareTo(a.compareKey));
  final threeAverage = threeMonthWindow
      .take(3)
      .map((snap) => snap.expenseTotal)
      .toList();
  final averageThree = threeAverage.isEmpty
      ? totalExpenses
      : threeAverage.reduce((a, b) => a + b) / threeAverage.length;

  final comparison = {
    'vsPreviousMonth': _percentDelta(totalExpenses, previous.expenseTotal),
    'vsThreeMonthAverage': _percentDelta(totalExpenses, averageThree),
  };

  final topCategories =
      categoryTotals.entries
          .map(
            (entry) => {
              'category': entry.key,
              'total': entry.value,
              'percentage': totalExpenses == 0
                  ? 0
                  : entry.value / totalExpenses,
            },
          )
          .toList()
        ..sort(
          (a, b) => (b['total'] as double).compareTo(a['total'] as double),
        );

  final filteredTrend =
      (history + [target])
          .where((snap) => snap.compareKey <= target.compareKey)
          .toList()
        ..sort((a, b) => a.compareKey.compareTo(b.compareKey));
  final trendline = filteredTrend
      .map(
        (snap) => {
          'label': DateFormat.MMM().format(DateTime(snap.year, snap.month)),
          'value': snap.expenseTotal,
        },
      )
      .toList();

  final projectedOverspendPercent = target.projectedOverspendPercent(now);
  final isImproving = previous.expenseTotal == 0
      ? true
      : totalExpenses <= previous.expenseTotal;

  return {
    'monthId': target.id,
    'totalIncome': totalIncome,
    'totalExpenses': totalExpenses,
    'remaining': remaining,
    'averageDailySpend': averageDailySpend,
    'topCategories': topCategories.take(3).toList(),
    'comparison': comparison,
    'trendline': trendline,
    'isImproving': isImproving,
    'projectedOverspendPercent': projectedOverspendPercent,
  };
}

class _Snapshot {
  _Snapshot({
    required this.id,
    required this.year,
    required this.month,
    required this.baseAllowance,
    required this.rolloverAmount,
    required this.rolloverEnabled,
    required this.savingsTarget,
    required this.incomes,
    required this.expenses,
  });

  factory _Snapshot.fromMap(Map<String, dynamic> map) {
    return _Snapshot(
      id: map['id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      baseAllowance: (map['baseAllowance'] as num?)?.toDouble() ?? 0,
      rolloverAmount: (map['rolloverAmount'] as num?)?.toDouble() ?? 0,
      rolloverEnabled: map['rolloverEnabled'] as bool? ?? true,
      savingsTarget: (map['savingsTarget'] as num?)?.toDouble() ?? 0,
      incomes: (map['incomes'] as List<dynamic>? ?? const [])
          .map((item) => _AmountPoint.fromMap(item as Map<String, dynamic>))
          .toList(),
      expenses: (map['expenses'] as List<dynamic>? ?? const [])
          .map((item) => _ExpensePoint.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final int year;
  final int month;
  final double baseAllowance;
  final double rolloverAmount;
  final bool rolloverEnabled;
  final double savingsTarget;
  final List<_AmountPoint> incomes;
  final List<_ExpensePoint> expenses;

  int get compareKey => year * 100 + month;
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  double get incomeTotal => incomes.fold(0, (sum, p) => sum + p.amount);
  double get expenseTotal => expenses.fold(0, (sum, p) => sum + p.amount);

  double get availableFunds =>
      baseAllowance + (rolloverEnabled ? rolloverAmount : 0) + incomeTotal;
  double get remaining => availableFunds - expenseTotal;

  Map<String, double> get categoryTotals {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  double averageDailySpend(DateTime now) {
    final subscriptionTotal = expenses
        .where(
          (expense) => expense.category == ExpenseCategory.subscriptions.name,
        )
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final savingsTotal = expenses
        .where((expense) => expense.category == ExpenseCategory.savings.name)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final discretionary = expenseTotal - subscriptionTotal - savingsTotal;
    final isCurrent = now.year == year && now.month == month;
    final daysElapsed = isCurrent
        ? max(1, min(now.day, daysInMonth))
        : daysInMonth;
    return (subscriptionTotal / 30.0) +
        (daysElapsed == 0 ? 0 : discretionary / daysElapsed);
  }

  double projectedOverspendPercent(DateTime now) {
    final isCurrent = now.year == year && now.month == month;
    if (!isCurrent) {
      return 0;
    }
    final projectedTotal = averageDailySpend(now) * daysInMonth;
    if (availableFunds <= 0) {
      return 0;
    }
    if (projectedTotal <= availableFunds) {
      return 0;
    }
    return (projectedTotal - availableFunds) / availableFunds * 100;
  }
}

class _AmountPoint {
  _AmountPoint({required this.amount, required this.date});

  factory _AmountPoint.fromMap(Map<String, dynamic> map) {
    return _AmountPoint(
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }

  final double amount;
  final DateTime date;
}

class _ExpensePoint {
  _ExpensePoint({
    required this.amount,
    required this.category,
    required this.date,
  });

  factory _ExpensePoint.fromMap(Map<String, dynamic> map) {
    return _ExpensePoint(
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String? ?? ExpenseCategory.misc.name,
      date: DateTime.parse(map['date'] as String),
    );
  }

  final double amount;
  final String category;
  final DateTime date;
}

double _percentDelta(double current, double reference) {
  if (reference == 0) {
    return current == 0 ? 0 : 100;
  }
  return (current - reference) / reference * 100;
}
