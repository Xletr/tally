import 'package:intl/intl.dart';

final NumberFormat _compactCurrency = NumberFormat.compactCurrency(
  symbol: "\$",
  decimalDigits: 0,
);
final NumberFormat _detailedCurrency = NumberFormat.currency(
  symbol: "\$",
  decimalDigits: 2,
);
final DateFormat _monthFormat = DateFormat('MMMM yyyy');
final DateFormat _monthShortFormat = DateFormat('MMM yyyy');

String formatCurrency(double value, {bool compact = false}) {
  if (compact) {
    return _compactCurrency.format(value);
  }
  return _detailedCurrency.format(value);
}

String formatPlainCurrency(double value) => _detailedCurrency.format(value);

String formatMonth(DateTime date) => _monthFormat.format(date);

String formatMonthShort(DateTime date) => _monthShortFormat.format(date);

String formatPercentage(double value, {int decimals = 0}) =>
    '${value.toStringAsFixed(decimals)}%';

String formatDay(DateTime date) => DateFormat.MMMd().format(date);
