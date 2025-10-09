import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/entities/subscription_summary.dart';
import '../../domain/providers/budget_providers.dart';

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(subscriptionSummariesProvider);
    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Unable to load subscriptions\n$error')),
      data: (summaries) => _SubscriptionsView(summaries: summaries),
    );
  }
}

enum _SubscriptionSort { nextCharge, amountHigh, name }

class _SubscriptionsView extends ConsumerStatefulWidget {
  const _SubscriptionsView({required this.summaries});

  final List<SubscriptionSummary> summaries;

  @override
  ConsumerState<_SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends ConsumerState<_SubscriptionsView> {
  _SubscriptionSort _sort = _SubscriptionSort.nextCharge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMonthly = widget.summaries
        .where((summary) => summary.template.active)
        .fold<double>(0, (sum, summary) => sum + summary.template.amount);
    final sortedSummaries = _sortedSummaries();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubscriptionEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add subscription'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscriptions',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monthly total ${formatCurrency(totalMonthly)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_SubscriptionSort>(
                      value: _sort,
                      alignment: Alignment.centerRight,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      borderRadius: BorderRadius.circular(16),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sort = value);
                      },
                      items: _SubscriptionSort.values
                          .map(
                            (option) => DropdownMenuItem<_SubscriptionSort>(
                              value: option,
                              child: Text(_sortLabel(option)),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) =>
                          _SubscriptionSort.values.map((option) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text(_sortLabel(option)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.summaries.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      itemBuilder: (context, index) {
                        final summary = sortedSummaries[index];
                        return _SubscriptionCard(summary: summary);
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: sortedSummaries.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<SubscriptionSummary> _sortedSummaries() {
    final list = [...widget.summaries];
    switch (_sort) {
      case _SubscriptionSort.nextCharge:
        list.sort((a, b) {
          final aActive = a.template.active ? 0 : 1;
          final bActive = b.template.active ? 0 : 1;
          if (aActive != bActive) {
            return aActive.compareTo(bActive);
          }
          final aDate = _nextChargeDate(a.template);
          final bDate = _nextChargeDate(b.template);
          final compare = aDate.compareTo(bDate);
          if (compare != 0) return compare;
          return _displayName(a.template).compareTo(_displayName(b.template));
        });
        break;
      case _SubscriptionSort.amountHigh:
        list.sort((a, b) {
          final aActive = a.template.active ? 0 : 1;
          final bActive = b.template.active ? 0 : 1;
          if (aActive != bActive) {
            return aActive.compareTo(bActive);
          }
          final compare = b.template.amount.compareTo(a.template.amount);
          if (compare != 0) return compare;
          return _displayName(a.template).compareTo(_displayName(b.template));
        });
        break;
      case _SubscriptionSort.name:
        list.sort(
          (a, b) =>
              _displayName(a.template).compareTo(_displayName(b.template)),
        );
        break;
    }
    return list;
  }

  String _sortLabel(_SubscriptionSort sort) {
    switch (sort) {
      case _SubscriptionSort.nextCharge:
        return 'Next charge';
      case _SubscriptionSort.amountHigh:
        return 'Highest cost';
      case _SubscriptionSort.name:
        return 'Name A-Z';
    }
  }

  DateTime _nextChargeDate(RecurringExpense template) {
    final now = DateTime.now();
    final day = template.dayOfMonth.clamp(1, 28);
    final currentMonthDate = DateTime(now.year, now.month, day);
    if (currentMonthDate.isAfter(now) || _isSameDay(currentMonthDate, now)) {
      return currentMonthDate;
    }
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final normalizedDay = day.clamp(1, lastDay);
    return DateTime(nextMonth.year, nextMonth.month, normalizedDay);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _displayName(RecurringExpense template) {
    return template.label.isEmpty ? 'Subscription' : template.label;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subscriptions_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No subscriptions yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add recurring charges like streaming services or utilities to see how much they cost each month.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.summary});

  final SubscriptionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final template = summary.template;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(budgetRepositoryProvider);
    final monthlyCost = template.amount;
    final lifetime = summary.lifetimeSpent;
    final subtitle = summary.chargeCount == 0
        ? 'No charges yet'
        : '${summary.chargeCount} charges · ${formatCurrency(lifetime)} total';

    return Card(
      child: ListTile(
        title: Text(
          template.label.isEmpty ? 'Subscription' : template.label,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(monthlyCost),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (summary.lastChargedAt != null)
              Text(
                'Last billed ${formatDay(summary.lastChargedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        onTap: () => _showSubscriptionEditor(context, ref, existing: template),
        onLongPress: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete subscription?'),
              content: const Text(
                'This removes future charges but keeps previous history.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await repository.deleteRecurringExpense(summary.template.id);
            messenger.showSnackBar(
              const SnackBar(content: Text('Subscription deleted')),
            );
            ref.invalidate(subscriptionSummariesProvider);
          }
        },
      ),
    );
  }
}

Future<void> _showSubscriptionEditor(
  BuildContext context,
  WidgetRef ref, {
  RecurringExpense? existing,
}) async {
  final repository = ref.read(budgetRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();
  final labelController = TextEditingController(text: existing?.label ?? '');
  final amountController = TextEditingController(
    text: (existing?.amount ?? 9.99).toStringAsFixed(2),
  );
  final noteController = TextEditingController(text: existing?.note ?? '');
  int billingDay = existing?.dayOfMonth ?? 1;
  bool autoAdd = existing?.autoAdd ?? true;
  bool active = existing?.active ?? true;

  final shouldSave = await showModalBottomSheet<bool>(
    context: context,
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
                    existing == null ? 'New subscription' : 'Edit subscription',
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
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Name'),
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
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: billingDay.toDouble(),
                      min: 1,
                      max: 28,
                      divisions: 27,
                      label: 'Day $billingDay',
                      onChanged: (value) =>
                          setState(() => billingDay = value.round()),
                    ),
                  ),
                  Text('Day $billingDay'),
                ],
              ),
              SwitchListTile.adaptive(
                value: autoAdd,
                title: const Text('Auto-add to future months'),
                onChanged: (value) => setState(() => autoAdd = value),
              ),
              SwitchListTile.adaptive(
                value: active,
                title: const Text('Active'),
                onChanged: (value) => setState(() => active = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save subscription'),
              ),
            ],
          ),
        );
      },
    ),
  );

  if (shouldSave == true) {
    final amount =
        double.tryParse(amountController.text) ?? (existing?.amount ?? 0);
    final subscription = RecurringExpense(
      id: existing?.id ?? const Uuid().v4(),
      label: labelController.text.trim().isEmpty
          ? 'Subscription'
          : labelController.text.trim(),
      category: ExpenseCategory.subscriptions,
      amount: amount.abs(),
      dayOfMonth: billingDay,
      autoAdd: autoAdd,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
      active: active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await repository.upsertRecurringExpense(subscription);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Subscription added' : 'Subscription updated',
        ),
      ),
    );
    ref.invalidate(subscriptionSummariesProvider);
  }

  // Controllers intentionally not disposed to avoid late rebuilds after the sheet closes; they
  // live only for the duration of this method scope and will be garbage collected.
}
