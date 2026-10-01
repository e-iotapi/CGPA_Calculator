/// Draft → live (ARCHITECTURE.md §2, §11). Course identity edits wait in
/// `courses/{id}` until an owner reads the diff — stated in CGPA terms — and
/// presses Publish, which writes the next `catalog/v{n}` and moves the marker.
library;

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/catalog/catalog.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A draft edit to one course's identity. Ids never change (§2): a corrected
/// code is a new course plus a retirement.
class CourseEdit {
  const CourseEdit({
    required this.id,
    this.title,
    this.credits,
    this.retired,
    this.elective,
  });

  /// The course id.
  final String id;

  /// The new title, if changed.
  final String? title;

  /// The new credits, if changed.
  final double? credits;

  /// Whether the course is retired, if changed.
  final bool? retired;

  /// The default elective tag on chart rows.
  final String? elective;

  /// Serialises the edit, leaving out unchanged fields.
  Map<String, dynamic> toMap() => {
    'id': id,
    if (title != null) 'title': title,
    if (credits != null) 'credits': credits,
    if (retired != null) 'retired': retired,
    if (elective != null) 'elective': elective,
  };

  /// Reads an edit from its [toMap] form.
  static CourseEdit fromMap(Map m) => CourseEdit(
    id: m['id'] as String,
    title: m['title'] as String?,
    credits: (m['credits'] as num?)?.toDouble(),
    retired: m['retired'] as bool?,
    elective: m['elective'] as String?,
  );
}

/// [live] with [edits] applied, as the next version. A new id needs a title
/// and credits; it joins the list Add a course searches.
Catalog applyEdits(Catalog live, Iterable<CourseEdit> edits) {
  final byId = {for (final e in edits) e.id: e};
  Course row(Course c) {
    final e = byId[c.id];
    if (e == null) return c;
    return Course(
      id: c.id,
      title: e.title ?? c.title,
      credits: e.credits ?? c.credits,
      sem: c.sem,
      discipline: c.discipline,
      elective: e.elective ?? c.elective,
      grade1: c.grade1,
      grade2: c.grade2,
    );
  }

  final master = [
    for (final m in live.master)
      if (byId[m.id] case final e?)
        Mastercourselist(
          id: m.id,
          title: e.title ?? m.title,
          credits: e.credits ?? m.credits,
        )
      else
        m,
  ];
  final have = {for (final m in master) m.id};
  for (final e in byId.values) {
    if (!have.contains(e.id) && e.title != null && e.credits != null) {
      master.add(
        Mastercourselist(id: e.id, title: e.title!, credits: e.credits!),
      );
    }
  }
  return Catalog(
    version: live.version + 1,
    chartOld: [for (final c in live.chartOld) row(c)],
    chartNew: [for (final c in live.chartNew) row(c)],
    master: master,
    retired: {
      for (final id in live.retired)
        if (byId[id]?.retired != false) id,
      for (final e in byId.values)
        if (e.retired == true) e.id,
    },
  );
}

final _codeShape = RegExp(r'^[A-Z]{2,6} [A-Z0-9]{3,6}$');

/// Why a brand new course's draft can't be saved, or null when it is fine
/// (BUG-48: negative credits and a made-up department went straight
/// through). An existing course's code, department and credit range are
/// already real, so only a new id is checked.
String? newCourseError(String code, double credits, Catalog live) {
  if (!_codeShape.hasMatch(code)) return 'Course codes look like "CS F211".';
  final dept = code.split(' ').first;
  if (!live.master.any((c) => c.id.split(' ').first == dept)) {
    return '"$dept" is not a department Pointer knows.';
  }
  if (credits < 0.5 || credits > 25) {
    return 'Credits must be between 0.5 and 25.';
  }
  return null;
}

/// A course whose credits move from `from` to `to`.
typedef CreditChange = ({String id, String title, double from, double to});

/// A course and a phrase saying what happens to it.
typedef CourseLine = ({String id, String title, String what});

/// What a publish changes, in the order the owner reads it (§11): credits
/// first — they move CGPAs — then retirements, then the cosmetic rest.
class CatalogDiff {
  const CatalogDiff({
    required this.credits,
    required this.retired,
    required this.added,
    required this.cosmetic,
  });

  /// Courses whose credits change.
  final List<CreditChange> credits;

  /// Courses being retired.
  final List<CourseLine> retired;

  /// Brand new course ids (BUG-48/52: not a cosmetic change).
  final List<CourseLine> added;

  /// Titles, default tags and restored ones.
  final List<CourseLine> cosmetic;

  /// The total number of changes.
  int get count =>
      credits.length + retired.length + added.length + cosmetic.length;

  /// Whether nothing changes.
  bool get isEmpty => count == 0;
}

