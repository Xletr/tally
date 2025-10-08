import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
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
    final bytes = Uint8List.fromList(utf8.encode(json));

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final defaultName = 'tally-backup-$timestamp.json';

    final docsDir = await getApplicationDocumentsDirectory();
    final filePath = '${docsDir.path}/$defaultName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    String? destination;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        destination = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(
            sourceFilePath: file.path,
            fileName: defaultName,
            mimeTypesFilter: const ['application/json'],
          ),
        );
      } catch (_) {
        destination = null;
      }
    } else {
      try {
        destination = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Tally backup',
          fileName: defaultName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: bytes,
        );
      } catch (_) {
        destination = null;
      }
    }

    if (destination == null || destination.isEmpty) {
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }

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
