import 'package:hive/hive.dart';

import '../../domain/entities/income_entry.dart';

part 'income_entry_model.g.dart';

@HiveType(typeId: 2)
class IncomeEntryModel extends HiveObject {
  IncomeEntryModel({
    required this.id,
    required this.monthId,
    required this.source,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String monthId;

  @HiveField(2)
  String source;

  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String? note;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? updatedAt;

  IncomeEntry toDomain() {
    return IncomeEntry(
      id: id,
      monthId: monthId,
      source: source,
      amount: amount,
      date: date,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static IncomeEntryModel fromDomain(IncomeEntry entry) {
    return IncomeEntryModel(
      id: entry.id,
      monthId: entry.monthId,
      source: entry.source,
      amount: entry.amount,
      date: entry.date,
      note: entry.note,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monthId': monthId,
      'source': source,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static IncomeEntryModel fromMap(Map<String, dynamic> map) {
    return IncomeEntryModel(
      id: map['id'] as String,
      monthId: map['monthId'] as String,
      source: map['source'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}
