import 'package:equatable/equatable.dart';

class IncomeEntry extends Equatable {
  const IncomeEntry({
    required this.id,
    required this.monthId,
    required this.source,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String monthId;
  final String source;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  IncomeEntry copyWith({
    String? id,
    String? monthId,
    String? source,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncomeEntry(
      id: id ?? this.id,
      monthId: monthId ?? this.monthId,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    monthId,
    source,
    amount,
    date,
    note,
    createdAt,
    updatedAt,
  ];
}
