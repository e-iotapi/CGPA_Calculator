import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:cgpa_calculator/core/perf/perf.dart';
import 'package:cgpa_calculator/core/professors/professor.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/timings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// `professors/{id}` (ARCHITECTURE.md §10.1). Presidents in scope, admins
/// and owners add, rename and merge; CRs pick; students read. Every write
/// carries its audit entry.
class ProfessorStore {
  ProfessorStore(this.db, {this.roles});

  /// The Firestore instance read and written.
  final FirebaseFirestore db;

  /// Null for a student, who only reads.
  final RoleStore? roles;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection('professors');

  static final _names = <String, Professor>{};

  /// A department's professors on a campus, merged ones hidden.
  Future<List<Professor>> department(String campus, String department) async =>
      cacheFirst<List<Professor>>(
        key: 'prof|$campus|$department',
        maxAge: reviewIndexMaxAge,
        version: await markerOf(db, campus, Paths.professors(department)),
        fetch: () async {
          final q =
              await _col
                  .where('campus', isEqualTo: campus)
                  .where('department', isEqualTo: department)
                  .get();
          final all = [
            for (final d in q.docs) Professor.fromMap(d.id, d.data()),
          ];
          for (final p in all) {
            _names[p.id] = p;
          }
          return all.where((p) => !p.merged).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
        },
        encode: _encodeAll,
        decode: _decodeAll,
      );

  // The id is the document's, not a field: kept beside each map.
  static List<Object?> _encodeAll(List<Professor> l) => [
    for (final p in l) {'id': p.id, ...p.toMap()},
  ];

  static List<Professor> _decodeAll(Object? o) => [
    for (final m in o as List) Professor.fromMap((m as Map)['id'] as String, m),
  ];

  /// The saved [department], read synchronously; null when none is saved.
  List<Professor>? peekDepartment(String campus, String department) =>
      peekCache('prof|$campus|$department', _decodeAll);

