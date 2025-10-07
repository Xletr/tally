import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/providers/budget_providers.dart';
import '../../domain/providers/settings_providers.dart';
import '../shell/app_shell.dart';
import '../widgets/quick_entry_editor.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pageController = PageController();
  final _allowanceController = TextEditingController();
  final _savingsController = TextEditingController();
  int _index = 0;
  bool _initialized = false;
  late Map<ExpenseCategory, List<double>> _presets;
  late Map<ExpenseCategory, int> _presetIcons;
  late List<double> _savingsPresets;
  late bool _notificationsEnabled;
  late bool _midReminderEnabled;
  late bool _endReminderEnabled;
  late bool _overspendAlerts;
  late ReminderTime _midReminderTime;
  late ReminderTime _endReminderTime;

  @override
  void dispose() {
    _pageController.dispose();
    _allowanceController.dispose();
    _savingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    return settingsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Unable to load settings\n$error')),
      ),
      data: (settings) {
        if (!_initialized) {
          _initialize(settings);
        }
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _StepperHeader(
                  currentIndex: _index,
                  totalSteps: 4,
                  onSkip: () => _finish(settings),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _OnboardingWelcome(onNext: _next),
                      _AllowanceStep(
                        allowanceController: _allowanceController,
                        savingsController: _savingsController,
                        onNext: _next,
                        onBack: _back,
                      ),
                      _PresetStep(
                        presets: _presets,
                        icons: _presetIcons,
                        savingsPresets: _savingsPresets,
                        settings: settings,
                        onChanged: (categories, icons, savings) {
                          setState(() {
                            _presets = {
                              for (final entry in categories.entries)
                                entry.key: List<double>.from(entry.value),
                            };
                            _presetIcons = Map<ExpenseCategory, int>.from(
                              icons,
                            );
                            _savingsPresets = List<double>.from(savings);
                          });
                        },
                        onNext: _next,
                        onBack: _back,
                      ),
                      _NotificationStep(
                        notificationsEnabled: _notificationsEnabled,
                        midReminderEnabled: _midReminderEnabled,
                        endReminderEnabled: _endReminderEnabled,
                        overspendEnabled: _overspendAlerts,
                        midReminderTime: _midReminderTime,
                        endReminderTime: _endReminderTime,
                        onToggleNotifications: (value) =>
                            setState(() => _notificationsEnabled = value),
                        onToggleMidReminder: (value) =>
                            setState(() => _midReminderEnabled = value),
                        onToggleEndReminder: (value) =>
                            setState(() => _endReminderEnabled = value),
                        onToggleOverspend: (value) =>
                            setState(() => _overspendAlerts = value),
                        onPickMidTime: (time) =>
                            setState(() => _midReminderTime = time),
                        onPickEndTime: (time) =>
                            setState(() => _endReminderTime = time),
                        onFinish: () => _finish(settings),
                        onBack: _back,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initialize(BudgetSettings settings) {
    final allowance = settings.defaultMonthlyAllowance > 0
        ? settings.defaultMonthlyAllowance
        : 500;
    final savingsGoal = settings.monthlySavingsGoal > 0
        ? settings.monthlySavingsGoal
        : allowance * settings.defaultSavingsRate;
    _allowanceController.text = allowance.toStringAsFixed(0);
    _savingsController.text = savingsGoal.toStringAsFixed(0);
    _presets = {
      for (final entry in settings.categoryQuickEntryPresets.entries)
        entry.key: List<double>.from(entry.value),
    };
    _presetIcons = {
      for (final entry in settings.quickEntryCategoryIcons.entries)
        entry.key: entry.value,
    };
    for (final category in _PresetStepState.allowedCategories) {
      _presetIcons.putIfAbsent(
        category,
        () => settings.iconForCategory(category).codePoint,
      );
    }
    _presetIcons.putIfAbsent(
      ExpenseCategory.savings,
      () => settings.iconForCategory(ExpenseCategory.savings).codePoint,
    );
    _savingsPresets = List<double>.from(settings.savingsQuickEntryPresets);
    if (_savingsPresets.isEmpty) {
      _savingsPresets = const [25, 50, 100];
    }
    _notificationsEnabled = settings.notificationsEnabled;
    _midReminderEnabled = settings.midMonthReminder;
    _endReminderEnabled = settings.endOfMonthReminder;
    _overspendAlerts = settings.overspendAlerts;
    _midReminderTime = settings.midMonthReminderAt;
    _endReminderTime = settings.endOfMonthReminderAt;
    _initialized = true;
  }

  void _next() {
    if (_index < 3) {
      setState(() => _index += 1);
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index -= 1);
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish(BudgetSettings currentSettings) async {
    final allowance =
        double.tryParse(_allowanceController.text) ??
        currentSettings.defaultMonthlyAllowance;
    final savingsGoal =
        double.tryParse(_savingsController.text) ??
        currentSettings.monthlySavingsGoal;

    final sanitizedPresets = {
      for (final entry in _presets.entries)
        entry.key: entry.value.map((value) => value.abs()).toSet().toList()
          ..sort(),
    };
    sanitizedPresets.remove(ExpenseCategory.savings);
    sanitizedPresets.remove(ExpenseCategory.subscriptions);
    final sanitizedIcons = <ExpenseCategory, int>{
      for (final entry in _presetIcons.entries) entry.key: entry.value,
    };
    final sanitizedSavings =
        _savingsPresets.map((value) => value.abs()).toSet().toList()..sort();

    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final repo = ref.read(budgetRepositoryProvider);

    await settingsCtrl.completeOnboarding(
      allowance: allowance,
      savingsGoal: savingsGoal,
      presets: sanitizedPresets,
      icons: sanitizedIcons,
      savings: sanitizedSavings,
    );
    await settingsCtrl.updateMonthlySavingsGoal(savingsGoal);
    await settingsCtrl.updateDefaultAllowance(allowance);
    if (allowance > 0) {
      await settingsCtrl.updateDefaultSavingsRate(
        (savingsGoal / allowance).clamp(0, 1),
      );
    }
    await settingsCtrl.updateNotifications(
      enabled: _notificationsEnabled,
      midMonth: _midReminderEnabled,
      endOfMonth: _endReminderEnabled,
      overspend: _overspendAlerts,
    );
    await settingsCtrl.updateReminderTime(
      midMonth: _midReminderTime,
      endOfMonth: _endReminderTime,
    );

    final month = await repo.ensureCurrentMonth(allowRollover: false);
    await repo.saveBudgetMonth(
      month.copyWith(
        savingsTarget: savingsGoal > 0 ? savingsGoal : month.savingsTarget,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }
}

class _StepperHeader extends StatelessWidget {
  const _StepperHeader({
    required this.currentIndex,
    required this.totalSteps,
    required this.onSkip,
  });

  final int currentIndex;
  final int totalSteps;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            'Step ${currentIndex + 1} of $totalSteps',
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          TextButton(onPressed: onSkip, child: const Text('Skip')),
        ],
      ),
    );
  }
}

class _OnboardingWelcome extends StatelessWidget {
  const _OnboardingWelcome({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'Welcome to Tally',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Let’s capture the basics of your monthly inflow so Tally can guide you with smart reminders and shortcuts.',
            style: theme.textTheme.bodyLarge,
          ),
          const Spacer(),
          FilledButton(onPressed: onNext, child: const Text('Start setup')),
        ],
      ),
    );
  }
}

