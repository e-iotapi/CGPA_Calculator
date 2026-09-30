/// Bulk upload of evaluation schemes as `pointer.eval.v1` JSON (ARCHITECTURE.md
/// §13.2). It behaves like the ERP importer, not a save button: parse, check
/// the whole file, then preview exactly what is created, changed and left
/// alone. One bad row rejects the file, and the error names the row.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/models/offering.dart';

/// The `schema` value an eval-scheme JSON file must carry.
const evalSchema = 'pointer.eval.v1';

/// Shipped beside the upload button. Verbatim from §13.2 — do not paraphrase:
/// "never invent a value" and "do not adjust them to fit" are what stop a
/// plausible, wrong scheme passing validation.
const evalPrompt =
    '''Read every attached course handout and return one JSON object and nothing else. No prose, no markdown fences, no explanation.

Use exactly this shape: `{"schema":"pointer.eval.v1","campus":…,"term":…,"courses":[…]}`. Each course is `{"code","professors","weighted","totalMarks","gradedOutOf","components","notes"}` and each component is `{"name","weight","outOf","date","rule","parts"}`.

Rules you must follow:
- **Never invent a value.** If the handout does not state something, leave the field out. Do not infer a weight from the other components, and do not assume a standard BITS split.
- Put anything you are unsure about in that course's `notes` field, in plain English.
- Use the course code exactly as printed, including the space: "CS F301", not "CSF301".
- `weighted` is true when components carry percentages, false when the course is marked out of a single total.
- `rule` is `{"type":"all"}` unless the handout says best N of M, which is `{"type":"bestNofM","n":N,"m":M}`.
- `outOf` is that component's own maximum, never a shared divisor.
- `gradedOutOf` is the scale the whole course's final total is reported out of (e.g. 200), only if the handout states one.
- Dates are `YYYY-MM-DD`. Omit the field if the handout gives no date.
- If weights do not sum to 100 on a weighted course, still return them as printed and say so in `notes`. Do not adjust them to fit.
- One entry per course. If a handout covers two sections with different schemes, return one course entry per scheme and note which section each is.''';

/// The file failed a check; nothing is imported. [message] names the row.
class EvalImportError implements Exception {
  const EvalImportError(this.message);

  /// What is wrong, naming the row.
  final String message;
  @override
  String toString() => message;
}

/// One course from the file, read into this term's offering shape.
class ImportedScheme {
  const ImportedScheme({
    required this.courseId,
    required this.weighted,
    required this.totalMarks,
    required this.components,
    this.notes,
    this.professorNames = const [],
    this.outOf,
  });

  /// The course the scheme is for.
  final String courseId;

  /// The course's "Graded out of" (`"gradedOutOf"` in the file), or null.
  final double? outOf;
  /// Whether component weights are percentages.
  final bool weighted;

  /// The total marks when the course is not weighted.
  final double totalMarks;

  /// Ids are blank until [schemeFor] matches them against the offering.
  final List<OfferedComponent> components;

  /// Remarks from the handout reader, shown before import.
  final String? notes;

  /// As typed in the handout. Professors are picked from the department list
  /// (§10.1), so these are shown, never stored.
  final List<String> professorNames;

  /// The sum of the component weights.
  double get assigned => components.fold(0.0, (s, c) => s + c.weight);
}

/// A parsed eval-scheme file: one campus and term, and its courses.
class EvalFile {
  const EvalFile({
    required this.campus,
    required this.term,
    required this.courses,
  });
  /// The campus key and term the file applies to.
  final String campus, term;

  /// The schemes in the file.
  final List<ImportedScheme> courses;
}

