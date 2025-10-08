import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/service_providers.dart';
import '../../domain/entities/budget_insights.dart';
import '../../domain/entities/budget_month.dart';
import '../../domain/entities/expense_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/logic/budget_metrics.dart';
import '../../domain/providers/budget_providers.dart';
import '../../domain/providers/settings_providers.dart';
import '../widgets/category_icon.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/quick_entry_editor.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthAsync = ref.watch(currentBudgetMonthProvider);
    final insightsAsync = ref.watch(budgetInsightsProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);

    ref.listen(currentBudgetMonthProvider, (previous, next) {
      final settings = ref
          .read(settingsControllerProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      if (settings == null) return;
      next.whenData((month) {
        ref
            .read(notificationServiceProvider)
            .scheduleMonthlyReminders(month, settings);
      });
    });

    ref.listen(budgetInsightsProvider, (previous, next) {
      final month = ref
          .read(currentBudgetMonthProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      final settings = ref
          .read(settingsControllerProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      if (month == null || settings == null) {
        return;
      }
      final previousPercent =
          previous?.maybeWhen(
            data: (value) => value.projectedOverspendPercent,
            orElse: () => 0.0,
          ) ??
          0.0;
      next.whenData((value) {
        if (value.projectedOverspendPercent > 5 &&
            value.projectedOverspendPercent != previousPercent) {
          ref
              .read(notificationServiceProvider)
              .showOverspendAlert(month, value, settings);
        }
      });
    });

    return monthAsync.when(
      data: (month) {
        final metrics = BudgetMetrics.fromMonth(month);
        final insights = insightsAsync.maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
        final transactions = _buildTimeline(month);
        final settings = settingsAsync.maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
        final historyAsync = ref.watch(allMonthsProvider);
        final hasHistory = historyAsync.maybeWhen(
          data: (months) => months.length > 1,
          orElse: () => false,
        );
        if (settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _HomeScrollView(
          month: month,
          metrics: metrics,
          insights: insights,
          settings: settings,
          transactions: transactions,
          onOpenSettings: () => _showSettingsSheet(context, ref),
          onEditEntry: (entry) => _showEditEntry(context, ref, entry, month),
          hasHistory: hasHistory,
          onViewHistory: () => _showMonthHistory(context, ref),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorState(error: error),
    );
  }
}

class _HomeScrollView extends StatelessWidget {
  const _HomeScrollView({
    required this.month,
    required this.metrics,
    required this.transactions,
    required this.settings,
    required this.onOpenSettings,
    required this.onEditEntry,
    required this.hasHistory,
    required this.onViewHistory,
    this.insights,
  });

  final BudgetMonth month;
  final BudgetMetrics metrics;
  final List<_TimelineEntry> transactions;
  final BudgetSettings settings;
  final BudgetInsights? insights;
  final VoidCallback onOpenSettings;
  final void Function(_TimelineEntry entry) onEditEntry;
  final bool hasHistory;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          title: const Text('Tally'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Settings',
              onPressed: onOpenSettings,
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _BalanceCard(
              month: month,
              metrics: metrics,
              settings: settings,
              insights: insights,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(child: _CategorySection(metrics: metrics)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList.builder(
            itemBuilder: (context, index) {
              final entry = transactions[index];
              return _TimelineTile(
                entry: entry,
                onEdit: () => onEditEntry(entry),
              );
            },
            itemCount: transactions.length,
          ),
        ),
        if (hasHistory)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _HistoryButton(onTap: onViewHistory),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.month,
    required this.metrics,
    required this.settings,
    this.insights,
  });

  final BudgetMonth month;
  final BudgetMetrics metrics;
  final BudgetSettings settings;
  final BudgetInsights? insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final monthLabel = formatMonthShort(month.cycleStart);

    final progress = metrics.utilization;
    final normalizedProgress = progress < 0
        ? 0.0
        : progress > 1
        ? 1.0
        : progress;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining this month',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: metrics.remaining),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                formatCurrency(value, compact: false),
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: normalizedProgress),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricGridItem(
                    label: 'Inflow',
                    value: formatCurrency(metrics.available),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricGridItem(
                    label: 'Spent',
                    value: formatCurrency(metrics.spent),
                    icon: Icons.local_fire_department_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricGridItem(
                    label: 'Avg/day',
                    value: formatCurrency(metrics.averageDailySpend),
                    icon: Icons.speed_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricGridItem(
                    label: 'Cycle',
                    value: monthLabel,
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
              ],
            ),
            if (settings.monthlySavingsGoal > 0) ...[
              const SizedBox(height: 12),
              _SavingsInlineProgress(
                saved: metrics.savingsDeposited,
                goal: settings.monthlySavingsGoal,
              ),
            ],
            if (insights != null && insights!.projectedOverspendPercent > 5)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'At this pace you might overspend by ${formatPercentage(insights!.projectedOverspendPercent)}.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricGridItem extends StatelessWidget {
  const _MetricGridItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 6),
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

class _SavingsInlineProgress extends StatelessWidget {
  const _SavingsInlineProgress({required this.saved, required this.goal});

  final double saved;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sanitizedSaved = saved < 0 ? 0.0 : saved;
    final sanitizedGoal = goal <= 0 ? 0.0 : goal;
    final progress = sanitizedGoal == 0
        ? 1.0
        : (sanitizedSaved / sanitizedGoal).clamp(0, 1).toDouble();
    final remaining = sanitizedGoal == 0
        ? 0.0
        : (sanitizedGoal - sanitizedSaved) <= 0
        ? 0.0
        : sanitizedGoal - sanitizedSaved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Savings progress', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 6),
        Text(
          remaining > 0
              ? 'Add ${formatCurrency(remaining)} more to reach this month’s savings goal.'
              : 'Savings goal met – great work!',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.metrics});

  final BudgetMetrics metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.categoryTotals.isEmpty) {
      return const _EmptyCategories();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where money is going',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: CategoryPieChart(data: metrics.categoryTotals),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics.categoryTotals.entries.map((entry) {
            final percentage = metrics.spent == 0
                ? 0.0
                : (entry.value / metrics.spent) * 100;
            return _CategoryChip(
              category: entry.key,
              amount: entry.value,
              percentage: percentage,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No expenses yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first expense to see a category breakdown.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  final ExpenseCategory category;
  final double amount;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.secondaryContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryIcon(category),
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.label, style: theme.textTheme.labelLarge),
              Text(
                '${formatCurrency(amount)} · ${formatPercentage(percentage)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.onEdit});

  final _TimelineEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIncome = entry.type == _TimelineType.income;
    final isSavings = entry.expense?.category == ExpenseCategory.savings;
    final amountColor = isIncome
        ? colorScheme.primary
        : isSavings
        ? colorScheme.tertiary
        : colorScheme.error;
    final leadingBackground = isIncome
        ? colorScheme.surfaceContainerHighest
        : isSavings
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final leadingIconColor = amountColor;
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: amountColor,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onEdit,
        onLongPress: onEdit,
        tileColor: isSavings
            ? colorScheme.tertiaryContainer.withValues(alpha: 0.25)
            : null,
        leading: CircleAvatar(
          backgroundColor: leadingBackground,
          child: Icon(entry.icon, color: leadingIconColor),
        ),
        title: Text(entry.title, style: theme.textTheme.titleMedium),
        subtitle: Text(entry.subtitle, style: theme.textTheme.bodySmall),
        trailing: Text(
          (isIncome ? '+' : '-') + formatCurrency(entry.amount, compact: false),
          style: amountStyle,
        ),
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.primaryContainer,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Past months',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See prior inflows, spending, and rollover history.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMonthTile extends StatelessWidget {
  const _HistoryMonthTile({required this.month, required this.isCurrent});

  final BudgetMonth month;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final incomeTotal = month.incomeTotal;
    final spentTotal = month.expenseTotal;
    final remaining = month.remaining;
    final savingsTotal = month.expenses
        .where((e) => e.category == ExpenseCategory.savings)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final subscriptionsTotal = month.expenses
        .where((e) => e.category == ExpenseCategory.subscriptions)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final double rollover =
        month.rolloverEnabled ? month.rolloverAmount : 0.0;

    final stats = <Widget>[
      _HistoryStatChip(label: 'Inflow', value: formatCurrency(incomeTotal)),
      _HistoryStatChip(label: 'Spent', value: formatCurrency(spentTotal)),
      _HistoryStatChip(label: 'Left', value: formatCurrency(remaining)),
    ];

    if (savingsTotal.abs() > 0.01) {
      stats.add(
        _HistoryStatChip(label: 'Saved', value: formatCurrency(savingsTotal)),
      );
    }

    if (subscriptionsTotal.abs() > 0.01) {
      stats.add(
        _HistoryStatChip(label: 'Subs', value: formatCurrency(subscriptionsTotal)),
      );
    }

    if (rollover.abs() > 0.01) {
      stats.add(
        _HistoryStatChip(label: 'Rollover', value: formatCurrency(rollover)),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatMonthShort(month.cycleStart),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: colorScheme.secondaryContainer,
                    label: Text(
                      'Current',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStatChip extends StatelessWidget {
  const _HistoryStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Text(
            'We could not load your budget',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('$error', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

List<_TimelineEntry> _buildTimeline(BudgetMonth month) {
  final entries = <_TimelineEntry>[];
  for (final income in month.incomes) {
    entries.add(_TimelineEntry.fromIncome(income));
  }
  for (final expense in month.expenses) {
    entries.add(_TimelineEntry.fromExpense(expense));
  }
  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
}

enum _TimelineType { income, expense }

class _TimelineEntry {
  _TimelineEntry._({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.icon,
    this.income,
    this.expense,
  });

  factory _TimelineEntry.fromIncome(IncomeEntry income) {
    final title = income.source.isEmpty ? 'Income' : income.source;
    return _TimelineEntry._(
      type: _TimelineType.income,
      title: title,
      subtitle: formatDay(income.date),
      amount: income.amount,
      date: income.date,
      icon: Icons.trending_up_rounded,
      income: income,
    );
  }

  factory _TimelineEntry.fromExpense(ExpenseEntry expense) {
    return _TimelineEntry._(
      type: _TimelineType.expense,
      title: expense.note?.isNotEmpty == true
          ? expense.note!
          : expense.category.label,
      subtitle: formatDay(expense.date),
      amount: expense.amount,
      date: expense.date,
      icon: categoryIcon(expense.category),
      expense: expense,
    );
  }

  final _TimelineType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final IconData icon;
  final IncomeEntry? income;
  final ExpenseEntry? expense;
}

Future<void> _showEditEntry(
  BuildContext context,
  WidgetRef ref,
  _TimelineEntry entry,
  BudgetMonth currentMonth,
) async {
  final repository = ref.read(budgetRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final earliestStart = await repository.getEarliestMonthStart();
  final minDate = DateTime(earliestStart.year, earliestStart.month, 1);
  final maxDate = currentMonth.cycleEnd;

  if (entry.type == _TimelineType.income && entry.income != null) {
    final income = entry.income!;
    final amountController = TextEditingController(
      text: income.amount.toStringAsFixed(2),
    );
    final sourceController = TextEditingController(text: income.source);
    final noteController = TextEditingController(text: income.note ?? '');
    DateTime selectedDate = clampDate(income.date, minDate, maxDate);

    final modalContext = context;
    // ignore: use_build_context_synchronously
    final shouldSave = await showModalBottomSheet<bool>(
      context: modalContext, // ignore: use_build_context_synchronously
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Edit income',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '\$',
                    labelText: 'Amount',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(labelText: 'Source'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Date: ${formatDay(selectedDate)}'),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: minDate,
                          lastDate: maxDate,
                        );
                        if (picked != null) {
                          setState(
                            () => selectedDate =
                                clampDate(picked, minDate, maxDate),
                          );
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await repository.removeIncome(income.id);
                        if (context.mounted) {
                          Navigator.of(context).pop(false);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Income deleted')),
                          );
                        }
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!modalContext.mounted) {
      return;
    }

    if (shouldSave == true) {
      final parsedAmount =
          double.tryParse(amountController.text) ?? income.amount;
      final updated = income.copyWith(
        amount: parsedAmount,
        source: sourceController.text.trim(),
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        date: selectedDate,
        monthId: monthIdFromDate(selectedDate),
        updatedAt: DateTime.now(),
      );
      await repository.ensureMonth(selectedDate);
      await repository.updateIncome(updated);
      messenger.showSnackBar(const SnackBar(content: Text('Income updated')));
    }

    return;
  }

  if (entry.expense != null) {
    final expense = entry.expense!;
    final amountController = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: expense.note ?? '');
    ExpenseCategory category = expense.category;
    DateTime selectedDate = clampDate(expense.date, minDate, maxDate);

    final modalContext = context;
    // ignore: use_build_context_synchronously
    final shouldSave = await showModalBottomSheet<bool>(
      context: modalContext, // ignore: use_build_context_synchronously
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      expense.isRecurring
                          ? 'Edit subscription'
                          : 'Edit expense',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '\$',
                    labelText: 'Amount',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ExpenseCategory.values
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Date: ${formatDay(selectedDate)}'),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: minDate,
                          lastDate: maxDate,
                        );
                        if (picked != null) {
                          setState(
                            () => selectedDate =
                                clampDate(picked, minDate, maxDate),
                          );
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                if (expense.isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Updating adjusts future subscription amounts.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await repository.removeExpense(expense.id);
                        if (context.mounted) {
                          Navigator.of(context).pop(false);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Expense deleted')),
                          );
                        }
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!modalContext.mounted) {
      return;
    }

    if (shouldSave == true) {
      final parsedAmount =
          double.tryParse(amountController.text) ?? expense.amount;
      final updated = expense.copyWith(
        amount: parsedAmount,
        category: category,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        date: selectedDate,
        monthId: monthIdFromDate(selectedDate),
        updatedAt: DateTime.now(),
      );
      await repository.ensureMonth(selectedDate);
      await repository.updateExpense(updated);
      messenger.showSnackBar(const SnackBar(content: Text('Expense updated')));
    }

    // controllers live only within this method scope; avoid disposing to prevent rebuild issues
  }
}

Future<void> _showMonthHistory(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(budgetRepositoryProvider);
  final months = await repository.getAllMonths();
  if (months.length <= 1) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No past months yet.')), 
      );
    }
    return;
  }

  final currentId = ref.read(currentMonthIdProvider);

  final modalContext = context;

  // ignore: use_build_context_synchronously
  await showModalBottomSheet<void>(
    context: modalContext, // ignore: use_build_context_synchronously
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Past months',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final month = months[index];
                      return _HistoryMonthTile(
                        month: month,
                        isCurrent: month.id == currentId,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: months.length,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (!modalContext.mounted) {
    return;
  }
}

Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final theme = Theme.of(context);

    return settingsAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load settings\n$error'),
      ),
      data: (settings) {
        final messenger = ScaffoldMessenger.of(context);
        final backupService = ref.watch(backupServiceProvider);
        final formattedBackup = settings.lastBackupAt != null
            ? DateFormat.yMMMd().add_jm().format(
                settings.lastBackupAt!.toLocal(),
              )
            : null;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Appearance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) =>
                        controller.updateThemeMode(selection.first),
                  ),
                  SwitchListTile.adaptive(
                    value: settings.dynamicColorEnabled,
                    title: const Text('Dynamic color'),
                    subtitle: const Text(
                      'Blend the palette with your wallpaper on supported devices.',
                    ),
                    onChanged: controller.toggleDynamicColor,
                  ),
                  SwitchListTile.adaptive(
                    value: settings.highContrast,
                    title: const Text('High contrast'),
                    onChanged: controller.toggleHighContrast,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preview',
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Toggle to check readability at a glance. High contrast boosts text and stroke emphasis.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: settings.highContrast,
                          onChanged: controller.toggleHighContrast,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Budget defaults',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    value: settings.autoRollover,
                    title: const Text('Rollover remaining funds'),
                    subtitle: const Text(
                      'Carry leftover balance into the next month automatically.',
                    ),
                    onChanged: controller.toggleAutoRollover,
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Default monthly inflow'),
                    subtitle: Text(
                      formatCurrency(settings.defaultMonthlyAllowance),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editNumber(
                      context,
                      title: 'Default monthly inflow',
                      initialValue: settings.defaultMonthlyAllowance,
                      onSubmit: controller.updateDefaultAllowance,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Savings goal per month'),
                    subtitle: Text(formatCurrency(settings.monthlySavingsGoal)),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editNumber(
                      context,
                      title: 'Savings goal',
                      initialValue: settings.monthlySavingsGoal,
                      onSubmit: controller.updateMonthlySavingsGoal,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flash_on_rounded),
                    title: const Text('Manage quick entry presets'),
                    subtitle: const Text(
                      'Tune favourite amounts for each category.',
                    ),
                    onTap: () => _openPresetEditor(context, ref, settings),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    value: settings.notificationsEnabled,
                    title: const Text('Enable notifications'),
                    onChanged: (value) =>
                        controller.updateNotifications(enabled: value),
                  ),
                  _NotificationSettingTile(
                    title: 'Mid-month reminder',
                    enabled: settings.midMonthReminder,
                    time: settings.midMonthReminderAt,
                    onToggle: (value) =>
                        controller.updateNotifications(midMonth: value),
                    onPickTime: (time) =>
                        controller.updateReminderTime(midMonth: time),
                  ),
                  _NotificationSettingTile(
                    title: 'End-of-month wrap up',
                    enabled: settings.endOfMonthReminder,
                    time: settings.endOfMonthReminderAt,
                    onToggle: (value) =>
                        controller.updateNotifications(endOfMonth: value),
                    onPickTime: (time) =>
                        controller.updateReminderTime(endOfMonth: time),
                  ),
                  SwitchListTile.adaptive(
                    value: settings.overspendAlerts,
                    title: const Text('Overspend alerts'),
                    onChanged: (value) =>
                        controller.updateNotifications(overspend: value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Backups',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.file_upload_rounded),
                    title: const Text('Export data'),
                    subtitle: formattedBackup != null
                        ? Text('Last export: $formattedBackup')
                        : null,
                    onTap: () async {
                      final confirmed = await _confirmAction(
                        context,
                        title: 'Export data',
                        message:
                            'Generate an encrypted backup file with your budgets? You choose the location next.',
                      );
                      if (confirmed != true) return;
                      final file = await backupService.exportData();
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            file != null
                                ? 'Backup saved. Local copy: ${file.path}'
                                : 'Export cancelled',
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download_rounded),
                    title: const Text('Import data'),
                    onTap: () async {
                      final repo = ref.read(budgetRepositoryProvider);
                      final months = await repo.getRecentMonths(limit: 24);
                      if (!context.mounted) return;
                      final incomeCount = months.fold<int>(
                        0,
                        (sum, month) => sum + month.incomes.length,
                      );
                      final expenseCount = months.fold<int>(
                        0,
                        (sum, month) => sum + month.expenses.length,
                      );
                      final confirmed = await _confirmAction(
                        context,
                        title: 'Import data',
                        message:
                            'Importing replaces your current data (months: ${months.length}, incomes: $incomeCount, expenses: $expenseCount). Continue?',
                      );
                      if (!context.mounted) return;
                      if (confirmed != true) return;
                      await backupService.importData();
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Import complete')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required double initialValue,
    required Future<void> Function(double) onSubmit,
  }) async {
    final textController = TextEditingController(
      text: initialValue.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '\$',
            hintText: 'Enter amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(textController.text);
              Navigator.of(context).pop(amount);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) {
      await onSubmit(value);
    }
  }

  Future<void> _openPresetEditor(
    BuildContext context,
    WidgetRef ref,
    BudgetSettings settings,
  ) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final result = await showQuickEntryEditor(
      context,
      initialCategories: settings.categoryQuickEntryPresets,
      initialIconCodes: settings.quickEntryCategoryIcons,
      initialSavingsPresets: settings.savingsQuickEntryPresets,
      settings: settings,
    );

    if (result != null) {
      await controller.saveQuickEntryConfiguration(
        categories: result.categories,
        icons: result.iconCodes,
        savings: result.savingsPresets,
      );
    }
  }

  Future<bool?> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingTile extends StatelessWidget {
  const _NotificationSettingTile({
    required this.title,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  final String title;
  final bool enabled;
  final ReminderTime time;
  final ValueChanged<bool> onToggle;
  final ValueChanged<ReminderTime> onPickTime;

  @override
  Widget build(BuildContext context) {
    final timeOfDay = time.asTimeOfDay();
    final localizations = MaterialLocalizations.of(context);
    final formatted = localizations.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    return SwitchListTile.adaptive(
      value: enabled,
      title: Text(title),
      subtitle: Text('Scheduled for $formatted'),
      onChanged: onToggle,
      secondary: IconButton(
        icon: const Icon(Icons.schedule_rounded),
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: timeOfDay,
          );
          if (picked != null) {
            onPickTime(ReminderTime.fromTimeOfDay(picked));
          }
        },
      ),
    );
  }
}
