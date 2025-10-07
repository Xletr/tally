import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/budget_settings.dart';
import '../../domain/entities/expense_category.dart';

part 'budget_settings_model.g.dart';

@HiveType(typeId: 5)
class BudgetSettingsModel extends HiveObject {
  BudgetSettingsModel({
    required this.themeModeIndex,
    required this.dynamicColorEnabled,
    required this.highContrast,
    required this.autoRollover,
    required this.notificationsEnabled,
    required this.midMonthReminder,
    required this.endOfMonthReminder,
    required this.overspendAlerts,
    required this.defaultSavingsRate,
    this.lastBackupAt,
    this.quickEntryPresets = const [5, 10, 20, 50],
    this.onboardingCompleted = false,
    this.defaultMonthlyAllowance = 0,
    Map<String, List<double>>? categoryQuickEntryPresets,
    this.monthlySavingsGoal = 0,
    this.midReminderMinutes = 18 * 60,
    this.endReminderMinutes = 18 * 60,
    Map<String, int>? quickEntryCategoryIcons,
    List<double>? savingsQuickEntryPresets,
  }) : categoryQuickEntryPresets =
           categoryQuickEntryPresets ?? const <String, List<double>>{},
       quickEntryCategoryIcons =
           quickEntryCategoryIcons ?? const <String, int>{},
       savingsQuickEntryPresets = savingsQuickEntryPresets ?? const <double>[];

  @HiveField(0)
  int themeModeIndex;

  @HiveField(1)
  bool dynamicColorEnabled;

  @HiveField(2)
  bool highContrast;

  @HiveField(3)
  bool autoRollover;

  @HiveField(4)
  bool notificationsEnabled;

  @HiveField(5)
  bool midMonthReminder;

  @HiveField(6)
  bool endOfMonthReminder;

  @HiveField(7)
  bool overspendAlerts;

  @HiveField(8)
  double defaultSavingsRate;

  @HiveField(9)
  DateTime? lastBackupAt;

  @HiveField(10)
  List<double> quickEntryPresets;

  @HiveField(11)
  bool onboardingCompleted;

  @HiveField(12)
  double defaultMonthlyAllowance;

  @HiveField(13)
  Map<String, List<double>>? categoryQuickEntryPresets;

  @HiveField(14)
  double monthlySavingsGoal;

  @HiveField(15)
  int midReminderMinutes;

  @HiveField(16)
  int endReminderMinutes;

  @HiveField(17)
  Map<String, int> quickEntryCategoryIcons;

  @HiveField(18)
  List<double> savingsQuickEntryPresets;

