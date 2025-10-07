import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/bootstrap.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../entities/budget_settings.dart';
import '../entities/expense_category.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapProvider);
  return SettingsRepositoryImpl(bootstrap);
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, BudgetSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<BudgetSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);
  StreamSubscription<BudgetSettings>? _subscription;

  @override
  FutureOr<BudgetSettings> build() async {
    final initial = await _repository.load();
    _subscription = _repository.watch().listen((value) {
      state = AsyncData(value);
    });
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return initial;
  }

  Future<void> updateThemeMode(ThemeMode mode) =>
      _persist(state.value?.copyWith(themeMode: mode));

  Future<void> toggleHighContrast(bool value) =>
      _persist(state.value?.copyWith(highContrast: value));

  Future<void> toggleDynamicColor(bool value) =>
      _persist(state.value?.copyWith(dynamicColorEnabled: value));

  Future<void> toggleAutoRollover(bool value) =>
      _persist(state.value?.copyWith(autoRollover: value));

  Future<void> updateDefaultSavingsRate(double rate) =>
      _persist(state.value?.copyWith(defaultSavingsRate: rate));

  Future<void> updateMonthlySavingsGoal(double amount) =>
      _persist(state.value?.copyWith(monthlySavingsGoal: amount));

  Future<void> updateDefaultAllowance(double amount) =>
      _persist(state.value?.copyWith(defaultMonthlyAllowance: amount));

  Future<void> updateNotifications({
    bool? enabled,
    bool? midMonth,
    bool? endOfMonth,
    bool? overspend,
  }) {
    final current = state.value;
    if (current == null) return Future.value();
    return _persist(
      current.copyWith(
        notificationsEnabled: enabled ?? current.notificationsEnabled,
        midMonthReminder: midMonth ?? current.midMonthReminder,
        endOfMonthReminder: endOfMonth ?? current.endOfMonthReminder,
        overspendAlerts: overspend ?? current.overspendAlerts,
      ),
    );
  }

  Future<void> saveQuickEntryConfiguration({
    required Map<ExpenseCategory, List<double>> categories,
    required Map<ExpenseCategory, int> icons,
    required List<double> savings,
  }) {
    final current = state.value;
    if (current == null) return Future.value();

    final sanitizedCategories = <ExpenseCategory, List<double>>{};
    for (final entry in categories.entries) {
      final sorted = entry.value.map((value) => value.abs()).toSet().toList()
        ..sort();
      if (sorted.isNotEmpty) {
        sanitizedCategories[entry.key] = List<double>.unmodifiable(sorted);
      }
    }

    if (sanitizedCategories.isEmpty) {
      final fallback = current.categoryQuickEntryPresets.isNotEmpty
          ? current.categoryQuickEntryPresets.entries.first
          : MapEntry(ExpenseCategory.food, const [8.0, 12.0, 18.0, 25.0]);
      sanitizedCategories[fallback.key] = fallback.value;
    }

    final sanitizedIcons = <ExpenseCategory, int>{};
    for (final entry in icons.entries) {
      sanitizedIcons[entry.key] = entry.value;
    }

    final savingsSorted = savings.map((value) => value.abs()).toSet().toList()
      ..sort();
    final finalSavings = savingsSorted.isEmpty
        ? current.savingsQuickEntryPresets
        : savingsSorted;

    return _persist(
      current.copyWith(
        categoryQuickEntryPresets: sanitizedCategories,
        quickEntryCategoryIcons: sanitizedIcons,
        savingsQuickEntryPresets: finalSavings,
      ),
    );
  }

  Future<void> updateReminderTime({
    ReminderTime? midMonth,
    ReminderTime? endOfMonth,
  }) {
    final current = state.value;
    if (current == null) return Future.value();
    return _persist(
      current.copyWith(
        midMonthReminderAt: midMonth ?? current.midMonthReminderAt,
        endOfMonthReminderAt: endOfMonth ?? current.endOfMonthReminderAt,
      ),
    );
  }

  Future<void> completeOnboarding({
    required double allowance,
    required double savingsGoal,
    required Map<ExpenseCategory, List<double>> presets,
    required Map<ExpenseCategory, int> icons,
    required List<double> savings,
  }) {
    final current = state.value;
    if (current == null) return Future.value();
    return _persist(
      current.copyWith(
        onboardingCompleted: true,
        defaultMonthlyAllowance: allowance,
        monthlySavingsGoal: savingsGoal,
        categoryQuickEntryPresets: presets,
        quickEntryCategoryIcons: icons,
        savingsQuickEntryPresets: savings,
      ),
    );
  }

  Future<void> markBackup(DateTime timestamp) =>
      _persist(state.value?.copyWith(lastBackupAt: timestamp));

  Future<void> _persist(BudgetSettings? settings) async {
    if (settings == null) return;
    state = AsyncData(settings);
    await _repository.save(settings);
  }
}

class ThemeController {
  const ThemeController({
    this.mode = ThemeMode.system,
    this.useDynamicColor = true,
    this.highContrast = false,
  });

  final ThemeMode mode;
  final bool useDynamicColor;
  final bool highContrast;
}

final themeControllerProvider = Provider<ThemeController>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return settings.when(
    data: (value) => ThemeController(
      mode: value.themeMode,
      useDynamicColor: value.dynamicColorEnabled,
      highContrast: value.highContrast,
    ),
    loading: () => const ThemeController(),
    error: (_, __) => const ThemeController(),
  );
});

final categoryQuickPresetsProvider =
    Provider<Map<ExpenseCategory, List<double>>>((ref) {
      final settings = ref.watch(settingsControllerProvider);
      return settings.maybeWhen(
        data: (value) => value.categoryQuickEntryPresets,
        orElse: () => const {},
      );
    });

final savingsQuickPresetsProvider = Provider<List<double>>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return settings.maybeWhen(
    data: (value) => value.savingsQuickEntryPresets,
    orElse: () => const [25.0, 50.0, 100.0],
  );
});

final quickEntryIconsProvider = Provider<Map<ExpenseCategory, IconData>>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return settings.maybeWhen(
    data: (value) => value.quickEntryCategoryIcons.map(
      (key, value) =>
          MapEntry(key, IconData(value, fontFamily: 'MaterialIcons')),
    ),
    orElse: () => const {},
  );
});
