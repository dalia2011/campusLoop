/// Date/time text for the UI.
///
/// The server stores UTC; the UI shows the device's local time zone. Every
/// function here converts with `toLocal()` so callers can pass model values
/// straight in. (No `intl` package needed for the short English formats the
/// designs use.)
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
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

String weekdayName(DateTime date) => _weekdays[date.toLocal().weekday - 1];

String _shortWeekday(DateTime local) =>
    _weekdays[local.weekday - 1].substring(0, 3);

/// "4:00 PM"
String formatTime(DateTime date) {
  final d = date.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "Fri 16 Oct"
String formatDay(DateTime date) {
  final d = date.toLocal();
  return '${_shortWeekday(d)} ${d.day} ${_months[d.month - 1]}';
}

/// "FRI 16 OCT · 4:00 PM" (small caps line on event cards)
String formatCardDate(DateTime date) =>
    '${formatDay(date).toUpperCase()} · ${formatTime(date)}';

/// "Fri 16 Oct · 4:00–6:00 PM". Handles ranges that cross AM/PM or midnight.
String formatEventRange(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  if (!sameDay) {
    return '${formatDay(s)}, ${formatTime(s)} – ${formatDay(e)}, ${formatTime(e)}';
  }
  final startText = formatTime(s);
  final endText = formatTime(e);
  final samePeriod = startText.endsWith(endText.substring(endText.length - 2));
  final shortStart = samePeriod
      ? startText.substring(0, startText.length - 3)
      : startText;
  return '${formatDay(s)} · $shortStart–$endText';
}

/// "15 Oct, 9:12 AM" (the "last synced" label on offline screens)
String formatSynced(DateTime date) {
  final d = date.toLocal();
  return '${d.day} ${_months[d.month - 1]}, ${formatTime(d)}';
}

/// "16 Oct" (filter chips for a custom date range)
String formatShortDate(DateTime date) {
  final d = date.toLocal();
  return '${d.day} ${_months[d.month - 1]}';
}
