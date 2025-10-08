import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/budget_month.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/providers/budget_providers.dart';
import '../../domain/providers/settings_providers.dart';
import '../widgets/category_icon.dart';

enum _EntryType { inflow, expense, savings }

class AddPage extends ConsumerStatefulWidget {
  const AddPage({super.key});

  @override
  ConsumerState<AddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<AddPage> {
  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();
  final _noteController = TextEditingController();
  final Uuid _uuid = const Uuid();

  DateTime _selectedDate = DateTime.now();
  _EntryType _type = _EntryType.expense;
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthAsync = ref.watch(currentBudgetMonthProvider);
    final currentMonth = currentMonthAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final earliestAsync = ref.watch(earliestMonthStartProvider);
    final earliestStart = earliestAsync.maybeWhen(
      data: (value) => value,
      orElse: () => currentMonth?.cycleStart ?? DateTime.now(),
    );
    final minDate = DateTime(earliestStart.year, earliestStart.month, 1);
    final maxDate = currentMonth?.cycleEnd ?? DateTime.now();

    final categoryPresets = ref.watch(categoryQuickPresetsProvider);
    final expenseSuggestions = ref.watch(expenseSuggestionsProvider);
    final incomeSuggestions = ref.watch(incomeSuggestionsProvider);
    final savingsPresets = ref.watch(savingsQuickPresetsProvider);
    final quickEntryIcons = ref.watch(quickEntryIconsProvider);
    final expenseCategories = categoryPresets.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (expenseCategories.isEmpty) {
      expenseCategories.addAll([
        ExpenseCategory.food,
        ExpenseCategory.transport,
        ExpenseCategory.purchases,
        ExpenseCategory.misc,
      ]);
    }

    final effectiveCategory = expenseCategories.contains(_selectedCategory)
        ? _selectedCategory
        : expenseCategories.first;

    List<double> amountPresets;
    switch (_type) {
      case _EntryType.expense:
        amountPresets = _combinedPresets(
          categoryPresets[effectiveCategory],
          expenseSuggestions[effectiveCategory],
        );
        break;
      case _EntryType.inflow:
        amountPresets = _combinedPresets(incomeSuggestions, const []);
        break;
      case _EntryType.savings:
        amountPresets = List<double>.from(savingsPresets);
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeSegmentedControl(
                type: _type,
                onChanged: (value) {
                  FocusScope.of(context).unfocus();
                  setState(() => _type = value);
                },
              ),
              const SizedBox(height: 20),
              _AmountField(
                controller: _amountController,
                presets: amountPresets,
                onPresetTap: (value) => setState(
                  () => _amountController.text = value.toStringAsFixed(0),
                ),
              ),
              const SizedBox(height: 16),
              if (_type == _EntryType.expense)
                _ExpenseExtras(
                  category: effectiveCategory,
                  categories: expenseCategories,
                  icons: quickEntryIcons,
                  onCategoryTapped: (category) =>
                      setState(() => _selectedCategory = category),
                )
              else if (_type == _EntryType.inflow)
                _IncomeExtras(
                  controller: _sourceController,
                  suggestions: incomeSuggestions,
                  onSuggestionTap: (value) => setState(
                    () => _amountController.text = value.toStringAsFixed(0),
                  ),
                )
              else
                _SavingsExtras(
                  icon:
                      quickEntryIcons[ExpenseCategory.savings] ??
                      categoryIcon(ExpenseCategory.savings),
                ),
              const SizedBox(height: 16),
              _NoteField(controller: _noteController),
              const SizedBox(height: 12),
              _DatePickerTile(
                selectedDate: _selectedDate,
                onPressed: () async {
                  final initialDate = clampDate(
                    _selectedDate,
                    minDate,
                    maxDate,
                  );
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: minDate,
                    lastDate: maxDate,
                  );
                  if (picked != null) {
                    setState(
                      () => _selectedDate = clampDate(picked, minDate, maxDate),
                    );
                  }
                },
              ),
              const Spacer(),
              FilledButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(switch (_type) {
                        _EntryType.inflow =>
                          Icons.account_balance_wallet_rounded,
                        _EntryType.expense =>
                          Icons.shopping_cart_checkout_rounded,
                        _EntryType.savings => Icons.savings_rounded,
                      }),
                onPressed: _isSaving ? null : () => _submit(context),
                label: Text(switch (_type) {
                  _EntryType.inflow => 'Add inflow',
                  _EntryType.expense => 'Add expense',
                  _EntryType.savings => 'Add savings',
                }),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final note = _noteController.text.trim();
    setState(() => _isSaving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final BudgetMonth currentMonth = ref.read(currentBudgetMonthProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        ) ??
        await ref.read(currentBudgetMonthProvider.future);
    final earliestStart = await ref.read(earliestMonthStartProvider.future);
    final minDate = DateTime(earliestStart.year, earliestStart.month, 1);
    final maxDate = currentMonth.cycleEnd;

    if (_selectedDate.isBefore(minDate) || _selectedDate.isAfter(maxDate)) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pick a date between ${DateFormat.yMMMd().format(minDate)} and ${DateFormat.yMMMd().format(maxDate)}',
          ),
        ),
      );
      return;
    }

    final monthId = monthIdFromDate(_selectedDate);
    final now = DateTime.now();
    final expenseCategories = ExpenseCategory.values
        .where((category) => category != ExpenseCategory.subscriptions)
        .toList();
    final effectiveCategory = expenseCategories.contains(_selectedCategory)
        ? _selectedCategory
        : expenseCategories.first;

    try {
      await repo.ensureMonth(_selectedDate);
      if (_type == _EntryType.inflow) {
        final source = _sourceController.text.trim();
        final entry = IncomeEntry(
          id: _uuid.v4(),
          monthId: monthId,
          source: source.isEmpty ? 'Monthly inflow' : source,
          amount: amount,
          date: _selectedDate,
          note: note.isEmpty ? null : note,
          createdAt: now,
        );
        await repo.addIncome(entry);
      } else {
        final isSavings = _type == _EntryType.savings;
        final expenseId = _uuid.v4();
        final entry = ExpenseEntry(
          id: expenseId,
          monthId: monthId,
          category: isSavings ? ExpenseCategory.savings : effectiveCategory,
          amount: amount,
          date: _selectedDate,
          isRecurring: false,
          recurringTemplateId: null,
          note: note.isEmpty ? null : note,
          createdAt: now,
        );
        await repo.addExpense(entry);
      }
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      setState(() {
        _amountController.clear();
        _noteController.clear();
        _sourceController.clear();
        _selectedDate = clampDate(DateTime.now(), minDate, maxDate);
      });
    } catch (err) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save entry')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<double> _combinedPresets(
    List<double>? primary,
    List<double>? secondary,
  ) {
    final buffer = <double>{};
    if (primary != null) {
      buffer.addAll(
        primary.map((value) => double.parse(value.toStringAsFixed(2))),
      );
    }
    if (secondary != null) {
      buffer.addAll(
        secondary.map((value) => double.parse(value.toStringAsFixed(2))),
      );
    }
    final list = buffer.toList()..sort();
    return list;
  }
}