class _AllowanceStep extends StatelessWidget {
  const _AllowanceStep({
    required this.allowanceController,
    required this.savingsController,
    required this.onNext,
    required this.onBack,
  });

  final TextEditingController allowanceController;
  final TextEditingController savingsController;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly basics',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: allowanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Average monthly inflow',
              prefixText: '\$',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: savingsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Savings goal per month',
              prefixText: '\$',
            ),
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Back')),
              const Spacer(),
              FilledButton(onPressed: onNext, child: const Text('Continue')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetStep extends StatefulWidget {
  const _PresetStep({
    required this.presets,
    required this.icons,
    required this.savingsPresets,
    required this.settings,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  final Map<ExpenseCategory, List<double>> presets;
  final Map<ExpenseCategory, int> icons;
  final List<double> savingsPresets;
  final BudgetSettings settings;
  final void Function(
    Map<ExpenseCategory, List<double>> categories,
    Map<ExpenseCategory, int> icons,
    List<double> savings,
  )
  onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<_PresetStep> createState() => _PresetStepState();
}

class _PresetStepState extends State<_PresetStep> {
  static const allowedCategories = <ExpenseCategory>{
    ExpenseCategory.food,
    ExpenseCategory.transport,
    ExpenseCategory.purchases,
    ExpenseCategory.misc,
  };

  late Map<ExpenseCategory, List<double>> _localCategories;
  late Map<ExpenseCategory, int> _localIcons;
  late List<double> _localSavings;
  bool _openedEditorOnce = false;

  @override
  void initState() {
    super.initState();
    _localCategories = {
      for (final entry in widget.presets.entries)
        if (allowedCategories.contains(entry.key))
          entry.key: List<double>.from(entry.value),
    };
    if (_localCategories.isEmpty) {
      _localCategories[ExpenseCategory.food] = const [8, 12, 18, 25];
    }
    _localIcons = Map<ExpenseCategory, int>.from(widget.icons);
    _localSavings = List<double>.from(widget.savingsPresets);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_openedEditorOnce) {
        _openEditor();
        _openedEditorOnce = true;
      }
    });
  }

  void _openEditor() async {
    final result = await showQuickEntryEditor(
      context,
      initialCategories: _localCategories,
      initialIconCodes: _localIcons,
      initialSavingsPresets: _localSavings,
      settings: widget.settings,
    );

    if (result != null && mounted) {
      setState(() {
        _localCategories = result.categories;
        _localIcons = result.iconCodes;
        _localSavings = result.savingsPresets;
      });
      widget.onChanged(
        result.categories,
        result.iconCodes,
        result.savingsPresets,
      );
    }
  }

  Map<ExpenseCategory, List<double>> get _displayCategories => _localCategories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick entry favourites',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These presets power the Inflow, Expense, and Savings tabs. You can tweak them now or anytime from Settings.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final entry in _displayCategories.entries)
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
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    IconData(
                                      _localIcons[entry.key] ??
                                          widget.settings
                                              .iconForCategory(entry.key)
                                              .codePoint,
                                      fontFamily: 'MaterialIcons',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.key.label,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: entry.value
                                  .map(
                                    (value) => Chip(
                                      label: Text(formatCurrency(value)),
                                    ),
                                  )
                                  .toList(),
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
                              child: Icon(
                                IconData(
                                  _localIcons[ExpenseCategory.savings] ??
                                      widget.settings
                                          .iconForCategory(
                                            ExpenseCategory.savings,
                                          )
                                          .codePoint,
                                  fontFamily: 'MaterialIcons',
                                ),
                              ),
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_localSavings.isEmpty)
                          Text(
                            'No quick amounts configured yet.',
                            style: theme.textTheme.bodySmall,
                          )
                        else
                          Wrap(
                            spacing: 8,
                            children: _localSavings
                                .map(
                                  (value) =>
                                      Chip(label: Text(formatCurrency(value))),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _openEditor,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Edit presets'),
              ),
              const Spacer(),
              TextButton(onPressed: widget.onBack, child: const Text('Back')),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  widget.onChanged(
                    _localCategories,
                    _localIcons,
                    _localSavings,
                  );
                  widget.onNext();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({
    required this.notificationsEnabled,
    required this.midReminderEnabled,
    required this.endReminderEnabled,
    required this.overspendEnabled,
    required this.midReminderTime,
    required this.endReminderTime,
    required this.onToggleNotifications,
    required this.onToggleMidReminder,
    required this.onToggleEndReminder,
    required this.onToggleOverspend,
    required this.onPickMidTime,
    required this.onPickEndTime,
    required this.onFinish,
    required this.onBack,
  });

  final bool notificationsEnabled;
  final bool midReminderEnabled;
  final bool endReminderEnabled;
  final bool overspendEnabled;
  final ReminderTime midReminderTime;
  final ReminderTime endReminderTime;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onToggleMidReminder;
  final ValueChanged<bool> onToggleEndReminder;
  final ValueChanged<bool> onToggleOverspend;
  final ValueChanged<ReminderTime> onPickMidTime;
  final ValueChanged<ReminderTime> onPickEndTime;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart alerts',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: notificationsEnabled,
            title: const Text('Enable notifications'),
            onChanged: onToggleNotifications,
          ),
          _ReminderTile(
            title: 'Mid-month check-in',
            enabled: midReminderEnabled,
            reminderTime: midReminderTime,
            onToggle: onToggleMidReminder,
            onPickTime: onPickMidTime,
          ),
          _ReminderTile(
            title: 'End-of-month wrap-up',
            enabled: endReminderEnabled,
            reminderTime: endReminderTime,
            onToggle: onToggleEndReminder,
            onPickTime: onPickEndTime,
          ),
          SwitchListTile.adaptive(
            value: overspendEnabled,
            title: const Text('Overspend alerts'),
            onChanged: onToggleOverspend,
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Back')),
              const Spacer(),
              FilledButton(
                onPressed: onFinish,
                child: const Text('Finish setup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.enabled,
    required this.reminderTime,
    required this.onToggle,
    required this.onPickTime,
  });

  final String title;
  final bool enabled;
  final ReminderTime reminderTime;
  final ValueChanged<bool> onToggle;
  final ValueChanged<ReminderTime> onPickTime;

  @override
  Widget build(BuildContext context) {
    final timeOfDay = reminderTime.asTimeOfDay();
    final materialLocalizations = MaterialLocalizations.of(context);
    final timeLabel = materialLocalizations.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    return SwitchListTile.adaptive(
      value: enabled,
      title: Text(title),
      subtitle: Text('Remind me at $timeLabel'),
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
