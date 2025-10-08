String monthIdFromDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

DateTime clampDate(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}
