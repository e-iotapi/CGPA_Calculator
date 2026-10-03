import 'dart:async';
import 'dart:convert';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';

/// The Hive box caching department resource lists.
const resourcesBoxName = 'resourcesBox';

/// Opens the [resourcesBoxName] box.
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

  /// The store whose identity and audit log the writes use.
  final RoleStore roles;

  /// The signed-in uid that salts [reportId], or `null` when signed out.
  final String? uid;

  FirebaseFirestore get _db => roles.db;
  CollectionReference<Map<String, dynamic>> get _resources =>
      _db.collection('resources');

  DocumentReference<Map<String, dynamic>> _versions(String campus) =>
      _db.collection('resourceVersions').doc(campus);

  /// The saved list for [department] on [campus], read synchronously; null
  /// when none is saved.
  List<Resource>? peekDepartment(String campus, String department) =>
      _live(_peekDepartment(campus, department));

  /// Unapproved links past their 15 days are hidden from everyone (B7).
  List<Resource>? _live(List<Resource>? rows) {
    if (rows == null) return null;
    final now = DateTime.now();
    return [
      for (final r in rows)
        if (!r.hiddenAt(now)) r,
    ];
  }

  List<Resource>? _peekDepartment(String campus, String department) {
    final cached = _cache?.get('$campus|$department');
    if (cached is! String) return null;
    try {
      return [
        for (final r in (jsonDecode(cached) as Map)['rows'] as List)
          Resource.fromMap(r),
      ];
    } on Object {
      return null;
    }
  }

  /// Every live link in [department] on [campus]: the saved list at once
  /// when the head's marker still matches it (the campus version is then
  /// re-checked in the background); the loaded list when the marker moved,
  /// the saved one if that fails; fetched when nothing is saved.
  Future<List<Resource>> department(String campus, String department) async =>
      _live(await _department(campus, department))!;

  Future<List<Resource>> _department(String campus, String department) async {
    final hit = _peekDepartment(campus, department);
    if (hit == null) return _load(campus, department);
    final saved = (jsonDecode(_cache!.get('$campus|$department') as String) as Map)['hv'];
    final marker = (await headFor(campus, db: _db))?.version(Paths.resources);
    if (marker != null && marker != saved) {
      try {
        return await _load(campus, department);
      } on Object {
        return hit;
      }
    }
    unawaited(_load(campus, department).then<void>((_) {}, onError: (Object _) {}));
    return hit;
  }

  /// A write on [campus] makes this device's saved lists stale at once.
  Future<void> _dropLocal(String campus) async {
    final c = _cache;
    if (c == null) return;
    await c.deleteAll(c.keys.where((k) => '$k'.startsWith('$campus|')).toList());
  }

  Future<List<Resource>> _load(String campus, String department) async {
    final key = '$campus|$department';
    final cached = _cache?.get(key);
    List<Resource>? fromCache;
    int? cachedV, cachedMarker;
    if (cached is String) {
      final m = jsonDecode(cached) as Map;
      cachedV = m['v'] as int;
      cachedMarker = m['hv'] as int?;
      fromCache = [for (final r in m['rows'] as List) Resource.fromMap(r)];
    }
    // The head's marker moves with every write here: unmoved, no read.
    final marker = (await headFor(campus, db: _db))?.version(Paths.resources);
    if (fromCache != null && marker != null && marker == cachedMarker) {
      return fromCache;
    }
    try {
      // 1 read: the campus's version doc carries every live link.
      final vd = await Perf.time(
        'resources.version',
        () => _versions(campus).get(),
      );
      final v = (vd.data()?['v'] as num?)?.toInt() ?? 0;
      if (fromCache != null && v == cachedV) {
        // Same links under a newer marker: remember it so the next open skips
        // this read.
        await _cache?.put(
          key,
          jsonEncode({
            'v': v,
            'hv': marker,
            'rows': [for (final r in fromCache) r.toMap()],
          }),
        );
        return fromCache;
      }
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
          'hv': marker,
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
          ..remove('removed')
          // The approval fields belong to the contributor flows: the merge
          // leaves the mirror's as they are.
          ..remove('approved')
          ..remove('publishedAt')
          ..remove('batchId')
          ..remove('rejectedReason');
    bumpPath(b, _db, campus, Paths.resources);
    b.set(_versions(campus), {
      'v': FieldValue.increment(1),
      if (r != null) 'k': id ?? r.id,
      if (r != null) 'links': {id ?? r.id: r.removed ? FieldValue.delete() : m},
    }, SetOptions(merge: true));
  }

  /// Adds [r] (its id is ignored). [actingFor] is the course a CR adds it
  /// for; presidents and owners leave it null.
  ///
  /// Staff links publish approved and earn their author +4 in the same
  /// batch (R-C). The points are optional: if the rules refuse them, the
  /// link is added without, exactly as before.
  Future<String> add(Resource r, {String? actingFor}) async {
    try {
      return await _add(r, actingFor: actingFor, points: true);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      return _add(r, actingFor: actingFor, points: false);
    }
  }

  Future<String> _add(
    Resource r, {
    String? actingFor,
    required bool points,
  }) async {
    final ref = _resources.doc();
    final b = _db.batch();
    if (points) await _award(b, r.campus, ref.id);
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
    LiveHeads.poke(Paths.resources);
    await _dropLocal(r.campus);
    return ref.id;
  }

  /// Writes +4 for my own approved [linkId] into [b]: the contributors
  /// doc, and the leaderboard once I have a username.
  Future<void> _award(WriteBatch b, String campus, String linkId) async {
    final ref = _db.collection('contributors').doc(roles.me);
    final c = (await ref.get()).data();
    final points = ((c?['points'] as num?)?.toInt() ?? 0) + 4;
    final username = c?['username'] as String? ?? '';
    if (c == null) {
      b.set(ref, {'campus': campus, 'points': points, 'lastLink': linkId});
    } else {
      b.update(ref, {'points': points, 'lastLink': linkId});
    }
    if (username.isNotEmpty) {
      b.set(_db.collection('leaderboard').doc(campus), {
        'p': {username: points},
        'k': username,
      }, SetOptions(merge: true));
      bumpPath(b, _db, campus, Paths.leaderboard);
    }
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
    LiveHeads.poke(Paths.resources);
    await _dropLocal(next.campus);
  }

  // ---- Contributors (B7) ---------------------------------------------------

  DocumentReference<Map<String, dynamic>> _pendingDoc(
    String campus,
    String dept,
  ) => _db.collection('pending').doc('$campus|$dept');

  Future<void> _afterPendingWrite(String campus, String dept) async {
    LiveHeads.poke(Paths.resources);
    LiveHeads.poke(Paths.pending(dept));
    await _dropLocal(campus);
    await forget('pend|');
    await forget('rmine|');
  }

  Future<String> _usernameOf() async =>
      ((await _db.collection('contributors').doc(roles.me).get())
              .data()?['username']
          as String?) ??
      '';

  /// Adds [r] as an unapproved link: live at once, listed for approval.
  /// [batchId] groups one submission; one commit per link (marker budget).
  Future<String> addAsContributor(
    Resource r, {
    String? batchId,
    String? username,
  }) async {
    final ref = _resources.doc();
    final bid = batchId ?? _resources.doc().id;
    final name = username ?? await _usernameOf();
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'resources/${ref.id}',
      summary: 'Submitted “${r.title}” to ${r.fromCourse ?? r.department}',
      campus: r.campus,
      course: r.fromCourse,
      after: {'url': r.url},
    );
    final data = r.toMap()..remove('id');
    b.set(ref, {
      ...data,
      'approved': false,
      'publishedAt': FieldValue.serverTimestamp(),
      'batchId': bid,
      'addedBy': {'email': roles.me, 'name': roles.myName},
      'addedAt': FieldValue.serverTimestamp(),
      'auditId': audit,
      'actingFor': '',
    });
    bumpPath(b, _db, r.campus, Paths.resources);
    bumpPath(b, _db, r.campus, Paths.pending(r.department));
    final copy =
        data
          ..remove('campus')
          ..remove('removed')
          ..remove('batchId')
          ..remove('rejectedReason');
    b.set(_versions(r.campus), {
      'v': FieldValue.increment(1),
      'k': ref.id,
      'links': {
        ref.id: {
          ...copy,
          'approved': false,
          'publishedAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));
    b.set(_pendingDoc(r.campus, r.department), {
      'batches': {
        bid: {
          'email': roles.me,
          'username': name,
          'at': FieldValue.serverTimestamp(),
          'links': {
            ref.id: {'title': r.title, 'url': r.url},
          },
        },
      },
      'b': bid,
      'k': ref.id,
    }, SetOptions(merge: true));
    await b.commit();
    await _afterPendingWrite(r.campus, r.department);
    return ref.id;
  }

  /// Submits [rs] as one batch: a commit per link, one shared batch id,
  /// returned. Stops and rethrows at the first failure.
  Future<String> addBatchAsContributor(List<Resource> rs) async {
    final bid = _resources.doc().id;
    final name = await _usernameOf();
    for (final r in rs) {
      await addAsContributor(r, batchId: bid, username: name);
    }
    return bid;
  }

  /// A contributor edits their own link: approval and window stay (an edited
  /// approved link stays approved, audited, no new points).
  Future<void> updateOwn(Resource r) async {
    final b = _db.batch();
    final audit = roles.logInto(
      b,
      path: 'resources/${r.id}',
      summary: 'Edited “${r.title}”',
      campus: r.campus,
      course: r.fromCourse,
      after: {'title': r.title, 'url': r.url},
    );
    b.update(_resources.doc(r.id), {
      'title': r.title,
      'url': r.url,
      'host': r.host,
      'kind': r.kind,
      'courseIds': r.courseIds,
      'pinnedToDepartment': r.pinnedToDepartment,
      'auditId': audit,
      'actingFor': '',
    });
    _bump(b, r.campus, r);
    // Still awaiting approval: the approvers' queue shows the new title/url.
    final queued = !r.approved && r.batchId.isNotEmpty;
    if (queued) {
      b.set(_pendingDoc(r.campus, r.department), {
        'batches': {
          r.batchId: {
            'links': {
              r.id: {'title': r.title, 'url': r.url},
            },
          },
        },
        'b': r.batchId,
        'k': r.id,
      }, SetOptions(merge: true));
      bumpPath(b, _db, r.campus, Paths.pending(r.department));
    }
    await b.commit();
    LiveHeads.poke(Paths.resources);
    await _dropLocal(r.campus);
    await forget('rmine|');
    if (queued) await _afterPendingWrite(r.campus, r.department);
  }

  /// The submissions awaiting a decision in [dept] on [campus], oldest
  /// first (approvers only).
  Future<List<PendingBatch>> pending(String campus, String dept) async =>
      cacheFirst<List<PendingBatch>>(
        key: 'pend|$campus|$dept',
        maxAge: const Duration(minutes: 5),
        version: await markerOf(_db, campus, Paths.pending(dept)),
        fetch: () async {
          final m = (await _pendingDoc(campus, dept).get()).data();
          final batches = (m?['batches'] as Map?) ?? const {};
          return [
            for (final e in batches.entries)
              if ((e.value as Map)['links'] case final Map ls
                  when ls.isNotEmpty)
                PendingBatch(
                  id: '${e.key}',
                  campus: campus,
                  dept: dept,
                  email: (e.value as Map)['email'] as String? ?? '',
                  username: (e.value as Map)['username'] as String? ?? '',
                  at:
                      asDate(
                        (e.value as Map)['at'],
                      )?.millisecondsSinceEpoch ??
                      0,
                  links: [
                    for (final l in ls.entries)
                      (
                        id: '${l.key}',
                        title: (l.value as Map)['title'] as String? ?? '',
                        url: (l.value as Map)['url'] as String? ?? '',
                      ),
                  ],
                ),
          ]..sort((a, b) => a.at - b.at);
        },
        encode: (l) => [for (final x in l) x.toMap()],
        decode: _decodePending,
      );

  static List<PendingBatch> _decodePending(Object? o) => [
    for (final m in o as List) PendingBatch.fromMap(m as Map),
  ];

  /// The saved [pending], read synchronously; null when none is saved.
  List<PendingBatch>? peekPending(String campus, String dept) =>
      peekCache('pend|$campus|$dept', _decodePending);

  /// Approves [linkIds] (default every link) of [b]: one commit per link
  /// (the rules' access limit, K1), +4 to the contributor each. Stops and
  /// rethrows at the first failure.
  Future<void> approve(PendingBatch b, {Iterable<String>? linkIds}) async {
    final ids = linkIds?.toSet() ?? {for (final l in b.links) l.id};
    var left = b.links.length;
    for (final l in b.links.where((l) => ids.contains(l.id))) {
      final ref = _db.collection('contributors').doc(b.email);
      final c = (await ref.get()).data();
      final points = ((c?['points'] as num?)?.toInt() ?? 0) + 4;
      final username = c?['username'] as String? ?? '';
      final wb = _db.batch();
      final audit = roles.logInto(
        wb,
        path: 'resources/${l.id}',
        summary: 'Approved “${l.title}”',
        campus: b.campus,
        after: {'approved': true},
      );
      wb.update(_resources.doc(l.id), {'approved': true, 'auditId': audit});
      wb.update(_versions(b.campus), {
        'v': FieldValue.increment(1),
        'k': l.id,
        'links.${l.id}.approved': true,
      });
      wb.update(_pendingDoc(b.campus, b.dept), {
        (left == 1 ? 'batches.${b.id}' : 'batches.${b.id}.links.${l.id}'):
            FieldValue.delete(),
        'b': b.id,
        'k': l.id,
      });
      if (c == null) {
        wb.set(ref, {
          'campus': b.campus,
          'points': points,
          'lastLink': l.id,
        });
      } else {
        wb.update(ref, {'points': points, 'lastLink': l.id});
      }
      bumpPath(wb, _db, b.campus, Paths.resources);
      bumpPath(wb, _db, b.campus, Paths.pending(b.dept));
      if (username.isNotEmpty) {
        wb.set(_db.collection('leaderboard').doc(b.campus), {
          'p': {username: points},
          'k': username,
        }, SetOptions(merge: true));
        bumpPath(wb, _db, b.campus, Paths.leaderboard);
      }
      await wb.commit();
      left--;
    }
    LiveHeads.poke(Paths.leaderboard);
    await _afterPendingWrite(b.campus, b.dept);
    await forget('lb|');
  }

  /// Rejects [linkIds] (default every link) of [b] with [reason]: the link
  /// is removed, no points.
  Future<void> reject(
    PendingBatch b, {
    Iterable<String>? linkIds,
    required String reason,
  }) async {
    final ids = linkIds?.toSet() ?? {for (final l in b.links) l.id};
    var left = b.links.length;
    for (final l in b.links.where((l) => ids.contains(l.id))) {
      final wb = _db.batch();
      final audit = roles.logInto(
        wb,
        path: 'resources/${l.id}',
        summary: 'Rejected “${l.title}”: $reason',
        campus: b.campus,
        after: {'removed': true},
      );
      wb.update(_resources.doc(l.id), {
        'removed': true,
        'rejectedReason': reason,
        'auditId': audit,
      });
      wb.update(_versions(b.campus), {
        'v': FieldValue.increment(1),
        'k': l.id,
        'links.${l.id}': FieldValue.delete(),
      });
      wb.update(_pendingDoc(b.campus, b.dept), {
        (left == 1 ? 'batches.${b.id}' : 'batches.${b.id}.links.${l.id}'):
            FieldValue.delete(),
        'b': b.id,
        'k': l.id,
      });
      bumpPath(wb, _db, b.campus, Paths.resources);
      bumpPath(wb, _db, b.campus, Paths.pending(b.dept));
      await wb.commit();
      left--;
    }
    await _afterPendingWrite(b.campus, b.dept);
  }

  /// The contributor's own links on [campus], pending, approved and
  /// rejected ones included.
  Future<List<Resource>> mine(String campus) => cacheFirst<List<Resource>>(
    key: 'rmine|$campus|${roles.me}',
    maxAge: const Duration(minutes: 5),
    fetch: () async {
      final q =
          await _resources
              .where('campus', isEqualTo: campus)
              .where('addedBy.email', isEqualTo: roles.me)
              .get();
      return [for (final d in q.docs) Resource.fromMap(d.data(), d.id)]
        ..sort((a, b) => b.addedAt - a.addedAt);
    },
    encode: (l) => [for (final r in l) r.toMap()],
    decode: _decodeMine,
  );

  static List<Resource> _decodeMine(Object? o) => [
    for (final m in o as List) Resource.fromMap(m as Map),
  ];

  /// The saved [mine], read synchronously; null when none is saved.
  List<Resource>? peekMine(String campus) =>
      peekCache('rmine|$campus|${roles.me}', _decodeMine);

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
