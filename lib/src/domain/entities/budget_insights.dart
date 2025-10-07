import 'package:equatable/equatable.dart';

import 'expense_category.dart';

class BudgetInsights extends Equatable {
  const BudgetInsights({
    required this.monthId,
    required this.totalIncome,
    required this.totalExpenses,
    required this.remaining,
    required this.averageDailySpend,
    required this.topCategories,
    required this.previousComparison,
    required this.trendline,
    required this.projectedOverspendPercent,
  });

  final String monthId;
  final double totalIncome;
  final double totalExpenses;
  final double remaining;
  final double averageDailySpend;
  final List<CategoryBreakdown> topCategories;
  final ComparisonDelta previousComparison;
  final Trendline trendline;
  final double projectedOverspendPercent;

  @override
  List<Object?> get props => [
    monthId,
    totalIncome,
    totalExpenses,
    remaining,
    averageDailySpend,
    topCategories,
    previousComparison,
    trendline,
    projectedOverspendPercent,
  ];
}

class CategoryBreakdown extends Equatable {
  const CategoryBreakdown({
    required this.category,
    required this.total,
    required this.percentage,
  });

  final ExpenseCategory category;
  final double total;
  final double percentage;

  @override
  List<Object?> get props => [category, total, percentage];
}

class ComparisonDelta extends Equatable {
  const ComparisonDelta({
    required this.vsPreviousMonth,
    required this.vsThreeMonthAverage,
  });

  final double vsPreviousMonth;
  final double vsThreeMonthAverage;

  @override
  List<Object?> get props => [vsPreviousMonth, vsThreeMonthAverage];
}

class Trendline extends Equatable {
  const Trendline({required this.points, required this.isImproving});

  final List<TrendPoint> points;
  final bool isImproving;

  @override
  List<Object?> get props => [points, isImproving];
}

class TrendPoint extends Equatable {
  const TrendPoint({required this.monthLabel, required this.value});

  final String monthLabel;
  final double value;

  @override
  List<Object?> get props => [monthLabel, value];
}
