// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BudgetSettingsModelAdapter extends TypeAdapter<BudgetSettingsModel> {
  @override
  final int typeId = 5;

  @override
  BudgetSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetSettingsModel(
      themeModeIndex: fields[0] as int,
      dynamicColorEnabled: fields[1] as bool,
      highContrast: fields[2] as bool,
      autoRollover: fields[3] as bool,
      notificationsEnabled: fields[4] as bool,
      midMonthReminder: fields[5] as bool,
      endOfMonthReminder: fields[6] as bool,
      overspendAlerts: fields[7] as bool,
      defaultSavingsRate: fields[8] as double,
      lastBackupAt: fields[9] as DateTime?,
      quickEntryPresets: (fields[10] as List).cast<double>(),
      onboardingCompleted: fields[11] as bool,
      defaultMonthlyAllowance: fields[12] as double,
      categoryQuickEntryPresets: (fields[13] as Map?)?.map(
        (dynamic k, dynamic v) =>
            MapEntry(k as String, (v as List).cast<double>()),
      ),
      monthlySavingsGoal: fields[14] as double,
      midReminderMinutes: fields[15] as int,
      endReminderMinutes: fields[16] as int,
      quickEntryCategoryIcons:
          (fields[17] as Map?)?.map(
            (dynamic k, dynamic v) => MapEntry(k as String, v as int),
          ) ??
          const <String, int>{},
      savingsQuickEntryPresets:
          (fields[18] as List?)?.cast<double>() ?? const <double>[],
    );
  }

  @override
  void write(BinaryWriter writer, BudgetSettingsModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.themeModeIndex)
      ..writeByte(1)
      ..write(obj.dynamicColorEnabled)
      ..writeByte(2)
      ..write(obj.highContrast)
      ..writeByte(3)
      ..write(obj.autoRollover)
      ..writeByte(4)
      ..write(obj.notificationsEnabled)
      ..writeByte(5)
      ..write(obj.midMonthReminder)
      ..writeByte(6)
      ..write(obj.endOfMonthReminder)
      ..writeByte(7)
      ..write(obj.overspendAlerts)
      ..writeByte(8)
      ..write(obj.defaultSavingsRate)
      ..writeByte(9)
      ..write(obj.lastBackupAt)
      ..writeByte(10)
      ..write(obj.quickEntryPresets)
      ..writeByte(11)
      ..write(obj.onboardingCompleted)
      ..writeByte(12)
      ..write(obj.defaultMonthlyAllowance)
      ..writeByte(13)
      ..write(obj.categoryQuickEntryPresets)
      ..writeByte(14)
      ..write(obj.monthlySavingsGoal)
      ..writeByte(15)
      ..write(obj.midReminderMinutes)
      ..writeByte(16)
      ..write(obj.endReminderMinutes)
      ..writeByte(17)
      ..write(obj.quickEntryCategoryIcons)
      ..writeByte(18)
      ..write(obj.savingsQuickEntryPresets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
