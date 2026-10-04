/// The student's calendar choices (B8b): Hive box `calendar`, key
/// `profile.<index>`, a JSON string, never synced. The published timetable is
/// never edited; everything here is an override on top of it.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/timetable/timetable.dart';
import 'package:hive_ce/hive.dart';

/// A replacement day and minutes for one published slot.
typedef SlotEdit = ({int d, int s, int e});

/// A start and end (minutes) the student gave a date they entered in Marks.
typedef MarkTime = ({int s, int e});

/// The key of a Marks date's time: `<courseId>|<label>|<date>`.
String markKey(String courseId, String label, String date) => '$courseId|$label|$date';

/// One weekly time the student typed for a course the timetable lacks.
typedef OwnTime = ({int d, int s, int e, String room});

/// An event that belongs to no course.
class CalendarCustom {
  const CalendarCustom({
    required this.id,
    required this.title,
    required this.d,
    required this.s,
    required this.e,
    required this.from,
    this.room = '',
    this.until,
    this.once = false,
    this.course = '',
  });

  /// [course]: the catalogue course this belongs to (a course of the
  /// student's own timings), or '' for an event that belongs to none.
  final String id, title, room, from, course;
  final String? until;
  final int d, s, e;
  final bool once;

  static CalendarCustom fromJson(Map m) => CalendarCustom(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    d: (m['d'] as num).toInt(),
    s: (m['s'] as num).toInt(),
    e: (m['e'] as num).toInt(),
    room: m['room'] as String? ?? '',
    from: m['from'] as String,
    until: m['until'] as String?,
    once: m['once'] == true,
    course: m['course'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'd': d,
    's': s,
    'e': e,
    'room': room,
    'from': from,
    if (until != null) 'until': until,
    'once': once,
    if (course.isNotEmpty) 'course': course,
  };
}

class CalendarState {
  const CalendarState({
    this.campus = '',
    this.sem = '',
    this.picks = const {},
    this.slotOverrides = const {},
    this.repeatUntil = const {},
    this.removed = const {},
    this.examsOff = const {},
    this.custom = const [],
    this.markTimes = const {},
    this.autoFilled = false,
  });
  final String campus, sem;

  /// [markKey] -> the time the student gave that dated part from Marks.
  final Map<String, MarkTime> markTimes;

  /// The student's courses were put in once for this sem; removing them all
  /// later does not bring them back.
  final bool autoFilled;

  /// Course id -> section keys attended.
  final Map<String, List<String>> picks;

  /// Slot id (`<sectionKey>|<d>-<s>`) -> its replacement, every week.
  final Map<String, SlotEdit> slotOverrides;

  /// Course id -> last date, inclusive.
  final Map<String, String> repeatUntil;

  /// Hidden occurrences (`<slotId>|<date>`) and courses whose exams are off.
  final Set<String> removed, examsOff;
  final List<CalendarCustom> custom;

  CalendarState copy({
    String? campus,
    String? sem,
    Map<String, List<String>>? picks,
    Map<String, SlotEdit>? slotOverrides,
    Map<String, String>? repeatUntil,
    Set<String>? removed,
    Set<String>? examsOff,
    List<CalendarCustom>? custom,
    Map<String, MarkTime>? markTimes,
    bool? autoFilled,
  }) => CalendarState(
    campus: campus ?? this.campus,
    sem: sem ?? this.sem,
    picks: picks ?? this.picks,
    slotOverrides: slotOverrides ?? this.slotOverrides,
    repeatUntil: repeatUntil ?? this.repeatUntil,
    removed: removed ?? this.removed,
    examsOff: examsOff ?? this.examsOff,
    custom: custom ?? this.custom,
    markTimes: markTimes ?? this.markTimes,
    autoFilled: autoFilled ?? this.autoFilled,
  );

