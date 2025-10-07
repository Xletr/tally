import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/entities/expense_category.dart';

class QuickEntryEditorResult {
  QuickEntryEditorResult({
    required this.categories,
    required this.iconCodes,
    required this.savingsPresets,
  });

  final Map<ExpenseCategory, List<double>> categories;
  final Map<ExpenseCategory, int> iconCodes;
  final List<double> savingsPresets;
}

Future<QuickEntryEditorResult?> showQuickEntryEditor(
  BuildContext context, {
  required Map<ExpenseCategory, List<double>> initialCategories,
  required Map<ExpenseCategory, int> initialIconCodes,
  required List<double> initialSavingsPresets,
  required BudgetSettings settings,
}) {
  return showModalBottomSheet<QuickEntryEditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickEntryEditorSheet(
      initialCategories: initialCategories,
      initialIconCodes: initialIconCodes,
      initialSavingsPresets: initialSavingsPresets,
      settings: settings,
    ),
  );
}

class _QuickEntryEditorSheet extends StatefulWidget {
  const _QuickEntryEditorSheet({
    required this.initialCategories,
    required this.initialIconCodes,
    required this.initialSavingsPresets,
    required this.settings,
  });

  final Map<ExpenseCategory, List<double>> initialCategories;
  final Map<ExpenseCategory, int> initialIconCodes;
  final List<double> initialSavingsPresets;
  final BudgetSettings settings;

  @override
  State<_QuickEntryEditorSheet> createState() => _QuickEntryEditorSheetState();
}

class _QuickEntryEditorSheetState extends State<_QuickEntryEditorSheet> {
  static const _allowedCategories = <ExpenseCategory>{
    ExpenseCategory.food,
    ExpenseCategory.transport,
    ExpenseCategory.purchases,
    ExpenseCategory.misc,
  };

  late Map<ExpenseCategory, List<double>> _categories;
  late Map<ExpenseCategory, int> _iconCodes;
  late List<double> _savingsPresets;

  final Map<ExpenseCategory, TextEditingController> _controllers = {};
  late final TextEditingController _savingsController;

  @override
  void initState() {
    super.initState();
    _categories = {
      for (final entry in widget.initialCategories.entries)
        if (_allowedCategories.contains(entry.key))
          entry.key: List<double>.from(entry.value),
    };
    if (_categories.isEmpty) {
      _categories[ExpenseCategory.food] = const [8, 12, 18, 25];
    }

    _iconCodes = Map<ExpenseCategory, int>.from(widget.initialIconCodes);
    for (final category in _allowedCategories) {
      _iconCodes.putIfAbsent(
        category,
        () => widget.settings.iconForCategory(category).codePoint,
      );
    }
    _iconCodes.putIfAbsent(
      ExpenseCategory.savings,
      () => widget.settings.iconForCategory(ExpenseCategory.savings).codePoint,
    );

    _savingsPresets = List<double>.from(widget.initialSavingsPresets);
    if (_savingsPresets.isEmpty) {
      _savingsPresets = const [25, 50, 100];
    }

    for (final category in _allowedCategories) {
      _controllers[category] = TextEditingController();
    }
    _savingsController = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _savingsController.dispose();
    super.dispose();
  }

  IconData _iconFor(ExpenseCategory category) => IconData(
    _iconCodes[category] ?? widget.settings.iconForCategory(category).codePoint,
    fontFamily: 'MaterialIcons',
  );

  void _addCategory(ExpenseCategory category) {
    setState(() {
      _categories[category] = List<double>.from(
        widget.settings.categoryQuickEntryPresets[category] ??
            const [10, 20, 40],
      );
      _iconCodes.putIfAbsent(
        category,
        () => widget.settings.iconForCategory(category).codePoint,
      );
      _controllers.putIfAbsent(category, () => TextEditingController());
    });
  }