final _term = RegExp(r'^\d{4}-\d{2}-(1|2|S)$');
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses and checks [source]. [known] is every course id in the catalogue;
/// [inScope] says whether the uploader may write a course. Throws
/// [EvalImportError] on the first problem.
EvalFile parseEvalFile(
  String source, {
  required String campus,
  required bool Function(String id) known,
  required bool Function(String id) inScope,
}) {
  Object? root;
  try {
    root = jsonDecode(source.trim());
  } on FormatException catch (e) {
    throw EvalImportError('Not JSON: ${e.message}');
  }
  if (root is! Map) throw const EvalImportError('Expected one JSON object.');
  if (root['schema'] != evalSchema) {
    throw EvalImportError('"schema" must be "$evalSchema".');
  }
  final c = '${root['campus'] ?? ''}'.trim().toLowerCase();
  if (c != campus) {
    throw EvalImportError(
      '"campus" is "${root['campus']}", but you are uploading for $campus.',
    );
  }
  final term = '${root['term'] ?? ''}';
  if (!_term.hasMatch(term)) {
    throw EvalImportError(
      '"term" must look like 2026-27-1 (or -2, -S), not "$term".',
    );
  }
  final list = root['courses'];
  if (list is! List || list.isEmpty) {
    throw const EvalImportError('"courses" must be a non-empty list.');
  }

  final seen = <String, int>{};
  final out = <ImportedScheme>[];
  for (var i = 0; i < list.length; i++) {
    final row = list[i];
    String where([String? code]) =>
        'courses[$i]${code == null ? '' : ' ($code)'}';
    if (row is! Map) throw EvalImportError('${where()} is not an object.');
    final code = '${row['code'] ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (code.isEmpty) throw EvalImportError('${where()} has no "code".');
    final at = where(code);
    if (!known(code)) {
      throw EvalImportError('$at: no such course in the catalogue.');
    }
    if (!inScope(code)) {
      throw EvalImportError('$at is outside what you maintain.');
    }
    if (seen[code] case final j?) {
      throw EvalImportError(
        '$at appears again (first at courses[$j]). Keep one scheme per '
        'course — a term has one offering.',
      );
    }
    seen[code] = i;

    final weighted = row['weighted'] ?? true;
    if (weighted is! bool) {
      throw EvalImportError('$at: "weighted" must be true or false.');
    }
    final total = row['totalMarks'] ?? 100;
    if (total is! num || total <= 0) {
      throw EvalImportError('$at: "totalMarks" must be a positive number.');
    }
    final gradedOutOf = row['gradedOutOf'];
    if (gradedOutOf != null && (gradedOutOf is! num || gradedOutOf <= 0)) {
      throw EvalImportError('$at: "gradedOutOf" must be a positive number.');
    }
    final comps = row['components'];
    if (comps is! List || comps.isEmpty) {
      throw EvalImportError('$at: "components" must be a non-empty list.');
    }
    final components = <OfferedComponent>[];
    for (var k = 0; k < comps.length; k++) {
      components.add(_component(comps[k], '$at components[$k]'));
    }
    final names = components.map((c) => c.name.toLowerCase()).toList();
    if (names.toSet().length != names.length) {
      throw EvalImportError('$at: two components share a name.');
    }
    final profs = row['professors'];
    out.add(
      ImportedScheme(
        courseId: code,
        weighted: weighted,
        totalMarks: total.toDouble(),
        components: components,
        outOf: (gradedOutOf as num?)?.toDouble(),
        notes: switch (row['notes']) {
          final String n when n.trim().isNotEmpty => n.trim(),
          _ => null,
        },
        professorNames: [
          if (profs is List)
            for (final p in profs)
              if ('$p'.trim().isNotEmpty) '$p'.trim(),
        ],
      ),
    );
  }
  return EvalFile(campus: campus, term: term, courses: out);
}

