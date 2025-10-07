import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/budget_providers.dart';
import '../../domain/providers/settings_providers.dart';
import 'backup_service.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('NotificationService must be provided at runtime');
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final budgetRepository = ref.watch(budgetRepositoryProvider);
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  return BackupService(
    budgetRepository: budgetRepository,
    settingsRepository: settingsRepository,
  );
});
