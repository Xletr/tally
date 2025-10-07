import 'package:hive/hive.dart';

part 'expense_category.g.dart';

@HiveType(typeId: 0)
enum ExpenseCategory {
  @HiveField(0)
  food,
  @HiveField(1)
  transport,
  @HiveField(2)
  subscriptions,
  @HiveField(3)
  purchases,
  @HiveField(4)
  misc,
  @HiveField(5)
  savings,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.subscriptions:
        return 'Subscriptions';
      case ExpenseCategory.purchases:
        return 'Purchases';
      case ExpenseCategory.misc:
        return 'Misc';
      case ExpenseCategory.savings:
        return 'Savings';
    }
  }

  String get analyticsKey => name;
}