OfferedComponent _component(Object? m, String at) {
  if (m is! Map) throw EvalImportError('$at is not an object.');
  final name = '${m['name'] ?? ''}'.trim();
  if (name.isEmpty) throw EvalImportError('$at has no "name".');
  final here = '$at ($name)';
  final weight = m['weight'];
  if (weight is! num || weight < 0) {
    throw EvalImportError(
      '$here: "weight" is missing. The handout must state it; the page '
      'never guesses one.',
    );
  }
  final date = m['date'];
  if (date != null && (date is! String || !_date.hasMatch(date))) {
    throw EvalImportError('$here: "date" must be YYYY-MM-DD.');
  }
  var countBest = 0;
  final rule = m['rule'] ?? const {'type': 'all'};
  if (rule is! Map) throw EvalImportError('$here: "rule" must be an object.');
  switch (rule['type']) {
    case 'all':
      break;
    case 'bestNofM':
      final n = rule['n'], mm = rule['m'];
      if (n is! int || mm is! int || n < 1 || n > mm) {
        throw EvalImportError('$here: bestNofM needs whole n ≤ m.');
      }
      countBest = n;
    default:
      throw EvalImportError('$here: "rule" type must be all or bestNofM.');
  }
  final parts = <OfferedPart>[];
  final rawParts = m['parts'];
  if (rawParts == null) {
    final outOf = m['outOf'];
    if (outOf is! num || outOf <= 0) {
      throw EvalImportError('$here: "outOf" must be a positive number.');
    }
    parts.add(
      OfferedPart(name: '', outOf: outOf.toDouble(), date: date as String?),
    );
  } else {
    if (rawParts is! List || rawParts.isEmpty) {
      throw EvalImportError('$here: "parts" must be a non-empty list.');
    }
    for (var j = 0; j < rawParts.length; j++) {
      final p = rawParts[j];
      final pAt = '$here parts[$j]';
      if (p is! Map) throw EvalImportError('$pAt is not an object.');
      final outOf = p['outOf'];
      if (outOf is! num || outOf <= 0) {
        throw EvalImportError('$pAt: "outOf" must be a positive number.');
      }
      final pDate = p['date'] ?? date;
      if (pDate != null && (pDate is! String || !_date.hasMatch(pDate))) {
        throw EvalImportError('$pAt: "date" must be YYYY-MM-DD.');
      }
      parts.add(
        OfferedPart(
          name: '${p['name'] ?? 'Part ${j + 1}'}'.trim(),
          outOf: outOf.toDouble(),
          date: pDate as String?,
        ),
      );
    }
  }
  if (countBest > parts.length) {
    throw EvalImportError('$here: best $countBest of ${parts.length} parts.');
  }
  return OfferedComponent(
    id: '',
    name: name,
    weight: weight.toDouble(),
    parts: parts,
    countBest: countBest,
  );
}

/// [imported] as this term's offering, keeping component ids (and so every
/// student's marks) where a component of the same name already exists (§5),
/// and the averages and professors already set.
Offering schemeFor(
  ImportedScheme imported, {
  required String campus,
  required String term,
  Offering? existing,
  String Function()? newId,
}) {
  final byName = {
    for (final c in existing?.components ?? const <OfferedComponent>[])
      c.name.toLowerCase(): c,
  };
  final used = <String>{};
  var n = 0;
  String fresh() {
    if (newId != null) return newId();
    String id;
    do {
      id = 'c${++n}';
    } while (byName.values.any((c) => c.id == id) || used.contains(id));
    return id;
  }

  return Offering(
    courseId: imported.courseId,
    campus: campus,
    term: term,
    weighted: imported.weighted,
    totalMarks: imported.totalMarks,
    components: [
      for (final c in imported.components)
        () {
          final old = byName[c.name.toLowerCase()];
          final id = old?.id ?? fresh();
          used.add(id);
          return OfferedComponent(
            id: id,
            name: c.name,
            weight: c.weight,
            parts: c.parts,
            countBest: c.countBest,
            average: old?.average,
          );
        }(),
    ],
    courseAverage: existing?.courseAverage,
    outOf: imported.outOf ?? existing?.outOf,
    professors: existing?.professors ?? const [],
    updatedAt: existing?.updatedAt ?? 0,
  );
}

/// What the file does to one course.
enum ImportEffect { create, change, same }

/// The scheme part of an offering, for comparing: what the file can change.
String schemeKey(Offering? o) =>
    o == null || !o.hasScheme
        ? ''
        : jsonEncode({
          'w': o.weighted,
          't': o.totalMarks,
          'o': o.outOf,
          'c': [
            for (final c in o.components)
              [
                c.id,
                c.name,
                c.weight,
                c.countBest,
                [
                  for (final p in c.parts) [p.name, p.outOf, p.date],
                ],
              ],
          ],
        });

/// What importing [next] does to the [existing] offering.
ImportEffect effectOf(Offering next, Offering? existing) =>
    existing == null || !existing.hasScheme
        ? ImportEffect.create
        : schemeKey(next) == schemeKey(existing)
        ? ImportEffect.same
        : ImportEffect.change;

/// Splits [items] into runs of [size] (§16.3 fix 11: five courses a batch).
List<List<T>> chunked<T>(List<T> items, [int size = 5]) => [
  for (var i = 0; i < items.length; i += size)
    items.sublist(i, i + size > items.length ? items.length : i + size),
];
