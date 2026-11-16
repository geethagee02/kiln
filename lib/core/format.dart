const seedStampIso = '2026-01-01T00:00:00.000Z';

String isoMillis(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  final year = utc.year.toString().padLeft(4, '0');
  final millisecond = utc.millisecond.toString().padLeft(3, '0');
  return '$year-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}.$millisecond'
      'Z';
}

DateTime parseIso(String value) => DateTime.parse(value).toUtc();

String formatPercent(double value) {
  final rounded = (value * 10).round() / 10;
  if ((rounded - rounded.roundToDouble()).abs() < 0.001) {
    return rounded.round().toString();
  }
  return rounded.toStringAsFixed(1);
}

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime mondayOf(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - 1));
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String weekdayName(DateTime day) => _weekdays[day.weekday - 1];

String weekdayShort(DateTime day) => _weekdayShort[day.weekday - 1];

String monthDay(DateTime day) => '${_months[day.month - 1]} ${day.day}';

String weekRangeLabel(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  if (monday.month == sunday.month) {
    return '${_months[monday.month - 1]} ${monday.day} – ${sunday.day}';
  }
  return '${monthDay(monday)} – ${monthDay(sunday)}';
}

String clockLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

String coneLabel(String min, String max) {
  if (min == max) return 'Cone $min';
  return 'Cone $min–$max';
}
