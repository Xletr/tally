import '../../core/bootstrap/bootstrap.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/budget_settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._bootstrap);

  final AppBootstrap _bootstrap;

  @override
  Future<BudgetSettings> load() async {
    return _bootstrap.activeSettingsModel.toDomain();
  }

  @override
  Stream<BudgetSettings> watch() {
    return _bootstrap.watchSettingsModel().map((model) => model.toDomain());
  }

  @override
  Future<void> save(BudgetSettings settings) async {
    final model = BudgetSettingsModel.fromDomain(settings);
    await _bootstrap.saveSettingsModel(model);
  }
}