  BudgetSettings toDomain() {
    final presets = _mapFromStrings(
      categoryQuickEntryPresets,
      quickEntryPresets,
    );
    final savingsPresets = _normalizeSavingsFromMap(
      savingsQuickEntryPresets,
      presets,
    );
    final filteredPresets = Map<ExpenseCategory, List<double>>.from(presets)
      ..remove(ExpenseCategory.savings)
      ..remove(ExpenseCategory.subscriptions);
    return BudgetSettings(
      themeMode: ThemeMode
          .values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)],
      dynamicColorEnabled: dynamicColorEnabled,
      highContrast: highContrast,
      autoRollover: autoRollover,
      notificationsEnabled: notificationsEnabled,
      midMonthReminder: midMonthReminder,
      endOfMonthReminder: endOfMonthReminder,
      overspendAlerts: overspendAlerts,
      defaultSavingsRate: defaultSavingsRate,
      monthlySavingsGoal: monthlySavingsGoal,
      onboardingCompleted: onboardingCompleted,
      defaultMonthlyAllowance: defaultMonthlyAllowance,
      categoryQuickEntryPresets: filteredPresets,
      quickEntryCategoryIcons: _iconMapFromStrings(quickEntryCategoryIcons),
      savingsQuickEntryPresets: savingsPresets,
      midMonthReminderAt: ReminderTime(
        hour: midReminderMinutes ~/ 60,
        minute: midReminderMinutes % 60,
      ),
      endOfMonthReminderAt: ReminderTime(
        hour: endReminderMinutes ~/ 60,
        minute: endReminderMinutes % 60,
      ),
      lastBackupAt: lastBackupAt,
    );
  }

  static BudgetSettingsModel fromDomain(BudgetSettings settings) {
    final combinedPresets = _mapToStrings(settings.categoryQuickEntryPresets)
      ..[ExpenseCategory.savings.name] = settings.savingsQuickEntryPresets;
    return BudgetSettingsModel(
      themeModeIndex: settings.themeMode.index,
      dynamicColorEnabled: settings.dynamicColorEnabled,
      highContrast: settings.highContrast,
      autoRollover: settings.autoRollover,
      notificationsEnabled: settings.notificationsEnabled,
      midMonthReminder: settings.midMonthReminder,
      endOfMonthReminder: settings.endOfMonthReminder,
      overspendAlerts: settings.overspendAlerts,
      defaultSavingsRate: settings.defaultSavingsRate,
      lastBackupAt: settings.lastBackupAt,
      quickEntryPresets: const [5, 10, 20, 50],
      onboardingCompleted: settings.onboardingCompleted,
      defaultMonthlyAllowance: settings.defaultMonthlyAllowance,
      categoryQuickEntryPresets: combinedPresets,
      monthlySavingsGoal: settings.monthlySavingsGoal,
      midReminderMinutes:
          settings.midMonthReminderAt.hour * 60 +
          settings.midMonthReminderAt.minute,
      endReminderMinutes:
          settings.endOfMonthReminderAt.hour * 60 +
          settings.endOfMonthReminderAt.minute,
      quickEntryCategoryIcons: _iconMapToStrings(
        settings.quickEntryCategoryIcons,
      ),
      savingsQuickEntryPresets: settings.savingsQuickEntryPresets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themeModeIndex': themeModeIndex,
      'dynamicColorEnabled': dynamicColorEnabled,
      'highContrast': highContrast,
      'autoRollover': autoRollover,
      'notificationsEnabled': notificationsEnabled,
      'midMonthReminder': midMonthReminder,
      'endOfMonthReminder': endOfMonthReminder,
      'overspendAlerts': overspendAlerts,
      'defaultSavingsRate': defaultSavingsRate,
      'lastBackupAt': lastBackupAt?.toIso8601String(),
      'quickEntryPresets': quickEntryPresets,
      'onboardingCompleted': onboardingCompleted,
      'defaultMonthlyAllowance': defaultMonthlyAllowance,
      'categoryQuickEntryPresets': categoryQuickEntryPresets,
      'monthlySavingsGoal': monthlySavingsGoal,
      'midReminderMinutes': midReminderMinutes,
      'endReminderMinutes': endReminderMinutes,
      'quickEntryCategoryIcons': quickEntryCategoryIcons,
      'savingsQuickEntryPresets': savingsQuickEntryPresets,
    };
  }

  static BudgetSettingsModel fromMap(Map<String, dynamic> map) {
    return BudgetSettingsModel(
      themeModeIndex: map['themeModeIndex'] as int? ?? ThemeMode.system.index,
      dynamicColorEnabled: map['dynamicColorEnabled'] as bool? ?? true,
      highContrast: map['highContrast'] as bool? ?? false,
      autoRollover: map['autoRollover'] as bool? ?? true,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      midMonthReminder: map['midMonthReminder'] as bool? ?? true,
      endOfMonthReminder: map['endOfMonthReminder'] as bool? ?? true,
      overspendAlerts: map['overspendAlerts'] as bool? ?? true,
      defaultSavingsRate:
          (map['defaultSavingsRate'] as num?)?.toDouble() ?? 0.15,
      lastBackupAt: map['lastBackupAt'] != null
          ? DateTime.parse(map['lastBackupAt'] as String)
          : null,
      quickEntryPresets:
          (map['quickEntryPresets'] as List<dynamic>? ?? const [5, 10, 20, 50])
              .map((e) => (e as num).toDouble())
              .toList(),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      defaultMonthlyAllowance:
          (map['defaultMonthlyAllowance'] as num?)?.toDouble() ?? 0,
      categoryQuickEntryPresets: (map['categoryQuickEntryPresets'] as Map?)
          ?.map(
            (key, value) => MapEntry(
              key as String,
              (value as List).map((e) => (e as num).toDouble()).toList(),
            ),
          ),
      monthlySavingsGoal: (map['monthlySavingsGoal'] as num?)?.toDouble() ?? 0,
      midReminderMinutes: map['midReminderMinutes'] as int? ?? 18 * 60,
      endReminderMinutes: map['endReminderMinutes'] as int? ?? 18 * 60,
      quickEntryCategoryIcons:
          (map['quickEntryCategoryIcons'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toInt()),
          ) ??
          const <String, int>{},
      savingsQuickEntryPresets:
          (map['savingsQuickEntryPresets'] as List?)
              ?.map((value) => (value as num).toDouble())
              .toList() ??
          const <double>[],
    );
  }

  static Map<ExpenseCategory, List<double>> _mapFromStrings(
    Map<String, List<double>>? stored,
    List<double> legacyPresets,
  ) {
    final map = <ExpenseCategory, List<double>>{};
    if (stored != null && stored.isNotEmpty) {
      for (final entry in stored.entries) {
        final category = ExpenseCategory.values.firstWhere(
          (cat) => cat.name == entry.key,
          orElse: () => ExpenseCategory.misc,
        );
        map[category] = List<double>.unmodifiable(entry.value);
      }
    }
    if (map.isEmpty) {
      final fallback = legacyPresets.isEmpty
          ? const [5.0, 10.0, 20.0, 50.0]
          : legacyPresets;
      for (final category in ExpenseCategory.values) {
        map[category] = List<double>.unmodifiable(fallback);
      }
    }
    return map;
  }

  static Map<String, List<double>> _mapToStrings(
    Map<ExpenseCategory, List<double>> presets,
  ) {
    return presets.map((key, value) => MapEntry(key.name, value));
  }

  static Map<ExpenseCategory, int> _iconMapFromStrings(
    Map<String, int> stored,
  ) {
    final map = <ExpenseCategory, int>{};
    for (final entry in stored.entries) {
      final category = ExpenseCategory.values.firstWhere(
        (cat) => cat.name == entry.key,
        orElse: () => ExpenseCategory.misc,
      );
      map[category] = entry.value;
    }
    return map;
  }

  static Map<String, int> _iconMapToStrings(Map<ExpenseCategory, int> icons) {
    return icons.map((key, value) => MapEntry(key.name, value));
  }

  static List<double> _normalizeSavingsFromMap(
    List<double> storedSavings,
    Map<ExpenseCategory, List<double>> presets,
  ) {
    if (storedSavings.isNotEmpty) {
      return storedSavings.map((value) => value.abs()).toSet().toList()..sort();
    }
    final fromMap = presets[ExpenseCategory.savings];
    if (fromMap != null && fromMap.isNotEmpty) {
      return fromMap.map((value) => value.abs()).toSet().toList()..sort();
    }
    return const [25.0, 50.0, 100.0];
  }
}
