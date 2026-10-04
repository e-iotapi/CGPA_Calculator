// Synthetic timetable data and in-memory stand-ins for the calendar tests.
// Invented courses only (never from the published PDF).

import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:cgpa_calculator/core/timetable/timetable_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_ce/hive.dart';

/// A box that lives in memory: UI-triggered Hive writes stall under fake time.
class MemBox implements Box {
  final data = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      data.containsKey(key) ? data[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => data[key] = value;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Serves [t] as the published timetable; [fail] makes a load throw.
class FakeTimetableStore implements TimetableStore {
  FakeTimetableStore(this.t, {this.fail = false, this.peek = true});
  Timetable? t;
  bool fail, peek;
  int loads = 0;

  @override
  Future<Timetable?> current(String campus) async {
    loads++;
    if (fail) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return t;
  }

  @override
  Timetable? peekCurrent(String campus) => peek ? t : null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Two courses, one holiday, one deadline, a term span (Aug 3 to Nov 28).
Timetable fakeTimetable() => Timetable.fromJson({
  'v': 1,
  'campus': 'goa',
  'sem': '2026-1',
  'publishedAt': 1790000000000,
  'marker': 1,
  'hours': {
    '1': [480, 540],
  },
  'examSlots': {
    'FN': [570, 750],
  },
  'events': [
    {'from': '2026-08-03', 'title': 'Instruction begins', 'kind': 'term'},
    {'from': '2026-09-22', 'title': 'Fees due', 'kind': 'deadline'},
    {'from': '2026-09-24', 'title': 'Founders day', 'kind': 'holiday'},
    {'from': '2026-10-12', 'to': '2026-10-17', 'title': 'Midsem exams', 'kind': 'exam'},
    {'from': '2026-11-28', 'title': 'Last day of classes', 'kind': 'term'},
  ],
  'courses': {
    'AAA F111': {
      't': 'Intro Widgets',
      'cr': 4,
      'sec': [
        {
          'ty': 'L',
          'no': 1,
          'prof': ['A Teacher'],
          'room': 'F101',
          'slots': [
            {'d': 1, 's': 540, 'e': 600},
            {'d': 3, 's': 540, 'e': 600},
            {'d': 5, 's': 540, 'e': 600},
          ],
        },
        {
          'ty': 'T',
          'no': 1,
          'prof': <String>[],
          'slots': [
            {'d': 4, 's': 660, 'e': 720},
          ],
        },
      ],
      'mid': {'d': '2026-10-12', 's': 570, 'e': 660},
      'compre': {'d': '2026-12-10', 'slot': 'FN', 's': 570, 'e': 750},
    },
    'CCC F311': {
      't': 'Gadget Design',
      'sec': [
        {
          'ty': 'L',
          'no': 1,
          'prof': <String>[],
          'room': 'G12',
          'slots': [
            {'d': 2, 's': 840, 'e': 900},
          ],
        },
      ],
    },
  },
});