  static CalendarState fromJson(Map m) => CalendarState(
    campus: m['campus'] as String? ?? '',
    sem: m['sem'] as String? ?? '',
    picks: {
      for (final e in ((m['picks'] as Map?) ?? const {}).entries)
        '${e.key}': [for (final k in e.value as List) '$k'],
    },
    slotOverrides: {
      for (final e in ((m['slotOverrides'] as Map?) ?? const {}).entries)
        '${e.key}': (
          d: ((e.value as Map)['d'] as num).toInt(),
          s: ((e.value as Map)['s'] as num).toInt(),
          e: ((e.value as Map)['e'] as num).toInt(),
        ),
    },
    repeatUntil: {
      for (final e in ((m['repeatUntil'] as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    },
    removed: {
      for (final e in ((m['removed'] as Map?) ?? const {}).entries)
        if (e.value == true) '${e.key}',
    },
    examsOff: {
      for (final e in ((m['examsOff'] as Map?) ?? const {}).entries)
        if (e.value == true) '${e.key}',
    },
    custom: [
      for (final c in (m['custom'] as List?) ?? const [])
        CalendarCustom.fromJson(c as Map),
    ],
    markTimes: {
      for (final e in ((m['markTimes'] as Map?) ?? const {}).entries)
        '${e.key}': (
          s: ((e.value as Map)['s'] as num).toInt(),
          e: ((e.value as Map)['e'] as num).toInt(),
        ),
    },
    autoFilled: m['autoFilled'] == true,
  );

  Map<String, dynamic> toJson() => {
    'ver': 1,
    'campus': campus,
    'sem': sem,
    'picks': picks,
    'slotOverrides': {
      for (final e in slotOverrides.entries)
        e.key: {'d': e.value.d, 's': e.value.s, 'e': e.value.e},
    },
    'repeatUntil': repeatUntil,
    'removed': {for (final k in removed) k: true},
    'examsOff': {for (final k in examsOff) k: true},
    'custom': [for (final c in custom) c.toJson()],
    if (markTimes.isNotEmpty)
      'markTimes': {
        for (final e in markTimes.entries) e.key: {'s': e.value.s, 'e': e.value.e},
      },
    if (autoFilled) 'autoFilled': true,
  };
}

class CalendarStore {
  CalendarStore(this.box, {required this.profile}) {
    final raw = box.get(_key);
    if (raw is String) {
      try {
        _state = CalendarState.fromJson(jsonDecode(raw) as Map);
      } on Object {
        // A bad entry starts over rather than blocking the calendar.
      }
    }
  }

  final Box box;
  final int profile;
  CalendarState _state = const CalendarState();

  String get _key => 'profile.$profile';

  CalendarState get state => _state;

  Future<void> _save(CalendarState s) {
    _state = s;
    return box.put(_key, jsonEncode(s.toJson()));
  }

  /// Starts (or restarts) on [campus] and [sem]: a different sem drops the
  /// old picks and edits (the UI shows them as archived before it calls this).
  Future<void> adopt(String campus, String sem) =>
      (_state.campus == campus && _state.sem == sem)
          ? Future.value()
          : _save(CalendarState(campus: campus, sem: sem, custom: _state.custom, markTimes: _state.markTimes));

  bool _of(String course, String key) => key.startsWith('$course|');

  Future<void> addCourse(TtCourse c, List<String> sectionKeys) => _save(
    _state.copy(
      picks: {..._state.picks, c.id: List.of(sectionKeys)},
      slotOverrides: {
        for (final e in _state.slotOverrides.entries)
          if (!_of(c.id, e.key)) e.key: e.value,
      },
      removed: _state.removed.where((k) => !_of(c.id, k)).toSet(),
    ),
  );

  /// Moves every class of [oldKey]'s type in [courseId] to [newKey] (same type): the
  /// pick changes, the old section's own edits and hidden days go with it.
  Future<void> setSection(String courseId, String oldKey, String newKey) => _save(
    _state.copy(
      picks: {
        ..._state.picks,
        courseId: [for (final k in _state.picks[courseId] ?? const <String>[]) k == oldKey ? newKey : k],
      },
      slotOverrides: {
        for (final e in _state.slotOverrides.entries)
          if (!e.key.startsWith('$oldKey|')) e.key: e.value,
      },
      removed: _state.removed.where((k) => !k.startsWith('$oldKey|')).toSet(),
    ),
  );

  /// The first load of a sem: puts [picks] in (course id -> section keys),
  /// once. A student who already has picks keeps them; either way it does not
  /// run again, so removing every course later leaves the calendar empty.
  Future<void> autoFill(Map<String, List<String>> picks) =>
      _state.autoFilled
          ? Future.value()
          : _save(
            _state.copy(
              picks: _state.picks.isEmpty ? picks : _state.picks,
              autoFilled: true,
            ),
          );

  /// A course the timetable does not have: [times] weekly from [from] to
  /// [until], replacing any earlier ones for [courseId].
  Future<void> setOwnCourse(
    String courseId,
    String title,
    List<OwnTime> times, {
    required String from,
    required String until,
  }) async {
    for (final t in times) {
      _check((d: t.d, s: t.s, e: t.e));
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await _save(
      _state.copy(
        custom: [
          ..._state.custom.where((c) => c.course != courseId),
          for (final (i, t) in times.indexed)
            CalendarCustom(
              id: 'o$stamp$i',
              title: title,
              d: t.d,
              s: t.s,
              e: t.e,
              room: t.room,
              from: from,
              until: until,
              course: courseId,
            ),
        ],
      ),
    );
  }

  Future<void> removeCourse(String courseId) => _save(
    _state.copy(
      custom: _state.custom.where((c) => c.course != courseId).toList(),
      picks: {..._state.picks}..remove(courseId),
      slotOverrides: {
        for (final e in _state.slotOverrides.entries)
          if (!_of(courseId, e.key)) e.key: e.value,
      },
      repeatUntil: {..._state.repeatUntil}..remove(courseId),
      removed: _state.removed.where((k) => !_of(courseId, k)).toSet(),
      examsOff: {..._state.examsOff}..remove(courseId),
    ),
  );

  void _check(SlotEdit v) {
    if (v.e <= v.s) throw StateError('A slot must end after it starts');
  }

  Future<void> setSlotOverride(String slotId, {required int d, required int s, required int e}) =>
      setSlotOverrides({slotId: (d: d, s: s, e: e)});

  /// One write for a whole class sheet.
  Future<void> setSlotOverrides(Map<String, SlotEdit> edits) async {
    edits.values.forEach(_check);
    await _save(_state.copy(slotOverrides: {..._state.slotOverrides, ...edits}));
  }

  Future<void> resetSlot(String slotId) =>
      _save(_state.copy(slotOverrides: {..._state.slotOverrides}..remove(slotId)));

  Future<void> setRepeatUntil(String courseId, String date) =>
      _save(_state.copy(repeatUntil: {..._state.repeatUntil, courseId: date}));

  Future<void> removeOccurrence(String slotId, String date) =>
      _save(_state.copy(removed: {..._state.removed, '$slotId|$date'}));

  Future<void> setExamsShown(String courseId, bool shown) => _save(
    _state.copy(
      examsOff: shown
          ? (_state.examsOff.toSet()..remove(courseId))
          : {..._state.examsOff, courseId},
    ),
  );

  Future<void> addCustom(CalendarCustom e) => _save(
    _state.copy(custom: [..._state.custom.where((c) => c.id != e.id), e]),
  );

  /// A time for a dated part from Marks (see [markKey]); only on this device.
  Future<void> setMarkTime(String key, {required int s, required int e}) async {
    _check((d: 0, s: s, e: e));
    await _save(_state.copy(markTimes: {..._state.markTimes, key: (s: s, e: e)}));
  }

  Future<void> clearMarkTime(String key) =>
      _save(_state.copy(markTimes: {..._state.markTimes}..remove(key)));

  Future<void> removeCustom(String id) =>
      _save(_state.copy(custom: _state.custom.where((c) => c.id != id).toList()));
}
