import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/settings_repository.dart';

class BackupService {
  BackupService({
    required BudgetRepository budgetRepository,
    required SettingsRepository settingsRepository,
  }) : _budgetRepository = budgetRepository,
       _settingsRepository = settingsRepository;

  final BudgetRepository _budgetRepository;
  final SettingsRepository _settingsRepository;

  Future<File?> exportData() async {
    final data = await _budgetRepository.exportData();
    final json = const JsonEncoder.withIndent('  ').convert(data);

    var directoryPath = await FilePicker.platform.getDirectoryPath();
    directoryPath ??= (await getApplicationDocumentsDirectory()).path;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filePath = '$directoryPath/tally-backup-$timestamp.json';
    final file = File(filePath);
    await file.writeAsString(json);

    final settings = await _settingsRepository.load();
    await _settingsRepository.save(
      settings.copyWith(lastBackupAt: DateTime.now()),
    );

    return file;
  }

  Future<void> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final content = utf8.decode(bytes);
    final data = jsonDecode(content) as Map<String, dynamic>;
    await _budgetRepository.importData(data);
  }
}
