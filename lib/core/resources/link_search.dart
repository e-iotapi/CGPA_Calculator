import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_ce/hive.dart';

/// Resource search (owner, 2026-10-06): names, links, departments and
/// courses, typo-tolerant, widened by a few built-in synonyms and by what
/// students taught it. A search that found nothing, followed within a
/// minute by one whose link they opened, is a vote for "the first means the
/// second"; five people agreeing make it count for everyone.

/// Lower case, letters and digits only, single spaces, at most 40.
String normQuery(String s) {
  final t = _clean(s);
  return t.length <= 40 ? t : t.substring(0, 40).trim();
}

String _clean(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Phrases that mean the same, built in so search helps from day one.
const _seeds = [
  ['pyq', 'pyqs', 'previous year', 'question paper', 'past paper'],
  ['notes', 'slides', 'lecture', 'ppt'],
  ['tut', 'tutorial'],
  ['lab', 'practical'],
  ['book', 'textbook', 'reference'],
  ['handout', 'course handout'],
  ['os', 'operating systems'],
  ['dsa', 'data structures'],
  ['ml', 'machine learning'],
];

/// Votes needed before a learned pair counts.
const hintVotes = 5;

/// What else [query] should find: the built-in synonyms and the learned
/// pairs either way. A learned alternative needs [hintVotes] votes and at
/// least half of the query's most voted one, so a stray jump never rides
/// along with the real meaning.
List<String> alsoSearch(String query, Map<String, Map<String, int>> learned) {
  final q = normQuery(query);
  if (q.isEmpty) return const [];
  List<String> strong(String k) {
    final alts = learned[k] ?? const {};
    if (alts.isEmpty) return const [];
    final top = alts.values.reduce((a, b) => a > b ? a : b);
    return [
      for (final e in alts.entries)
        if (e.value >= hintVotes && e.value * 2 >= top) e.key,
    ];
  }

  return {
    for (final group in _seeds)
      if (group.contains(q)) ...group,
    ...strong(q),
    for (final k in learned.keys)
      if (strong(k).contains(q)) k,
  }.where((s) => s != q).toList();
}

/// Within one edit (add, drop, change or swap two letters) of each other.
bool _near(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  var i = 0, j = 0, edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (b.length > a.length) {
      j++;
    } else if (i + 1 < a.length && a[i] == b[j + 1] && a[i + 1] == b[j]) {
      i += 2;
      j += 2;
    } else {
      i++;
      j++;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/// Whether every word of [phrase] is in [words]: a word starts with it, or
/// (four letters and up) contains it or is one typo from it.
bool _matches(String phrase, List<String> words, String all) => phrase
    .split(' ')
    .every(
      (t) =>
          words.any((w) => w.startsWith(t)) ||
          (t.length >= 4 && (all.contains(t) || words.any((w) => _near(t, w)))),
    );

/// The links matching [query] or one of [also], the query's own matches
/// first, title matches before the rest.
List<Resource> searchLinks(
  List<Resource> links,
  String query, {
  List<String> also = const [],
  required String Function(String courseId) courseTitle,
  required String Function(String dept) departmentName,
}) {
  final q = normQuery(query);
  if (q.isEmpty) return const [];
  final out = <Resource>[];
  final seen = <String>{};
  for (final phrase in [q, ...also.map(normQuery)]) {
    if (phrase.isEmpty) continue;
    final titled = <Resource>[], rest = <Resource>[];
    for (final r in links) {
      if (seen.contains(r.id)) continue;
      final title = _clean(r.title);
      final hay = _clean(
        [
          r.title,
          r.url,
          r.department,
          departmentName(r.department),
          for (final c in r.courseIds) ...[c, courseTitle(c)],
        ].join(' '),
      );
      if (!_matches(phrase, hay.split(' '), hay)) continue;
      (_matches(phrase, title.split(' '), title) ? titled : rest).add(r);
    }
    for (final r in [...titled, ...rest]) {
      seen.add(r.id);
      out.add(r);
    }
  }
  return out;
}

/// The learned pairs of a campus: `searchHints/{campus}` holds
/// `q: {query: {otherQuery: votes}}`, and `k`/`t` name the pair a write
/// moved (firestore.rules checks one +1 at a time).
class SearchHints {
  SearchHints(this._db, {Box? device}) : _device = device;
  final FirebaseFirestore _db;
  final Box? _device;

  DocumentReference<Map<String, dynamic>> _doc(String campus) =>
      _db.collection('searchHints').doc(campus);

  static Map<String, Map<String, int>> _decode(Object? o) => {
    for (final e in ((o as Map?) ?? const {}).entries)
      '${e.key}': {
        for (final a in (e.value as Map).entries)
          '${a.key}': (a.value as num).toInt(),
      },
  };

  /// Read at most every 3 hours: new pairs need no rush.
  Future<Map<String, Map<String, int>>> load(String campus) =>
      cacheFirst<Map<String, Map<String, int>>>(
        key: 'hints|$campus',
        maxAge: const Duration(hours: 3),
        fetch: () async => _decode((await _doc(campus).get()).data()?['q']),
        encode: (m) => m,
        decode: _decode,
      );

  Map<String, Map<String, int>>? peek(String campus) =>
      peekCache('hints|$campus', _decode);

  Box? get _box =>
      _device ??
      (Hive.isBoxOpen(deviceBoxName) ? Hive.box(deviceBoxName) : null);

  /// One vote for "[from] means [to]", once per device per pair. Failures
  /// are dropped: a lost vote costs nothing.
  Future<void> learn(String campus, String from, String to) async {
    final a = normQuery(from), b = normQuery(to);
    if (a.isEmpty || b.isEmpty || a == b) return;
    final mark = 'hint|$campus|$a|$b';
    if (_box?.get(mark) == true) return;
    await _box?.put(mark, true);
    try {
      await _doc(campus).set({
        'q': {
          a: {b: FieldValue.increment(1)},
        },
        'k': a,
        't': b,
      }, SetOptions(merge: true));
    } on Object {
      // ponytail: the campus list is capped at 500 queries; past it new
      // ones are refused, prune old ones if it fills.
    }
  }
}