  void _removeCategory(ExpenseCategory category) {
    if (_categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one category.')),
      );
      return;
    }
    setState(() {
      _categories.remove(category);
      _iconCodes.remove(category);
      _controllers.remove(category)?.dispose();
    });
  }

  Future<void> _pickIcon(ExpenseCategory category) async {
    const iconOptions = <IconData>[
      Icons.restaurant_rounded,
      Icons.fastfood_rounded,
      Icons.local_pizza_rounded,
      Icons.ramen_dining_rounded,
      Icons.directions_bus_rounded,
      Icons.pedal_bike_rounded,
      Icons.shopping_bag_rounded,
      Icons.shopping_cart_rounded,
      Icons.local_mall_rounded,
      Icons.scatter_plot_rounded,
      Icons.local_cafe_rounded,
      Icons.savings_rounded,
    ];

    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: iconOptions
                .map(
                  (icon) => InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(icon.codePoint),
                    child: Card(child: Center(child: Icon(icon))),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _iconCodes[category] = selected);
    }
  }

  void _addPresetAmount(ExpenseCategory category) {
    final controller = _controllers[category];
    if (controller == null) return;
    final value = double.tryParse(controller.text);
    if (value == null || value <= 0) return;

    setState(() {
      final list = _categories.putIfAbsent(category, () => <double>[]);
      list.add(value.abs());
      _categories[category] = list.toSet().toList()..sort();
      controller.clear();
    });
  }

  void _addSavingsPreset() {
    final value = double.tryParse(_savingsController.text);
    if (value == null || value <= 0) return;
    setState(() {
      _savingsPresets.add(value.abs());
      _savingsPresets = _savingsPresets.toSet().toList()..sort();
      _savingsController.clear();
    });
  }

  void _removeSavingsPreset(double value) {
    setState(() {
      _savingsPresets.remove(value);
    });
  }

  void _saveAndClose() {
    final sanitizedCategories = {
      for (final entry in _categories.entries)
        entry.key: entry.value.toSet().toList()..sort(),
    };

    final result = QuickEntryEditorResult(
      categories: sanitizedCategories,
      iconCodes: Map<ExpenseCategory, int>.from(_iconCodes),
      savingsPresets: _savingsPresets.toSet().toList()..sort(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCategories = _allowedCategories
        .where((c) => _categories.containsKey(c))
        .toList();
    final availableCategories = _allowedCategories
        .where((c) => !_categories.containsKey(c))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Quick entry presets',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (availableCategories.isNotEmpty)
                  IconButton(
                    tooltip: 'Add category',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      final selected =
                          await showModalBottomSheet<ExpenseCategory>(
                            context: context,
                            builder: (context) => SafeArea(
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  const ListTile(
                                    title: Text('Select category'),
                                  ),
                                  for (final category in availableCategories)
                                    ListTile(
                                      leading: Icon(_iconFor(category)),
                                      title: Text(category.label),
                                      onTap: () =>
                                          Navigator.of(context).pop(category),
                                    ),
                                ],
                              ),
                            ),
                          );
                      if (selected != null) {
                        _addCategory(selected);
                      }
                    },
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final category in activeCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(_iconFor(category)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      category.label,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Change icon',
                                    icon: const Icon(Icons.brush_rounded),
                                    onPressed: () => _pickIcon(category),
                                  ),
                                  if (activeCategories.length > 1)
                                    IconButton(
                                      tooltip: 'Remove category',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () =>
                                          _removeCategory(category),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    (_categories[category] ?? const <double>[])
                                        .map(
                                          (value) => InputChip(
                                            label: Text(formatCurrency(value)),
                                            onDeleted: () {
                                              setState(() {
                                                _categories[category]?.remove(
                                                  value,
                                                );
                                              });
                                            },
                                          ),
                                        )
                                        .toList(),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _controllers[category],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        prefixText: '\$',
                                        labelText: 'Add amount',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonal(
                                    onPressed: () => _addPresetAmount(category),
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(_iconFor(ExpenseCategory.savings)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Savings quick amounts',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Change icon',
                                icon: const Icon(Icons.brush_rounded),
                                onPressed: () =>
                                    _pickIcon(ExpenseCategory.savings),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_savingsPresets.isEmpty)
                            Text(
                              'No quick amounts configured yet.',
                              style: theme.textTheme.bodySmall,
                            )
                          else
                            Wrap(
                              spacing: 8,
                              children: _savingsPresets
                                  .map(
                                    (value) => InputChip(
                                      label: Text(formatCurrency(value)),
                                      onDeleted: () =>
                                          _removeSavingsPreset(value),
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _savingsController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    prefixText: '\$',
                                    labelText: 'Add amount',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.tonal(
                                onPressed: _addSavingsPreset,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saveAndClose,
              child: const Text('Save presets'),
            ),
          ],
        ),
      ),
    );
  }
}