  /// Professors on [campus] whose name or an alias matches [query], merged
  /// ones hidden. One indexed query on the most selective word, then every
  /// word checked here.
  Future<List<Professor>> search(
    String campus,
    String query, {
    int limit = 20,
  }) async {
    final tokens = nameTokens(query);
    if (tokens.isEmpty) return const [];
    final key = tokens.reduce((a, b) => b.length > a.length ? b : a);
    final q =
        await _col
            .where('campus', isEqualTo: campus)
            .where('nameTokens', arrayContains: key)
            .limit(limit)
            .get();
    final all = [for (final d in q.docs) Professor.fromMap(d.id, d.data())];
    for (final p in all) {
      _names[p.id] = p;
    }
    return all.where((p) => !p.merged && p.matches(query)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Every course [p] (and anyone merged into them) is recorded as teaching
  /// on [campus], with its terms, newest first.
  Future<Map<String, List<String>>> taught(Professor p, String campus) =>
      cacheFirst<Map<String, List<String>>>(
        key: 'taught|$campus|${p.id}',
        maxAge: reviewIndexMaxAge,
        fetch: () async {
          final q =
              await db
                  .collectionGroup('offerings')
                  .where('campus', isEqualTo: campus)
                  .where(
                    'professors',
                    arrayContainsAny: p.allIds.take(10).toList(),
                  )
                  .get();
          final out = <String, List<String>>{};
          for (final d in q.docs) {
            final m = d.data();
            if (m['courseId'] case final String c) {
              (out[c] ??= []).add(m['term'] as String? ?? '');
            }
          }
          for (final l in out.values) {
            l.sort((a, b) => b.compareTo(a));
          }
          return out;
        },
        encode: (m) => m,
        decode: _decodeTaught,
      );

  static Map<String, List<String>> _decodeTaught(Object? o) => {
    for (final e in (o as Map).entries)
      '${e.key}': [for (final t in e.value as List) '$t'],
  };

  /// The saved [taught], read synchronously; null when none is saved.
  Map<String, List<String>>? peekTaught(Professor p, String campus) =>
      peekCache('taught|$campus|${p.id}', _decodeTaught);

  /// One professor, following a merge to the survivor; cached for the
  /// session.
  // Budget: 1 read per not-yet-cached professor id (P0); cached across the
  // in-memory _names map for the session once loaded.
  Future<Professor?> get(String id) async {
    // The device cache (when open) is the session cache; _names stands in without it.
    var p = sharedCacheBox == null ? _names[id] : null;
    p ??= await cacheFirst<Professor?>(
      key: 'pid|$id',
      maxAge: reviewIndexMaxAge,
      fetch: () async {
        final d = await Perf.time('professors.get', () => _col.doc(id).get());
        final m = d.data();
        return m == null ? null : Professor.fromMap(id, m);
      },
      encode: (p) => p?.toMap(),
      decode: (o) => _decodeOne(id, o),
    );
    if (p == null) return null;
    _names[id] = p;
    final into = p.mergedInto;
    return into == null || into == id ? p : get(into);
  }

  static Professor? _decodeOne(String id, Object? o) =>
      o == null ? null : Professor.fromMap(id, o as Map);

  /// The saved [get] (without following a merge), read synchronously; null
  /// when none is saved.
  Professor? peekGet(String id) =>
      peekCache<Professor?>('pid|$id', (o) => _decodeOne(id, o));

  /// Whether [get] has saved an answer for [id], even "no such professor".
  bool peekSaved(String id) => sharedCacheBox?.containsKey('pid|$id') ?? false;

  /// The saved [get], following a merge to the survivor, read synchronously;
  /// null when it or the survivor is not saved.
  Professor? peekResolved(String id) {
    var p = peekGet(id);
    final seen = {id};
    // A merge cycle (a to b to a) ends at the first repeat.
    while (true) {
      final into = p?.mergedInto;
      if (into == null || !seen.add(into)) break;
      p = peekGet(into);
    }
    return p;
  }

  Future<void> _forget(String campus) async {
    await forget('prof|$campus|');
    await forget('pid|');
    await forget('taught|');
    await forget('audit|');
  }

  Map<String, dynamic> _stamp(RoleStore r, String auditId) => {
    'updatedBy': {'email': r.me, 'name': r.myName},
    'updatedAt': FieldValue.serverTimestamp(),
    'auditId': auditId,
  };

  /// Creates a professor in [department] on [campus], with an audit entry.
  ///
  /// Requires [roles].
  Future<Professor> add(String name, String campus, String department) async {
    final r = roles!;
    final ref = _col.doc();
    final b = db.batch();
    final audit = r.logInto(
      b,
      path: 'professors/${ref.id}',
      summary: 'Added professor $name to $department',
      campus: campus,
    );
    b.set(ref, {
      'name': name,
      'campus': campus,
      'department': department,
      'aliases': <String>[],
      'nameTokens': nameTokens(name).toList(),
      'mergedIds': <String>[],
      'active': true,
      ..._stamp(r, audit),
    });
    bumpPath(b, db, campus, Paths.professors(department));
    await b.commit();
    LiveHeads.poke(Paths.professors(department));
    await _forget(campus);
    return _names[ref.id] = Professor(
      id: ref.id,
      name: name,
      campus: campus,
      department: department,
    );
  }

  /// A rename keeps the id, so every review follows it; the old spelling
  /// stays findable as an alias.
  Future<void> rename(Professor p, String name) async {
    final r = roles!;
    final aliases = {...p.aliases, p.name}.toList();
    final b = db.batch();
    final audit = r.logInto(
      b,
      path: 'professors/${p.id}',
      summary: 'Renamed professor ${p.name} to $name',
      campus: p.campus,
    );
    b.update(_col.doc(p.id), {
      'name': name,
      'aliases': aliases,
      'nameTokens':
          {
            ...nameTokens(name),
            for (final a in aliases) ...nameTokens(a),
          }.toList(),
      ..._stamp(r, audit),
    });
    bumpPath(b, db, p.campus, Paths.professors(p.department));
    await b.commit();
    LiveHeads.poke(Paths.professors(p.department));
    await _forget(p.campus);
    _names.remove(p.id);
  }

  /// Merges [absorbed] into [keep] by pointer (§16.3 fix 7): the duplicate
  /// points at the survivor, the survivor lists it; nothing else is
  /// rewritten. One audited batch.
  Future<void> merge(Professor keep, Professor absorbed) async {
    final r = roles!;
    final b = db.batch();
    final audit = r.logInto(
      b,
      path: 'professors/${absorbed.id}',
      summary: 'Merged professor ${absorbed.name} into ${keep.name}',
      campus: keep.campus,
      after: {'mergedInto': keep.id},
    );
    b.update(_col.doc(absorbed.id), {
      'mergedInto': keep.id,
      'active': false,
      ..._stamp(r, audit),
    });
    final aliases = {...keep.aliases, absorbed.name, ...absorbed.aliases}
      ..remove(keep.name);
    b.update(_col.doc(keep.id), {
      'mergedIds':
          {...keep.mergedIds, absorbed.id, ...absorbed.mergedIds}.toList(),
      'aliases': aliases.toList(),
      'nameTokens':
          {
            ...nameTokens(keep.name),
            for (final a in aliases) ...nameTokens(a),
          }.toList(),
      ..._stamp(r, audit),
    });
    for (final p in {
      (keep.campus, keep.department),
      (absorbed.campus, absorbed.department),
    }) {
      bumpPath(b, db, p.$1, Paths.professors(p.$2));
    }
    await b.commit();
    LiveHeads.poke(Paths.professors(keep.department));
    LiveHeads.poke(Paths.professors(absorbed.department));
    await _forget(keep.campus);
    _names
      ..remove(keep.id)
      ..remove(absorbed.id);
  }
}
