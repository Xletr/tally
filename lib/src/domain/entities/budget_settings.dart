import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'expense_category.dart';

class ReminderTime extends Equatable {
  const ReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  TimeOfDay asTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  ReminderTime copyWith({int? hour, int? minute}) {
    return ReminderTime(hour: hour ?? this.hour, minute: minute ?? this.minute);
  }

  @override
  List<Object?> get props => [hour, minute];

  factory ReminderTime.fromTimeOfDay(TimeOfDay time) {
    return ReminderTime(hour: time.hour, minute: time.minute);
  }
}

class BudgetSettings extends Equatable {
  BudgetSettings({
    this.themeMode = ThemeMode.system,
    this.dynamicColorEnabled = true,
    this.highContrast = false,
    this.autoRollover = true,
    this.notificationsEnabled = true,
    this.midMonthReminder = true,
    this.endOfMonthReminder = true,
    this.overspendAlerts = true,
    this.defaultSavingsRate = 0.15,
    this.monthlySavingsGoal = 0,
    this.onboardingCompleted = false,
    this.defaultMonthlyAllowance = 0,
    Map<ExpenseCategory, List<double>>? categoryQuickEntryPresets,
    Map<ExpenseCategory, int>? quickEntryCategoryIcons,
    List<double>? savingsQuickEntryPresets,
    ReminderTime? midMonthReminderAt,
    ReminderTime? endOfMonthReminderAt,
    this.lastBackupAt,
  }) : categoryQuickEntryPresets = _normalizePresets(categoryQuickEntryPresets),
       quickEntryCategoryIcons = _normalizeIcons(quickEntryCategoryIcons),
       savingsQuickEntryPresets = _normalizeSavingsPresets(
         savingsQuickEntryPresets ??
             (categoryQuickEntryPresets != null
                 ? categoryQuickEntryPresets[ExpenseCategory.savings]
                 : null),
       ),
       midMonthReminderAt =
           midMonthReminderAt ?? const ReminderTime(hour: 18, minute: 0),
       endOfMonthReminderAt =
           endOfMonthReminderAt ?? const ReminderTime(hour: 18, minute: 0);

  final ThemeMode themeMode;
  final bool dynamicColorEnabled;
  final bool highContrast;
  final bool autoRollover;
  final bool notificationsEnabled;
  final bool midMonthReminder;
  final bool endOfMonthReminder;
  final bool overspendAlerts;
  final double defaultSavingsRate;
  final double monthlySavingsGoal;
  final bool onboardingCompleted;
  final double defaultMonthlyAllowance;
  final Map<ExpenseCategory, List<double>> categoryQuickEntryPresets;
  final Map<ExpenseCategory, int> quickEntryCategoryIcons;
  final List<double> savingsQuickEntryPresets;
  final ReminderTime midMonthReminderAt;
  final ReminderTime endOfMonthReminderAt;
  final DateTime? lastBackupAt;

