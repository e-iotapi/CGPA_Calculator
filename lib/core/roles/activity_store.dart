import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// When staff last made a meaningful edit, per course and department
/// (Last updated, B4): `activity/<campus>`, epoch ms.
class Activity {
  const Activity({this.course = const {}, this.dept = const {}});

  final Map<String, int> course, dept;

  int? ofCourse(String id) => course[id];
  int? ofDept(String d) => dept[d];

  Map<String, Object?> toJson() => {'course': course, 'dept': dept};

  static Map<String, int> _ms(Object? m) => {
    if (m is Map)
      for (final e in m.entries)
        if (_toMs(e.value) case final int v) '${e.key}': v,
  };

  static int? _toMs(Object? v) => switch (v) {
    Timestamp t => t.millisecondsSinceEpoch,
    num n => n.toInt(),
    _ => null,
  };

  factory Activity.fromMap(Map<String, Object?>? m) =>
      Activity(course: _ms(m?['course']), dept: _ms(m?['dept']));
}

class ActivityStore {
  ActivityStore(this.db);

  final FirebaseFirestore db;

  String _key(String campus) => 'act|$campus';

  /// Not a marker: a plain age keeps it one read per 10 minutes.
  Future<Activity> of(String campus) => cacheFirst<Activity>(
    key: _key(campus),
    maxAge: const Duration(minutes: 10),
    fetch: () async =>
        Activity.fromMap((await db.collection('activity').doc(campus).get())
            .data()),
    encode: (a) => a.toJson(),
    decode: (j) => Activity.fromMap((j as Map).cast<String, Object?>()),
  );

  Activity? peekOf(String campus) => peekCache<Activity>(
    _key(campus),
    (j) => Activity.fromMap((j as Map).cast<String, Object?>()),
  );

  /// Stamps [courseId] and/or [dept] with the server time in [b]. Call from
  /// staff edits only (resources, structures, professors).
  static void touch(
    WriteBatch b,
    FirebaseFirestore db,
    String campus, {
    String? courseId,
    String? dept,
  }) {
    b.set(db.collection('activity').doc(campus), {
      if (courseId != null) 'course': {courseId: FieldValue.serverTimestamp()},
      if (dept != null) 'dept': {dept: FieldValue.serverTimestamp()},
      'c': courseId ?? '',
      'd': dept ?? '',
    }, SetOptions(merge: true));
  }
}

/// Whole academic semesters between [tsMs] and [now]: Aug–Dec is semester 1,
/// Jan–May semester 2, Jun–Jul summer; 0 is this semester.
int semestersAgo(int tsMs, DateTime now) {
  int index(DateTime d) {
    final m = d.month;
    final slot = m >= 8 ? 0 : (m <= 5 ? 1 : 2);
    final year = m >= 8 ? d.year : d.year - 1;
    return year * 3 + slot;
  }

  final n = index(now) - index(DateTime.fromMillisecondsSinceEpoch(tsMs));
  return n < 0 ? 0 : n;
}

/// Stale: never updated, or two or more semesters ago.
bool isStale(int? tsMs, DateTime now) =>
    tsMs == null || semestersAgo(tsMs, now) >= 2;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Updated Aug 2026", "2 semesters ago", or "Not updated yet".
String updatedLabel(int? tsMs, DateTime now) {
  if (tsMs == null) return 'Not updated yet';
  final n = semestersAgo(tsMs, now);
  if (n >= 2) return '$n semesters ago';
  final d = DateTime.fromMillisecondsSinceEpoch(tsMs);
  return 'Updated ${_months[d.month - 1]} ${d.year}';
}
