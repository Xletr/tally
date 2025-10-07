import 'package:flutter/material.dart';

import '../../domain/entities/expense_category.dart';

IconData categoryIcon(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.food:
      return Icons.restaurant_rounded;
    case ExpenseCategory.transport:
      return Icons.directions_bus_rounded;
    case ExpenseCategory.subscriptions:
      return Icons.subscriptions_rounded;
    case ExpenseCategory.purchases:
      return Icons.shopping_bag_rounded;
    case ExpenseCategory.misc:
      return Icons.scatter_plot_rounded;
    case ExpenseCategory.savings:
      return Icons.savings_rounded;
  }
}
