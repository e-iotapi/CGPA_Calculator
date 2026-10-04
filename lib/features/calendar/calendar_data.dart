/// What the Calendar reads: the broadcast timetable's store and the student's
/// device-only overrides in the lazily opened Hive box `calendar`.
library;

import 'package:cgpa_calculator/core/heads/heads_client.dart';
import 'package:cgpa_calculator/core/roles/session.dart';
import 'package:cgpa_calculator/core/timetable/calendar_store.dart';
import 'package:cgpa_calculator/core/timetable/occurrences.dart';
import 'package:cgpa_calculator/core/timetable/timetable_store.dart';
import 'package:hive_ce/hive.dart';

const calendarBoxName = 'calendar';

/// Device-only switch: show the campus academic dates in Pointer.
const _showAcademicKey = 'showAcademic';

/// The signed-in student's timetable store, or null before sign-in. The
/// Worker is read first when POINTER_HEADS_URL is set; the store falls back to
/// Firestore itself.
TimetableStore? get timetableStore => switch (roleStore) {
  final r? => TimetableStore(r.db, workerBase: headsUrl),
  null => null,
};

/// Opens the calendar box (never before the first frame: only the Calendar
/// and Settings call this) and reads [profile]'s overrides.
Future<CalendarStore> openCalendarStore(int profile) async => CalendarStore(
  Hive.isBoxOpen(calendarBoxName)
      ? Hive.box(calendarBoxName)
      : await Hive.openBox(calendarBoxName),
  profile: profile,
);

/// The same, when the box is already open; null otherwise.
CalendarStore? peekCalendarStore(int profile) =>
    Hive.isBoxOpen(calendarBoxName)
        ? CalendarStore(Hive.box(calendarBoxName), profile: profile)
        : null;

bool showAcademic(CalendarStore s) =>
    s.box.get(_showAcademicKey, defaultValue: true) != false;

Future<void> setShowAcademic(CalendarStore s, bool on) =>
    s.box.put(_showAcademicKey, on);

/// The slot an occurrence came from: its id without the trailing `|<date>`.
String slotOf(Occurrence o) => o.id.substring(0, o.id.length - 11);
