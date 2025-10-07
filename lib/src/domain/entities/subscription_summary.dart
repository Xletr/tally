import 'package:equatable/equatable.dart';

import 'recurring_expense.dart';

class SubscriptionSummary extends Equatable {
  const SubscriptionSummary({
    required this.template,
    required this.lifetimeSpent,
    required this.chargeCount,
    required this.lastChargedAt,
  });

  final RecurringExpense template;
  final double lifetimeSpent;
  final int chargeCount;
  final DateTime? lastChargedAt;

  double get averageMonthlyCost => template.amount;

  @override
  List<Object?> get props => [
    template,
    lifetimeSpent,
    chargeCount,
    lastChargedAt,
  ];
}
