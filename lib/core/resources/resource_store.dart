import 'dart:convert';

import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

const resourcesBoxName = 'resourcesBox';

Future<void> openResources() => Hive.openBox(resourcesBoxName);

Box? get _cache =>
    Hive.isBoxOpen(resourcesBoxName) ? Hive.box(resourcesBoxName) : null;

/// `sha256(uid + id)` as lowercase hex: one report per person per link,
/// with nothing that links a person's reports together (§16.3 fix 3).
String reportId(String uid, String resourceId) =>
    sha256.convert(utf8.encode(uid + resourceId)).toString();

/// Resources and their reports (ARCHITECTURE.md §6, §16.3 fix 3). Students
/// read one department on one campus at a time, cached, re-read only when
/// `resourceVersions/{campus}` has moved; every write bumps it in the same
/// batch, with its audit entry.
class ResourceStore {
  ResourceStore(this.roles, {this.uid});
  final RoleStore roles;
  final String? uid;

  FirebaseFirestore get _db => roles.db;
  CollectionReference<Map<String, dynamic>> get _resources =>
      _db.collection('resources');

  DocumentReference<Map<String, dynamic>> _versions(String campus) =>
      _db.collection('resourceVersions').doc(campus);

  /// Every live link in [department] on [campus]; from the cache when the
  /// campus version has not moved. Offline, the cache as it stands.
  Future<List<Resource>> department(String campus, String department) async {
    final key = '$campus|$department';
    final cached = _cache?.get(key);
    List<Resource>? fromCache;
    int? cachedV;
    if (cached is String) {
      final m = jsonDecode(cached) as Map;
      cachedV = m['v'] as int;
      fromCache = [for (final r in m['rows'] as List) Resource.fromMap(r)];
    }
    try {
      // 1 read: the campus's version doc carries every live link.
      final vd = await Perf.time(
        'resources.version',
        () => _versions(campus).get(),
      );
      final v = (vd.data()?['v'] as num?)?.toInt() ?? 0;
      if (fromCache != null && v == cachedV) return fromCache;
      final List<Resource> rows;
      if (vd.data()?['links'] case final Map links) {
        rows = [
          for (final e in links.entries)
            if (Resource.fromMap({
                  ...e.value as Map,
                  'campus': campus,
                }, '${e.key}')
                case final r when r.department == department && !r.removed)
              r,
        ];
      } else {
        // ponytail: campuses whose links predate the index; drop once
        // every campus has been re-saved or backfilled.
        final q = await Perf.time(
          'resources.department',
          () =>
              _resources
                  .where('campus', isEqualTo: campus)
                  .where('department', isEqualTo: department)
                  .get(),
        );
        rows = [
          for (final d in q.docs)
            if (Resource.fromMap(d.data(), d.id) case final r when !r.removed)
              r,
        ];
      }
      await _cache?.put(
        key,
        jsonEncode({
          'v': v,
          'rows': [for (final r in rows) r.toMap()],
        }),
      );
      return rows;
    } on FirebaseException {
      if (fromCache != null) return fromCache;
      rethrow;
    }
  }

  /// Moves the campus version and, for [r], its copy in `links` (gone
  /// once removed).
  void _bump(WriteBatch b, String campus, [Resource? r, String? id]) {
    final m =
        r?.toMap()
          ?..remove('id')
          ..remove('campus')
          ..remove('removed');
    b.set(_versions(campus), {
      'v': FieldValue.increment(1),
      if (r != null) 'k': id ?? r.id,
      if (r != null) 'links': {id ?? r.id: r.removed ? FieldValue.delete() : m},
    }, SetOptions(merge: true));
  }

