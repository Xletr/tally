import '../entities/budget_settings.dart';

abstract class SettingsRepository {
  Future<BudgetSettings> load();

  Stream<BudgetSettings> watch();

  Future<void> save(BudgetSettings settings);
}