/// Lists what publishing [next] over [live] changes.
CatalogDiff diffCatalog(Catalog live, Catalog next) {
  final a = {for (final m in live.master) m.id: m};
  final b = {for (final m in next.master) m.id: m};
  final tagsA = {
    for (final c in [...live.chartOld, ...live.chartNew]) c.id: c.elective,
  };
  final tagsB = {
    for (final c in [...next.chartOld, ...next.chartNew]) c.id: c.elective,
  };
  final credits = <CreditChange>[];
  final added = <CourseLine>[];
  final cosmetic = <CourseLine>[];
  for (final m in b.values) {
    final old = a[m.id];
    if (old == null) {
      added.add((id: m.id, title: m.title, what: 'New course'));
      continue;
    }
    if (old.credits != m.credits) {
      credits.add((id: m.id, title: m.title, from: old.credits, to: m.credits));
    }
    if (old.title != m.title) {
      cosmetic.add((
        id: m.id,
        title: m.title,
        what: 'Title “${old.title}” → “${m.title}”',
      ));
    }
  }
  for (final id in tagsB.keys) {
    if (tagsA[id] case final t? when t != tagsB[id]) {
      cosmetic.add((
        id: id,
        title: b[id]?.title ?? id,
        what:
            'Default tag ${t.isEmpty ? '—' : t} → '
            '${tagsB[id]!.isEmpty ? '—' : tagsB[id]}',
      ));
    }
  }
  final retired = [
    for (final id in next.retired.difference(live.retired).toList()..sort())
      (id: id, title: b[id]?.title ?? id, what: 'Retired'),
  ];
  for (final id in live.retired.difference(next.retired)) {
    cosmetic.add((id: id, title: b[id]?.title ?? id, what: 'Back on offer'));
  }
  credits.sort((x, y) => x.id.compareTo(y.id));
  added.sort((x, y) => x.id.compareTo(y.id));
  cosmetic.sort((x, y) => x.id.compareTo(y.id));
  return CatalogDiff(
    credits: credits,
    retired: retired,
    added: added,
    cosmetic: cosmetic,
  );
}

/// `courses/{id}` drafts and the live bundle, for the owner's Publish page.
class CatalogStore {
  CatalogStore(this.roles);
  /// The store whose identity and audit log the writes use.
  final RoleStore roles;
  FirebaseFirestore get _db => roles.db;

  /// Reads the draft edits, one query.
  Future<List<CourseEdit>> drafts() async {
    final q =
        await _db.collection('courses').where('draft', isEqualTo: true).get();
    return [for (final d in q.docs) CourseEdit.fromMap(d.data())];
  }

  /// Saves [e] as a draft; nothing reaches students until Publish.
  Future<void> saveDraft(CourseEdit e, {required String campus}) async {
    final b = _db.batch();
    final id = roles.logInto(
      b,
      path: 'courses/${e.id}',
      summary: 'Drafted a catalogue change to ${e.id}',
      campus: campus,
      course: e.id,
      after: e.toMap(),
    );
    b.set(_db.collection('courses').doc(e.id), {
      ...e.toMap(),
      'draft': true,
      'auditId': id,
      'updatedBy': {'email': roles.me, 'name': roles.myName},
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await b.commit();
  }

  /// Writes `catalog/v{n}`, moves the marker to it and clears the drafts it
  /// carried, with one audit entry. Reverting is pointing the marker back.
  Future<void> publish(
    Catalog next,
    CatalogDiff diff,
    List<CourseEdit> from,
  ) async {
    final b = _db.batch();
    final id = roles.logInto(
      b,
      path: 'catalog/marker',
      summary:
          'Published catalogue v${next.version}: ${diff.credits.length} credit, '
          '${diff.retired.length} retired, ${diff.added.length} new, '
          '${diff.cosmetic.length} other',
      campus: 'all',
      after: {
        'version': next.version,
        'credits': [for (final c in diff.credits) c.id],
        'retired': [for (final c in diff.retired) c.id],
        'added': [for (final c in diff.added) c.id],
      },
    );
    b.set(_db.collection('catalog').doc('v${next.version}'), {
      'version': next.version,
      'schema': next.schema,
      'json': next.toJson(),
    });
    b.set(_db.collection('catalog').doc('marker'), {
      'version': next.version,
      'schema': next.schema,
      'auditId': id,
    });
    setOnAllHeads(b, _db, {
      'catalog': next.version,
      'catalogSchema': next.schema,
    });
    for (final e in from) {
      b.update(_db.collection('courses').doc(e.id), {'draft': false});
    }
    await b.commit();
    // The head cache (heads.dart) is stale-while-revalidate for up to 6h:
    // on this device, the very next catalogue read — this owner's own
    // "did it publish" check included — would otherwise still see the old
    // version until that window passes (BUG-48).
    await forget('head|');
    skipWorkerUntil = DateTime.now().add(const Duration(minutes: 2));
  }
}