  /// Adds [r] (its id is ignored). [actingFor] is the course a CR adds it
  /// for; presidents and owners leave it null.
  Future<String> add(Resource r, {String? actingFor}) async {
    final ref = _resources.doc();
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'resources/${ref.id}',
      summary: 'Added “${r.title}” to ${r.fromCourse ?? r.department}',
      campus: r.campus,
      course: r.fromCourse,
      after: {'url': r.url},
    );
    b.set(ref, {
      ...r.toMap()..remove('id'),
      'addedBy': {'email': roles.me, 'name': roles.myName},
      'addedAt': FieldValue.serverTimestamp(),
      'auditId': audit,
      'actingFor': actingFor ?? '',
    });
    _bump(
      b,
      r.campus,
      Resource.fromMap({
        ...r.toMap(),
        'addedBy': {'name': roles.myName, 'email': roles.me},
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      }, ref.id),
      ref.id,
    );
    await b.commit();
    return ref.id;
  }

  /// Saves [next] over [before], logged as [summary]. Closes the link's
  /// open reports in the same batch when [closeFlag] (Fix the link).
  Future<void> update(
    Resource before,
    Resource next,
    String summary, {
    String? actingFor,
    bool closeFlag = false,
  }) async {
    final b = _db.batch();
    final path = 'resources/${next.id}';
    final audit = roles.logInto(
      b,
      path: path,
      summary: summary,
      campus: next.campus,
      course: actingFor ?? next.fromCourse,
      before: {'title': before.title, 'url': before.url},
      after: {'title': next.title, 'url': next.url},
    );
    b.update(_resources.doc(next.id), {
      'title': next.title,
      'url': next.url,
      'host': next.host,
      'kind': next.kind,
      'courseIds': next.courseIds,
      'pinnedToDepartment': next.pinnedToDepartment,
      'removed': next.removed,
      'auditId': audit,
      'actingFor': actingFor ?? '',
    });
    if (closeFlag) {
      b.update(_db.collection('resourceFlags').doc(next.id), {
        'open': false,
        'auditId': audit,
      });
    }
    _bump(b, next.campus, next);
    await b.commit();
  }

  /// Reports [r]. False when this person already reported it.
  Future<bool> report(Resource r, ReportReason reason, {String? note}) async {
    final u = uid;
    if (u == null) return false;
    final id = reportId(u, r.id);
    final flagRef = _db.collection('resourceFlags').doc(r.id);
    final entry = _db.doc('resourceReports/${r.id}/entries/$id');
    final old = (await flagRef.get()).data();
    final reasons = <String, int>{
      for (final e in (old?['reasons'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    };
    reasons[reason.name] = (reasons[reason.name] ?? 0) + 1;
    final b =
        _db.batch()
          ..set(entry, {
            'reason': reason.name,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            'campus': r.campus,
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(flagRef, {
            'campus': r.campus,
            'department': r.department,
            'courseIds': r.courseIds,
            'open': true,
            'count': ((old?['count'] as num?)?.toInt() ?? 0) + 1,
            'reasons': reasons,
            'lastAt': FieldValue.serverTimestamp(),
          });
    try {
      await b.commit();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Open reports in [department] on [campus], rolled-up course links
  /// included.
  Future<List<ResourceFlag>> flags(String campus, String department) async {
    final q =
        await _db
            .collection('resourceFlags')
            .where('campus', isEqualTo: campus)
            .where('department', isEqualTo: department)
            .where('open', isEqualTo: true)
            .get();
    return [for (final d in q.docs) ResourceFlag.fromMap(d.id, d.data())];
  }

  /// Open reports on [courseId]'s links, for its CR.
  Future<List<ResourceFlag>> courseFlags(String campus, String courseId) async {
    final q =
        await _db
            .collection('resourceFlags')
            .where('campus', isEqualTo: campus)
            .where('courseIds', arrayContains: courseId)
            .where('open', isEqualTo: true)
            .get();
    return [for (final d in q.docs) ResourceFlag.fromMap(d.id, d.data())];
  }

  /// It works · dismiss: closes the reports, logged.
  Future<void> dismiss(ResourceFlag f, String title) async {
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'resourceFlags/${f.resourceId}',
      summary:
          'Dismissed ${f.count} report${f.count == 1 ? '' : 's'} on '
          '“$title”',
      campus: f.campus,
      course: f.courseIds.firstOrNull,
    );
    b.update(_db.collection('resourceFlags').doc(f.resourceId), {
      'open': false,
      'auditId': audit,
    });
    await b.commit();
  }
}
