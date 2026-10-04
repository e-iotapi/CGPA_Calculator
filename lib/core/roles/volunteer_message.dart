/// The two messages a president copies for a course's WhatsApp group when
/// students volunteer as CR (ARCHITECTURE.md §16.3 fix 16). Verbatim;
/// Pointer sends nothing and records nothing.
library;

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

/// Three days ahead at 6:00 PM.
DateTime defaultDeadline(DateTime now) =>
    DateTime(now.year, now.month, now.day + 3, 18);

/// "6:00 PM on Wednesday, 30 September 2026".
String deadlineText(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'} on ${_weekdays[d.weekday - 1]}, '
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// The message for [volunteers] (their names) on [courseCode]: an election
/// for several, an objection notice for one.
String volunteerMessage({
  required String courseCode,
  required String courseTitle,
  required List<String> volunteers,
  required String deadline,
  required String presidentName,
  required String departmentName,
  required String deptKey,
  required String campusName,
}) {
  final sign =
      'Regards,\n'
      '$presidentName\n'
      'Department President, $departmentName ($deptKey), $campusName';
  if (volunteers.length == 1) {
    final v = volunteers.single;
    return 'Dear students of $courseCode $courseTitle,\n\n'
        'The course does not have a Class Representative at present. $v has '
        'volunteered for the role.\n\n'
        'Unless an objection is received by $deadline, $v will be appointed '
        'as the Class Representative for $courseCode. Should you have an '
        'objection, please write to me directly before that time.\n\n'
        '$sign';
  }
  final list = [
    for (final (i, v) in volunteers.indexed) '${i + 1}. $v',
  ].join('\n');
  return 'Dear students of $courseCode $courseTitle,\n\n'
      'The course does not have a Class Representative at present. The '
      'following students have volunteered for the role:\n\n'
      '$list\n\n'
      'The Class Representative will be chosen by election. A poll will '
      'follow this message; kindly cast your vote by $deadline. Should you '
      'have an objection to any candidate, please write to me directly before '
      'that time.\n\n'
      'The result will be announced in this group.\n\n'
      '$sign';
}
