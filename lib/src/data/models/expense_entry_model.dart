import 'package:hive/hive.dart';

import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entry.dart';

part 'expense_entry_model.g.dart';

@HiveType(typeId: 3)
class ExpenseEntryModel extends HiveObject {
  ExpenseEntryModel({
    required this.id,
    required this.monthId,
    required this.category,
    required this.amount,
    required this.date,
    this.isRecurring = false,
    this.recurringTemplateId,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String monthId;

  @HiveField(2)
  ExpenseCategory category;

  @HiveField(3)
  double amount;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  bool isRecurring;

  @HiveField(6)
  String? recurringTemplateId;

  @HiveField(7)
  String? note;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? updatedAt;

  ExpenseEntry toDomain() {
    return ExpenseEntry(
      id: id,
      monthId: monthId,
      category: category,
      amount: amount,
      date: date,
      isRecurring: isRecurring,
      recurringTemplateId: recurringTemplateId,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ExpenseEntryModel fromDomain(ExpenseEntry entry) {
    return ExpenseEntryModel(
      id: entry.id,
      monthId: entry.monthId,
      category: entry.category,
      amount: entry.amount,
      date: entry.date,
      isRecurring: entry.isRecurring,
      recurringTemplateId: entry.recurringTemplateId,
      note: entry.note,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monthId': monthId,
      'category': category.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'isRecurring': isRecurring,
      'recurringTemplateId': recurringTemplateId,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static ExpenseEntryModel fromMap(Map<String, dynamic> map) {
    return ExpenseEntryModel(
      id: map['id'] as String,
      monthId: map['monthId'] as String,
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ExpenseCategory.misc,
      ),
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      isRecurring: map['isRecurring'] as bool? ?? false,
      recurringTemplateId: map['recurringTemplateId'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}
