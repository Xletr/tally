import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/budget_month_model.dart';
import '../../data/models/budget_settings_model.dart';
import '../../data/models/expense_entry_model.dart';
import '../../data/models/income_entry_model.dart';
import '../../data/models/recurring_expense_model.dart';
import '../../domain/entities/budget_settings.dart';
import '../../domain/entities/expense_category.dart';

final appBootstrapProvider = Provider<AppBootstrap>((ref) {
  throw UnimplementedError('AppBootstrap has not been initialized');
});

class AppBootstrap {
  AppBootstrap();

  static const _encryptionKeyKey = 'tally_encryption_key';
  static const _settingsKey = 'budget_settings';
  static const _storage = FlutterSecureStorage();

  HiveAesCipher? _cipher;
  static bool _adaptersRegistered = false;

  late final Box<BudgetMonthModel> monthsBox;
  late final Box<IncomeEntryModel> incomesBox;
  late final Box<ExpenseEntryModel> expensesBox;
  late final Box<RecurringExpenseModel> recurringBox;
  late final Box<BudgetSettingsModel> settingsBox;

  HiveAesCipher get cipher {
    final cipher = _cipher;
    if (cipher == null) {
      throw StateError('Cipher accessed before initialization');
    }
    return cipher;
  }

  Future<void> initialize() async {
    await Hive.initFlutter();
    _registerAdapters();
    await _ensureCipher();
    monthsBox = await Hive.openBox<BudgetMonthModel>(
      'budget_months',
      encryptionCipher: cipher,
    );
    incomesBox = await Hive.openBox<IncomeEntryModel>(
      'income_entries',
      encryptionCipher: cipher,
    );
    expensesBox = await Hive.openBox<ExpenseEntryModel>(
      'expense_entries',
      encryptionCipher: cipher,
    );
    recurringBox = await Hive.openBox<RecurringExpenseModel>(
      'recurring_expenses',
      encryptionCipher: cipher,
    );
    settingsBox = await Hive.openBox<BudgetSettingsModel>(
      'budget_settings',
      encryptionCipher: cipher,
    );
    await _ensureDefaultSettings();
  }

  Future<void> dispose() async {
    await Hive.close();
  }

  BudgetSettingsModel get activeSettingsModel {
    final model = settingsBox.get(_settingsKey);
    if (model != null) {
      return model;
    }
    final fallback = BudgetSettingsModel.fromDomain(BudgetSettings());
    settingsBox.put(_settingsKey, fallback);
    return fallback;
  }

  Future<void> saveSettingsModel(BudgetSettingsModel model) async {
    await settingsBox.put(_settingsKey, model);
  }

  Stream<BudgetSettingsModel> watchSettingsModel() async* {
    yield activeSettingsModel;
    yield* settingsBox.watch(key: _settingsKey).map((_) => activeSettingsModel);
  }

  void _registerAdapters() {
    if (_adaptersRegistered) {
      return;
    }
    Hive
      ..registerAdapter(ExpenseCategoryAdapter())
      ..registerAdapter(BudgetMonthModelAdapter())
      ..registerAdapter(IncomeEntryModelAdapter())
      ..registerAdapter(ExpenseEntryModelAdapter())
      ..registerAdapter(RecurringExpenseModelAdapter())
      ..registerAdapter(BudgetSettingsModelAdapter());
    _adaptersRegistered = true;
  }

  Future<void> _ensureCipher() async {
    final existing = await _storage.read(key: _encryptionKeyKey);
    if (existing != null) {
      _cipher = HiveAesCipher(base64Decode(existing));
      return;
    }
    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final encoded = base64Encode(key);
    await _storage.write(key: _encryptionKeyKey, value: encoded);
    _cipher = HiveAesCipher(key);
  }

  Future<void> _ensureDefaultSettings() async {
    if (!settingsBox.containsKey(_settingsKey)) {
      await settingsBox.put(
        _settingsKey,
        BudgetSettingsModel.fromDomain(BudgetSettings()),
      );
    }
  }
}