  BudgetSettings copyWith({
    ThemeMode? themeMode,
    bool? dynamicColorEnabled,
    bool? highContrast,
    bool? autoRollover,
    bool? notificationsEnabled,
    bool? midMonthReminder,
    bool? endOfMonthReminder,
    bool? overspendAlerts,
    double? defaultSavingsRate,
    double? monthlySavingsGoal,
    bool? onboardingCompleted,
    double? defaultMonthlyAllowance,
    Map<ExpenseCategory, List<double>>? categoryQuickEntryPresets,
    Map<ExpenseCategory, int>? quickEntryCategoryIcons,
    List<double>? savingsQuickEntryPresets,
    ReminderTime? midMonthReminderAt,
    ReminderTime? endOfMonthReminderAt,
    DateTime? lastBackupAt,
  }) {
    return BudgetSettings(
      themeMode: themeMode ?? this.themeMode,
      dynamicColorEnabled: dynamicColorEnabled ?? this.dynamicColorEnabled,
      highContrast: highContrast ?? this.highContrast,
      autoRollover: autoRollover ?? this.autoRollover,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      midMonthReminder: midMonthReminder ?? this.midMonthReminder,
      endOfMonthReminder: endOfMonthReminder ?? this.endOfMonthReminder,
      overspendAlerts: overspendAlerts ?? this.overspendAlerts,
      defaultSavingsRate: defaultSavingsRate ?? this.defaultSavingsRate,
      monthlySavingsGoal: monthlySavingsGoal ?? this.monthlySavingsGoal,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      defaultMonthlyAllowance:
          defaultMonthlyAllowance ?? this.defaultMonthlyAllowance,
      categoryQuickEntryPresets: categoryQuickEntryPresets != null
          ? _normalizePresets(categoryQuickEntryPresets)
          : this.categoryQuickEntryPresets,
      quickEntryCategoryIcons: quickEntryCategoryIcons != null
          ? _normalizeIcons(quickEntryCategoryIcons)
          : this.quickEntryCategoryIcons,
      savingsQuickEntryPresets: savingsQuickEntryPresets != null
          ? _normalizeSavingsPresets(savingsQuickEntryPresets)
          : this.savingsQuickEntryPresets,
      midMonthReminderAt: midMonthReminderAt ?? this.midMonthReminderAt,
      endOfMonthReminderAt: endOfMonthReminderAt ?? this.endOfMonthReminderAt,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }

  static Map<ExpenseCategory, List<double>> _normalizePresets(
    Map<ExpenseCategory, List<double>>? presets,
  ) {
    final allowed = _expenseCategories;
    final defaults = <ExpenseCategory, List<double>>{
      ExpenseCategory.food: const [8, 12, 18, 25],
      ExpenseCategory.transport: const [5, 10, 20],
      ExpenseCategory.purchases: const [15, 30, 60],
      ExpenseCategory.misc: const [5, 15, 40],
    };

    if (presets == null || presets.isEmpty) {
      return defaults.map(
        (key, value) => MapEntry(key, List<double>.unmodifiable(value)),
      );
    }

    final result = <ExpenseCategory, List<double>>{};
    for (final category in allowed) {
      final values =
          presets[category] ?? defaults[category] ?? const <double>[];
      final sanitized = values.map((value) => value.abs()).toSet().toList()
        ..sort();
      result[category] = List<double>.unmodifiable(sanitized);
    }
    return result;
  }

  static List<double> _normalizeSavingsPresets(List<double>? presets) {
    final defaults = const [25.0, 50.0, 100.0];
    final source = presets == null || presets.isEmpty ? defaults : presets;
    final sanitized = source.map((value) => value.abs()).toSet().toList()
      ..sort();
    return List<double>.unmodifiable(sanitized);
  }

  static Map<ExpenseCategory, int> _normalizeIcons(
    Map<ExpenseCategory, int>? icons,
  ) {
    final result = <ExpenseCategory, int>{};
    for (final entry in _defaultIconCodes.entries) {
      final value = icons?[entry.key];
      result[entry.key] = value ?? entry.value;
    }
    return result;
  }

  static final Map<ExpenseCategory, int> _defaultIconCodes = {
    ExpenseCategory.food: Icons.restaurant_rounded.codePoint,
    ExpenseCategory.transport: Icons.directions_bus_rounded.codePoint,
    ExpenseCategory.subscriptions: Icons.subscriptions_rounded.codePoint,
    ExpenseCategory.purchases: Icons.shopping_bag_rounded.codePoint,
    ExpenseCategory.misc: Icons.scatter_plot_rounded.codePoint,
    ExpenseCategory.savings: Icons.savings_rounded.codePoint,
  };

  static const List<ExpenseCategory> _expenseCategories = [
    ExpenseCategory.food,
    ExpenseCategory.transport,
    ExpenseCategory.purchases,
    ExpenseCategory.misc,
  ];

  IconData iconForCategory(ExpenseCategory category) {
    final code =
        quickEntryCategoryIcons[category] ??
        _defaultIconCodes[category] ??
        Icons.category.codePoint;
    return IconData(code, fontFamily: 'MaterialIcons');
  }

  @override
  List<Object?> get props => [
    themeMode,
    dynamicColorEnabled,
    highContrast,
    autoRollover,
    notificationsEnabled,
    midMonthReminder,
    endOfMonthReminder,
    overspendAlerts,
    defaultSavingsRate,
    monthlySavingsGoal,
    onboardingCompleted,
    defaultMonthlyAllowance,
    categoryQuickEntryPresets,
    quickEntryCategoryIcons,
    savingsQuickEntryPresets,
    midMonthReminderAt,
    endOfMonthReminderAt,
    lastBackupAt,
  ];
}
