import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/budget_insights.dart';
import '../../domain/entities/budget_month.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/logic/spending_guidance.dart';
import '../../domain/providers/budget_providers.dart';
import '../widgets/category_icon.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(budgetInsightsProvider);
    return insightsAsync.when(
      data: (insights) => _InsightsBody(insights: insights),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Unable to load insights\n$error')),
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  const _InsightsBody({required this.insights});

  final BudgetInsights insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref
        .watch(currentBudgetMonthProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final recentMonthsAsync = ref.watch(recentMonthsProvider);
    final recurringAsync = ref.watch(recurringExpenseListProvider);
    final now = ref.watch(currentDateProvider);

    final historyMonths = recentMonthsAsync.maybeWhen(
      data: (months) => months,
      orElse: () => const <BudgetMonth>[],
    );

    final previousMonth = month != null
        ? _findPreviousMonth(month, historyMonths)
        : null;

    final guidance = month != null
        ? computeSpendingGuidance(month: month, insights: insights, now: now)
        : null;

    final priorMonthCount = month == null
        ? 0
        : historyMonths
              .where((candidate) => _isBefore(candidate, month))
              .length;
    final hasPreviousMonth = priorMonthCount >= 1;
    final hasThreeAverage = priorMonthCount >= 3;

    final categoryDeltas = month != null && previousMonth != null
        ? _calculateCategoryDeltas(month, previousMonth, now)
        : const <_CategoryDelta>[];

    final recurringTemplates = recurringAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <RecurringExpense>[],
    );
    final recurringSummary = month != null && guidance != null
        ? _buildRecurringSummary(month, recurringTemplates, guidance)
        : null;
    final topSpends = month != null
        ? _buildTopSpends(month)
        : const <_TopSpendItem>[];

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Insights',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (month != null && guidance != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _SpendingOutlookCard(
                  month: month,
                  insights: insights,
                  guidance: guidance,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: _ComparisonRow(
                insights: insights,
                hasPreviousMonth: hasPreviousMonth,
                hasThreeMonthAverage: hasThreeAverage,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _CategoryMomentumCard(
                deltas: categoryDeltas,
                hasHistory: previousMonth != null,
              ),
            ),
          ),
          if (recurringSummary != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _RecurringImpactCard(summary: recurringSummary),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _TrendCard(
                points: insights.trendline.points,
                improving: insights.trendline.isImproving,
              ),
            ),
          ),
          if (topSpends.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _TopSpendsCard(items: topSpends),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _SpendingOutlookCard extends StatelessWidget {
  const _SpendingOutlookCard({
    required this.month,
    required this.insights,
    required this.guidance,
  });

  final BudgetMonth month;
  final BudgetInsights insights;
  final SpendingGuidance guidance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = guidance.remaining;
    final daysRemaining = guidance.daysRemaining;
    final projectedBalance = guidance.projectedClose;
    final runwayDays = guidance.runwayDays;
    final isCurrentMonth =
        guidance.now.year == month.year && guidance.now.month == month.month;

    String headline;
    if (remaining < 0) {
      headline = 'Over budget by ${formatCurrency(remaining.abs())}.';
    } else if (insights.projectedOverspendPercent > 0) {
      headline =
          'On pace to overspend by ${formatPercentage(insights.projectedOverspendPercent, decimals: 0)}.';
    } else if (runwayDays == null) {
      headline = 'No recent spend — balance should hold through the month.';
    } else if (runwayDays < daysRemaining) {
      final baseDate = isCurrentMonth
          ? guidance.now
          : DateTime(month.year, month.month, guidance.daysElapsed);
      final runOutDate = baseDate.add(Duration(days: runwayDays.ceil()));
      headline = 'At this pace funds last until ${formatDay(runOutDate)}.';
    } else {
      headline =
          'On track to finish with ${formatCurrency(projectedBalance)} left.';
    }

    String supporting;
    if (daysRemaining <= 0) {
      supporting =
          'Cycle is closing; use these insights to plan the next month.';
    } else {
      final breakEvenDaily = guidance.breakEvenDaily;
      final savingsDaily = guidance.savingsAwareDaily;
      if (remaining < 0) {
        final shortfall = remaining.abs();
        final perDay = breakEvenDaily.abs();
        final savingsGap = guidance.savingsGap;
        final savingsNote = savingsGap > 0
            ? ' You still need ${formatCurrency(savingsGap)} for savings, so plan to capture that before discretionary spend.'
            : '';
        supporting =
            'You would need to free up ${formatCurrency(shortfall)} overall (${formatCurrency(perDay)} per day) to break even.$savingsNote';
      } else {
        if (guidance.savingsGap > 0) {
          supporting =
              'Stay under ${formatCurrency(savingsDaily)} per day to leave ${formatCurrency(guidance.savingsGap)} for savings (break-even is ${formatCurrency(breakEvenDaily)}).';
        } else {
          supporting =
              'Staying within ${formatCurrency(breakEvenDaily)} per day keeps you on budget for the rest of the month.';
        }
      }
    }

    final runwayLabel = remaining <= 0
        ? 'None'
        : runwayDays == null
        ? 'Whole month'
        : '~${runwayDays <= 0 ? 0 : runwayDays.ceil()} days';

    final totalSpendable = month.availableFunds - month.savingsTarget;
    final adjustedSpendable = totalSpendable <= 0 ? 0.0 : totalSpendable;
    final plannedDaily = guidance.daysInMonth == 0
        ? 0.0
        : adjustedSpendable / guidance.daysInMonth;
    final diffDaily = guidance.averageDailySpend - plannedDaily;
    final varianceLabel = diffDaily.abs() < 0.5
        ? '${formatCurrency(guidance.averageDailySpend)}/day (on plan)'
        : diffDaily > 0
            ? '${formatCurrency(guidance.averageDailySpend)}/day (+${formatCurrency(diffDaily.abs())}/day vs plan)'
            : '${formatCurrency(guidance.averageDailySpend)}/day (-${formatCurrency(diffDaily.abs())}/day vs plan)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Spending outlook',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(headline, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(supporting, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InsightStatChip(
                  label: 'Projected close',
                  value: formatCurrency(projectedBalance),
                ),
                _InsightStatChip(label: 'Runway', value: runwayLabel),
                _InsightStatChip(label: 'Daily pacing', value: varianceLabel),
              ],
            ),
            if (insights.projectedOverspendPercent > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Cut spend by roughly ${formatPercentage(insights.projectedOverspendPercent, decimals: 0)} to avoid overshooting.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightStatChip extends StatelessWidget {
  const _InsightStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMomentumCard extends StatelessWidget {
  const _CategoryMomentumCard({required this.deltas, required this.hasHistory});

  final List<_CategoryDelta> deltas;
  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!hasHistory) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'We’ll highlight category shifts once you have at least one previous month to compare.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (deltas.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Spending is steady — no major category swings compared to last month.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final top = deltas.take(3).toList();
    final divider = Divider(
      height: 20,
      color: theme.colorScheme.surfaceContainerHighest,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Category momentum',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < top.length; i++) ...[
              _CategoryDeltaTile(delta: top[i]),
              if (i != top.length - 1) divider,
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryDeltaTile extends StatelessWidget {
  const _CategoryDeltaTile({required this.delta});

  final _CategoryDelta delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final change = delta.delta;
    final isIncrease = change > 0.5;
    final isDecrease = change < -0.5;
    final indicatorColor = isIncrease
        ? colorScheme.error
        : isDecrease
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
    final changeLabel = () {
      if (!isIncrease && !isDecrease) {
        return 'Tracking close to last month.';
      }
      final direction = isIncrease ? 'Up' : 'Down';
      return '$direction ${formatCurrency(change.abs())} projected vs last month';
    }();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Icon(categoryIcon(delta.category), color: indicatorColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(delta.category.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(changeLabel, style: theme.textTheme.bodySmall),
              Text(
                'Projected: ${formatCurrency(delta.current)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecurringImpactCard extends StatelessWidget {
  const _RecurringImpactCard({required this.summary});

  final _RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (summary.total <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No recurring subscriptions were charged this month.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final sharePercent =
        (summary.share * 100).clamp(0, 9999.0).toDouble();
    final descriptor = 'Total';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Recurring commitments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$descriptor ${formatCurrency(summary.total)} this month (${formatPercentage(sharePercent, decimals: 0)} of projected spend).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text('Top subscriptions', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (var i = 0; i < summary.breakdowns.length && i < 3; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: _RecurringBreakdownTile(
                  breakdown: summary.breakdowns[i],
                  total: summary.total,
                ),
              ),
            if (summary.breakdowns.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '+${summary.breakdowns.length - 3} more active subscriptions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecurringBreakdownTile extends StatelessWidget {
  const _RecurringBreakdownTile({required this.breakdown, required this.total});

  final _RecurringBreakdown breakdown;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final share = total == 0 ? 0.0 : breakdown.amount / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(breakdown.label, style: theme.textTheme.titleMedium),
            ),
            Text(
              formatCurrency(breakdown.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: share.clamp(0, 1),
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatPercentage(share * 100, decimals: 0)} of subscription spend',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TopSpendsCard extends StatelessWidget {
  const _TopSpendsCard({required this.items});

  final List<_TopSpendItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Largest purchases',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length && i < 3; i++) ...[
              _TopSpendTile(item: items[i]),
              if (i != items.length - 1 && i < 2)
                Divider(height: 20, color: colorScheme.surfaceContainerHighest),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopSpendTile extends StatelessWidget {
  const _TopSpendTile({required this.item});

  final _TopSpendItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleParts = <String>[formatDay(item.date), item.category.label];
    if (item.isRecurring) {
      subtitleParts.add('Recurring');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Icon(
              categoryIcon(item.category),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCurrency(item.amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.insights,
    required this.hasPreviousMonth,
    required this.hasThreeMonthAverage,
  });

  final BudgetInsights insights;
  final bool hasPreviousMonth;
  final bool hasThreeMonthAverage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ComparisonCard(
            label: 'vs last month',
            delta: insights.previousComparison.vsPreviousMonth,
            hasData: hasPreviousMonth,
            comparisonLabel: 'last month',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ComparisonCard(
            label: 'vs 3-month avg',
            delta: insights.previousComparison.vsThreeMonthAverage,
            hasData: hasThreeMonthAverage,
            comparisonLabel: 'the 3-month average',
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.label,
    required this.delta,
    this.hasData = true,
    this.comparisonLabel = 'last period',
  });

  final String label;
  final double delta;
  final bool hasData;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!hasData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 16),
              Text(
                'Need more history to compare yet.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    final improvementThreshold = 0.1;
    final isDecrease = delta <= -improvementThreshold;
    final isIncrease = delta >= improvementThreshold;
    final neutral = !isDecrease && !isIncrease;
    final icon = neutral
        ? Icons.horizontal_rule_rounded
        : (isDecrease
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded);
    final color = neutral
        ? theme.colorScheme.surfaceContainerHighest
        : isDecrease
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer;
    final description = () {
      if (neutral) {
        return 'Tracking close to last month.';
      }
      final direction = isDecrease ? 'Down' : 'Up';
      return '$direction ${formatCurrency(delta.abs())}/day compared to $comparisonLabel.';
    }();

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon),
                const SizedBox(width: 6),
                Text(
                  '${_formatSignedCurrency(delta)} /day',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points, required this.improving});

  final List<TrendPoint> points;
  final bool improving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Spending trend',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  improving
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  color: improving
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              points[index].monthLabel,
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 4,
                      color: theme.colorScheme.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDelta {
  const _CategoryDelta({
    required this.category,
    required this.current,
    required this.previous,
  });

  final ExpenseCategory category;
  final double current;
  final double previous;

  double get delta => current - previous;
}

class _RecurringSummary {
  const _RecurringSummary({
    required this.total,
    required this.share,
    required this.breakdowns,
    required this.projected,
  });

  final double total;
  final double share;
  final List<_RecurringBreakdown> breakdowns;
  final bool projected;
}

class _RecurringBreakdown {
  const _RecurringBreakdown({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _TopSpendItem {
  const _TopSpendItem({
    required this.label,
    required this.amount,
    required this.category,
    required this.date,
    required this.isRecurring,
  });

  final String label;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final bool isRecurring;
}

BudgetMonth? _findPreviousMonth(BudgetMonth current, List<BudgetMonth> months) {
  if (months.isEmpty) {
    return null;
  }
  final sorted = [
    ...months,
  ]..sort((a, b) => (a.year * 100 + a.month).compareTo(b.year * 100 + b.month));
  BudgetMonth? previous;
  for (final month in sorted) {
    final beforeCurrent = _isBefore(month, current);
    if (beforeCurrent) {
      previous = month;
    }
    if (month.id == current.id) {
      break;
    }
  }
  return previous;
}

List<_CategoryDelta> _calculateCategoryDeltas(
  BudgetMonth current,
  BudgetMonth previous,
  DateTime now,
) {
  Map<ExpenseCategory, double> totalsFor(BudgetMonth month) {
    final totals = <ExpenseCategory, double>{};
    for (final expense in month.expenses) {
      if (expense.category == ExpenseCategory.savings ||
          expense.category == ExpenseCategory.subscriptions) {
        continue;
      }
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  final currentTotals = totalsFor(current);
  final previousTotals = totalsFor(previous);
  final categories = <ExpenseCategory>{
    ...currentTotals.keys,
    ...previousTotals.keys,
  };

  final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
  final isCurrent = now.year == current.year && now.month == current.month;
  final daysElapsed = isCurrent
      ? now.day.clamp(1, daysInMonth)
      : daysInMonth;

  final deltas =
      categories
          .map((category) {
            final currentValue = currentTotals[category] ?? 0;
            final previousValue = previousTotals[category] ?? 0;
            final projectedCurrent = daysElapsed == 0
                ? currentValue
                : (currentValue / daysElapsed) * daysInMonth;
            return _CategoryDelta(
              category: category,
              current: projectedCurrent,
              previous: previousValue,
            );
          })
          .where((delta) => delta.delta.abs() >= 0.01)
          .toList()
        ..sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));

  return deltas;
}

_RecurringSummary? _buildRecurringSummary(
  BudgetMonth month,
  List<RecurringExpense> templates,
  SpendingGuidance guidance,
) {
  final monthDate = DateTime(month.year, month.month);
  final activeTemplates = templates.where((template) {
    if (!template.autoAdd || !template.active) {
      return false;
    }
    final creationMonth = DateTime(
      template.createdAt.year,
      template.createdAt.month,
    );
    return !creationMonth.isAfter(monthDate);
  }).toList();

  if (activeTemplates.isEmpty) {
    final fallbackExpenses = month.expenses
        .where((expense) => expense.category == ExpenseCategory.subscriptions)
        .toList();
    if (fallbackExpenses.isEmpty) {
      return null;
    }

    final grouped = <String, double>{};
    for (final expense in fallbackExpenses) {
      final noteLabel = expense.note?.trim();
      final key = (noteLabel != null && noteLabel.isNotEmpty)
          ? noteLabel
          : 'Subscription';
      grouped.update(
        key,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final breakdowns = grouped.entries
        .map(
          (entry) => _RecurringBreakdown(
            label: entry.key,
            amount: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final total = fallbackExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    if (total <= 0) {
      return null;
    }
    final projectedTotal = guidance.projectedTotalSpend <= 0
        ? total
        : guidance.projectedTotalSpend;
    final share = projectedTotal <= 0 ? 0.0 : total / projectedTotal;

    return _RecurringSummary(
      total: total,
      share: share,
      breakdowns: breakdowns,
      projected: false,
    );
  }

  final breakdowns = activeTemplates
      .map(
        (template) => _RecurringBreakdown(
          label: template.label.isEmpty ? 'Subscription' : template.label,
          amount: template.amount,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final total = activeTemplates.fold<double>(
    0,
    (sum, template) => sum + template.amount,
  );
  if (total <= 0) {
    return null;
  }
  final projectedTotal = guidance.projectedTotalSpend <= 0
      ? total
      : guidance.projectedTotalSpend;
  final share = projectedTotal <= 0 ? 0.0 : total / projectedTotal;

  return _RecurringSummary(
    total: total,
    share: share,
    breakdowns: breakdowns,
    projected: true,
  );
}

bool _isBefore(BudgetMonth a, BudgetMonth b) {
  return a.year < b.year || (a.year == b.year && a.month < b.month);
}

List<_TopSpendItem> _buildTopSpends(BudgetMonth month) {
  final filtered =
      month.expenses
          .where((expense) => expense.category != ExpenseCategory.savings)
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  return filtered.take(5).map((expense) {
    final label = expense.note?.trim().isNotEmpty == true
        ? expense.note!.trim()
        : expense.category.label;
    return _TopSpendItem(
      label: label,
      amount: expense.amount,
      category: expense.category,
      date: expense.date,
      isRecurring: expense.isRecurring,
    );
  }).toList();
}

String _formatSignedCurrency(double value) {
  final prefix = value >= 0 ? '+' : '-';
  return '$prefix${formatCurrency(value.abs())}';
}