class _TypeSegmentedControl extends StatelessWidget {
  const _TypeSegmentedControl({required this.type, required this.onChanged});

  final _EntryType type;
  final ValueChanged<_EntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_EntryType>(
      segments: [
        ButtonSegment(
          value: _EntryType.expense,
          label: const Text('Spend', softWrap: false),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        ButtonSegment(
          value: _EntryType.inflow,
          label: const Text('Inflow', softWrap: false),
          icon: const Icon(Icons.add_circle_outline),
        ),
        ButtonSegment(
          value: _EntryType.savings,
          label: const Text('Save', softWrap: false),
          icon: const Icon(Icons.savings_rounded),
        ),
      ],
      selected: {type},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.presets,
    required this.onPresetTap,
  });

  final TextEditingController controller;
  final List<double> presets;
  final ValueChanged<double> onPresetTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.attach_money_rounded),
            labelText: 'Amount',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: presets
              .map(
                (value) => ActionChip(
                  label: Text(formatCurrency(value, compact: false)),
                  onPressed: () => onPresetTap(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ExpenseExtras extends StatelessWidget {
  const _ExpenseExtras({
    required this.category,
    required this.categories,
    required this.icons,
    required this.onCategoryTapped,
  });

  final ExpenseCategory category;
  final List<ExpenseCategory> categories;
  final Map<ExpenseCategory, IconData> icons;
  final ValueChanged<ExpenseCategory> onCategoryTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: categories
              .map(
                (value) => ChoiceChip(
                  label: Text(value.label),
                  avatar: Icon(icons[value] ?? categoryIcon(value), size: 18),
                  selected: value == category,
                  onSelected: (_) => onCategoryTapped(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _IncomeExtras extends StatelessWidget {
  const _IncomeExtras({
    required this.controller,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final TextEditingController controller;
  final List<double> suggestions;
  final ValueChanged<double> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.work_outline_rounded),
            labelText: 'Source',
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: suggestions
                .map(
                  (value) => ActionChip(
                    label: Text(formatCurrency(value)),
                    onPressed: () => onSuggestionTap(value),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _SavingsExtras extends StatelessWidget {
  const _SavingsExtras({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.tertiaryContainer,
              child: Icon(icon, color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Savings transfer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Record money you are moving into savings. This counts as an expense so your remaining balance reflects the transfer.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onEditingComplete: () => FocusScope.of(context).unfocus(),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.edit_note_rounded),
        labelText: 'Note (optional)',
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({required this.selectedDate, required this.onPressed});

  final DateTime selectedDate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_rounded),
      title: const Text('Date'),
      subtitle: Text(formatDay(selectedDate)),
      trailing: IconButton(
        icon: const Icon(Icons.edit_calendar_rounded),
        onPressed: onPressed,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
