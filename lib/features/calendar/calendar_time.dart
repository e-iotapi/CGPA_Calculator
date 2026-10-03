/// Date and clock helpers for the calendar views. Dates are `YYYY-MM-DD`
/// strings (the broadcast's own form), times are minutes since midnight.
library;

import 'package:cgpa_calculator/core/timetable/timetable.dart';

const dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Mon" for ISO weekday [d] (1 = Monday).
String dayShort(int d) => dayNames[d - 1].substring(0, 3);

String _two(int n) => n.toString().padLeft(2, '0');

/// A local date-time's day as `YYYY-MM-DD`.
String dayStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String addDays(String date, int n) =>
    fmtDate(parseDate(date).add(Duration(days: n)));

/// The Monday of [date]'s week.
String mondayOf(String date) => addDays(date, 1 - parseDate(date).weekday);

/// "Mon 5 Oct".
String dateLabel(String date) {
  final d = parseDate(date);
  return '${dayShort(d.weekday)} ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';
}

/// "9:00 AM". 1440 reads as midnight.
String clock(int m) {
  final h = (m ~/ 60) % 24;
  return '${h % 12 == 0 ? 12 : h % 12}:${_two(m % 60)} ${h < 12 ? 'AM' : 'PM'}';
}

/// "9:00" (12-hour, no suffix): for blocks too small for AM/PM.
String clockShort(int m) {
  final h = (m ~/ 60) % 24;
  return '${h % 12 == 0 ? 12 : h % 12}:${_two(m % 60)}';
}

/// "9:00 AM – 10:00 AM".
String span(int s, int e) => '${clock(s)} – ${clock(e)}';

/// "8 AM", "12 PM" for the time axis.
String hourLabel(int h) => '${h % 12 == 0 ? 12 : h % 12} ${h % 24 < 12 ? 'AM' : 'PM'}';

/// Minutes since midnight from what a student types: "9", "9:30", "9:30 pm",
/// "14:00". Without am/pm an hour below 8 is read as afternoon (classes run
/// from 8). Null when it is not a time.
int? parseClock(String raw) {
  final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([ap])?m?$', caseSensitive: false)
      .firstMatch(raw.trim());
  if (m == null) return null;
  var h = int.parse(m[1]!);
  final min = int.tryParse(m[2] ?? '0')!;
  if (min > 59) return null;
  final suffix = m[3]?.toLowerCase();
  if (suffix != null) {
    if (h < 1 || h > 12) return null;
    h = h % 12 + (suffix == 'p' ? 12 : 0);
  } else {
    if (h > 23) return null;
    if (h >= 1 && h < 8) h += 12;
  }
  return h * 60 + min;
}
