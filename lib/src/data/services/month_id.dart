String buildMonthId(DateTime date) {
  final normalized = DateTime(date.year, date.month);
  return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}';
}

DateTime parseMonthId(String id) {
  final parts = id.split('-');
  if (parts.length != 2) {
    throw FormatException('Invalid month id: $id');
  }
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  return DateTime(year, month);
}
