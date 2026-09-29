/// How a stored course is written to users/{uid}: linked to the catalogue by
/// id, or whole as a custom entry (ARCHITECTURE.md §2, §5; step 3 of §9).
///
/// A course whose title and credits are the catalogue's is marked `linked`;
/// its title and credits are read from the catalogue when it is loaded, so a
/// published credit correction reaches it. Anything else — a course the
/// catalogue lacks, or one whose title or credits differ — is read as
/// stored, and nothing published changes it.
///
/// Title and credits are written either way: an older app still open on
/// some device reads every entry whole, and would fail on one without them.
library;

import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:hive/hive.dart';

/// The catalogue's title and credits for [id]: the newest chart row, else the
/// master list. Null for an id the catalogue has never had.
({String title, double credits})? catalogIdentity(String id, [Catalog? c]) =>
    _identities.of(c ?? catalog)[normalizeCourseId(id.trim())];

final _identities = PerCatalog((c) {
  final out = <String, ({String title, double credits})>{};
  for (final m in c.master) {
    out[normalizeCourseId(m.id)] = (title: m.title, credits: m.credits);
  }
  for (final r in [...c.chartOld, ...c.chartNew]) {
    out[normalizeCourseId(r.id)] = (title: r.title, credits: r.credits);
  }
  return out;
});

/// [c] as a users/{uid} entry, `linked` when its title and credits are the
/// catalogue's.
Map<String, dynamic> encodeCourse(Course c) {
  final identity = catalogIdentity(c.id);
  return {
    'id': c.id,
    'title': c.title,
    'credits': c.credits,
    if (identity?.title == c.title && identity?.credits == c.credits)
      'linked': true,
    'grade1': c.grade1,
    'grade2': c.grade2,
    'discipline': c.discipline,
    'sem': c.sem,
    'elective': c.elective,
    if (c.more.isNotEmpty)
      'more': {for (final e in c.more.entries) '${e.key}': e.value},
  };
}

/// A users/{uid} entry as a course. Reads every earlier shape: whole
/// entries, and linked ones written without title or credits.
Course decodeCourse(Map m) {
  final id = m['id'] as String;
  final identity = catalogIdentity(id);
  final linked = m['linked'] == true || !m.containsKey('title');
  return Course(
    title:
        (linked ? identity?.title : null) ??
        m['title'] as String? ??
        identity?.title ??
        id,
    id: id,
    credits:
        (linked ? identity?.credits : null) ??
        (m['credits'] as num?)?.toDouble() ??
        identity?.credits ??
        0,
    grade1: (m['grade1'] as num).toInt(),
    grade2: (m['grade2'] as num).toInt(),
    discipline: m['discipline'] as String,
    sem: m['sem'] as String,
    elective: m['elective'] as String? ?? 'CDC',
    more: {
      for (final e in Map<String, dynamic>.from(m['more'] ?? {}).entries)
        int.parse(e.key): (e.value as num).toInt(),
    },
  );
}

/// [c] under catalogue [next], when it was linked under [previous]: a title
/// or credit value that was the catalogue's follows the catalogue. Null when
/// nothing changes.
Course? relink(Course c, Catalog previous, Catalog next) {
  final was = catalogIdentity(c.id, previous);
  final now = catalogIdentity(c.id, next);
  if (was == null || now == null) return null;
  final title = c.title == was.title ? now.title : c.title;
  final credits = c.credits == was.credits ? now.credits : c.credits;
  if (title == c.title && credits == c.credits) return null;
  return Course(
    title: title,
    id: c.id,
    credits: credits,
    grade1: c.grade1,
    grade2: c.grade2,
    discipline: c.discipline,
    sem: c.sem,
    elective: c.elective,
    more: c.more,
  );
}

/// Moves every stored course that followed [previous] onto [next], under
/// its own key. Runs before the new bundle is cached, so a crash in between
/// leaves courses that already match [next] and are left alone next time.
Future<void> relinkStoredCourses(Catalog previous, Catalog next) async {
  for (final name in const ['coursesBox', 'offshootBox']) {
    if (!Hive.isBoxOpen(name)) continue;
    final box = Hive.box<Course>(name);
    await box.putAll({
      for (final e in box.toMap().entries)
        if (relink(e.value, previous, next) case final moved?) e.key: moved,
    });
  }
}
